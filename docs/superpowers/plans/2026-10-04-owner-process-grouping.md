# Owner Process Grouping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the CPU % of each child process into its owner process in the popover top N list, so that `claude` includes the `node` processes that it starts.

**Architecture:** `ps` also gives the parent PID. A new pure type `ProcessTree` in `HungryCore` finds the owner of each PID with the "after first shell" rule (spec section 3). `ProcessSampler` replaces the path of each `ProcessUsage` with its owner path before `AppGrouper` groups the values. `AppGrouper`, `ProcessCPUTracker`, `RankStabilizer`, and the UI do not change.

**Tech Stack:** Swift 6, Swift Package Manager, Swift Testing, macOS 14, `/bin/ps`, `libproc`.

**Spec:** `docs/superpowers/specs/2026-10-02-mac-hungry-menubar-design.md` — F7, section 3 "Owner process", section 5.3 steps 1–5 and 9, section 7 (2 new rows), section 9.1 items 3, 5, 6, section 9.2 item 3, section 9.3 item 8.

## Global Constraints

- Swift 6 language mode, strict concurrency. No `@unchecked Sendable`, no `nonisolated(unsafe)`.
- macOS 14 minimum. Xcode Command Line Tools only. Do not use `xcodebuild`.
- Tests use Swift Testing (`import Testing`). Run tests with `scripts/test.sh`, never plain `swift test`.
- `HungryCore` is pure logic: no AppKit, no SwiftUI, no system calls.
- Do not write code comments.
- No force unwrap (`!`) and no `try!` in `Sources/`.
- 1 main type per file. The file name equals the type name. Put a new file in the folder of its feature.
- CPU use of MacHungry is less than 5% of 1 core while the popover is open (N3). RAM is less than 35 MB after the first popover open (N1).
- Do not run `git commit` without an explicit instruction from the user. Each "Commit" step means: show the diff summary, ask the user, then commit only after a yes.

## Review Focus

1. **Login shells.** `ps` shows a login shell as `-/bin/zsh` or `-zsh`. It must count as a shell. Test: Task 3, `loginShellWithDashCountsAsShell`.
2. **Names that only contain a shell name.** `ssh`, `fish-lsp`, `bashbot`, `zsh-helper` are not shells. Only an exact name match counts. Test: Task 3, `namesThatContainShellNamesAreNotShells`.
3. **Process with parent PID 0.** `launchd` (PID 1) has parent 0. A process with parent 0 must own itself and must not crash. Test: Task 3, `launchdOwnsItselfAndParentZeroOwnsItself`.
4. **A CPU value for a PID that is not in the tree.** The usage must keep its own path. Test: Task 3, `usageWithUnknownPidKeepsItsPath`.
5. **The old `ps` line format (3 columns).** After the change, a 3-column line must be rejected, not read with a wrong parent PID. Test: Task 1, `rejectsMalformedLine` argument `"12 0:01.00 /bin/x"`.

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `Sources/HungryCore/Processes/ProcessSample.swift` | Modify | Add `parentPid`. |
| `Sources/HungryCore/Processes/PSParser.swift` | Modify | Read the `ppid` column. |
| `Sources/HungrySystem/Readers/PSRunner.swift` | Modify | Ask `ps` for `ppid`. |
| `Sources/HungrySystem/Readers/LibprocReader.swift` | Modify | Read `pbi_ppid` in the fallback. |
| `Sources/HungryCore/Processes/ProcessTree.swift` | Create | Owner rule. Maps usages to owner paths. |
| `Sources/HungrySystem/Samplers/ProcessSampler.swift` | Modify | Build the tree and use owner paths. |
| `Tests/HungryCoreTests/PSParserTests.swift` | Modify | New line format. |
| `Tests/HungryCoreTests/ProcessTreeTests.swift` | Create | Owner rule tests. |
| `Tests/HungryCoreTests/AppGrouperTests.swift` | Modify | Child process adds into its owner. |
| `Tests/HungrySystemTests/SamplerIntegrationTests.swift` | Modify | Parent PID from `ps` and from `libproc`. |

---

### Task 1: Parent PID from `ps`

