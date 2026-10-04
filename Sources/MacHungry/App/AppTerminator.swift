import AppKit
import Darwin
import HungryCore

@MainActor
enum AppTerminator {
    static func runningApps(for app: AppUsage) -> [NSRunningApplication] {
        guard let bundlePath = app.identity.bundlePath,
              let bundleID = Bundle(path: bundlePath)?.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier else { return [] }
        let currentUser = getuid()
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter {
            $0.processIdentifier != ownPID && ownerUID(of: $0.processIdentifier) == currentUser
        }
    }

    static func canQuit(_ app: AppUsage) -> Bool {
        !runningApps(for: app).isEmpty
    }

    static func confirmAndQuit(_ app: AppUsage) {
        let targets = runningApps(for: app)
        guard !targets.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Quit \(app.identity.name)?"
        alert.informativeText = "MacHungry asks the app to quit normally. The app can ask you to save your work."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        targets.forEach { $0.terminate() }
    }

    private static func ownerUID(of pid: pid_t) -> uid_t? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return info.pbi_uid
    }
}
