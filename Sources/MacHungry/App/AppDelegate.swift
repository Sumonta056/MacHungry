import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = StatsStore()
        let monitor = StatsMonitor(store: store, topLimit: TopAppsPreference.load())
        let animator = MenuBarAnimator(theme: ThemePreference.load())
        controller = StatusItemController(store: store, monitor: monitor, animator: animator, iconCache: IconCache(), layout: LayoutPreference.load())
        monitor.start()
    }
}
