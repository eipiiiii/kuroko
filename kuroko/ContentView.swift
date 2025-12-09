//
//  ContentView.swift
//  kuroko
//
//  Created by 林栄介 on 2025/12/08.
//

import SwiftUI
import MarkdownUI
import GoogleGenerativeAI
import Foundation

// MARK: - Models
enum MessageRole: String, Codable {
    case user
    case model
    case tool // New role for tool outputs
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    var text: String
    var isStreaming: Bool = false
    var toolCallId: String? = nil // For identifying tool responses
    var toolCalls: [ToolCall]? = nil // For storing tool calls made by the model
}

// MARK: - ViewModel
@Observable
class KurokoViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var sessionManager: SessionManager
    
    private var apiKey: String = ""
    private var openRouterApiKey: String = ""
    private var selectedModel: String = "gemini-2.5-flash"
    private var selectedProvider: String = "gemini"
    private var model: GenerativeModel?
    private var customPrompt: String = "" // User-editable custom instructions
    
    // Search Config
    private var googleSearchApiKey: String = ""
    private var googleSearchEngineId: String = ""
    
    // MARK: - Fixed System Instructions (Read-only)
    static let FIXED_SYSTEM_PROMPT = """
You are a helpful AI assistant with access to web search capabilities.

## Your Knowledge Limitations:
- Your training data has a knowledge cutoff date (typically 2023-2024, varies by model).
- You DO NOT have access to real-time information without using tools.
- For any information after your cutoff or about current events, you MUST use the google_search tool.
- Never guess or hallucinate current information - always search when uncertain.

## Current Context:
Current date and time: [DYNAMIC_TIMESTAMP]

## Tool Usage Guidelines:
- When you need up-to-date information (e.g., current prices, latest news, recent events), use the `google_search` tool.
- When the user asks about information that may have changed since your knowledge cutoff, use the search tool.
- Always cite sources when using search results.
- If search results are insufficient, acknowledge the limitation.

## Response Style:
- Be concise and clear.
- Use markdown formatting for better readability.
- Provide accurate information based on your knowledge or search results.
"""


    
    init(sessionManager: SessionManager = SessionManager.shared) {
        self.sessionManager = sessionManager
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.openRouterApiKey = UserDefaults.standard.string(forKey: "openRouterApiKey") ?? ""
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "gemini-2.5-flash"
        self.selectedProvider = UserDefaults.standard.string(forKey: "selectedProvider") ?? "gemini"
        self.customPrompt = UserDefaults.standard.string(forKey: "customPrompt") ?? ""
        self.googleSearchApiKey = UserDefaults.standard.string(forKey: "googleSearchApiKey") ?? ""
        self.googleSearchEngineId = UserDefaults.standard.string(forKey: "googleSearchEngineId") ?? ""
        updateModelConfiguration()
        loadCurrentSession()
    }
    
    func updateModelConfiguration() {
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.openRouterApiKey = UserDefaults.standard.string(forKey: "openRouterApiKey") ?? ""
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "gemini-2.5-flash"
        self.selectedProvider = UserDefaults.standard.string(forKey: "selectedProvider") ?? "gemini"
        self.customPrompt = UserDefaults.standard.string(forKey: "customPrompt") ?? ""
        self.googleSearchApiKey = UserDefaults.standard.string(forKey: "googleSearchApiKey") ?? ""
        self.googleSearchEngineId = UserDefaults.standard.string(forKey: "googleSearchEngineId") ?? ""
        
        if selectedProvider == "gemini" {
            guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.model = nil
                if messages.isEmpty {
                    self.errorMessage = "Gemini APIキーを設定してください"
                }
                return
            }
            self.errorMessage = nil
            // Combine fixed system prompt with custom prompt and inject current timestamp
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let promptWithTimestamp = KurokoViewModel.FIXED_SYSTEM_PROMPT.replacingOccurrences(of: "[DYNAMIC_TIMESTAMP]", with: timestamp)
            let combinedPrompt = promptWithTimestamp + (customPrompt.isEmpty ? "" : "\n\n## Custom Instructions:\n" + customPrompt)
            if !combinedPrompt.isEmpty {
                 self.model = GenerativeModel(name: selectedModel, apiKey: apiKey, systemInstruction: ModelContent(parts: [.text(combinedPrompt)]))
            } else {
                 self.model = GenerativeModel(name: selectedModel, apiKey: apiKey)
            }
        } else {
            guard !openRouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.model = nil
                if messages.isEmpty {
                    self.errorMessage = "OpenRouter APIキーを設定してください"
                }
                return
            }
            self.errorMessage = nil
            self.model = nil // OpenRouterは別途処理
        }
    }
    
    @MainActor
    func sendMessage() {
        updateModelConfiguration()
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = inputText
        inputText = ""
        errorMessage = nil
        
        messages.append(ChatMessage(role: .user, text: userMessage))
        isLoading = true
        
        let aiMessageIndex = messages.count
        messages.append(ChatMessage(role: .model, text: "", isStreaming: true))
        
        if selectedProvider == "gemini" {
            // Gemini APIを使用
            guard let model = self.model else {
                isLoading = false
                messages[aiMessageIndex].isStreaming = false
                self.errorMessage = "Gemini APIキーが無効です"
                return
            }
            
            Task {
                do {
                    let history = messages.dropLast().map { message in
                        ModelContent(role: message.role == .user ? "user" : "model", parts: [.text(message.text)])
                    }
                    
                    let chat = model.startChat(history: history)
                    let responseStream = chat.sendMessageStream(userMessage)
                    
                    for try await chunk in responseStream {
                        if let text = chunk.text {
                            messages[aiMessageIndex].text += text
                        }
                    }
                    
                    messages[aiMessageIndex].isStreaming = false
                    isLoading = false
                    saveCurrentSession()
                    
                } catch {
                    isLoading = false
                    messages[aiMessageIndex].isStreaming = false
                    self.errorMessage = "エラー: \(error.localizedDescription)"
                }
            }
        } else {
            // OpenRouter APIを使用
            guard !openRouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                isLoading = false
                messages[aiMessageIndex].isStreaming = false
                self.errorMessage = "OpenRouter APIキーが無効です"
                return
            }
            
            Task {
                do {
                    try await sendOpenRouterMessage(userMessage: userMessage, aiMessageIndex: aiMessageIndex)
                } catch {
                    isLoading = false
                    messages[aiMessageIndex].isStreaming = false
                    self.errorMessage = "OpenRouterエラー: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func sendOpenRouterMessage(userMessage: String, aiMessageIndex: Int) async throws {
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(openRouterApiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("kuroko-swift", forHTTPHeaderField: "HTTP-Referer")
        request.addValue("kuroko-swift", forHTTPHeaderField: "X-Title")
        
        // メッセージ履歴を作成
        var allMessages: [[String: Any]] = []
        
        // System Prompt
        // Combine fixed system prompt with custom prompt and inject current timestamp
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let promptWithTimestamp = KurokoViewModel.FIXED_SYSTEM_PROMPT.replacingOccurrences(of: "[DYNAMIC_TIMESTAMP]", with: timestamp)
        let combinedPrompt = promptWithTimestamp + (customPrompt.isEmpty ? "" : "\n\n## Custom Instructions:\n" + customPrompt)
        if !combinedPrompt.isEmpty {
            allMessages.append([
                "role": "system",
                "content": combinedPrompt
            ])
        }
        
        // History
        let chatMessages = self.messages.dropLast().map { message -> [String: Any] in
            var msg: [String: Any] = [
                "role": message.role.rawValue, // user, model -> assistant, tool
                "content": message.text
            ]
            
            // Map 'model' role to 'assistant' for API
            if message.role == .model {
                msg["role"] = "assistant"
                if let toolCalls = message.toolCalls {
                    // Reconstruct tool_calls JSON
                    let toolCallsJSON = toolCalls.map { tc in
                        [
                            "id": tc.id,
                            "type": tc.type,
                            "function": [
                                "name": tc.function.name,
                                "arguments": tc.function.arguments
                            ]
                        ]
                    }
                    msg["tool_calls"] = toolCallsJSON
                }
            } else if message.role == .tool {
                msg["tool_call_id"] = message.toolCallId
            }
            
            return msg
        }
        
        allMessages.append(contentsOf: chatMessages)
        
        // Current User Message (If it's the start of interaction)
        // Note: The caller appends user message to `messages` BEFORE calling this.
        // So `dropLast()` removes the EMPTY AI message, but keeps the user message?
        // Wait, sendMessage() does:
        // messages.append(UserMessage)
        // messages.append(AIMessage) -> index
        // So dropLast() removes AIMessage. The UserMessage IS in chatMessages.
        // The original code was:
        // let chatMessages = self.messages.dropLast().map ...
        // allMessages.append(contentsOf: chatMessages)
        // let userMessageDict = ["role": "user", "content": userMessage]
        // allMessages.append(userMessageDict)
        // This DUPLICATED the user message if it was already in `chatMessages`.
        // Let's fix this logic.
        // Correct logic: `messages` contains [Historic..., UserNew, AIPlaceholder].
        // dropLast() -> [Historic..., UserNew].
        // So we DON'T need to append userMessage separately if we use `chatMessages`.
        // However, the original code did:
        // let chatMessages = self.messages.dropLast().map...
        // ...
        // allMessages.append(contentsOf: chatMessages)
        // allMessages.append(userMessageDict)
        // Check `sendMessage`:
        // messages.append(user)
        // messages.append(ai)
        // So `dropLast` includes `user`.
        // So the original code was sending the user message TWICE?
        // Ah, `sendMessage` func appends user message to `messages`.
        // `dropLast` includes it.
        // Then `allMessages.append(userMessageDict)` adds it AGAIN?
        // Let's assume I should trust the loop to build the full history properly.
        
        // Tools Definition
        var requestBody: [String: Any] = [
            "model": selectedModel,
            "messages": allMessages,
            "stream": true
        ]
        
        let toolsEnabled = !googleSearchApiKey.isEmpty && !googleSearchEngineId.isEmpty
        if toolsEnabled {
            let googleSearchTool: [String: Any] = [
                "type": "function",
                "function": [
                    "name": "google_search",
                    "description": "Search Google for information when you cannot answer from your knowledge base or need up-to-date information.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "query": [
                                "type": "string",
                                "description": "The search query to send to Google."
                            ]
                        ],
                        "required": ["query"]
                    ]
                ]
            ]
            requestBody["tools"] = [googleSearchTool]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Handle Streaming Response
        let responseString = String(data: data, encoding: .utf8) ?? ""
        let lines = responseString.components(separatedBy: "\n")
        
        var currentToolCall: ToolCall? = nil
        var currentToolId: String = ""
        var currentFunctionName: String = ""
        var currentFunctionArgs: String = ""
        var isToolCall = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.hasPrefix("data: ") {
                let jsonDataString = String(trimmedLine.dropFirst(6))
                if jsonDataString == "[DONE]" { break }
                
                guard let jsonData = jsonDataString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let delta = choices.first?["delta"] as? [String: Any] else { continue }
                
                // Handle Content
                if let content = delta["content"] as? String {
                    if !content.isEmpty {
                        await MainActor.run {
                            self.messages[aiMessageIndex].text += content
                        }
                    }
                }
                
                // Handle Tool Calls (Streaming)
                 if let toolCalls = delta["tool_calls"] as? [[String: Any]], let firstMethod = toolCalls.first {
                    isToolCall = true
                    if let id = firstMethod["id"] as? String {
                        currentToolId = id
                    }
                    if let function = firstMethod["function"] as? [String: Any] {
                        if let name = function["name"] as? String {
                            currentFunctionName = name
                        }
                        if let args = function["arguments"] as? String {
                            currentFunctionArgs += args
                        }
                    }
                }
            }
        }
        
        if isToolCall && !currentFunctionName.isEmpty {
            // Tool call completed
            let toolCall = ToolCall(id: currentToolId, type: "function", function: FunctionCall(name: currentFunctionName, arguments: currentFunctionArgs))
            
            await MainActor.run {
                // Update the current AI message to reflect it made a tool call (optional, depends on UI)
                self.messages[aiMessageIndex].toolCalls = [toolCall]
                self.messages[aiMessageIndex].isStreaming = false
                
                // Add visible text for the tool call so it is saved in history and visible to user
                if currentFunctionName == "google_search" {
                    // Parse the query for display
                    if let argsData = currentFunctionArgs.data(using: .utf8),
                       let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any],
                       let query = argsDict["query"] as? String {
                        self.messages[aiMessageIndex].text += "\n\n🔍 **Searching:** \(query)"
                    }
                }
            }
            
            // Execute Tool
            if currentFunctionName == "google_search" {
                // Parse args
                if let argsData = currentFunctionArgs.data(using: .utf8),
                   let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any],
                   let query = argsDict["query"] as? String {
                    
                    await MainActor.run {
                        // Append tool call to history (handled by updating the message above)
                        // Add Tool Result Message
                        // But first, we need to add a NEW placeholder for the NEXT AI response?
                        // Or do we continue stream? OpenRouter stream usually ends after tool_calls.
                        // We need to make a NEW request with tool outputs.
                    }
                    
                    let searchResult = try await SearchService.shared.performSearch(query: query, apiKey: googleSearchApiKey, engineId: googleSearchEngineId)
                    
                    await MainActor.run {
                         self.messages.append(ChatMessage(role: .tool, text: searchResult, toolCallId: currentToolId)) // Tool Result
                         // Add new AI placeholder
                         self.messages.append(ChatMessage(role: .model, text: "", isStreaming: true))
                    }
                     
                    // Recursive call for final answer
                    let newAiIndex = await MainActor.run { self.messages.count - 1 }
                    try await sendOpenRouterMessage(userMessage: "", aiMessageIndex: newAiIndex) // recursive call ignores userMessage if history is built correctly
                    return
                }
            }
        }
        
        await MainActor.run {
            self.messages[aiMessageIndex].isStreaming = false
            isLoading = false
            saveCurrentSession()
        }
    }
    
    // MARK: - Session Management
    
    func loadCurrentSession() {
        if let session = sessionManager.currentSession {
            messages = session.messages.map { sessionMessage in
                ChatMessage(
                    role: sessionMessage.role == "user" ? .user : (sessionMessage.role == "tool" ? .tool : .model),
                    text: sessionMessage.text,
                    isStreaming: false
                )
            }
        }
    }
    
    func saveCurrentSession() {
        // 現在のメッセージをSessionMessageに変換
        let sessionMessages = messages.map { message in
            SessionMessage(
                role: message.role.rawValue,
                text: message.text
            )
        }
        
        // 現在のセッションを更新または新規作成
        if sessionManager.currentSession != nil {
            sessionManager.currentSession?.messages = sessionMessages
            sessionManager.currentSession?.updatedAt = Date()
        } else {
            sessionManager.currentSession = ChatSession(messages: sessionMessages)
        }
        
        sessionManager.saveCurrentSession()
    }
    
    func startNewSession() {
        messages = []
        sessionManager.createNewSession()
    }
}