**Files:**
- Modify: `Sources/HungryCore/Processes/ProcessSample.swift`
- Modify: `Sources/HungryCore/Processes/PSParser.swift:6-16`
- Modify: `Sources/HungrySystem/Readers/PSRunner.swift:7`
- Test: `Tests/HungryCoreTests/PSParserTests.swift`
- Test: `Tests/HungrySystemTests/SamplerIntegrationTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: `ProcessSample.parentPid: Int32` and `ProcessSample.init(pid: Int32, parentPid: Int32 = 0, cpuSeconds: Double, path: String)`. The default `0` keeps all existing `ProcessSample(pid:cpuSeconds:path:)` calls valid. `PSParser.parseLine(_:)` reads the format `pid ppid time path`.

- [ ] **Step 1: Update the parser tests to the new format**

Replace the 3 line-based tests in `Tests/HungryCoreTests/PSParserTests.swift` (from `parsesLineWithLeadingSpacesAndPathWithSpaces` to the end of `parseSkipsBadLinesAndKeepsGoodLines`) with:

```swift
    @Test func parsesLineWithLeadingSpacesAndPathWithSpaces() throws {
        let sample = try #require(PSParser.parseLine("  412     1   1:30.00 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome"))
        #expect(sample == ProcessSample(pid: 412, parentPid: 1, cpuSeconds: 90, path: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"))
    }

    @Test func parsesParentPidColumn() throws {
        let sample = try #require(PSParser.parseLine(" 3286  3183   0:00.71 -/bin/zsh"))
        #expect(sample.pid == 3286)
        #expect(sample.parentPid == 3183)
        #expect(sample.path == "-/bin/zsh")
    }

    @Test(arguments: [
        "",
        "   ",
        "abc 1 0:01.00 /bin/x",
        "12 x 0:01.00 /bin/x",
        "12 1 bad /bin/x",
        "12 1 0:01.00",
        "12 1 0:01.00   ",
        "12 0:01.00 /bin/x",
    ])
    func rejectsMalformedLine(line: String) {
        #expect(PSParser.parseLine(Substring(line)) == nil)
    }

    @Test func parseSkipsBadLinesAndKeepsGoodLines() {
        let output = """
            1     0  34:42.90 /sbin/launchd
        garbage line
          287     1   0:05.04 /usr/libexec/textunderstandingd

        """
        let samples = PSParser.parse(output)
        #expect(samples.map(\.pid) == [1, 287])
        #expect(samples.map(\.parentPid) == [0, 1])
    }
```

- [ ] **Step 2: Run the parser tests and check that they fail**

Run: `scripts/test.sh --filter PSParserTests`
Expected: build FAIL with `extra argument 'parentPid' in call` (or `has no member 'parentPid'`).

- [ ] **Step 3: Add `parentPid` to `ProcessSample`**

Replace the full content of `Sources/HungryCore/Processes/ProcessSample.swift` with:

```swift
public struct ProcessSample: Equatable, Sendable {
    public var pid: Int32
    public var parentPid: Int32
    public var cpuSeconds: Double
    public var path: String

    public init(pid: Int32, parentPid: Int32 = 0, cpuSeconds: Double, path: String) {
        self.pid = pid
        self.parentPid = parentPid
        self.cpuSeconds = cpuSeconds
        self.path = path
    }
}
```

- [ ] **Step 4: Read the `ppid` column in `PSParser.parseLine`**

Replace `parseLine` in `Sources/HungryCore/Processes/PSParser.swift` with:

```swift
    public static func parseLine(_ line: Substring) -> ProcessSample? {
        let afterLeadingSpace = line.drop(while: \.isWhitespace)
        guard let pidEnd = afterLeadingSpace.firstIndex(where: \.isWhitespace),
              let pid = Int32(afterLeadingSpace[..<pidEnd]) else { return nil }
        let afterPid = afterLeadingSpace[pidEnd...].drop(while: \.isWhitespace)
        guard let parentEnd = afterPid.firstIndex(where: \.isWhitespace),
              let parentPid = Int32(afterPid[..<parentEnd]) else { return nil }
        let afterParent = afterPid[parentEnd...].drop(while: \.isWhitespace)
        guard let timeEnd = afterParent.firstIndex(where: \.isWhitespace),
              let seconds = parseTime(afterParent[..<timeEnd]) else { return nil }
        let path = afterParent[timeEnd...].drop(while: \.isWhitespace)
        guard !path.isEmpty else { return nil }
        return ProcessSample(pid: pid, parentPid: parentPid, cpuSeconds: seconds, path: String(path))
    }
