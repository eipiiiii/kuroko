//
//  ContentView.swift
//  kuroko
//
//  Created by 林栄介 on 2025/12/08.
//

import SwiftUI
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
    
    private var apiKey: String = ""
    private var openRouterApiKey: String = ""
    private var selectedModel: String = "gemini-2.5-flash"
    private var selectedProvider: String = "gemini"
    private var model: GenerativeModel?
    
    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.openRouterApiKey = UserDefaults.standard.string(forKey: "openRouterApiKey") ?? ""
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "gemini-2.5-flash"
        self.selectedProvider = UserDefaults.standard.string(forKey: "selectedProvider") ?? "gemini"
        updateModelConfiguration()
    }
    
    func updateModelConfiguration() {
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.openRouterApiKey = UserDefaults.standard.string(forKey: "openRouterApiKey") ?? ""
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "gemini-2.5-flash"
        self.selectedProvider = UserDefaults.standard.string(forKey: "selectedProvider") ?? "gemini"
        
        if selectedProvider == "gemini" {
            guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.model = nil
                if messages.isEmpty {
                    self.errorMessage = "Gemini APIキーを設定してください"
                }
                return
            }
            self.errorMessage = nil
            self.model = GenerativeModel(name: selectedModel, apiKey: apiKey)
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
        
        // ユーザーメッセージを追加
        let userMessageDict = [
            "role": "user",
            "content": userMessage
        ]
        let allMessages = chatMessages + [userMessageDict]
        
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
    }
}

// MARK: - View Extensions

extension View {
    func screen() -> UIScreen? {
        #if os(iOS)
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
        #endif
        return nil
    }
}

// MARK: - Markdown Parser

func parseMarkdown(_ markdown: String) -> AttributedString {
    do {
        let attributedString = try AttributedString(markdown: markdown)
        return attributedString
    } catch {
        // パース失敗時はプレーンテキストで返す
        return AttributedString(markdown)
    }
}

// MARK: - Views

struct ContentView: View {
    @State private var viewModel = KurokoViewModel()
    @State private var isShowingSettings = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Perplexity風の深い黒背景
                Color(red: 0.05, green: 0.05, blue: 0.05).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Chat List
                    ScrollViewReader { proxy in
                        ScrollView {
                            // メッセージ全体の余白設定
                            LazyVStack(spacing: 24) {
                                // ウェルカムメッセージ
                                if viewModel.messages.isEmpty && viewModel.errorMessage == nil {
                                    ContentUnavailableView {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.gray)
                                    } description: {
                                        Text("知りたいことは何ですか？")
                                            .font(.title3)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.white)
                                    }
                                    .padding(.top, 100)
                                }
                                
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                                
                                if let error = viewModel.errorMessage {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .padding()
                                }
                                
                                // 下部の余白（入力欄とかぶらないように）
                                Color.clear.frame(height: 20)
                            }
                            .padding(.horizontal, 16) // 画面端からの余白
                            .padding(.top, 16)
                        }
                        .onChange(of: viewModel.messages.last?.text) { _, _ in
                            if let lastId = viewModel.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    
                    // Input Area
                    InputArea(text: $viewModel.inputText, isLoading: viewModel.isLoading, isFocused: $isInputFocused) {
                        viewModel.sendMessage()
                        isInputFocused = false
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .background(Color(red: 0.05, green: 0.05, blue: 0.05)) // 背景と同じ色で溶け込ませる
                }
            }
            .navigationTitle("kuroko")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { isShowingSettings = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
                    .preferredColorScheme(.dark)
                    .onDisappear {
                        viewModel.updateModelConfiguration()
                    }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// メッセージのレイアウト
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        // Roleによって完全にレイアウトを分ける
        if message.role == .user {
            // MARK: User Message (Right Aligned)
            HStack {
                Spacer() // 左を埋めて右に寄せる
                
                Text(message.text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(uiColor: .lightText))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.15)) // Perplexity風の濃いグレー
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    // 最大幅を画面の75%程度に制限
                    .frame(maxWidth: screen()?.bounds.width ?? 375 * 0.75, alignment: .trailing)
            }
        } else {
            // MARK: AI Message (Left Aligned)
            VStack(alignment: .leading, spacing: 6) {
                // ヘッダー（アイコン + 名前）
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(.cyan) // Perplexityっぽいシアン色
                    
                    Text("Answer")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Spacer()
                }
                
                // 本文
                if message.text.isEmpty && message.isStreaming {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.gray)
                        Text("考え中...")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    .padding(.leading, 4)
                } else {
                    Text(parseMarkdown(message.text))
                        .font(.system(size: 16, weight: .regular))
                        .lineSpacing(5)
                        .foregroundStyle(Color(uiColor: .lightText)) // 真っ白すぎない白
                        .frame(maxWidth: .infinity, alignment: .leading) // 左詰め、幅いっぱい
                        .textSelection(.enabled)
                }
                
                // アクションボタン（生成完了後のみ）
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
}

// アクションボタン
struct ActionButton: View {
    let icon: String
    
    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.gray)
        }
    }
}

// 入力エリアUI
struct InputArea: View {
    @Binding var text: String
    var isLoading: Bool
    var isFocused: FocusState<Bool>.Binding
    var onSend: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // 左側のプラスボタン
            Button(action: {}) {
                Image(systemName: "plus")
                    .font(.system(size: 20))
                    .foregroundStyle(.gray)
                    .frame(width: 32, height: 32)
                    .background(Color(white: 0.2))
                    .clipShape(Circle())
            }
            .padding(.bottom, 8)
            
            // 入力フィールド（カプセル型）
            ZStack(alignment: .bottomTrailing) {
                TextField("質問する...", text: $text, axis: .vertical)
                    .focused(isFocused)
                    .padding(.leading, 16)
                    .padding(.trailing, 40) // 送信ボタン分の余白
                    .padding(.vertical, 12)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .cornerRadius(25)
                    .lineLimit(1...5)
                
                // 送信ボタン（入力内配置）
                Button(action: onSend) {
                    Image(systemName: text.isEmpty ? "mic.fill" : "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(text.isEmpty ? .gray : .black) // 入力ありで黒文字
                        .frame(width: 30, height: 30)
                        .background(text.isEmpty ? Color.clear : Color.cyan) // 入力ありでシアン背景
                        .clipShape(Circle())
                }
                .disabled(isLoading)
                .padding(.bottom, 9) // 位置微調整
                .padding(.trailing, 6)
            }
        }
        .padding(.top, 8)
    }
}



#Preview {
    ContentView()
}