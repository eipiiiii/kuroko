import SwiftUI
import UniformTypeIdentifiers

// MARK: - Data Models
// Shared models need to be internal/public for the separate MacSettingsView file to access them
struct OpenRouterModel: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let context_length: Int?
}

struct OpenRouterResponse: Decodable {
    let data: [OpenRouterModel]
}


// MARK: - Main Settings View
struct SettingsView: View {
    @Bindable var sessionManager: SessionManager

    var body: some View {
        IOSSettingsView(sessionManager: sessionManager)
    }
}

// MARK: - iOS Settings Implementation
struct IOSSettingsView: View {
    @AppStorage("selectedProvider") private var selectedProvider: String = "gemini"
    @AppStorage("selectedModel") private var selectedModel: String = "gemini-1.5-flash-latest"
    @Bindable var sessionManager: SessionManager
    @Environment(ThemeManager.self) private var themeManager
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Appearance")) {
                    NavigationLink(destination: ThemeSettingsView()) {
                        HStack {
                            Text("Theme")
                            Spacer()
                            Text(themeManager.currentTheme.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Model Provider")) {
                    NavigationLink(destination: GeminiSettingsView()) {
                        HStack {
                            Text("Gemini")
                            Spacer()
                            if selectedProvider == "gemini" {
                                Text(selectedModel)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    NavigationLink(destination: OpenRouterSettingsView()) {
                        HStack {
                            Text("OpenRouter")
                            Spacer()
                            if selectedProvider == "openrouter" {
                                Text(selectedModel)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }

                    
                    NavigationLink(destination: SearchSettingsView()) {
                         HStack {
                             Text("Search Config")
                             Spacer()
                             Image(systemName: "magnifyingglass")
                                 .foregroundStyle(.secondary)
                         }
                    }
                }
                
                Section(header: Text("Custom Instructions")) {
                   NavigationLink(destination: SystemPromptSettingsView()) {
                       Text("System Prompt")
                   }
                }
                
                Section(header: Text("File System")) {
                    NavigationLink(destination: FileAccessSettingsView(fileAccessManager: FileAccessManager.shared)) {
                        HStack {
                            Text("Working Directory")
                            Spacer()
                            if FileAccessManager.shared.workingDirectoryURL != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
                
                Section(header: Text("General")) {
                    NavigationLink(destination: ConversationHistorySettingsView(sessionManager: sessionManager)) {
                        Text("Conversation Save Location")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}


// MARK: - Gemini Settings
struct GeminiSettingsView: View {
    @AppStorage("apiKey") private var apiKey: String = ""
    @AppStorage("selectedModel") private var selectedModel: String = "gemini-1.5-flash-latest"
    @AppStorage("selectedProvider") private var selectedProvider: String = "gemini"
    
    @State private var searchQuery: String = ""

    let geminiModelOptions = [
        "gemini-1.5-flash-latest", "gemini-1.5-pro-latest", "gemini-1.0-pro",
    ]
    
    private var filteredModels: [String] {
        if searchQuery.isEmpty {
            return geminiModelOptions
        } else {
            return geminiModelOptions.filter { $0.lowercased().contains(searchQuery.lowercased()) }
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("API Key")) {
                SecureField("Enter Gemini API Key", text: $apiKey)
            }
            
            Section(header: Text("Model")) {
                Picker("Select Model", selection: $selectedModel) {
                    ForEach(filteredModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .onAppear {
            // When this view is active, ensure the provider is set to Gemini
            selectedProvider = "gemini"
        }
        .navigationTitle("Gemini")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $searchQuery, prompt: "Search Models")
    }
}


// MARK: - OpenRouter Settings
struct OpenRouterSettingsView: View {
    @AppStorage("openRouterApiKey") private var openRouterApiKey: String = ""
    @AppStorage("selectedModel") private var selectedModel: String = "gemini-1.5-flash-latest"
    @AppStorage("selectedProvider") private var selectedProvider: String = "gemini"
    @AppStorage("openRouterModels") private var openRouterModelsData: Data = Data()
    
    @State private var isLoadingModels = false
    @State private var openRouterModels: [OpenRouterModel] = []
    @State private var searchQuery: String = ""
    
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
        Form {
            Section(header: Text("API Key")) {
                SecureField("Enter OpenRouter API Key", text: $openRouterApiKey)
            }
            
            Section(header: Text("Model")) {
                modelSelectionView
            }
        }
        .onAppear {
            // When this view is active, ensure the provider is set to OpenRouter
            selectedProvider = "openrouter"
            loadSavedModels()
            // If models are not loaded and API key is present, fetch them
            if openRouterModels.isEmpty && !openRouterApiKey.isEmpty {
                Task {
                    await fetchOpenRouterModels()
                }
            }
        }
        .navigationTitle("OpenRouter")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $searchQuery, prompt: "Search Models")
    }
    
    @ViewBuilder
    private var modelSelectionView: some View {
        if isLoadingModels {
            HStack {
                ProgressView()
                Text("Loading Models...")
            }
        } else if openRouterModels.isEmpty {
            Button("Fetch Models") {
                Task {
                    await fetchOpenRouterModels()
                }
            }
            .disabled(openRouterApiKey.isEmpty)
        } else {
            Picker("Select Model", selection: $selectedModel) {
                ForEach(filteredOpenRouterModels) { model in
                    Text(model.name).tag(model.id)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }
    
    private func fetchOpenRouterModels() async {
        guard !openRouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
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


// MARK: - Conversation History Settings
struct ConversationHistorySettingsView: View {
    @Bindable var sessionManager: SessionManager
    @State private var showingFolderPicker = false
    
    var body: some View {
        Form {
            Section(header: Text("Save Location")) {
                HStack {
                    Image(systemName: "folder")
                    Text("Folder")
                    Spacer()
                    Text(sessionManager.saveDirectoryURL?.lastPathComponent ?? "Not Selected")
                        .foregroundStyle(.secondary)
                }
                Button("Select Folder...") {
                    showingFolderPicker = true
                }
            }
        }
        .navigationTitle("Save Location")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }
    
    private func handleFolderSelection(_ result: Result<[URL], Error>) {
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

// MARK: - Custom Instructions Settings
struct SystemPromptSettingsView: View {
    @AppStorage("customPrompt") private var customPrompt: String = ""
    @State private var showSystemInstructions = false
    
    var body: some View {
        Form {
            // Fixed System Instructions (Read-only)
            Section {
                DisclosureGroup("View System Instructions", isExpanded: $showSystemInstructions) {
                    ScrollView {
                        Text(APIConfigurationService.FIXED_SYSTEM_PROMPT)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 200)
                }
            } header: {
                Text("System Instructions")
            } footer: {
                Text("These are fixed instructions that ensure proper tool usage and response quality. They cannot be edited.")
                    .font(.caption)
            }
            
            // User Custom Instructions (Editable)
            Section {
                TextEditor(text: $customPrompt)
                    .frame(minHeight: 200)
            } header: {
                Text("Custom Instructions")
            } footer: {
                Text("Add your own instructions to customize the AI's behavior. These will be combined with the system instructions above.")
                    .font(.caption)
            }
        }
        .navigationTitle("Instructions")

        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Search Settings
struct SearchSettingsView: View {
    @AppStorage("googleSearchApiKey") private var googleSearchApiKey: String = ""
    @AppStorage("googleSearchEngineId") private var googleSearchEngineId: String = ""
    
    var body: some View {
        Form {
            Section {
                SecureField("API Key", text: $googleSearchApiKey)
                TextField("Search Engine ID (CX)", text: $googleSearchEngineId)
            } header: {
                Text("Google Custom Search")
            } footer: {
                Text("Required for web search capabilities. Get keys from Google Cloud Console and Programmable Search Engine.")
            }
        }
        .navigationTitle("Search")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct ThemeSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        Form {
            Section {
                ForEach(AppTheme.allCases) { theme in
                    Button(action: {
                        themeManager.currentTheme = theme
                    }) {
                        HStack {
                            Text(theme.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if themeManager.currentTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(themeManager.accentColor)
                            }
                        }
                    }
                }
            } header: {
                Text("App Theme")
            } footer: {
                Text("Select your preferred color theme.")
            }
        }
        .navigationTitle("Appearance")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    SettingsView(sessionManager: SessionManager())
        .environment(ThemeManager())
}