```

- [ ] **Step 5: Ask `ps` for the `ppid` column**

In `Sources/HungrySystem/Readers/PSRunner.swift`, change:

```swift
        process.arguments = ["-axo", "pid=,time=,comm="]
```

to:

```swift
        process.arguments = ["-axo", "pid=,ppid=,time=,comm="]
```

- [ ] **Step 6: Add the integration check for the parent PID from `ps`**

In `Tests/HungrySystemTests/SamplerIntegrationTests.swift`, replace `psRunnerReadsRootProcesses` with:

```swift
    @Test func psRunnerReadsRootProcessesAndParentPids() throws {
        let output = try #require(PSRunner.run(timeout: ProcessSampler.psTimeout))
        let samples = PSParser.parse(output)
        #expect(samples.count > 50)
        #expect(samples.contains { $0.pid == 1 })
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let own = try #require(samples.first { $0.pid == ownPID })
        #expect(own.parentPid == getppid())
    }
```

- [ ] **Step 7: Run all tests and check that they pass**

Run: `scripts/test.sh`
Expected: PASS for all tests, including `PSParserTests` and `psRunnerReadsRootProcessesAndParentPids`. The `ProcessCPUTrackerTests` still compile because of the default `parentPid: 0`.

- [ ] **Step 8: Commit (ask the user first)**

```bash
git add Sources/HungryCore/Processes/ProcessSample.swift Sources/HungryCore/Processes/PSParser.swift Sources/HungrySystem/Readers/PSRunner.swift Tests/HungryCoreTests/PSParserTests.swift Tests/HungrySystemTests/SamplerIntegrationTests.swift
git commit -m "feat(core): read parent pid from ps"
```

---

### Task 2: Parent PID in the `libproc` fallback

**Files:**
- Modify: `Sources/HungrySystem/Readers/LibprocReader.swift:19-23`
- Test: `Tests/HungrySystemTests/SamplerIntegrationTests.swift`

**Interfaces:**
- Consumes: `ProcessSample.init(pid:parentPid:cpuSeconds:path:)` from Task 1.
- Produces: `LibprocReader.samples()` gives samples with a real `parentPid` (0 if the read fails).

- [ ] **Step 1: Write the failing integration test**

In `Tests/HungrySystemTests/SamplerIntegrationTests.swift`, replace `libprocFallbackReadsOwnProcesses` with:

```swift
    @Test func libprocFallbackReadsOwnProcessAndParentPid() throws {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let own = try #require(LibprocReader.samples().first { $0.pid == ownPID })
        #expect(own.parentPid == getppid())
    }
```

- [ ] **Step 2: Run the test and check that it fails**

Run: `scripts/test.sh --filter libprocFallbackReadsOwnProcessAndParentPid`
Expected: FAIL. `own.parentPid` is `0`, not the value of `getppid()`.

- [ ] **Step 3: Read `pbi_ppid`**

In `Sources/HungrySystem/Readers/LibprocReader.swift`, change the `result.append(...)` line in `samples()` to:

```swift
            result.append(ProcessSample(pid: pid, parentPid: parentPid(of: pid), cpuSeconds: Double(cpuTicks) * scale / 1_000_000_000, path: path))
```

Add this method below `cpuTicks(of:)`:

```swift
    private static func parentPid(of pid: pid_t) -> Int32 {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        let read = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        return read == size ? Int32(bitPattern: info.pbi_ppid) : 0
    }