// MARK: - Cross Platform Extensions

extension Color {
    static var lightText: Color {
        #if os(iOS)
        return Color(uiColor: .lightText)
        #else
        return Color.white.opacity(0.6)
        #endif
    }
    
    static var invertedPrimary: Color {
        #if os(iOS)
        return Color(uiColor: .systemBackground)
        #else
        return Color(nsColor: .textBackgroundColor)
        #endif
    }
}

#if os(macOS)
// macOS doesn't have UIScreen
struct ScreenSize {
    static var width: CGFloat {
        NSScreen.main?.frame.width ?? 1024
    }
}
#endif

// MARK: - View Extensions

extension View {
    #if os(iOS)
    func screen() -> UIScreen? {
        // iOS 26向けにUIWindowSceneを使用
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    if window.isKeyWindow {
                        return window.screen
                    }
                }
            }
        }
        return nil
    }
    #else
    func screen() -> Any? {
        return nil
    }
    #endif
}



// MARK: - Views

struct ContentView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var viewModel = KurokoViewModel()
    @State private var isShowingSettings = false
    @State private var isShowingHistory = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        #if os(macOS)
        // macOS: NavigationSplitView with Sidebar
        NavigationSplitView {
            SidebarView(sessionManager: viewModel.sessionManager, viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            ChatView(viewModel: viewModel)
                #if os(macOS)
                .background(themeManager.backgroundColor) // Native macOS background
                #endif
        }
        .navigationTitle(viewModel.sessionManager.currentSession?.title ?? "kuroko")
        #else
        // iOS: Existing NavigationStack Layout
        NavigationStack {
            ChatView(viewModel: viewModel)
                .navigationTitle("kuroko")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { isShowingHistory = true }) {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 16) {
                            Button(action: { 
                                viewModel.startNewSession()
                            }) {
                                Image(systemName: "square.and.pencil")
                            }
                            
                            Button(action: { isShowingSettings = true }) {
                                Image(systemName: "slider.horizontal.3")
                            }
                        }
                    }
                }
                .sheet(isPresented: $isShowingSettings) {
                    SettingsView(sessionManager: viewModel.sessionManager)
                        // .preferredColorScheme(.dark) // Removed to support system theme
                        .onDisappear {
                            viewModel.updateModelConfiguration()
                        }
                }
                .sheet(isPresented: $isShowingHistory) {
                    SessionHistoryView(sessionManager: viewModel.sessionManager)
                        // .preferredColorScheme(.dark) // Removed
                        .onDisappear {
                            viewModel.loadCurrentSession()
                        }
                }
        }
        #endif
    }
}


