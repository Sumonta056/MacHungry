import Foundation
import HungryCore

enum LayoutPreference {
    static let orderKey = "statusSegmentOrder"
    static let hiddenKey = "statusSegmentHidden"

    static func load(from defaults: UserDefaults = .standard) -> StatusLayoutSettings {
        StatusLayoutSettings(
            storedOrder: defaults.stringArray(forKey: orderKey) ?? [],
            storedHidden: defaults.stringArray(forKey: hiddenKey) ?? []
        )
    }

    static func save(_ settings: StatusLayoutSettings, to defaults: UserDefaults = .standard) {
        defaults.set(settings.order.map(\.rawValue), forKey: orderKey)
        defaults.set(settings.hidden.map(\.rawValue).sorted(), forKey: hiddenKey)
    }
}
