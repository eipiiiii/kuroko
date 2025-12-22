import SwiftUI
import MarkdownUI

// MARK: - Tool Result View

/// Main view that dispatches to specific tool result views
struct ToolResultView: View {
    let state: ToolExecutionState
    let result: AnyToolResult?

    var body: some View {
        switch (state.toolType, result) {
        case (.fileOperation, .fileOperation(let r)):
            FileOperationView(state: state, result: r)
        case (.search, .search(let r)):
            SearchResultView(state: state, result: r)
        case (.codeExecution, .codeExecution(let r)):
            CodeExecutionView(state: state, result: r)
        default:
            DefaultToolResultView(state: state, result: result)
        }
    }
}

// MARK: - File Operation View

struct FileOperationView: View {
    let state: ToolExecutionState
    let result: FileOperationUIResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch result.operation {
            case .read:
                if let content = result.content {
                    CodeAccordionView(
                        title: result.filePath ?? "ファイル",
                        subtitle: "読み取り結果",
                        language: languageFromPath(result.filePath),
                        content: .full(content)
                    )
                }
            case .edit:
                if let diff = result.diff {
                    CodeAccordionView(
                        title: result.filePath ?? "ファイル",
                        subtitle: "編集差分",
                        language: languageFromPath(result.filePath),
                        content: .diff(diff)
                    )
                }
            case .list:
                if let content = result.content {
                    CodeAccordionView(
                        title: state.metadata["directory"] ?? "ディレクトリ",
                        subtitle: "ファイル一覧",
                        language: "shell-session",
                        content: .full(content)
                    )
                }
            default:
                if let content = result.content {
                    CodeAccordionView(
                        title: result.filePath ?? "ファイル",
                        subtitle: result.operation.rawValue,
                        language: languageFromPath(result.filePath),
                        content: .full(content)
                    )
                }
            }
        }
    }

    private func languageFromPath(_ path: String?) -> String {
        guard let path = path else { return "text" }
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "jsx", "ts", "tsx": return "javascript"
        case "py": return "python"
        case "md": return "markdown"
        case "json": return "json"
        case "xml", "html": return "xml"
        default: return "text"
        }
    }
}

// MARK: - Search Result View

struct SearchResultView: View {
    let state: ToolExecutionState
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(result.matches, id: \.fileOrUrl) { match in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.blue)
                        Text(match.fileOrUrl)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        if let lineNumber = match.lineNumber {
                            Text("行 \(lineNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Highlight matched text
                    if let attributedText = highlightMatches(in: match.text, ranges: match.ranges) {
                        Text(attributedText)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(3)
                    } else {
                        Text(match.text)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(3)
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func highlightMatches(in text: String, ranges: [SearchResult.SearchMatch.RangeInfo]) -> AttributedString? {
        var attributedString = AttributedString(text)
        for range in ranges {
            let startIndex = text.index(text.startIndex, offsetBy: range.start)
            let endIndex = text.index(text.startIndex, offsetBy: range.end)
            let nsRange = NSRange(startIndex..<endIndex, in: text)

            if let range = Range(nsRange, in: attributedString) {
                attributedString[range].backgroundColor = .yellow.opacity(0.3)
                attributedString[range].foregroundColor = .primary
            }
        }
        return attributedString
    }
}

// MARK: - Code Execution View

struct CodeExecutionView: View {
    let state: ToolExecutionState
    let result: CodeExecutionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Command header
            HStack {
                Image(systemName: "terminal")
                    .foregroundStyle(.green)
                Text("$ \(result.command)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                Spacer()
                Text("終了コード: \(result.exitCode)")
                    .font(.caption)
                    .foregroundStyle(result.exitCode == 0 ? .green : .red)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Output sections
            if !result.stdout.isEmpty {
                ExpandableContentView(
                    title: "標準出力",
                    content: result.stdout,
                    language: "shell-session"
                )
            }

            if !result.stderr.isEmpty {
                ExpandableContentView(
                    title: "エラー出力",
                    content: result.stderr,
                    language: "shell-session",
                    isError: true
                )
            }
        }
    }
}

// MARK: - Default Tool Result View

struct DefaultToolResultView: View {
    let state: ToolExecutionState
    let result: AnyToolResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if case .raw(let content) = result {
                Markdown(content)
                    .markdownTextStyle {
                        FontSize(14)
                        ForegroundColor(.primary)
                    }
            } else {
                Text("ツール実行完了")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Expandable Content View

struct ExpandableContentView: View {
    let title: String
    let content: String
    let language: String
    let isError: Bool

    init(title: String, content: String, language: String, isError: Bool = false) {
        self.title = title
        self.content = content
        self.language = language
        self.isError = isError
    }

    @State private var isExpanded = false

    private var shouldAutoExpand: Bool {
        content.components(separatedBy: .newlines).count <= 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundStyle(isError ? .red : .secondary)
                    Text(title)
                        .fontWeight(.medium)
                        .foregroundStyle(isError ? .red : .primary)
                    Spacer()
                    Text("\(content.components(separatedBy: .newlines).count) 行")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)

            if isExpanded || shouldAutoExpand {
                Divider()
                ScrollView {
                    CodeBlock(
                        source: content,
                        language: language
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: shouldAutoExpand ? nil : 200)
                .background(Color.secondary.opacity(0.05))
            }
        }
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            isExpanded = shouldAutoExpand
        }
    }
}

// MARK: - Code Accordion View

struct CodeAccordionView: View {
    let title: String
    let subtitle: String?
    let language: String
    let content: CodeContent

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Status indicator
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                ScrollView {
                    switch content {
                    case .full(let text):
                        CodeBlock(source: text, language: language)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)

                    case .diff(let diff):
                        DiffView(diff: diff, language: language)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }
                .frame(maxHeight: 400)
                .background(Color.secondary.opacity(0.05))
            }
        }
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Code Content

enum CodeContent {
    case full(String)
    case diff(DiffModel)
}

// MARK: - Diff View

struct DiffView: View {
    let diff: DiffModel
    let language: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(diff.hunks, id: \.self) { hunk in
                VStack(alignment: .leading, spacing: 0) {
                    Text("@@ -\(hunk.oldStart),\(hunk.oldLines) +\(hunk.newStart),\(hunk.newLines) @@")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.secondary.opacity(0.1))

                    ForEach(hunk.lines.indices, id: \.self) { index in
                        let line = hunk.lines[index]
                        HStack(spacing: 0) {
                            // Line prefix (+, -, space)
                            Text(line.prefix(1))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(line.hasPrefix("+") ? .green : line.hasPrefix("-") ? .red : .secondary)
                                .frame(width: 20, alignment: .center)

                            // Line content
                            Text(line.dropFirst())
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 4)
                        .background(
                            line.hasPrefix("+") ? Color.green.opacity(0.1) :
                            line.hasPrefix("-") ? Color.red.opacity(0.1) : Color.clear
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Code Block (Simplified)

struct CodeBlock: View {
    let source: String
    let language: String

    var body: some View {
        Text(source)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
