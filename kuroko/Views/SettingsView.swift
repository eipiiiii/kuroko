import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main Settings View
public struct SettingsView: View {
    @Bindable var sessionManager: SessionManager
    // The single source of truth for configuration
    @State private var configService = KurokoConfigurationService.shared
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    private var isFileSystemEnabled: Bool {
        let fileSystemTools = ["list_directory", "read_file", "create_file", "write_file", "search_files"]
        return fileSystemTools.contains { toolName in
            ToolRegistry.shared.tool(forName: toolName)?.isEnabled ?? false
        }
    }

    public var body: some View {
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

                Section(header: Text("Model")) {
                    NavigationLink(destination: ModelSettingsView(configService: configService)) {
                        HStack {
                            Text("OpenRouter") // Provider name
                            Spacer()
                            Text(configService.selectedModel.displayName)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }

                Section(header: Text("Tools")) {
                    NavigationLink(destination: SearchSettingsView(configService: configService)) {
                        HStack {
                            Text("Google Search")
                            Spacer()
                            if let tool = ToolRegistry.shared.tool(forName: "google_search"), tool.isEnabled {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    NavigationLink(destination: FileSystemSettingsView()) {
                        HStack {
                            Text("File System")
                            Spacer()
                            if isFileSystemEnabled {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                Section(header: Text("Custom Instructions")) {
                   NavigationLink(destination: SystemPromptSettingsView(configService: configService)) {
                       Text("System Prompt")
                   }
                }

                Section(header: Text("File System")) {
                    NavigationLink(destination: FileAccessSettingsView(fileAccessManager: FileAccessManager.shared)) {
                        HStack {
                            Text("Working Directory")
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
                        configService.saveConfiguration()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                configService.saveConfiguration()
            }
        }
    }
}

// MARK: - Model Settings
struct ModelSettingsView: View {
    @Bindable var configService: KurokoConfigurationService
    @State private var searchQuery = ""

    private var filteredModels: [LLMModel] {
        if searchQuery.isEmpty {
            return configService.availableModels
        } else {
            let query = searchQuery.lowercased()
            return configService.availableModels.filter {
                $0.displayName.lowercased().contains(query) || $0.modelName.lowercased().contains(query)
            }
        }
    }

    var body: some View {
        Form {
            Section(header: Text("API Key")) {
                SecureField("Enter OpenRouter API Key", text: $configService.openRouterApiKey)
            }

            Section {
                if configService.isFetchingModels {
                    HStack {
                        ProgressView()
                        Text("Fetching Models...")
                    }
                } else {
                    Button("Fetch Available Models") {
                        Task {
                            await configService.fetchOpenRouterModels()
                        }
                    }
                    .disabled(configService.openRouterApiKey.isEmpty)
                }
            }

            Section(header: Text("Available Models")) {
                Picker("Selected Model", selection: $configService.selectedModelId) {
                    ForEach(filteredModels) { model in
                        Text(model.displayName).tag(model.modelName)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("OpenRouter Models")
        .searchable(text: $searchQuery, prompt: "Search models")
        .onAppear {
            if configService.availableModels.isEmpty && !configService.openRouterApiKey.isEmpty {
                Task {
                    await configService.fetchOpenRouterModels()
                }
            }
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
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        if case .success(let urls) = result, let url = urls.first {
            sessionManager.setSaveDirectory(url)
        }
    }
}

// MARK: - Custom Instructions Settings
struct SystemPromptSettingsView: View {
    @Bindable var configService: KurokoConfigurationService
    @State private var showSystemInstructions = false

    var body: some View {
        Form {
            Section {
                DisclosureGroup("View System Instructions", isExpanded: $showSystemInstructions) {
                    ScrollView {
                        Text(KurokoConfigurationService.FIXED_SYSTEM_PROMPT)
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
                Text("These fixed instructions ensure proper tool usage and response quality.")
            }

            Section {
                TextEditor(text: $configService.customPrompt)
                    .frame(minHeight: 200)
            } header: {
                Text("Custom Instructions")
            } footer: {
                Text("Add your own instructions to customize the AI's behavior.")
            }
        }
        .navigationTitle("Instructions")
    }
}

// MARK: - Search Settings
struct SearchSettingsView: View {
    @Bindable var configService: KurokoConfigurationService
    @State private var isGoogleSearchEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle("Enable Google Search", isOn: $isGoogleSearchEnabled)
                    .onChange(of: isGoogleSearchEnabled) { _, newValue in
                        ToolRegistry.shared.setToolEnabled("google_search", enabled: newValue)
                    }
            } header: {
                Text("Tool Settings")
            }

            Section {
                SecureField("Google API Key", text: $configService.googleSearchApiKey)
                TextField("Search Engine ID (CX)", text: $configService.googleSearchEngineId)
            } header: {
                Text("Google Custom Search")
            } footer: {
                Text("Required for web search capabilities.")
            }
        }
        .navigationTitle("Search")
        .onAppear {
            // Initialize toggle state from current tool state
            if let googleSearchTool = ToolRegistry.shared.tool(forName: "google_search") {
                isGoogleSearchEnabled = googleSearchTool.isEnabled
            }
        }
    }
}

// MARK: - File System Settings
struct FileSystemSettingsView: View {
    @State private var isListDirectoryEnabled = true
    @State private var isReadFileEnabled = true
    @State private var isCreateFileEnabled = true
    @State private var isWriteFileEnabled = true
    @State private var isSearchFilesEnabled = true

    var body: some View {
        Form {
            Section(header: Text("File System Tools")) {
                Toggle("List Directory", isOn: $isListDirectoryEnabled)
                    .onChange(of: isListDirectoryEnabled) { _, newValue in
                        ToolRegistry.shared.setToolEnabled("list_directory", enabled: newValue)
                    }

                Toggle("Read File", isOn: $isReadFileEnabled)
                    .onChange(of: isReadFileEnabled) { _, newValue in
                        ToolRegistry.shared.setToolEnabled("read_file", enabled: newValue)
                    }

                Toggle("Create File", isOn: $isCreateFileEnabled)
                    .onChange(of: isCreateFileEnabled) { _, newValue in
                        ToolRegistry.shared.setToolEnabled("create_file", enabled: newValue)
                    }

                Toggle("Write File", isOn: $isWriteFileEnabled)
                    .onChange(of: isWriteFileEnabled) { _, newValue in
                        ToolRegistry.shared.setToolEnabled("write_file", enabled: newValue)
                    }

                Toggle("Search Files", isOn: $isSearchFilesEnabled)
                    .onChange(of: isSearchFilesEnabled) { _, newValue in
                        ToolRegistry.shared.setToolEnabled("search_files", enabled: newValue)
                    }
            }

            Section {
                NavigationLink(destination: FileAccessSettingsView(fileAccessManager: FileAccessManager.shared)) {
                    Text("Configure Working Directory")
                }
            } header: {
                Text("Settings")
            } footer: {
                Text("File system tools require a working directory to be set.")
            }
        }
        .navigationTitle("File System")
        .onAppear {
            // Initialize toggle states from current tool states
            let toolNames = ["list_directory", "read_file", "create_file", "write_file", "search_files"]
            let toggles = [$isListDirectoryEnabled, $isReadFileEnabled, $isCreateFileEnabled, $isWriteFileEnabled, $isSearchFilesEnabled]

            for (index, toolName) in toolNames.enumerated() {
                if let tool = ToolRegistry.shared.tool(forName: toolName) {
                    toggles[index].wrappedValue = tool.isEnabled
                }
            }
        }
    }
}

// MARK: - Theme Settings
struct ThemeSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Form {
            Section(header: Text("App Theme")) {
                ForEach(AppTheme.allCases) { theme in
                    Button(action: { themeManager.currentTheme = theme }) {
                        HStack {
                            Text(theme.displayName).foregroundStyle(.primary)
                            Spacer()
                            if themeManager.currentTheme == theme {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Theme")
    }
}

#Preview {
    // To preview, we need to provide the necessary environment objects
    struct PreviewWrapper: View {
        @State private var sessionManager = SessionManager()
        @State private var themeManager = ThemeManager()

        var body: some View {
            SettingsView(sessionManager: sessionManager)
                .environment(themeManager)
        }
    }
    return PreviewWrapper()
}