```

- [ ] **Step 4: Run all tests and check that they pass**

Run: `scripts/test.sh`
Expected: PASS for all tests.

- [ ] **Step 5: Commit (ask the user first)**

```bash
git add Sources/HungrySystem/Readers/LibprocReader.swift Tests/HungrySystemTests/SamplerIntegrationTests.swift
git commit -m "feat(system): read parent pid in libproc fallback"
```

---

### Task 3: `ProcessTree` owner rule

**Files:**
- Create: `Sources/HungryCore/Processes/ProcessTree.swift`
- Test: `Tests/HungryCoreTests/ProcessTreeTests.swift`

**Interfaces:**
- Consumes: `ProcessSample` with `parentPid` (Task 1). `ProcessUsage(pid:path:percent:)` (exists in `ProcessCPUTracker.swift`).
- Produces:
  - `public struct ProcessTree: Sendable`
  - `public static let maxDepth: Int` (value `64`)
  - `public static let shellNames: Set<String>`
  - `public init(samples: [ProcessSample])`
  - `public func ownerPath(of pid: Int32) -> String?` — `nil` only if the PID is not in the samples.
  - `public func ownerUsages(_ usages: [ProcessUsage]) -> [ProcessUsage]` — same PIDs and percents, path replaced by the owner path; unknown PIDs keep their path.

**Rule (spec section 3):** Make the chain from the process up. Stop before `launchd` (PID 1), before a parent that is not in the samples, or before a parent PID ≤ 0. If a PID repeats or the chain has more than `maxDepth` entries, the process owns itself. Read the chain from the top down. If it has a shell, the owner is the first non-shell after the first shell. Otherwise, or if no non-shell follows, the owner is the top entry. `launchd` owns itself. A shell is a process whose last path component, without a leading `-`, is in `shellNames`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/HungryCoreTests/ProcessTreeTests.swift`:

```swift
import Testing
@testable import HungryCore

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
```

- [ ] **Step 2: Run the tests and check that they fail**

Run: `scripts/test.sh --filter ProcessTreeTests`
Expected: build FAIL with `cannot find 'ProcessTree' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/HungryCore/Processes/ProcessTree.swift`:

```swift
public struct ProcessTree: Sendable {
    public static let maxDepth = 64
    public static let shellNames: Set<String> = ["sh", "bash", "zsh", "fish", "dash", "ksh", "tcsh", "csh", "login"]

    private static let launchdPid: Int32 = 1

    private let parents: [Int32: Int32]
    private let paths: [Int32: String]

    public init(samples: [ProcessSample]) {
        var parents: [Int32: Int32] = [:]
        var paths: [Int32: String] = [:]
        parents.reserveCapacity(samples.count)
        paths.reserveCapacity(samples.count)
        for sample in samples {
            parents[sample.pid] = sample.parentPid
            paths[sample.pid] = sample.path
        }
        self.parents = parents
        self.paths = paths
    }

    public func ownerPath(of pid: Int32) -> String? {
        guard let ownPath = paths[pid] else { return nil }
        guard pid != Self.launchdPid, let chain = chainUp(from: pid) else { return ownPath }
        let topDown = Array(chain.reversed())
        if let firstShell = topDown.firstIndex(where: isShell),
           let owner = topDown[(firstShell + 1)...].first(where: { !isShell($0) }) {
            return paths[owner] ?? ownPath
        }
        return topDown.first.flatMap { paths[$0] } ?? ownPath
    }

    public func ownerUsages(_ usages: [ProcessUsage]) -> [ProcessUsage] {
        usages.map { usage in
            ProcessUsage(pid: usage.pid, path: ownerPath(of: usage.pid) ?? usage.path, percent: usage.percent)
        }
    }

    private func chainUp(from pid: Int32) -> [Int32]? {
        var chain = [pid]
        var visited: Set<Int32> = [pid]
        var current = pid
        while let parent = parents[current], parent > Self.launchdPid, paths[parent] != nil {
            guard !visited.contains(parent), chain.count < Self.maxDepth else { return nil }
            chain.append(parent)
            visited.insert(parent)
            current = parent
        }
        return chain
    }

    private func isShell(_ pid: Int32) -> Bool {
        guard let path = paths[pid] else { return false }
        let name = path.split(separator: "/").last.map(String.init) ?? path
        let bare = name.hasPrefix("-") ? String(name.dropFirst()) : name
        return Self.shellNames.contains(bare)
    }
}
```

Note for the implementer: for `-/bin/zsh`, `split(separator: "/")` gives `["-", "bin", "zsh"]`, so the last component is `zsh`. For `-zsh`, the last component is `-zsh`, and the code removes the `-`.

- [ ] **Step 4: Run the tests and check that they pass**

Run: `scripts/test.sh --filter ProcessTreeTests`
Expected: PASS for all `ProcessTreeTests` (17 tests, 20 cases with the 4 arguments of `namesThatContainShellNamesAreNotShells`).

- [ ] **Step 5: Run all tests**

Run: `scripts/test.sh`
Expected: PASS for all tests.

- [ ] **Step 6: Commit (ask the user first)**

```bash
git add Sources/HungryCore/Processes/ProcessTree.swift Tests/HungryCoreTests/ProcessTreeTests.swift
git commit -m "feat(core): add process tree owner rule"
```

