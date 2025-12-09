import SwiftUI

#if os(iOS)
import UIKit
#endif

#if os(macOS)
import AppKit
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

#if os(macOS)
// macOS doesn't have UIScreen
struct ScreenSize {
    static var width: CGFloat {
        NSScreen.main?.frame.width ?? 1024
    }
}
#endif
