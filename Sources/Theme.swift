import SwiftUI
import SwiftData
import Combine

enum ThemeMode: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

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
}

/// Runtime theme + accessibility accents (bridges SwiftData AppSettings ↔ SwiftUI).
@MainActor
final class ThemeController: ObservableObject {
    @Published var mode: ThemeMode = .system
    @Published var colorBlindMode: Bool = false

    func sync(from settings: AppSettings?) {
        guard let settings else { return }
        mode = settings.themeMode
        colorBlindMode = settings.colorBlindMode
    }

    func apply(to settings: AppSettings) {
        settings.themeMode = mode
        settings.colorBlindMode = colorBlindMode
    }
}

private struct ColorBlindModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var colorBlindMode: Bool {
        get { self[ColorBlindModeKey.self] }
        set { self[ColorBlindModeKey.self] = newValue }
    }
}

extension View {
    func lifeOSTheme(mode: ThemeMode, colorBlind: Bool) -> some View {
        self
            .preferredColorScheme(mode.colorScheme)
            .environment(\.colorBlindMode, colorBlind)
    }
}

enum LifeOSAccent {
    static func primary(colorBlind: Bool) -> Color {
        colorBlind ? Color(red: 0.0, green: 0.45, blue: 0.75) : .accentColor
    }

    static func success(colorBlind: Bool) -> Color {
        colorBlind ? Color(red: 0.0, green: 0.55, blue: 0.55) : .green
    }

    static func warning(colorBlind: Bool) -> Color {
        colorBlind ? Color(red: 0.85, green: 0.55, blue: 0.0) : .orange
    }

    static func danger(colorBlind: Bool) -> Color {
        colorBlind ? Color(red: 0.75, green: 0.15, blue: 0.35) : .red
    }
}