// メッセージのレイアウト
struct MessageBubble: View {
    let message: ChatMessage
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        #if os(iOS)
        // iOS: Perplexity-style Layout
        if message.role == .user {
            HStack {
                Spacer()
                Text(message.text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(themeManager.textColorOnMain) // Text color adapts to main color
                    // However, to be "native" usually user bubbles are Blue/Green and text is White.
                    // The previous code had a Dark Gray bubble with Light text.
                    // Let's stick to a Native Look: User = AccentColor, Text = White.
                    // Assistant = Transparent/Gray, Text = Primary.
                    // Wait, the user specifically asked to fix "text color and UI color issues".
                    // The previous implementation was explicitly "Perplexity-like" (Dark).
                    // If I switch to Native, User bubble -> Blue, Assistant -> Clear.
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(themeManager.mainColor) // User bubble uses Main Color
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(themeManager.accentColor)
                    
                    Text("Answer")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                
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
        #else
        // macOS: Native Layout
        HStack {
            if message.role == .user {
                Spacer()
                
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(themeManager.textColorOnMain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(themeManager.mainColor)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .frame(maxWidth: 400, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    if message.text.isEmpty && message.isStreaming {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.leading, 4)
                    } else {
                        Markdown(message.text)
                            .id(message.id)
                            .markdownTextStyle {
                                FontSize(16)
                                ForegroundColor(themeManager.textColor)
                            }
                            .markdownTheme(.gitHub.text {
                                ForegroundColor(themeManager.textColor)
                            }.link {
                                ForegroundColor(themeManager.accentColor)
                            })
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(nsColor: .controlBackgroundColor))
                    }
                    
                    if !message.isStreaming && !message.text.isEmpty {
                        HStack(spacing: 12) {
                            ActionButton(icon: "doc.on.doc")
                            ActionButton(icon: "arrowshape.turn.up.right")
                        }
                        .padding(.leading, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
        }
        #endif
    }
}

// アクションボタン
struct ActionButton: View {
    let icon: String
    
    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

// 入力エリアUI
struct InputArea: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var text: String
    var isLoading: Bool
    var isFocused: FocusState<Bool>.Binding
    var onSend: () -> Void
    
    var body: some View {
        #if os(iOS)
        // iOS: Capsule Style Input
        HStack(alignment: .bottom, spacing: 10) {
            Button(action: {}) {
                Image(systemName: "plus")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(Circle())
            }
            
            ZStack(alignment: .bottomTrailing) {
                TextField("質問する...", text: $text, axis: .vertical)
                    .focused(isFocused)
                    .padding(.leading, 16)
                    .padding(.trailing, 40)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(25)
                    .lineLimit(1...5)
                    .foregroundStyle(.primary)
                
                Button(action: onSend) {
                    Image(systemName: text.isEmpty ? "mic.fill" : "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(text.isEmpty ? Color.secondary : themeManager.textColorOnAccent)
                        .frame(width: 30, height: 30)
                        .background(text.isEmpty ? Color.clear : themeManager.accentColor) // Use theme color for send button
                        .clipShape(Circle())
                }
                .disabled(isLoading)
                .padding(.bottom, 9)
                .padding(.trailing, 6)
            }
        }
        .padding(.top, 8)
        #else
        // macOS: Native Style Input
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message...", text: $text, axis: .vertical)
                .focused(isFocused)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color(nsColor: .controlBackgroundColor)))
                }
                .lineLimit(1...5)
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(text.isEmpty ? .gray : themeManager.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty || isLoading)
        }
        .padding(8)
        .background(.regularMaterial)
        #endif
    }
}

#Preview {
    ContentView()
}
