import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
struct MacSettingsView: View {
    @Bindable var sessionManager: SessionManager
    
    var body: some View {
        TabView {
            MacGeneralSettingsView(sessionManager: sessionManager)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            MacAppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            MacModelSettingsView()
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }
            

            MacSystemPromptSettingsView()
                .tabItem {
                    Label("Instructions", systemImage: "text.quote")
                }
            
            MacSearchSettingsView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
        }
        .padding()
        .frame(width: 500, height: 450)
    }
}

struct MacGeneralSettingsView: View {
    @Bindable var sessionManager: SessionManager
    @State private var showingFolderPicker = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Conversation Save Location:")
                    Spacer()
                    Text(sessionManager.saveDirectoryURL?.lastPathComponent ?? "Not Selected")
                        .foregroundStyle(.secondary)
                    
                    Button("Choose...") {
                        showingFolderPicker = true
                    }
                }
            } header: {
                Text("Storage")
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    sessionManager.setSaveDirectory(url)
                }
            case .failure(let error):
                print("Folder selection error: \(error)")
            }
        }
    }
}

struct MacAppearanceSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        Form {
            Picker("Theme", selection: Bindable(themeManager).currentTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.inline)
            
            Text("Select your preferred color theme.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct MacModelSettingsView: View {
    @AppStorage("selectedProvider") private var selectedProvider: String = "gemini"
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Provider", selection: $selectedProvider) {
                Text("Gemini").tag("gemini")
                Text("OpenRouter").tag("openrouter")
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            if selectedProvider == "gemini" {
                MacGeminiSettingsView()
            } else {
                MacOpenRouterSettingsView()
            }
        }
    }
}

struct MacGeminiSettingsView: View {
    @AppStorage("apiKey") private var apiKey: String = ""
    @AppStorage("selectedModel") private var selectedModel: String = "gemini-1.5-flash-latest"
    
    let geminiModelOptions = [
        "gemini-1.5-flash-latest", "gemini-1.5-pro-latest", "gemini-1.0-pro",
    ]
    
    var body: some View {
        Form {
            TextField("API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
            
            Picker("Model", selection: $selectedModel) {
                ForEach(geminiModelOptions, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct MacOpenRouterSettingsView: View {
    @AppStorage("openRouterApiKey") private var openRouterApiKey: String = ""
    @AppStorage("selectedModel") private var selectedModel: String = "gemini-1.5-flash-latest"
    @AppStorage("openRouterModels") private var openRouterModelsData: Data = Data()
    
    @State private var isLoadingModels = false
    @State private var openRouterModels: [OpenRouterModel] = []
    
    var body: some View {
        Form {
            TextField("API Key", text: $openRouterApiKey)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Picker("Model", selection: $selectedModel) {
                    if openRouterModels.isEmpty {
                        Text("No models loaded").tag(selectedModel)
                    } else {
                        ForEach(openRouterModels) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                }
                
                if isLoadingModels {
                    ProgressView()
                    .controlSize(.small)
                } else {
                    Button(action: {
                        Task { await fetchOpenRouterModels() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(openRouterApiKey.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadSavedModels()
            if openRouterModels.isEmpty && !openRouterApiKey.isEmpty {
                Task { await fetchOpenRouterModels() }
            }
        }
    }
    
    private func fetchOpenRouterModels() async {
        guard !openRouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoadingModels = true
        defer { isLoadingModels = false }
        
        do {
            let url = URL(string: "https://openrouter.ai/api/v1/models")!
            var request = URLRequest(url: url)
            request.addValue("Bearer \(openRouterApiKey)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            let response = try decoder.decode(OpenRouterResponse.self, from: data)
            
            let sortedModels = response.data.sorted { $0.name.lowercased() < $1.name.lowercased() }
            self.openRouterModels = sortedModels
            
            if let encoded = try? JSONEncoder().encode(sortedModels) {
                openRouterModelsData = encoded
            }
        } catch {
            print("Failed to fetch or decode OpenRouter models: \(error)")
        }
    }
    
    private func loadSavedModels() {
        if let decoded = try? JSONDecoder().decode([OpenRouterModel].self, from: openRouterModelsData) {
            openRouterModels = decoded
        }
    }
}

struct MacSystemPromptSettingsView: View {
    @AppStorage("customPrompt") private var customPrompt: String = ""
    @State private var showSystemInstructions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Fixed System Instructions (Read-only)
            VStack(alignment: .leading, spacing: 8) {
                Text("System Instructions")
                    .font(.headline)
                Text("These are fixed instructions that ensure proper tool usage and response quality. They cannot be edited.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                DisclosureGroup("View System Instructions", isExpanded: $showSystemInstructions) {
                    ScrollView {
                        Text(KurokoViewModel.FIXED_SYSTEM_PROMPT)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .padding(8)
                    }
                    .frame(maxHeight: 150)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                }
            }
            
            Divider()
            
            // User Custom Instructions (Editable)
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Instructions")
                    .font(.headline)
                Text("Add your own instructions to customize the AI's behavior. These will be combined with the system instructions above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextEditor(text: $customPrompt)
                    .font(.body)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        .padding()
    }
}

struct MacSearchSettingsView: View {
    @AppStorage("googleSearchApiKey") private var googleSearchApiKey: String = ""
    @AppStorage("googleSearchEngineId") private var googleSearchEngineId: String = ""
    
    var body: some View {
        Form {
            Section {
                SecureField("API Key", text: $googleSearchApiKey)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Search Engine ID (CX)", text: $googleSearchEngineId)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Google Custom Search")
            } footer: {
                Text("These keys are required to enable web search capabilities for the model. API Key from Google Cloud Console, Search Engine ID from Programmable Search Engine.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
#endif
