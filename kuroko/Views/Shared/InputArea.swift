import SwiftUI

// MARK: - Input Area

struct InputArea: View {
    @Environment(ThemeManager.self) private var themeManager
    @Binding var text: String
    var isLoading: Bool
    var hasError: Bool
    var isFocused: FocusState<Bool>.Binding
    var onSend: () -> Void
    var onStop: () -> Void
    var onRetry: () -> Void
    
    var body: some View {
        #if os(iOS)
        // iOS: Capsule Style Input with keyboard handling
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
                
                // Dynamic button based on state
                if isLoading {
                    Button(action: onStop) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(themeManager.textColorOnAccent)
                            .frame(width: 30, height: 30)
                            .background(themeManager.accentColor)
                            .clipShape(Circle())
                    }
                    .padding(.bottom, 9)
                    .padding(.trailing, 6)
                } else if hasError {
                    Button(action: onRetry) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(themeManager.textColorOnAccent)
                            .frame(width: 30, height: 30)
                            .background(themeManager.accentColor)
                            .clipShape(Circle())
                    }
                    .padding(.bottom, 9)
                    .padding(.trailing, 6)
                } else {
                    Button(action: onSend) {
                        Image(systemName: text.isEmpty ? "mic.fill" : "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(text.isEmpty ? Color.secondary : themeManager.textColorOnAccent)
                            .frame(width: 30, height: 30)
                            .background(text.isEmpty ? Color.clear : themeManager.accentColor)
                            .clipShape(Circle())
                    }
                    .disabled(isLoading)
                    .padding(.bottom, 9)
                    .padding(.trailing, 6)
                }
            }
        }
        .padding(.top, 8)
        #else
        // macOS: Native Style Input (no keyboard avoidance needed)
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
            
            // Dynamic button based on state
            if isLoading {
                Button(action: onStop) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(themeManager.accentColor)
                }
                .buttonStyle(.plain)
            } else if hasError {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(themeManager.accentColor)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(text.isEmpty ? .gray : themeManager.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty || isLoading)
            }
        }
        .padding(8)
        .background(.regularMaterial)
        #endif
    }
}
