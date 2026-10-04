import Observation
import HungryCore

@MainActor
@Observable
final class PopoverModel {
    private(set) var themeID: String
    private(set) var topAppsLimit: TopAppsLimit
    private(set) var launchAtLogin: Bool
    private(set) var loginError: String?

    @ObservationIgnored private let onThemeChange: (any AnimationTheme) -> Void
    @ObservationIgnored private let onTopAppsLimitChange: (TopAppsLimit) -> Void

    init(
        topAppsLimit: TopAppsLimit,
        onThemeChange: @escaping (any AnimationTheme) -> Void,
        onTopAppsLimitChange: @escaping (TopAppsLimit) -> Void
    ) {
        self.themeID = ThemePreference.load().id
        self.topAppsLimit = topAppsLimit
        self.launchAtLogin = LoginItemManager.isEnabled
        self.onThemeChange = onThemeChange
        self.onTopAppsLimitChange = onTopAppsLimitChange
    }

    func selectTheme(id: String) {
        let theme = ThemeRegistry.theme(withID: id)
        guard theme.id != themeID else { return }
        themeID = theme.id
        ThemePreference.save(theme)
        onThemeChange(theme)
    }

    func selectTopAppsLimit(_ limit: TopAppsLimit) {
        guard limit != topAppsLimit else { return }
        topAppsLimit = limit
        TopAppsPreference.save(limit)
        onTopAppsLimitChange(limit)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemManager.setEnabled(enabled)
            launchAtLogin = enabled
            loginError = nil
        } catch {
            launchAtLogin = LoginItemManager.isEnabled
            loginError = error.localizedDescription
        }
    }
}
