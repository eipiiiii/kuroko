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
            #if os(iOS)
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
                // Tool response - collapsible with Apple-style design
                VStack(alignment: .leading, spacing: 8) {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            if message.text.isEmpty && message.isStreaming {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(themeManager.accentColor)
                                    Text("実行中...")
                                        .font(.subheadline)
                                        .foregroundStyle(themeManager.textColor.opacity(0.7))
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            } else {
                                Markdown(message.text)
                                    .id(message.id)
                                    .markdownTextStyle {
                                        FontSize(14)
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
                                    .padding(.vertical, 4)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.accentColor.opacity(0.1))
                                    .frame(width: 28, height: 28)

                                Image(systemName: "cpu")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(themeManager.accentColor)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("ツール実行結果")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(themeManager.textColor)

                                Text(message.toolCalls?.first?.function.name ?? "ツール")
                                    .font(.caption)
                                    .foregroundStyle(themeManager.textColor.opacity(0.7))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                        .contentShape(Rectangle())
                    }

                    // Actions for tool responses
                    if !message.isStreaming && !message.text.isEmpty {
                        HStack(spacing: 16) {
                            ActionButton(icon: "doc.on.doc")
                            ActionButton(icon: "arrowshape.turn.up.right")
                            Spacer()
                        }
                        .padding(.top, 4)
                        .padding(.leading, 16)
                    }
                }
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
            #else
            // macOS: Native Layout
            if message.role == .user {
                HStack {
                    Spacer()

                    Text(message.text)
                        .font(.body)
                        .foregroundStyle(themeManager.textColorOnMain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(themeManager.mainColor)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .frame(maxWidth: 400, alignment: .trailing)
                }
            } else if message.role == .tool {
                // Tool response - collapsible
                VStack(alignment: .leading, spacing: 6) {
                    DisclosureGroup {
                        if message.text.isEmpty && message.isStreaming {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.secondary)
                                Text("実行中...")
                                    .font(.caption)
                                    .foregroundStyle(themeManager.textColor.opacity(0.8))
                            }
                            .padding(.leading, 4)
                        } else {
                            Markdown(message.text)
                                .id(message.id)
                                .markdownTextStyle {
                                    FontSize(14)
                                    ForegroundColor(themeManager.textColor)
                                }
                                .markdownTheme(.gitHub.text {
                                    ForegroundColor(themeManager.textColor)
                                }.link {
                                    ForegroundColor(themeManager.accentColor)
                                })
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)

                            Text("Tool Response")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }

                    // Actions for tool responses
                    if !message.isStreaming && !message.text.isEmpty {
                        HStack(spacing: 12) {
                            ActionButton(icon: "doc.on.doc")
                            ActionButton(icon: "arrowshape.turn.up.right")
                        }
                        .padding(.leading, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
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
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 15)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                appearAnimation = true
            }
        }
    }
}