---

### Task 4: Use owners in `ProcessSampler`

**Files:**
- Modify: `Sources/HungrySystem/Samplers/ProcessSampler.swift:17-27`
- Test: `Tests/HungryCoreTests/AppGrouperTests.swift`

**Interfaces:**
- Consumes: `ProcessTree(samples:)` and `ProcessTree.ownerUsages(_:)` (Task 3). `AppGrouper.topApps(_:limit:)` (no change).
- Produces: `ProcessSampler.sample(limit:)` gives apps grouped by owner. The signature does not change.

- [ ] **Step 1: Write the grouping test**

Add this test at the end of `AppGrouperTests` in `Tests/HungryCoreTests/AppGrouperTests.swift`:

```swift
    @Test func childProcessAddsIntoItsOwner() {
        let tree = ProcessTree(samples: [
            ProcessSample(pid: 1, parentPid: 0, cpuSeconds: 0, path: "/sbin/launchd"),
            ProcessSample(pid: 10, parentPid: 1, cpuSeconds: 0, path: "/Applications/Orca.app/Contents/MacOS/Orca"),
            ProcessSample(pid: 11, parentPid: 10, cpuSeconds: 0, path: "/bin/zsh"),
            ProcessSample(pid: 12, parentPid: 11, cpuSeconds: 0, path: "claude"),
            ProcessSample(pid: 13, parentPid: 12, cpuSeconds: 0, path: "/usr/local/bin/node"),
            ProcessSample(pid: 14, parentPid: 11, cpuSeconds: 0, path: "/usr/local/bin/node"),
        ])
        let usages = [
            ProcessUsage(pid: 12, path: "claude", percent: 2),
            ProcessUsage(pid: 13, path: "/usr/local/bin/node", percent: 18),
            ProcessUsage(pid: 14, path: "/usr/local/bin/node", percent: 5),
        ]
        let top = AppGrouper.topApps(tree.ownerUsages(usages), limit: 10)
        #expect(top.map(\.identity.name) == ["claude", "node"])
        #expect(top.map(\.percent) == [20, 5])
    }
```

- [ ] **Step 2: Run the test and check that it passes**

Run: `scripts/test.sh --filter AppGrouperTests`
Expected: PASS. This test locks the contract between Task 3 and `AppGrouper`. It passes already, because `AppGrouper` does not change.

- [ ] **Step 3: Use the tree in `ProcessSampler.sample`**

Replace `sample(limit:)` in `Sources/HungrySystem/Samplers/ProcessSampler.swift` with:

```swift
    public mutating func sample(limit: Int) -> ProcessSnapshot {
        let wasReady = tracker.hasBaseline
        let output = PSRunner.run(timeout: Self.psTimeout)
        let now = ProcessInfo.processInfo.systemUptime
        let samples = output.map(PSParser.parse) ?? LibprocReader.samples()
        let usages = tracker.update(samples: samples, at: now)
        let tree = ProcessTree(samples: samples)
        return ProcessSnapshot(
            apps: AppGrouper.topApps(tree.ownerUsages(usages), limit: limit),
            isReady: wasReady,
            isLimited: output == nil
        )
    }
```

- [ ] **Step 4: Run all tests and build**

Run: `scripts/test.sh && swift build`
Expected: PASS for all tests, including `processSamplerIsReadyOnSecondSample`. `Build complete!`.

- [ ] **Step 5: Manual check (spec 9.3 item 8)**

1. Run `/build-run`.
2. Open the popover while a `claude` session with MCP servers runs.
3. Run `ps -axo pid=,ppid=,comm= | grep node` and find the `node` processes whose parent is a `claude` PID. Check that no separate `node` row shows for them, and that the `claude` row value is higher than before this change.
4. Check that `Orca`, `WindowServer`, and `Claude` rows still show.

- [ ] **Step 6: Performance audit**

Ask the `perf-auditor` agent to measure MacHungry with the popover open for 60 s. Pass: CPU < 5% of 1 core, RAM < 35 MB (N1, N3).

- [ ] **Step 7: Commit (ask the user first)**

```bash
git add Sources/HungrySystem/Samplers/ProcessSampler.swift Tests/HungryCoreTests/AppGrouperTests.swift
git commit -m "feat(system): group top apps by owner process"
```
