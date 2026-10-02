import Testing
@testable import HungryCore

struct AppGrouperTests {
    @Test func plainAppUsesBundleName() {
        let identity = AppGrouper.identity(forPath: "/Applications/Xcode.app/Contents/MacOS/Xcode")
        #expect(identity == AppIdentity(name: "Xcode", bundlePath: "/Applications/Xcode.app"))
    }

    @Test func nestedHelperUsesOutermostApp() {
        let path = "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)"
        #expect(AppGrouper.identity(forPath: path) == AppIdentity(name: "Google Chrome", bundlePath: "/Applications/Google Chrome.app"))
    }

    @Test func daemonUsesLastPathComponent() {
        #expect(AppGrouper.identity(forPath: "/usr/libexec/logd") == AppIdentity(name: "logd", bundlePath: nil))
    }

    @Test func bareNameHasNoBundle() {
        #expect(AppGrouper.identity(forPath: "kernel_task") == AppIdentity(name: "kernel_task", bundlePath: nil))
    }

    @Test func folderNamedLikeAppSuffixIsNotABundle() {
        #expect(AppGrouper.identity(forPath: "/opt/My.app.backup/bin/tool") == AppIdentity(name: "tool", bundlePath: nil))
    }

    @Test func topAppsSumsGroupsSortsAndLimits() {
        let usages = [
            ProcessUsage(pid: 1, path: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", percent: 10),
            ProcessUsage(pid: 2, path: "/Applications/Google Chrome.app/Contents/Frameworks/H.app/Contents/MacOS/H", percent: 30),
            ProcessUsage(pid: 3, path: "/usr/libexec/logd", percent: 25),
            ProcessUsage(pid: 4, path: "/usr/sbin/cfprefsd", percent: 1),
        ]
        let top = AppGrouper.topApps(usages, limit: 2)
        #expect(top.map(\.identity.name) == ["Google Chrome", "logd"])
        #expect(top.map(\.percent) == [40, 25])
    }

    @Test func equalPercentSortsByName() {
        let usages = [
            ProcessUsage(pid: 1, path: "/bin/zeta", percent: 5),
            ProcessUsage(pid: 2, path: "/bin/alpha", percent: 5),
        ]
        #expect(AppGrouper.topApps(usages, limit: 10).map(\.identity.name) == ["alpha", "zeta"])
    }

    @Test func negativeLimitGivesEmptyList() {
        #expect(AppGrouper.topApps([ProcessUsage(pid: 1, path: "/bin/a", percent: 1)], limit: -1).isEmpty)
    }
}
