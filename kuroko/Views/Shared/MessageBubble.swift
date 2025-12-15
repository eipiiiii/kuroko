import SwiftUI
import MarkdownUI

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        Group {
            #if os(iOS)
            // iOS: Perplexity-style Layout
            if message.role == .user {
                HStack {
                    Spacer()
                    Text(message.text)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(themeManager.textColorOnMain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(themeManager.mainColor)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .frame(maxWidth: 300, alignment: .trailing)
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
                        HStack(spacing: 20) {
                            ActionButton(icon: "doc.on.doc")
                            ActionButton(icon: "arrowshape.turn.up.right")
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
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
    }
}
