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
enum MessageRole {
    case user
    case model
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    var text: String
    var isStreaming: Bool = false
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
    private var systemPrompt: String = ""
    
    init(sessionManager: SessionManager = SessionManager.shared) {
        self.sessionManager = sessionManager
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.openRouterApiKey = UserDefaults.standard.string(forKey: "openRouterApiKey") ?? ""
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "gemini-2.5-flash"
        self.selectedProvider = UserDefaults.standard.string(forKey: "selectedProvider") ?? "gemini"
        self.systemPrompt = UserDefaults.standard.string(forKey: "systemPrompt") ?? ""
        updateModelConfiguration()
        loadCurrentSession()
    }
    
    func updateModelConfiguration() {
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.openRouterApiKey = UserDefaults.standard.string(forKey: "openRouterApiKey") ?? ""
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "gemini-2.5-flash"
        self.selectedProvider = UserDefaults.standard.string(forKey: "selectedProvider") ?? "gemini"
        self.systemPrompt = UserDefaults.standard.string(forKey: "systemPrompt") ?? ""
        
        if selectedProvider == "gemini" {
            guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.model = nil
                if messages.isEmpty {
                    self.errorMessage = "Gemini APIキーを設定してください"
                }
                return
            }
            self.errorMessage = nil
            if !systemPrompt.isEmpty {
                 self.model = GenerativeModel(name: selectedModel, apiKey: apiKey, systemInstruction: ModelContent(parts: [.text(systemPrompt)]))
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
        let chatMessages = self.messages.dropLast().map { message in
            [
                "role": message.role == .user ? "user" : "assistant",
                "content": message.text
            ]
        }
        
        // システムプロンプトを追加
        var allMessages: [[String: Any]] = []
        if !systemPrompt.isEmpty {
            allMessages.append([
                "role": "main", // OpenRouter/Anthropic style often uses 'system', but some models prefer 'system'. Standard is 'system' or 'developer'. using 'system' for broad compatibility.
                "content": systemPrompt
            ])
            // Note: Some OpenRouter models map 'system' role correctly.
            // Let's use 'system' as the role.
            allMessages[0]["role"] = "system"
        }
        
        allMessages.append(contentsOf: chatMessages)
        
        // ユーザーメッセージを追加
        let userMessageDict = [
            "role": "user",
            "content": userMessage
        ]
        
        // 既存のallMessagesロジックを修正
        if !systemPrompt.isEmpty {
            // 上で追加済み
        } else {
            // chatMessagesをベースにする
            allMessages = chatMessages
        }
        
        allMessages.append(userMessageDict)
        
        let body: [String: Any] = [
            "model": selectedModel,
            "messages": allMessages,
            "stream": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // ストリーミング応答を処理
        let responseString = String(data: data, encoding: .utf8) ?? ""
        let lines = responseString.components(separatedBy: "\n")
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.hasPrefix("data: ") {
                let jsonDataString = String(trimmedLine.dropFirst(6))
                if jsonDataString == "[DONE]" {
                    break
                }
                
                if let jsonData = jsonDataString.data(using: .utf8) {
                    if let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let delta = choices.first?["delta"] as? [String: Any],
                       let content = delta["content"] as? String {
                        if !content.isEmpty {
                            self.messages[aiMessageIndex].text += content
                        }
                    }
                }
            }
        }
        
        self.messages[aiMessageIndex].isStreaming = false
        isLoading = false
        saveCurrentSession()
    }
    
    // MARK: - Session Management
    
    func loadCurrentSession() {
        if let session = sessionManager.currentSession {
            messages = session.messages.map { sessionMessage in
                ChatMessage(
                    role: sessionMessage.role == "user" ? .user : .model,
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
                role: message.role == .user ? "user" : "model",
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
                .background(Color(nsColor: .windowBackgroundColor)) // Native macOS background
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
    
    var body: some View {
        #if os(iOS)
        // iOS: Perplexity-style Layout
        if message.role == .user {
            HStack {
                Spacer()
                Text(message.text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white) // User bubbles often keep white text on dark/colored bubbles even in Light Mode if the bubble is dark.
                    // However, to be "native" usually user bubbles are Blue/Green and text is White.
                    // The previous code had a Dark Gray bubble with Light text.
                    // Let's stick to a Native Look: User = AccentColor, Text = White.
                    // Assistant = Transparent/Gray, Text = Primary.
                    // Wait, the user specifically asked to fix "text color and UI color issues".
                    // The previous implementation was explicitly "Perplexity-like" (Dark).
                    // If I switch to Native, User bubble -> Blue, Assistant -> Clear.
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.accentColor) // Native-like accent color
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                    
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
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)
                } else {
                    Markdown(message.text)
                        .id(message.id)
                        .markdownTextStyle {
                            FontSize(16)
                            ForegroundColor(.primary)
                            FontWeight(.regular)
                        }
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
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
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
                                ForegroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                        .foregroundStyle(text.isEmpty ? Color.secondary : Color.white)
                        .frame(width: 30, height: 30)
                        .background(text.isEmpty ? Color.clear : Color.accentColor) // Use accent color for send button
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
                    .foregroundStyle(text.isEmpty ? .gray : Color.accentColor)
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
