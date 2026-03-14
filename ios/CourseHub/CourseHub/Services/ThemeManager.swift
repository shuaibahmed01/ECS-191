import SwiftUI

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

@Observable
class ThemeManager {
    static let shared = ThemeManager()
    private let key = "app_theme"

    var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: key)
        }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: key) ?? "system"
        self.currentTheme = AppTheme(rawValue: stored) ?? .system
    }
}
