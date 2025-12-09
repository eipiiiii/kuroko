import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case monochrome
    case ocean
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .monochrome: return "Monochrome"
        case .ocean: return "Ocean"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .monochrome:
            return Color.accentColor // Uses Assets.xcassets (Black/White adaptive)
        case .ocean:
            return Color(red: 33/255, green: 128/255, blue: 141/255) // #21808D
        }
    }
    
    // Defines the text color that should appear ON TOP of the accent color
    var textColorOnAccent: Color {
        switch self {
        case .monochrome:
            // For monochrome (Black/White), we want the text to invert relative to the background
            // Light Mode: Bg is Black -> Text should be White
            // Dark Mode: Bg is White -> Text should be Black
            return Color.invertedPrimary
        case .ocean:
            // Ocean is a dark teal (#21808D). White text looks good on it in both modes.
            return .white
        }
    }
}

@Observable
class ThemeManager {
    var currentTheme: AppTheme = .monochrome {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        }
    }
    
    var accentColor: Color {
        currentTheme.accentColor
    }
    
    var textColorOnAccent: Color {
        currentTheme.textColorOnAccent
    }
}
