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

                    NavigationLink(destination: AppleCalendarSettingsView()) {
                        HStack {
                            Text("Apple Calendar")
                            Spacer()
                            if let tool = ToolRegistry.shared.tool(forName: "add_calendar_event"), tool.isEnabled {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    NavigationLink(destination: AppleRemindersSettingsView()) {
                        HStack {
                            Text("Apple Reminders")
                            Spacer()
                            if let tool = ToolRegistry.shared.tool(forName: "add_reminder"), tool.isEnabled {
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
                    NavigationLink(destination: OperationModeSettingsView()) {
                        Text("Operation Mode")
                    }

                    NavigationLink(destination: LanguageAndTimezoneSettingsView(configService: configService)) {
                        HStack {
                            Text("Language & Timezone")
                            Spacer()
                            Text("\(configService.responseLanguage == "ja" ? "日本語" : "English") • \(configService.timezone)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }

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
    @State private var isGoogleSearchAutoApproved = true

    var body: some View {
        Form {
            Section {
                Toggle("Enable Google Search", isOn: $isGoogleSearchEnabled)
                    .onChange(of: isGoogleSearchEnabled) { _, newValue in
                        ToolRegistry.shared.setToolEnabled("google_search", enabled: newValue)
                    }

                if isGoogleSearchEnabled {
                    Toggle("Auto-approve Google Search", isOn: $isGoogleSearchAutoApproved)
                        .onChange(of: isGoogleSearchAutoApproved) { _, newValue in
                            ToolRegistry.shared.setToolAutoApproval("google_search", autoApproval: newValue)
                        }
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
            // Initialize toggle states from current tool state
            if let googleSearchTool = ToolRegistry.shared.tool(forName: "google_search") {
                isGoogleSearchEnabled = googleSearchTool.isEnabled
                isGoogleSearchAutoApproved = googleSearchTool.autoApproval
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
    @State private var isListDirectoryAutoApproved = false
    @State private var isReadFileAutoApproved = false
    @State private var isCreateFileAutoApproved = false
    @State private var isWriteFileAutoApproved = false
    @State private var isSearchFilesAutoApproved = false

    var body: some View {
        Form {
            Section(header: Text("File System Tools")) {
                VStack(alignment: .leading) {
                    Toggle("List Directory", isOn: $isListDirectoryEnabled)
                        .onChange(of: isListDirectoryEnabled) { _, newValue in
                            ToolRegistry.shared.setToolEnabled("list_directory", enabled: newValue)
                        }

                    if isListDirectoryEnabled {
                        Toggle("Auto-approve List Directory", isOn: $isListDirectoryAutoApproved)
                            .onChange(of: isListDirectoryAutoApproved) { _, newValue in
                                ToolRegistry.shared.setToolAutoApproval("list_directory", autoApproval: newValue)
                            }
                            .padding(.leading)
                    }
                }

                VStack(alignment: .leading) {
                    Toggle("Read File", isOn: $isReadFileEnabled)
                        .onChange(of: isReadFileEnabled) { _, newValue in
                            ToolRegistry.shared.setToolEnabled("read_file", enabled: newValue)
                        }

                    if isReadFileEnabled {
                        Toggle("Auto-approve Read File", isOn: $isReadFileAutoApproved)
                            .onChange(of: isReadFileAutoApproved) { _, newValue in
                                ToolRegistry.shared.setToolAutoApproval("read_file", autoApproval: newValue)
                            }
                            .padding(.leading)
                    }
                }

                VStack(alignment: .leading) {
                    Toggle("Create File", isOn: $isCreateFileEnabled)
                        .onChange(of: isCreateFileEnabled) { _, newValue in
                            ToolRegistry.shared.setToolEnabled("create_file", enabled: newValue)
                        }

                    if isCreateFileEnabled {
                        Toggle("Auto-approve Create File", isOn: $isCreateFileAutoApproved)
                            .onChange(of: isCreateFileAutoApproved) { _, newValue in
                                ToolRegistry.shared.setToolAutoApproval("create_file", autoApproval: newValue)
                            }
                            .padding(.leading)
                    }
                }

                VStack(alignment: .leading) {
                    Toggle("Write File", isOn: $isWriteFileEnabled)
                        .onChange(of: isWriteFileEnabled) { _, newValue in
                            ToolRegistry.shared.setToolEnabled("write_file", enabled: newValue)
                        }

                    if isWriteFileEnabled {
                        Toggle("Auto-approve Write File", isOn: $isWriteFileAutoApproved)
                            .onChange(of: isWriteFileAutoApproved) { _, newValue in
                                ToolRegistry.shared.setToolAutoApproval("write_file", autoApproval: newValue)
                            }
                            .padding(.leading)
                    }
                }

                VStack(alignment: .leading) {
                    Toggle("Search Files", isOn: $isSearchFilesEnabled)
                        .onChange(of: isSearchFilesEnabled) { _, newValue in
                            ToolRegistry.shared.setToolEnabled("search_files", enabled: newValue)
                        }

                    if isSearchFilesEnabled {
                        Toggle("Auto-approve Search Files", isOn: $isSearchFilesAutoApproved)
                            .onChange(of: isSearchFilesAutoApproved) { _, newValue in
                                ToolRegistry.shared.setToolAutoApproval("search_files", autoApproval: newValue)
                            }
                            .padding(.leading)
                    }
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
            let enabledToggles = [$isListDirectoryEnabled, $isReadFileEnabled, $isCreateFileEnabled, $isWriteFileEnabled, $isSearchFilesEnabled]
            let autoApprovalToggles = [$isListDirectoryAutoApproved, $isReadFileAutoApproved, $isCreateFileAutoApproved, $isWriteFileAutoApproved, $isSearchFilesAutoApproved]

            for (index, toolName) in toolNames.enumerated() {
                if let tool = ToolRegistry.shared.tool(forName: toolName) {
                    enabledToggles[index].wrappedValue = tool.isEnabled
                    autoApprovalToggles[index].wrappedValue = tool.autoApproval
                }
            }
        }
    }
}

// MARK: - Apple Calendar Settings
struct AppleCalendarSettingsView: View {
    @State private var isAddEventEnabled = true
    @State private var isGetEventsEnabled = true
    @State private var isAddEventAutoApproved = false
    @State private var isGetEventsAutoApproved = false

    var body: some View {
        Form {
            Section(header: Text("Calendar Tools")) {
                VStack(alignment: .leading) {
                    Toggle("Add Calendar Event", isOn: $isAddEventEnabled)
                        .onChange(of: isAddEventEnabled) { _, newValue in
                            ToolRegistry.shared.setToolEnabled("add_calendar_event", enabled: newValue)
                        }

                    if isAddEventEnabled {
                        Toggle("Auto-approve Add Calendar Event", isOn: $isAddEventAutoApproved)
                            .onChange(of: isAddEventAutoApproved) { _, newValue in
                                ToolRegistry.shared.setToolAutoApproval("add_calendar_event", autoApproval: newValue)
                            }
                            .padding(.leading)
                    }
                }

                VStack(alignment: .leading) {
                    Toggle("Get Calendar Events", isOn: $isGetEventsEnabled)
                        .onChange(of: isGetEventsEnabled) { _, newValue in
                            ToolRegistry.shared.setToolEnabled("get_calendar_events", enabled: newValue)
                        }

                    if isGetEventsEnabled {
                        Toggle("Auto-approve Get Calendar Events", isOn: $isGetEventsAutoApproved)
                            .onChange(of: isGetEventsAutoApproved) { _, newValue in
                                ToolRegistry.shared.setToolAutoApproval("get_calendar_events", autoApproval: newValue)
                            }
                            .padding(.leading)
                    }
                }
            }

            Section {
                Text("These tools allow the AI to add events to and retrieve events from your Apple Calendar. Access permissions will be requested when first used.")
            } header: {
                Text("Information")
            }
        }
        .navigationTitle("Apple Calendar")
        .onAppear {
            // Initialize toggle states from current tool states
            let toolNames = ["add_calendar_event", "get_calendar_events"]
            let enabledToggles = [$isAddEventEnabled, $isGetEventsEnabled]
            let autoApprovalToggles = [$isAddEventAutoApproved, $isGetEventsAutoApproved]

            for (index, toolName) in toolNames.enumerated() {
                if let tool = ToolRegistry.shared.tool(forName: toolName) {
                    enabledToggles[index].wrappedValue = tool.isEnabled
                    autoApprovalToggles[index].wrappedValue = tool.autoApproval
                }
            }
        }
    }
}

// MARK: - Apple Reminders Settings
struct AppleRemindersSettingsView: View {
    @State private var isAddReminderEnabled = true
    @State private var isGetRemindersEnabled = true
    @State private var isAddReminderAutoApproved = false
    @State private var isGetRemindersAutoApproved = false

    var body: some View {
        Form {
            Section(header: Text("Reminders Tools")) {
                VStack(alignment: .leading) {
                    Toggle("Add Reminder", isOn: $isAddReminderEnabled)
                        .onChange(of: isAddReminderEnabled) { _, newValue in
                            ToolRegistry.shared.setToolEnabled("add_reminder", enabled: newValue)
                        }

                    if isAddReminderEnabled {
                        Toggle("Auto-approve Add Reminder", isOn: $isAddReminderAutoApproved)
                            .onChange(of: isAddReminderAutoApproved) { _, newValue in
                                ToolRegistry.shared.setToolAutoApproval("add_reminder", autoApproval: newValue)
                            }
                            .padding(.leading)
                    }
                }

                VStack(alignment: .leading) {
                    Toggle("Get Reminders", isOn: $isGetRemindersEnabled)
                        .onChange(of: isGetRemindersEnabled) { _, newValue in
                            ToolRegistry.shared.setToolEnabled("get_reminders", enabled: newValue)
                        }

                    if isGetRemindersEnabled {
                        Toggle("Auto-approve Get Reminders", isOn: $isGetRemindersAutoApproved)
                            .onChange(of: isGetRemindersAutoApproved) { _, newValue in
                                ToolRegistry.shared.setToolAutoApproval("get_reminders", autoApproval: newValue)
                            }
                            .padding(.leading)
                    }
                }
            }

            Section {
                Text("These tools allow the AI to add tasks to and retrieve tasks from your Apple Reminders. Access permissions will be requested when first used.")
            } header: {
                Text("Information")
            }
        }
        .navigationTitle("Apple Reminders")
        .onAppear {
            // Initialize toggle states from current tool states
            let toolNames = ["add_reminder", "get_reminders"]
            let enabledToggles = [$isAddReminderEnabled, $isGetRemindersEnabled]
            let autoApprovalToggles = [$isAddReminderAutoApproved, $isGetRemindersAutoApproved]

            for (index, toolName) in toolNames.enumerated() {
                if let tool = ToolRegistry.shared.tool(forName: toolName) {
                    enabledToggles[index].wrappedValue = tool.isEnabled
                    autoApprovalToggles[index].wrappedValue = tool.autoApproval
                }
            }
        }
    }
}

// MARK: - Operation Mode Settings
struct OperationModeSettingsView: View {
    @State private var currentMode: OperationMode = .act

    var body: some View {
        Form {
            Section(header: Text("Current Mode")) {
                Picker("Operation Mode", selection: $currentMode) {
                    Text("Plan Mode").tag(OperationMode.plan)
                    Text("Act Mode").tag(OperationMode.act)
                }
                .pickerStyle(.segmented)
            }

            Section {
                switch currentMode {
                case .plan:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Plan Mode")
                            .font(.headline)
                        Text("Focus on planning and understanding requirements. The AI will analyze codebases, explore files, and help you develop implementation strategies without making changes.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                case .act:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Act Mode")
                            .font(.headline)
                        Text("Execute the plan. The AI can make changes to your codebase, run commands, and implement the solutions you've planned.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Mode Description")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About Plan & Act")
                        .font(.headline)
                    Text("This mode system is inspired by Cline's approach to structured AI development. Plan mode helps you think through complex tasks, while Act mode executes the implementation.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Operation Mode")
        .onAppear {
            // Get current mode from a shared state or service if available
            // For now, default to Act mode
        }
    }
}

// MARK: - Language and Timezone Settings
struct LanguageAndTimezoneSettingsView: View {
    @Bindable var configService: KurokoConfigurationService

    // Common timezone identifiers
    private let commonTimezones = [
        ("Asia/Tokyo", "日本時間 (JST, UTC+9)"),
        ("America/New_York", "東部標準時 (EST, UTC-5)"),
        ("America/Los_Angeles", "太平洋標準時 (PST, UTC-8)"),
        ("Europe/London", "グリニッジ標準時 (GMT, UTC+0)"),
        ("Europe/Paris", "中央ヨーロッパ時間 (CET, UTC+1)"),
        ("Asia/Shanghai", "中国標準時 (CST, UTC+8)"),
        ("Australia/Sydney", "オーストラリア東部時間 (AEDT, UTC+10)"),
        ("America/Sao_Paulo", "ブラジル時間 (BRT, UTC-3)")
    ]

    var body: some View {
        Form {
            Section(header: Text("Language")) {
                Picker("Response Language", selection: $configService.responseLanguage) {
                    Text("日本語").tag("ja")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Timezone"), footer: Text("AI will use this timezone for date and time related questions.")) {
                Picker("Timezone", selection: $configService.timezone) {
                    ForEach(commonTimezones, id: \.0) { timezone in
                        Text(timezone.1).tag(timezone.0)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section(header: Text("Current Settings Preview")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Language:")
                        Spacer()
                        Text(configService.responseLanguage == "ja" ? "日本語" : "English")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Timezone:")
                        Spacer()
                        Text(commonTimezones.first { $0.0 == configService.timezone }?.1 ?? configService.timezone)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Current Time:")
                        Spacer()
                        Text(getCurrentTimeString())
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Language & Timezone")
    }

    private func getCurrentTimeString() -> String {
        let date = Date()
        let timezone = TimeZone(identifier: configService.timezone) ?? TimeZone.current

        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = configService.responseLanguage == "ja" ?
            "yyyy年M月d日 HH:mm:ss" : "MMM d, yyyy HH:mm:ss"

        return formatter.string(from: date)
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
