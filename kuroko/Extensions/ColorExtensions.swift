import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - Color Extensions

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
