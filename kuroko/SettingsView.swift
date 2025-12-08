import SwiftUI

// MARK: - OpenRouter Models
struct OpenRouterModel: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let pricing: Pricing?
    let context_length: Int?
    
    struct Pricing: Codable {
        let prompt: Double?
        let completion: Double?
        let request: Double?
    }
}

struct SettingsView: View {
    @AppStorage("apiKey") private var apiKey: String = ""
    @AppStorage("openRouterApiKey") private var openRouterApiKey: String = ""
    @AppStorage("selectedModel") private var selectedModel: String = "gemini-2.5-flash"
    @AppStorage("selectedProvider") private var selectedProvider: String = "gemini"
    @AppStorage("openRouterModels") private var openRouterModelsData: Data = Data()
    
    @Environment(\.dismiss) private var dismiss
    @State private var isLoadingModels = false
    @State private var openRouterModels: [OpenRouterModel] = []
    @State private var searchQuery: String = ""
    
    let providerOptions = ["gemini", "openrouter"]
    
    let geminiModelOptions = [
        // Gemini 2.5 Flash（最もバランスが良い）
        "gemini-2.5-flash",
        "gemini-2.5-flash-preview-09-2025",
        "gemini-flash-latest",
        
        // Gemini 2.5 Flash-Lite（コスト効率が良い）
        "gemini-2.5-flash-lite",
        "gemini-2.5-flash-lite-preview-09-2025",
        
        // Gemini 2.0 Flash（安定している）
        "gemini-2.0-flash",
        "gemini-2.0-flash-preview-09-2025",
        
        // Gemini 2.0 Flash-Lite（最も軽量）
        "gemini-2.0-flash-lite",
        "gemini-2.0-flash-lite-preview-09-2025",
        
        // Gemini 2.5 Pro（高性能）
        "gemini-2.5-pro",
        "gemini-2.5-pro-preview-09-2025",
        
        // Gemini 3 Pro（最新鋭）
        "gemini-3-pro"
    ]
    
    // フィルタリングされたOpenRouterモデル
    private var filteredOpenRouterModels: [OpenRouterModel] {
        if searchQuery.isEmpty {
            return openRouterModels
        } else {
            let query = searchQuery.lowercased()
            return openRouterModels.filter { model in
                model.name.lowercased().contains(query) ||
                model.id.lowercased().contains(query) ||
                (model.description?.lowercased().contains(query) ?? false)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("APIプロバイダー")) {
                    Picker("プロバイダーを選択", selection: $selectedProvider) {
                        ForEach(providerOptions, id: \.self) { provider in
                            Text(provider.capitalized).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if selectedProvider == "gemini" {
                    Section(header: Text("Gemini APIキー")) {
                        SecureField("Gemini APIキーを入力してください", text: $apiKey)
                    }
                    
                    Section(header: Text("Geminiモデル")) {
                        Picker("モデルを選択", selection: $selectedModel) {
                            ForEach(geminiModelOptions, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                } else {
                    Section(header: Text("OpenRouter APIキー")) {
                        SecureField("OpenRouter APIキーを入力してください", text: $openRouterApiKey)
                    }
                    
                    Section(header: Text("OpenRouterモデル")) {
                        if isLoadingModels {
                            HStack {
                                ProgressView()
                                Text("モデルを取得中...")
                                Spacer()
                            }
                        } else {
                            if openRouterModels.isEmpty {
                                Button("モデルを取得") {
                                    isLoadingModels = true
                                    Task {
                                        await fetchOpenRouterModels()
                                        isLoadingModels = false
                                    }
                                }
                            } else {
                                // 検索バー
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.gray)
                                    TextField("モデルを検索...", text: $searchQuery)
                                        .textFieldStyle(PlainTextFieldStyle())
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                
                                // 検索結果の件数表示
                                if !searchQuery.isEmpty {
                                    Text("検索結果: \(filteredOpenRouterModels.count)件")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // モデル選択
                                ScrollView {
                                    LazyVStack(spacing: 8) {
                                        ForEach(filteredOpenRouterModels, id: \.id) { model in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(model.name)
                                                        .font(.body)
                                                        .fontWeight(.medium)
                                                    if let description = model.description {
                                                        Text(description)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                            .lineLimit(2)
                                                    }
                                                    HStack {
                                                        Text(model.id)
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                        Spacer()
                                                        if let contextLength = model.context_length {
                                                            Text("Context: \(contextLength)")
                                                                .font(.caption2)
                                                                .foregroundColor(.secondary)
                                                        }
                                                    }
                                                }
                                                Spacer()
                                                Image(systemName: selectedModel == model.id ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(selectedModel == model.id ? .blue : .gray)
                                            }
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedModel = model.id
                                            }
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                                .frame(height: 300)
                            }
                        }
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if selectedProvider == "openrouter" && openRouterApiKey.isEmpty {
                // OpenRouter APIキーが空の場合はGeminiを選択
                selectedProvider = "gemini"
            }
            
            // 保存されたモデルを読み込む
            loadSavedModels()
        }
    }
    
    private func fetchOpenRouterModels() async {
        guard !openRouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        do {
            let url = URL(string: "https://openrouter.ai/api/v1/models")!
            var request = URLRequest(url: url)
            request.addValue("Bearer \(openRouterApiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            
            // OpenRouter APIの応答形式：{ data: [{...}, {...}] }
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]] {
                
                var models: [OpenRouterModel] = []
                for modelData in dataArray {
                    if let id = modelData["id"] as? String,
                       let name = modelData["name"] as? String {
                        let model = OpenRouterModel(
                            id: id,
                            name: name,
                            description: modelData["description"] as? String,
                            pricing: nil, // 簡略化
                            context_length: modelData["context_length"] as? Int
                        )
                        models.append(model)
                    }
                }
                
                let sortedModels = models.sorted { $0.name < $1.name }
                openRouterModels = sortedModels
                
                // UserDefaultsに保存
                if let encoded = try? JSONEncoder().encode(sortedModels) {
                    openRouterModelsData = encoded
                }
            }
        } catch {
            print("OpenRouterモデル取得エラー: \(error)")
        }
    }
    
    private func loadSavedModels() {
        if let decoded = try? JSONDecoder().decode([OpenRouterModel].self, from: openRouterModelsData) {
            openRouterModels = decoded
        }
    }
}

#Preview {
    SettingsView()
}
