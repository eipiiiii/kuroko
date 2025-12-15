import SwiftUI
import MarkdownUI

struct ChatView: View {
    @Bindable var viewModel: KurokoViewModel
    @Environment(ThemeManager.self) private var themeManager
    @FocusState var isInputFocused: Bool
    
    var body: some View {
        ZStack {
            #if os(iOS)
            themeManager.backgroundColor.ignoresSafeArea()
            #endif
            
            VStack(spacing: 0) {
                // Chat List
                ScrollViewReader { proxy in
                    ScrollView {
                        // Center content on wide screens (macOS)
                        HStack {
                            Spacer()
                            
                            LazyVStack(spacing: 24) {
                                // Welcome Message or Error
                                if viewModel.messages.isEmpty {
                                    if case .error(let message) = viewModel.viewState {
                                        ContentUnavailableView {
                                            Image(systemName: "exclamationmark.triangle")
                                                .font(.system(size: 40))
                                                .foregroundStyle(.red)
                                        } description: {
                                            Text(message)
                                                .font(.title3)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.top, 100)
                                    } else {
                                        ContentUnavailableView {
                                            Image(systemName: "magnifyingglass")
                                                .font(.system(size: 40))
                                                .foregroundStyle(.secondary)
                                        } description: {
                                            Text("知りたいことは何ですか？")
                                                .font(.title3)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.top, 100)
                                    }
                                }
                                
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                                
                                if case .error(let message) = viewModel.viewState, !viewModel.messages.isEmpty {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .padding()
                                }
                                
                                // Clean spacing at bottom
                                Color.clear.frame(height: 20)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .frame(maxWidth: 800) // Limit max width for readability on macOS
                            
                            Spacer()
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: viewModel.messages.last?.text) { oldValue, newValue in
                        DispatchQueue.main.async {
                            if let lastId = viewModel.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input Area
                InputArea(
                    text: $viewModel.inputText,
                    isLoading: viewModel.viewState == .loading,
                    hasError: viewModel.viewState != .idle && viewModel.viewState != .loading,
                    isFocused: $isInputFocused,
                    onSend: {
                        viewModel.sendMessage()
                        isInputFocused = false
                    },
                    onStop: {
                        viewModel.stopGeneration()
                    },
                    onRetry: {
                        viewModel.retryLastMessage()
                        isInputFocused = false
                    }
                )
                #if os(iOS)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(themeManager.backgroundColor)
                #endif
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
    }
}
