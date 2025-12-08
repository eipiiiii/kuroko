//
//  ContentView.swift
//  kuroko
//
//  Created by 林栄介 on 2025/12/08.
//

import SwiftUI
import GoogleGenerativeAI

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
// iOS 17+ (Observation Framework) を使用したモダンな設計
@Observable
class KurokoViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    
    // API Keyは本来、Info.plistや環境変数から読み込むべきですが、
    // ここでは開発用にプレースホルダーとしています。
    private let model = GenerativeModel(name: "gemini-2.5-flash", apiKey: "AIzaSyCnq9odznwc0FK58YagoL_LOP1q7jInfcc")
    
    // 将来的にここにMCPやローカルファイル読み込みロジックを追加します
    
    @MainActor
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = inputText
        inputText = "" // 入力欄をクリア
        errorMessage = nil
        
        // ユーザーのメッセージを追加
        messages.append(ChatMessage(role: .user, text: userMessage))
        isLoading = true
        
        // AIのプレースホルダーを追加
        let aiMessageIndex = messages.count
        messages.append(ChatMessage(role: .model, text: "", isStreaming: true))
        
        Task {
            do {
                // 過去の文脈を含めたチャット履歴を作成
                let history = messages.dropLast().map { message in
                    ModelContent(role: message.role == .user ? "user" : "model", parts: passText(message.text))
                }
                
                let chat = model.startChat(history: history)
                
                // ストリーミングレスポンスの処理
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
                self.errorMessage = "エラーが発生しました: \(error.localizedDescription)"
                // エラー時はAIの空メッセージを削除しても良い
            }
        }
    }
    
    // ヘルパー: 文字列をModelContentのPartsに変換
    private func passText(_ text: String) -> [ModelContent.Part] {
        return [.text(text)]
    }
}

// MARK: - Views

struct ContentView: View {
    @State private var viewModel = KurokoViewModel()
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // ウェルカムメッセージ（履歴がない場合）
                            if viewModel.messages.isEmpty {
                                ContentUnavailableView {
                                    Label("Kuroko", systemImage: "sparkles")
                                } description: {
                                    Text("何かお手伝いすることはありますか？")
                                }
                                .padding(.top, 50)
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
                        }
                        .padding()
                    }
                    // 新しいメッセージが来たら自動スクロール
                    .onChange(of: viewModel.messages.last?.text) { _, _ in
                        if let lastId = viewModel.messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input Area
                InputArea(text: $viewModel.inputText, isLoading: viewModel.isLoading) {
                    viewModel.sendMessage()
                }
                .padding()
                #if os(iOS)
                .background(.ultraThinMaterial)
                #else
                .background(.background)
                #endif
            }
            .navigationTitle("kuroko")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // 将来の設定画面用ボタン
                    Button(action: {}, label: { Image(systemName: "gearshape") })
                }
            }
            #endif
        }
    }
}

// メッセージの吹き出しUI
struct MessageBubble: View {
    let message: ChatMessage

    private var systemGray6: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    var body: some View {
        HStack(alignment: .top) {
            if message.role == .user {
                Spacer()
            } else {
                Image(systemName: "cpu") // AIアイコン
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading) {
                if message.role == .model && message.text.isEmpty && message.isStreaming {
                    // ローディングインジケータ（AIが考え中）
                    ProgressView()
                        .controlSize(.small)
                } else {
                    // Markdown対応のためにTextSelectionを有効化
                    Text(LocalizedStringKey(message.text)) // シンプルなMarkdown解析
                        .textSelection(.enabled)
                }
            }
            .padding(12)
            .background(message.role == .user ? Color.blue : systemGray6)
            .foregroundStyle(message.role == .user ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            // ユーザーの吹き出しの右下、AIの左下の角を少し尖らせるなどの装飾も可能
            
            if message.role == .model {
                Spacer()
            }
        }
    }
}

// 入力エリアUI
struct InputArea: View {
    @Binding var text: String
    var isLoading: Bool
    var onSend: () -> Void
    
    private var systemGray6: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    var body: some View {
        HStack(alignment: .bottom) {
            TextField("メッセージを入力...", text: $text, axis: .vertical)
                .padding(10)
                .background(systemGray6)
                .cornerRadius(20)
                .lineLimit(1...5) // 1行から5行まで可変
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(text.isEmpty || isLoading ? Color.gray : Color.blue)
            }
            .disabled(text.isEmpty || isLoading)
        }
    }
}

#Preview {
    ContentView()
}
