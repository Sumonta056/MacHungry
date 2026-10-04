import Testing
import HungryCore

struct ProcessTreeTests {
    private static let launchd = ProcessSample(pid: 1, parentPid: 0, cpuSeconds: 0, path: "/sbin/launchd")
    private static let orca = "/Applications/Orca.app/Contents/MacOS/Orca"

    private func tree(_ samples: [ProcessSample]) -> ProcessTree {
        ProcessTree(samples: [Self.launchd] + samples)
    }

    private func sample(_ pid: Int32, _ parent: Int32, _ path: String) -> ProcessSample {
        ProcessSample(pid: pid, parentPid: parent, cpuSeconds: 0, path: path)
    }

    @Test func cliChildWithInnerShellBelongsToCli() {
        let tree = tree([
            sample(10, 1, Self.orca),
            sample(11, 10, "/bin/zsh"),
            sample(12, 11, "claude"),
            sample(13, 12, "/bin/sh"),
            sample(14, 13, "/usr/local/bin/node"),
        ])
        #expect(tree.ownerPath(of: 14) == "claude")
        #expect(tree.ownerPath(of: 13) == "claude")
        #expect(tree.ownerPath(of: 12) == "claude")
    }

    @Test func toolStartedFromTerminalShellOwnsItself() {
        let tree = tree([
            sample(10, 1, Self.orca),
            sample(11, 10, "/bin/zsh"),
            sample(12, 11, "/usr/local/bin/node"),
        ])
        #expect(tree.ownerPath(of: 12) == "/usr/local/bin/node")
    }

    @Test func tmuxChainBelongsToCli() {
        let tree = tree([
            sample(10, 1, "/opt/homebrew/bin/tmux"),
            sample(11, 10, "-zsh"),
            sample(12, 11, "claude"),
            sample(13, 12, "/usr/local/bin/node"),
        ])
        #expect(tree.ownerPath(of: 13) == "claude")
    }

    @Test func appHelperBelongsToApp() {
        let app = "/Applications/Claude.app/Contents/MacOS/Claude"
        let tree = tree([
            sample(10, 1, app),
            sample(11, 10, "/Applications/Claude.app/Contents/Frameworks/Claude Helper.app/Contents/MacOS/Claude Helper"),
        ])
        #expect(tree.ownerPath(of: 11) == app)
    }

    @Test func terminalHelperBelongsToTerminal() {
        let tree = tree([
            sample(10, 1, Self.orca),
            sample(11, 10, "/Applications/Orca.app/Contents/Frameworks/Orca Helper.app/Contents/MacOS/Orca Helper"),
        ])
        #expect(tree.ownerPath(of: 11) == Self.orca)
    }

    @Test func idleShellBelongsToTopProcess() {
        let tree = tree([
            sample(10, 1, Self.orca),
            sample(11, 10, "/bin/zsh"),
        ])
        #expect(tree.ownerPath(of: 11) == Self.orca)
    }

    @Test func daemonBelowLaunchdOwnsItself() {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer"
        let tree = tree([sample(10, 1, path)])
        #expect(tree.ownerPath(of: 10) == path)
    }

    @Test func nestedShellsUseFirstNonShellAfterFirstShell() {
        let tree = tree([
            sample(10, 1, Self.orca),
            sample(11, 10, "/bin/zsh"),
            sample(12, 11, "/bin/bash"),
            sample(13, 12, "claude"),
            sample(14, 13, "/usr/local/bin/node"),
        ])
        #expect(tree.ownerPath(of: 14) == "claude")
    }

    @Test func missingParentMakesHighestKnownProcessTheTop() {
        let tree = ProcessTree(samples: [
            sample(11, 999, "/bin/zsh"),
            sample(12, 11, "claude"),
            sample(13, 12, "/usr/local/bin/node"),
        ])
        #expect(tree.ownerPath(of: 13) == "claude")
        #expect(tree.ownerPath(of: 11) == "/bin/zsh")
    }

    @Test func parentLoopOwnsItself() {
        let tree = tree([
            sample(20, 21, "/bin/a"),
            sample(21, 20, "/bin/b"),
        ])
        #expect(tree.ownerPath(of: 20) == "/bin/a")
        #expect(tree.ownerPath(of: 21) == "/bin/b")
    }

    @Test func chainLongerThanMaxDepthOwnsItself() {
        let count = Int32(ProcessTree.maxDepth + 5)
        let chain = (0..<count).map { index in
            sample(100 + index, index == 0 ? 1 : 99 + index, "/bin/p\(index)")
        }
        let tree = tree(chain)
        let deepest = 100 + count - 1
        #expect(tree.ownerPath(of: deepest) == "/bin/p\(count - 1)")
        #expect(tree.ownerPath(of: 101) == "/bin/p0")
    }

    @Test(arguments: [(ProcessTree.maxDepth, "/bin/p0"), (ProcessTree.maxDepth + 1, "/bin/p\(ProcessTree.maxDepth + 1)")])
    func depthLimitBoundary(steps: Int, expectedOwner: String) {
        let count = Int32(steps + 1)
        let chain = (0..<count).map { index in
            sample(100 + index, index == 0 ? 1 : 99 + index, "/bin/p\(index)")
        }
        #expect(tree(chain).ownerPath(of: 100 + count - 1) == expectedOwner)
    }

    @Test func launchdOwnsItselfAndParentZeroOwnsItself() {
        let tree = tree([sample(50, 0, "kernel_task")])
        #expect(tree.ownerPath(of: 1) == "/sbin/launchd")
        #expect(tree.ownerPath(of: 50) == "kernel_task")
    }

    @Test func loginShellWithDashCountsAsShell() {
        let tree = tree([
            sample(10, 1, Self.orca),
            sample(11, 10, "-/bin/zsh"),
            sample(12, 11, "claude"),
            sample(13, 12, "/usr/local/bin/node"),
        ])
        #expect(tree.ownerPath(of: 13) == "claude")
    }

    @Test(arguments: ["/usr/bin/ssh", "/usr/local/bin/fish-lsp", "bashbot", "zsh-helper"])
    func namesThatContainShellNamesAreNotShells(path: String) {
        let tree = tree([
            sample(10, 1, path),
            sample(11, 10, "/usr/local/bin/node"),
        ])
        #expect(tree.ownerPath(of: 11) == path)
    }

    @Test func unknownPidHasNoOwner() {
        #expect(tree([]).ownerPath(of: 777) == nil)
    }

    @Test func ownerUsagesReplacesPathWithOwnerPath() {
        let tree = tree([
            sample(10, 1, Self.orca),
            sample(11, 10, "/bin/zsh"),
            sample(12, 11, "claude"),
            sample(13, 12, "/usr/local/bin/node"),
        ])
        let usages = tree.ownerUsages([ProcessUsage(pid: 13, path: "/usr/local/bin/node", percent: 7.5)])
        #expect(usages == [ProcessUsage(pid: 13, path: "claude", percent: 7.5)])
    }

    @Test func usageWithUnknownPidKeepsItsPath() {
        let usages = tree([]).ownerUsages([ProcessUsage(pid: 777, path: "/bin/gone", percent: 1)])
        #expect(usages == [ProcessUsage(pid: 777, path: "/bin/gone", percent: 1)])
    }
}
