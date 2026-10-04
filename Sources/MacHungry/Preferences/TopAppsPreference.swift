import Foundation
import HungryCore

enum TopAppsPreference {
    static let key = "topAppsLimit"

    static func load(from defaults: UserDefaults = .standard) -> TopAppsLimit {
        TopAppsLimit(stored: defaults.object(forKey: key) as? Int)
    }

    static func save(_ limit: TopAppsLimit, to defaults: UserDefaults = .standard) {
        defaults.set(limit.rawValue, forKey: key)
    }
}
