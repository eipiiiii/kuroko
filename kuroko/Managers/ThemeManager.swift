import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case monochrome
    case ocean
    case modernAI
    case classicEditorial
    case japanTradition
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .monochrome: return "Monochrome"
        case .ocean: return "Ocean"
        case .modernAI: return "Modern AI"
        case .classicEditorial: return "Classic Editorial"
        case .japanTradition: return "Japan Tradition"
        }
    }
    
    // MARK: - Color Palette
    
    var backgroundColor: Color {
        switch self {
        case .monochrome:
            // Default system background
            return Color.invertedPrimary
        case .ocean:
            return Color(light: .white, dark: .black) // Simple default for Ocean
        case .modernAI:
            return Color(light: Hex("#F8FAFC"), dark: Hex("#0F172A"))
        case .classicEditorial:
            return Color(light: Hex("#FFFFFF"), dark: Hex("#1A1A1A"))
        case .japanTradition:
            return Color(light: Hex("#F6F7F8"), dark: Hex("#17184B"))
        }
    }
    
    var mainColor: Color {
        switch self {
        case .monochrome:
             return Color.accentColor
        case .ocean:
             return Color(red: 33/255, green: 128/255, blue: 141/255)
        case .modernAI:
            return Color(light: Hex("#6366F1"), dark: Hex("#818CF8"))
        case .classicEditorial:
            return Color(light: Hex("#005F73"), dark: Hex("#48CAE4"))
        case .japanTradition:
            return Color(light: Hex("#165E83"), dark: Hex("#A0D8EF"))
        }
    }
    
    var accentColor: Color {
        switch self {
        case .monochrome:
            return Color.accentColor
        case .ocean:
            return Color(red: 33/255, green: 128/255, blue: 141/255)
        case .modernAI:
            return Color(light: Hex("#00D4FF"), dark: Hex("#38BDF8"))
        case .classicEditorial:
            return Color(light: Hex("#EE9B00"), dark: Hex("#FFB703"))
        case .japanTradition:
            return Color(light: Hex("#B7282E"), dark: Hex("#FF6B6B"))
        }
    }
    
    var textColor: Color {
        switch self {
        case .monochrome:
            return .primary
        case .ocean:
            return .primary
        case .modernAI:
            return Color(light: Hex("#334155"), dark: Hex("#E2E8F0"))
        case .classicEditorial:
            return Color(light: Hex("#111827"), dark: Hex("#F3F4F6"))
        case .japanTradition:
            return Color(light: Hex("#0D0015"), dark: Hex("#F6F7F8"))
        }
    }
    
    var textColorOnAccent: Color {
        switch self {
        case .monochrome:
            return Color.invertedPrimary
        case .ocean:
            return .white
        case .modernAI:
            return .white
        case .classicEditorial:
            return .white
        case .japanTradition:
            return .white
        }
    }
    
    var textColorOnMain: Color {
        switch self {
        case .monochrome:
            return Color.invertedPrimary
        case .ocean:
            return .white
        case .modernAI:
            return .white
        case .classicEditorial:
            return Color(light: .white, dark: .black) // Dark Main (#48CAE4) needs Black text
        case .japanTradition:
            return Color(light: .white, dark: .black) // Dark Main (#A0D8EF) needs Black text
        }
    }
}

// MARK: - Color Helpers

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

func Hex(_ hex: String) -> Color {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

    var rgb: UInt64 = 0

    var r: CGFloat = 0.0
    var g: CGFloat = 0.0
    var b: CGFloat = 0.0
    var a: CGFloat = 1.0

    let length = hexSanitized.count

    guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return .gray }

    if length == 6 {
        r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        b = CGFloat(rgb & 0x0000FF) / 255.0

    } else if length == 8 {
        r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
        g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
        b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
        a = CGFloat(rgb & 0x000000FF) / 255.0

    } else {
        return .gray
    }

    return Color(red: r, green: g, blue: b, opacity: a)
}

@Observable
public class ThemeManager {
    var currentTheme: AppTheme = .monochrome {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    public init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        }
    }
    
    var accentColor: Color {
        currentTheme.accentColor
    }
    
    var mainColor: Color {
        currentTheme.mainColor
    }
    
    var backgroundColor: Color {
        currentTheme.backgroundColor
    }
    
    var textColor: Color {
        currentTheme.textColor
    }
    
    var textColorOnAccent: Color {
        currentTheme.textColorOnAccent
    }
    
    var textColorOnMain: Color {
        currentTheme.textColorOnMain
    }
}
