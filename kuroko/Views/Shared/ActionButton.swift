import SwiftUI

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let label: String?
    let action: (() -> Void)?
    @Environment(ThemeManager.self) private var themeManager

    init(icon: String, label: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                if let label = label {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(.horizontal, label != nil ? 12 : 8)
            .padding(.vertical, 6)
            .foregroundStyle(.secondary)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(.rect)
        .hoverEffect(.lift)
        #if os(macOS)
        .onHover { hovering in
            // macOS specific hover effect
        }
        #endif
    }
}
