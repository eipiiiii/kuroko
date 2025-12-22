import SwiftUI
import MarkdownUI

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    @Environment(ThemeManager.self) private var themeManager

    @State private var appearAnimation = false

    private var userMessageBackground: Color {
        if themeManager.currentTheme == .monochrome {
            // ChatGPTスタイルの灰色（モノクロテーマ用）
            return Color(uiColor: .systemGray5)
        } else {
            return themeManager.mainColor
        }
    }

    private var userMessageTextColor: Color {
        if themeManager.currentTheme == .monochrome {
            // 灰色背景に対して読みやすい文字色
            return Color.primary
        } else {
            return themeManager.textColorOnMain
        }
    }

    var body: some View {
        Group {
            // iOS: Perplexity-style Layout
            if message.role == .user {
                HStack {
                    Spacer()
                    Text(message.text)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(userMessageTextColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(userMessageBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .frame(maxWidth: 300, alignment: .trailing)
                }
            } else if message.role == .tool {
                // Tool response - Cline-style design with detailed UI
                ToolMessageBubble(
                    message: message,
                    themeManager: themeManager
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    // Content
                    if message.text.isEmpty && message.isStreaming {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.secondary)
                            Text("考え中...")
                                .font(.caption)
                                .foregroundStyle(themeManager.textColor.opacity(0.8))
                        }
                        .padding(.leading, 4)
                    } else {
                        Markdown(message.text)
                            .id(message.id)
                            .markdownTextStyle {
                                FontSize(16)
                                ForegroundColor(themeManager.textColor)
                                FontWeight(.regular)
                            }
                            .markdownTheme(.gitHub.text {
                                ForegroundColor(themeManager.textColor)
                            }.link {
                                ForegroundColor(themeManager.accentColor)
                            })
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }

                    // Actions
                    if !message.isStreaming && !message.text.isEmpty {
                        HStack(spacing: 20) {
                            ActionButton(icon: "doc.on.doc")
                            ActionButton(icon: "arrowshape.turn.up.right")
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 15)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                appearAnimation = true
            }
    }
}
}

// MARK: - Tool Message Bubble

struct ToolMessageBubble: View {
    let message: ChatMessage
    let themeManager: ThemeManager

    @State private var isExpanded = true

    // Mock data for demonstration - in real implementation, this would come from ViewModel
    private var mockToolState: ToolExecutionState {
        ToolExecutionState(
            toolName: message.toolCalls?.first?.function.name ?? "unknown",
            toolType: toolTypeFromName(message.toolCalls?.first?.function.name),
            phase: message.isStreaming ? .executing : .completed,
            progress: message.isStreaming ? 0.5 : 1.0,
            currentStep: message.isStreaming ? "実行中..." : nil,
            metadata: ["query": "sample query"]
        )
    }

    private var parsedToolResult: AnyToolResult? {
        // Parse actual tool result from message.text
        guard let toolName = message.toolCalls?.first?.function.name else {
            return .raw(message.text)
        }

        switch toolName {
        case "search_web", "google_search":
            return parseSearchResult(message.text)
        case "read_file":
            return .fileOperation(FileOperationUIResult(
                operation: .read,
                filePath: extractFilePath(from: toolName, arguments: message.toolCalls?.first?.function.arguments),
                content: message.text,
                diff: nil
            ))
        case "run_terminal_cmd":
            return parseCodeExecutionResult(message.text)
        default:
            return .raw(message.text)
        }
    }

    private func parseSearchResult(_ text: String) -> AnyToolResult {
        // Parse Google search result format: "🔍 **Search Results:**\n\n1. **Title** - Snippet\n   Source: [domain](link)\n\n..."
        let lines = text.components(separatedBy: .newlines)
        var matches: [SearchResult.SearchMatch] = []
        var currentQuery = ""

        // Extract query if possible (currently using placeholder)
        currentQuery = "search query"

        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            // Look for numbered result lines
            if line.hasPrefix("1. ") || line.hasPrefix("2. ") || line.hasPrefix("3. ") ||
               line.hasPrefix("4. ") || line.hasPrefix("5. ") {

                var title = ""
                var snippet = ""
                var url = ""

                // Parse title and snippet
                if let titleStart = line.firstIndex(of: "*"), let titleEnd = line.lastIndex(of: "*") {
                    let titleRange = line.index(after: titleStart)..<titleEnd
                    title = String(line[titleRange])

                    // Extract snippet after " - "
                    if let dashRange = line.range(of: " - ") {
                        let snippetStart = line.index(dashRange.upperBound, offsetBy: 0)
                        snippet = String(line[snippetStart...])
                    }
                }

                // Look for source URL in next line
                if i + 1 < lines.count {
                    let nextLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
                    if nextLine.hasPrefix("Source: ") {
                        // Extract URL from markdown link: [domain](link)
                        if let linkStart = nextLine.range(of: "("),
                           let linkEnd = nextLine.range(of: ")", range: linkStart.upperBound..<nextLine.endIndex) {
                            let urlRange = nextLine.index(after: linkStart.lowerBound)..<linkEnd.lowerBound
                            url = String(nextLine[urlRange])
                        }
                    }
                }

                if !title.isEmpty && !url.isEmpty {
                    matches.append(SearchResult.SearchMatch(
                        fileOrUrl: url,
                        lineNumber: nil,
                        text: snippet.isEmpty ? title : "\(title) - \(snippet)",
                        ranges: [] // Highlighting not implemented yet
                    ))
                }

                i += 2 // Skip next line (source)
            } else {
                i += 1
            }
        }

        return .search(SearchResult(query: currentQuery, matches: matches))
    }

    private func parseCodeExecutionResult(_ text: String) -> AnyToolResult {
        // Parse command execution result
        // For now, assume stdout, no stderr, exit code 0
        return .codeExecution(CodeExecutionResult(
            command: "command", // Extract from tool arguments if available
            stdout: text,
            stderr: "",
            exitCode: 0
        ))
    }

    private func extractFilePath(from toolName: String, arguments: String?) -> String? {
        // Try to extract file path from tool arguments
        guard let arguments = arguments else { return nil }

        if let data = arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json["file_path"] as? String ?? json["path"] as? String
        }

        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            ToolHeader(state: mockToolState, themeManager: themeManager)

            if isExpanded {
                // Progress section (if executing)
                if mockToolState.phase == .executing || mockToolState.phase == .processingResult {
                    ProgressSection(state: mockToolState, themeManager: themeManager)
                }

                // Error section (if failed)
                if mockToolState.phase == .failed, let error = mockToolState.error {
                    ToolErrorView(error: error)
                } else if let result = parsedToolResult {
                    // Result section
                    ToolResultView(state: mockToolState, result: result)
                }

                // Raw content fallback
                if parsedToolResult == nil && !message.text.isEmpty && !message.isStreaming {
                    Markdown(message.text)
                        .markdownTextStyle {
                            FontSize(15)
                            ForegroundColor(themeManager.textColor)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }

            // Footer actions
            ToolFooter(state: mockToolState, themeManager: themeManager)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func toolTypeFromName(_ name: String?) -> ToolType {
        guard let name = name else { return .other }

        switch name {
        case "search_web", "google_search":
            return .search
        case "read_file", "list_dir", "run_terminal_cmd":
            return .fileOperation
        case "run_terminal_cmd":
            return .codeExecution
        default:
            return .other
        }
    }
}

// MARK: - Tool Header

struct ToolHeader: View {
    let state: ToolExecutionState
    let themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            // Tool icon
            ZStack {
                Circle()
                    .fill(iconColor(for: state.toolName, themeManager: themeManager).opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: iconName(for: state.toolName))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor(for: state.toolName, themeManager: themeManager))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(for: state.toolName))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(themeManager.textColor)

                HStack(spacing: 6) {
                    // Status indicator
                    statusIndicator(for: state.phase)

                    // Duration (if completed)
                    if let duration = state.executionDuration {
                        Text(String(format: "%.1fs", duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Expand/collapse button
            Button(action: {}) {
                Image(systemName: "chevron.down")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func statusIndicator(for phase: ToolExecutionPhase) -> some View {
        switch phase {
        case .starting, .executing, .processingResult:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                    .tint(.blue)
                Text("実行中")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        case .completed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 12))
                Text("完了")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 12))
                Text("失敗")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // Helper functions
    private func iconName(for toolName: String?) -> String {
        guard let toolName = toolName else { return "cpu" }

        switch toolName {
        case "search_web", "google_search":
            return "magnifyingglass"
        case "read_file", "list_dir", "run_terminal_cmd":
            return "folder"
        case "create_event", "get_events":
            return "calendar"
        case "create_reminder", "get_reminders":
            return "checklist"
        default:
            return "cpu"
        }
    }

    private func displayName(for toolName: String?) -> String {
        guard let toolName = toolName else { return "ツール実行" }

        switch toolName {
        case "search_web", "google_search":
            return "ウェブ検索"
        case "read_file":
            return "ファイル読み取り"
        case "list_dir":
            return "ディレクトリ一覧"
        case "run_terminal_cmd":
            return "ターミナル実行"
        case "create_event":
            return "イベント作成"
        case "get_events":
            return "イベント取得"
        case "create_reminder":
            return "リマインダー作成"
        case "get_reminders":
            return "リマインダー取得"
        default:
            return "ツール実行"
        }
    }

    private func iconColor(for toolName: String?, themeManager: ThemeManager) -> Color {
        guard let toolName = toolName else { return themeManager.accentColor }

        switch toolName {
        case "search_web", "google_search":
            return .blue
        case "read_file", "list_dir", "run_terminal_cmd":
            return .green
        case "create_event", "get_events":
            return .orange
        case "create_reminder", "get_reminders":
            return .purple
        default:
            return themeManager.accentColor
        }
    }
}

// MARK: - Progress Section

struct ProgressSection: View {
    let state: ToolExecutionState
    let themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: state.progress, total: 1.0)
                .progressViewStyle(.linear)
                .tint(.blue)

            if let step = state.currentStep {
                Text(step)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Tool Error View

struct ToolErrorView: View {
    let error: ToolErrorInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 16))

                Text("実行エラー")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
            }

            Text(error.message)
                .font(.caption)
                .foregroundStyle(.primary)

            if let details = error.debugDetails {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack {
                Spacer()
                Button("再実行") {
                    // Retry action
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Tool Footer

struct ToolFooter: View {
    let state: ToolExecutionState
    let themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 16) {
            ActionButton(icon: "doc.on.doc")
            ActionButton(icon: "arrowshape.turn.up.right")

            Spacer()

            if state.phase == .completed {
                Text("完了")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.top, 8)
    }
}
