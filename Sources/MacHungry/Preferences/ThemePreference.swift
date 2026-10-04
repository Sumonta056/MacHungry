import Foundation
import HungryCore

enum ThemePreference {
    static let key = "selectedThemeID"

    static func load(from defaults: UserDefaults = .standard) -> any AnimationTheme {
        ThemeRegistry.theme(withID: defaults.string(forKey: key))
    }

    static func save(_ theme: any AnimationTheme, to defaults: UserDefaults = .standard) {
        defaults.set(theme.id, forKey: key)
    }
}
