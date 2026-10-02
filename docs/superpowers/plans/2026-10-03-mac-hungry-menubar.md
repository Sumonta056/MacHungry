# MacHungry Menu Bar Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build MacHungry, a macOS menu bar app that shows live CPU %, RAM %, and CPU temperature, an animation whose speed follows CPU, and a popover with the top 10 apps by CPU.

**Architecture:** 3 Swift Package Manager modules. `HungryCore` holds pure, unit-tested logic. `HungrySystem` holds the samplers (Mach, `libproc`, `/bin/ps`, SMC through IOKit) in 1 background actor. `MacHungry` is the AppKit + SwiftUI app: 1 status item whose content draws in Core Animation layers (cheap), and an `NSPopover` with a SwiftUI view.

**Tech Stack:** Swift 6 (language mode 6), Swift Package Manager (tools 6.0), AppKit, SwiftUI, Observation, Core Animation, IOKit, ServiceManagement, Swift Testing. Xcode Command Line Tools only.

**Spec:** `docs/superpowers/specs/2026-10-02-mac-hungry-menubar-design.md` (read section 5.6 before Task 6, and sections 6.1 and 12 before Task 7).

**Verified:** Every code block in this plan comes from a prototype that the user checked in the real menu bar on 2026-10-03. A script applied Tasks 1–8 in order to an empty folder; each task built and passed its tests.

## Global Constraints

- macOS 14.0 minimum (`platforms: [.macOS(.v14)]`, `LSMinimumSystemVersion` 14.0).
- Swift tools version 6.0. Swift 6 strict concurrency. 0 compiler warnings from our code. (The `ld: warning: search path … not found` lines come from the Command Line Tools and are not ours.)
- No full Xcode: do not use `xcodebuild` or `.xcodeproj`.
- No third-party dependencies.
- No code comments.
- No SwiftUI `@State`, `@Entry`, or `@Previewable` (macro plugin missing with the Command Line Tools). Use `@Observable` + `Binding(get:set:)`.
- `HungryCore` imports `Foundation` only and makes no system calls.
- No test target imports the `MacHungry` executable.
- Set `rep.size` before `NSGraphicsContext(bitmapImageRep:)`.
- Never set `NSStatusBarButton.image` per animation frame.
- Never call `forceTerminate()`.
- Budget: RAM < 30 MB; CPU < 1% with the popover closed (also at full load); CPU < 5% with it open.
- Bundle id `com.machungry.app`, version `0.1.0`, build `1`. Universal binary (arm64 + x86_64).
- Commits: the user's rules say **never commit without explicit instruction**. Each "Commit" step means: show the user the staged files, ask for approval, then commit on the feature branch (never on `main`; a hook blocks it).
- Always run tests with `scripts/test.sh`, never with plain `swift test`. The default build system sometimes omits the Swift Testing plugin path (about 50% of clean builds fail with `plugin for module 'TestingMacros' not found`). The script passes the path explicitly; it passed 4 of 4 clean builds.

## Review Focus

These 5 conditions are likely to bite a user, but no unit test covers them. Each one has a check in the task that owns the code.

1. **Light/dark change while the app runs.** The menu bar content must switch between white and black at once. Check: Task 7, Step 4.
2. **The window moves between a Retina and a non-Retina display.** The content must stay sharp and the correct size (`viewDidChangeBackingProperties`). Check: Task 7, Step 4.
3. **CPU at exactly 100%.** The only value that is wider than its `99%` slot. The item must grow by 1 digit and not overlap. Check: Task 7, Step 5.
4. **Quit on an app with many processes (helpers).** `Quit` must ask first, `Cancel` must do nothing, and system rows must have no `(×)`. Check: Task 8, Step 3.
5. **Theme change while the app runs, then restart.** The width changes once, the new frames show, and the theme stays after restart (F5). Check: Task 8, Step 3.

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `Package.swift` | Modules and targets (grows in Tasks 1, 6, 7) | 1, 6, 7 |
| `.gitignore` | Ignore `.build/` and `build/` | 1 |
| `Sources/HungryCore/CoreTicks.swift`, `CPUCalculator.swift` | CPU % from tick snapshots | 1 |
| `Sources/HungryCore/MemoryCalculator.swift` | RAM % from page counts | 1 |
| `Sources/HungryCore/ProcessSample.swift`, `PSParser.swift` | Parse `ps` output | 2 |
| `Sources/HungryCore/ProcessCPUTracker.swift` | CPU % per PID | 2 |
| `Sources/HungryCore/AppGrouper.swift` | Path → app, sum, top N | 3 |
| `Sources/HungryCore/RankStabilizer.swift` | Stable row order | 3 |
| `Sources/HungryCore/SpeedCurve.swift` | Smoothing and frame interval | 4 |
| `Sources/HungryCore/UsageFormatter.swift` | Text for values and tooltip | 4 |
| `Sources/HungryCore/Themes/*.swift` | Theme protocol, 3 themes, registry | 4 |
| `Sources/HungryCore/TemperatureReading.swift`, `ChipFamily.swift`, `TemperatureSensors.swift` | Chip detection, SMC key tables, hottest/smoothing | 5 |
| `Sources/HungryCore/UsageFormatter.swift` | Replaced with the temperature version | 5 |
| `Sources/HungrySystem/*.swift` | Mach, `libproc`, `ps`, and SMC samplers and the actor | 6 |
| `scripts/draw-frames.swift` | Draws the PNG frames | 7 |
| `Resources/Info.plist`, `Resources/Themes/**` | Bundle metadata and frames | 7 |
| `scripts/make-app.sh` | Universal `.app` + DMG, optional notarization | 7 |
| `Sources/MacHungry/` menu bar files | Store, monitor, renderer, composer, layer view, animator, controller, start-up | 7 |
| `Sources/MacHungry/` popover files | Model, views (incl. temperature row), icon cache, quit, login item | 8 |

---

### Task 1: Package scaffold, CPU and memory calculators

**Requirements:** F1, F2, N4, N6 (spec 5.1, 5.2, 8)

**Files:**
- Create or replace: `Package.swift`
- Create or replace: `.gitignore`
- Create or replace: `scripts/test.sh`
- Create or replace: `Sources/HungryCore/CoreTicks.swift`
- Create or replace: `Sources/HungryCore/CPUCalculator.swift`
- Create or replace: `Sources/HungryCore/MemoryCalculator.swift`
- Test: `Tests/HungryCoreTests/CPUCalculatorTests.swift`
- Test: `Tests/HungryCoreTests/MemoryCalculatorTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `CoreTicks(user:system:nice:idle:)` (all `UInt32`); `CPUCalculator.usagePercent(previous: [CoreTicks], current: [CoreTicks]) -> Double`; `MemoryPages(internalPages:purgeablePages:wiredPages:compressedPages:)` (all `UInt64`); `MemoryUsage(usedBytes: UInt64, totalBytes: UInt64, percent: Double)`; `MemoryCalculator.usage(pages:pageSize:totalBytes:) -> MemoryUsage`.

- [ ] **Step 1: Create the setup files**

`Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacHungry",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "HungryCore"),
        .testTarget(name: "HungryCoreTests", dependencies: ["HungryCore"]),
    ]
)
```

`.gitignore`:

```text
.build/
build/
.DS_Store
```

`scripts/test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

TOOLCHAIN="$(dirname "$(dirname "$(xcrun --find swift)")")"
exec swift test -Xswiftc -plugin-path -Xswiftc "$TOOLCHAIN/lib/swift/host/plugins/testing" "$@"
```

Make the test script executable: `chmod +x scripts/test.sh`. Use `scripts/test.sh` for every test run in this plan. It passes the Swift Testing macro plugin path, which the default build system sometimes omits.

- [ ] **Step 2: Write the failing tests**

`Tests/HungryCoreTests/CPUCalculatorTests.swift`:

```swift
import Testing
@testable import HungryCore

struct CPUCalculatorTests {
    @Test func idleMachineIsZero() {
        let previous = [CoreTicks(user: 10, system: 10, nice: 0, idle: 100)]
        let current = [CoreTicks(user: 10, system: 10, nice: 0, idle: 200)]
        #expect(CPUCalculator.usagePercent(previous: previous, current: current) == 0)
    }

    @Test func fullLoadIsHundred() {
        let previous = [CoreTicks(user: 0, system: 0, nice: 0, idle: 50)]
        let current = [CoreTicks(user: 60, system: 30, nice: 10, idle: 50)]
        #expect(CPUCalculator.usagePercent(previous: previous, current: current) == 100)
    }

    @Test func mixedCoresAverageBusyShare() {
        let previous = [CoreTicks(user: 0, system: 0, nice: 0, idle: 0), CoreTicks(user: 0, system: 0, nice: 0, idle: 0)]
        let current = [CoreTicks(user: 100, system: 0, nice: 0, idle: 0), CoreTicks(user: 0, system: 0, nice: 0, idle: 100)]
        #expect(CPUCalculator.usagePercent(previous: previous, current: current) == 50)
    }

    @Test func noElapsedTicksIsZero() {
        let ticks = [CoreTicks(user: 5, system: 5, nice: 5, idle: 5)]
        #expect(CPUCalculator.usagePercent(previous: ticks, current: ticks) == 0)
    }

    @Test func coreCountChangeIsZero() {
        let previous = [CoreTicks(user: 0, system: 0, nice: 0, idle: 0)]
        let current = [CoreTicks(user: 9, system: 0, nice: 0, idle: 1), CoreTicks(user: 9, system: 0, nice: 0, idle: 1)]
        #expect(CPUCalculator.usagePercent(previous: previous, current: current) == 0)
    }

    @Test func counterWrapAroundStaysPositive() {
        let previous = [CoreTicks(user: UInt32.max - 9, system: 0, nice: 0, idle: 0)]
        let current = [CoreTicks(user: 10, system: 0, nice: 0, idle: 20)]
        #expect(CPUCalculator.usagePercent(previous: previous, current: current) == 50)
    }
}
```

`Tests/HungryCoreTests/MemoryCalculatorTests.swift`:

```swift
import Testing
@testable import HungryCore

struct MemoryCalculatorTests {
    @Test func usedMemoryIsAppPlusWiredPlusCompressed() {
        let pages = MemoryPages(internalPages: 600, purgeablePages: 100, wiredPages: 200, compressedPages: 300)
        let usage = MemoryCalculator.usage(pages: pages, pageSize: 1_000, totalBytes: 2_000_000)
        #expect(usage.usedBytes == 1_000_000)
        #expect(usage.totalBytes == 2_000_000)
        #expect(usage.percent == 50)
    }

    @Test func purgeableLargerThanInternalCountsAsZeroAppMemory() {
        let pages = MemoryPages(internalPages: 10, purgeablePages: 50, wiredPages: 100, compressedPages: 0)
        let usage = MemoryCalculator.usage(pages: pages, pageSize: 10, totalBytes: 10_000)
        #expect(usage.usedBytes == 1_000)
        #expect(usage.percent == 10)
    }

    @Test func usedMemoryNeverExceedsTotal() {
        let pages = MemoryPages(internalPages: 5_000, purgeablePages: 0, wiredPages: 0, compressedPages: 0)
        let usage = MemoryCalculator.usage(pages: pages, pageSize: 16_384, totalBytes: 1_000)
        #expect(usage.usedBytes == 1_000)
        #expect(usage.percent == 100)
    }

    @Test func zeroTotalGivesZeroPercent() {
        let pages = MemoryPages(internalPages: 1, purgeablePages: 0, wiredPages: 1, compressedPages: 1)
        #expect(MemoryCalculator.usage(pages: pages, pageSize: 16_384, totalBytes: 0).percent == 0)
    }
}
```

- [ ] **Step 3: Run the tests and see them fail**

Run: `scripts/test.sh`

Expected: the build fails with a build error, because the `HungryCore` target has no source files yet (or `cannot find 'CoreTicks' in scope`).

- [ ] **Step 4: Write the implementation**

`Sources/HungryCore/CoreTicks.swift`:

```swift
public struct CoreTicks: Equatable, Sendable {
    public var user: UInt32
    public var system: UInt32
    public var nice: UInt32
    public var idle: UInt32

    public init(user: UInt32, system: UInt32, nice: UInt32, idle: UInt32) {
        self.user = user
        self.system = system
        self.nice = nice
        self.idle = idle
    }
}
```

`Sources/HungryCore/CPUCalculator.swift`:

```swift
public enum CPUCalculator {
    public static func usagePercent(previous: [CoreTicks], current: [CoreTicks]) -> Double {
        guard previous.count == current.count, !current.isEmpty else { return 0 }
        var busy: UInt64 = 0
        var total: UInt64 = 0
        for (old, new) in zip(previous, current) {
            let coreBusy = delta(old.user, new.user) + delta(old.system, new.system) + delta(old.nice, new.nice)
            busy += coreBusy
            total += coreBusy + delta(old.idle, new.idle)
        }
        guard total > 0 else { return 0 }
        return Double(busy) / Double(total) * 100
    }

    private static func delta(_ old: UInt32, _ new: UInt32) -> UInt64 {
        UInt64(new &- old)
    }
}
```

`Sources/HungryCore/MemoryCalculator.swift`:

```swift
public struct MemoryPages: Equatable, Sendable {
    public var internalPages: UInt64
    public var purgeablePages: UInt64
    public var wiredPages: UInt64
    public var compressedPages: UInt64

    public init(internalPages: UInt64, purgeablePages: UInt64, wiredPages: UInt64, compressedPages: UInt64) {
        self.internalPages = internalPages
        self.purgeablePages = purgeablePages
        self.wiredPages = wiredPages
        self.compressedPages = compressedPages
    }
}

public struct MemoryUsage: Equatable, Sendable {
    public var usedBytes: UInt64
    public var totalBytes: UInt64
    public var percent: Double

    public init(usedBytes: UInt64, totalBytes: UInt64, percent: Double) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.percent = percent
    }
}

public enum MemoryCalculator {
    public static func usage(pages: MemoryPages, pageSize: UInt64, totalBytes: UInt64) -> MemoryUsage {
        let appPages = pages.internalPages > pages.purgeablePages ? pages.internalPages - pages.purgeablePages : 0
        let usedBytes = min((appPages + pages.wiredPages + pages.compressedPages) * pageSize, totalBytes)
        let percent = totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0
        return MemoryUsage(usedBytes: usedBytes, totalBytes: totalBytes, percent: percent)
    }
}
```

- [ ] **Step 5: Run the tests and see them pass**

Run: `scripts/test.sh`

Expected: `Test run with 10 tests in 2 suites passed`. 0 warnings from our code.

- [ ] **Step 6: Commit (ask the user first)**

```bash
git add .gitignore Package.swift Sources/HungryCore/CPUCalculator.swift Sources/HungryCore/CoreTicks.swift Sources/HungryCore/MemoryCalculator.swift Tests/HungryCoreTests/CPUCalculatorTests.swift Tests/HungryCoreTests/MemoryCalculatorTests.swift scripts/test.sh
git commit -m "feat(core): add CPU and memory calculators"
```

---

### Task 2: ps parser and per-process CPU tracker

**Requirements:** F7, F8, F9 (spec 5.3 steps 2–3, 7)

**Files:**
- Create or replace: `Sources/HungryCore/ProcessSample.swift`
- Create or replace: `Sources/HungryCore/PSParser.swift`
- Create or replace: `Sources/HungryCore/ProcessCPUTracker.swift`
- Test: `Tests/HungryCoreTests/PSParserTests.swift`
- Test: `Tests/HungryCoreTests/ProcessCPUTrackerTests.swift`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `ProcessSample(pid: Int32, cpuSeconds: Double, path: String)`; `PSParser.parse(_ output: String) -> [ProcessSample]`, `PSParser.parseLine(_: Substring) -> ProcessSample?`, `PSParser.parseTime(_: Substring) -> Double?`; `ProcessUsage(pid: Int32, path: String, percent: Double)`; `ProcessCPUTracker` with `hasBaseline: Bool`, `trackedCount: Int`, `mutating update(samples: [ProcessSample], at time: Double) -> [ProcessUsage]`, `mutating reset()`.

- [ ] **Step 1: Write the failing tests**

`Tests/HungryCoreTests/PSParserTests.swift`:

```swift
import Testing
@testable import HungryCore

struct PSParserTests {
    @Test(arguments: [
        ("0:05.04", 5.04),
        ("34:42.90", 2_082.90),
        ("2072:15.03", 124_335.03),
        ("1:02:03.50", 3_723.50),
        ("2-01:00:00.00", 176_400.0),
    ])
    func parsesTimeFormats(text: String, expected: Double) throws {
        let seconds = try #require(PSParser.parseTime(Substring(text)))
        #expect(abs(seconds - expected) < 0.000_1)
    }

    @Test(arguments: ["", "abc", "1:2:3:4", "5", "-1:00.00", "x-1:00.00", "1:inf", "1::00"])
    func rejectsMalformedTime(text: String) {
        #expect(PSParser.parseTime(Substring(text)) == nil)
    }

    @Test func parsesLineWithLeadingSpacesAndPathWithSpaces() throws {
        let sample = try #require(PSParser.parseLine("  412   1:30.00 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome"))
        #expect(sample == ProcessSample(pid: 412, cpuSeconds: 90, path: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"))
    }

    @Test(arguments: ["", "   ", "abc 0:01.00 /bin/x", "12 bad /bin/x", "12 0:01.00", "12 0:01.00   "])
    func rejectsMalformedLine(line: String) {
        #expect(PSParser.parseLine(Substring(line)) == nil)
    }

    @Test func parseSkipsBadLinesAndKeepsGoodLines() {
        let output = """
            1  34:42.90 /sbin/launchd
        garbage line
          287   0:05.04 /usr/libexec/textunderstandingd

        """
        let samples = PSParser.parse(output)
        #expect(samples.map(\.pid) == [1, 287])
    }
}
```

`Tests/HungryCoreTests/ProcessCPUTrackerTests.swift`:

```swift
import Testing
@testable import HungryCore

struct ProcessCPUTrackerTests {
    @Test func firstSampleOnlyCreatesBaseline() {
        var tracker = ProcessCPUTracker()
        #expect(!tracker.hasBaseline)
        let usages = tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 10, path: "/bin/a")], at: 100)
        #expect(usages.isEmpty)
        #expect(tracker.hasBaseline)
    }

    @Test func percentIsCPUSecondsOverWallSeconds() throws {
        var tracker = ProcessCPUTracker()
        _ = tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 10, path: "/bin/a")], at: 100)
        let usages = tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 13, path: "/bin/a")], at: 102)
        let usage = try #require(usages.first)
        #expect(usage.percent == 150)
        #expect(usage.path == "/bin/a")
    }

    @Test func newPidShowsFromNextSample() {
        var tracker = ProcessCPUTracker()
        _ = tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 0, path: "/bin/a")], at: 0)
        let usages = tracker.update(samples: [
            ProcessSample(pid: 1, cpuSeconds: 1, path: "/bin/a"),
            ProcessSample(pid: 2, cpuSeconds: 50, path: "/bin/b"),
        ], at: 1)
        #expect(usages.map(\.pid) == [1])
    }

    @Test func pidReuseShowsZeroForThatSample() throws {
        var tracker = ProcessCPUTracker()
        _ = tracker.update(samples: [ProcessSample(pid: 7, cpuSeconds: 500, path: "/bin/old")], at: 0)
        let usages = tracker.update(samples: [ProcessSample(pid: 7, cpuSeconds: 2, path: "/bin/new")], at: 1)
        #expect(try #require(usages.first).percent == 0)
        let next = tracker.update(samples: [ProcessSample(pid: 7, cpuSeconds: 3, path: "/bin/new")], at: 2)
        #expect(try #require(next.first).percent == 100)
    }

    @Test func stoppedPidsAreRemoved() {
        var tracker = ProcessCPUTracker()
        _ = tracker.update(samples: [
            ProcessSample(pid: 1, cpuSeconds: 0, path: "/bin/a"),
            ProcessSample(pid: 2, cpuSeconds: 0, path: "/bin/b"),
        ], at: 0)
        _ = tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 0, path: "/bin/a")], at: 1)
        #expect(tracker.trackedCount == 1)
    }

    @Test func nonPositiveElapsedTimeGivesNoUsage() {
        var tracker = ProcessCPUTracker()
        _ = tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 0, path: "/bin/a")], at: 5)
        #expect(tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 1, path: "/bin/a")], at: 5).isEmpty)
    }

    @Test func resetClearsBaseline() {
        var tracker = ProcessCPUTracker()
        _ = tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 0, path: "/bin/a")], at: 0)
        tracker.reset()
        #expect(!tracker.hasBaseline)
        #expect(tracker.trackedCount == 0)
    }
}
```

- [ ] **Step 2: Run the tests and see them fail**

Run: `scripts/test.sh`

Expected: the build fails with `error: cannot find 'PSParser' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/HungryCore/ProcessSample.swift`:

```swift
public struct ProcessSample: Equatable, Sendable {
    public var pid: Int32
    public var cpuSeconds: Double
    public var path: String

    public init(pid: Int32, cpuSeconds: Double, path: String) {
        self.pid = pid
        self.cpuSeconds = cpuSeconds
        self.path = path
    }
}
```

`Sources/HungryCore/PSParser.swift`:

```swift
public enum PSParser {
    public static func parse(_ output: String) -> [ProcessSample] {
        output.split(whereSeparator: \.isNewline).compactMap { parseLine($0) }
    }

    public static func parseLine(_ line: Substring) -> ProcessSample? {
        let afterLeadingSpace = line.drop(while: \.isWhitespace)
        guard let pidEnd = afterLeadingSpace.firstIndex(where: \.isWhitespace),
              let pid = Int32(afterLeadingSpace[..<pidEnd]) else { return nil }
        let afterPid = afterLeadingSpace[pidEnd...].drop(while: \.isWhitespace)
        guard let timeEnd = afterPid.firstIndex(where: \.isWhitespace),
              let seconds = parseTime(afterPid[..<timeEnd]) else { return nil }
        let path = afterPid[timeEnd...].drop(while: \.isWhitespace)
        guard !path.isEmpty else { return nil }
        return ProcessSample(pid: pid, cpuSeconds: seconds, path: String(path))
    }

    public static func parseTime(_ text: Substring) -> Double? {
        var days = 0.0
        var clock = text
        if let dash = text.firstIndex(of: "-") {
            guard let parsedDays = Double(text[..<dash]) else { return nil }
            days = parsedDays
            clock = text[text.index(after: dash)...]
        }
        let parts = clock.split(separator: ":", omittingEmptySubsequences: false)
        let values = parts.compactMap { Double($0) }
        guard (2...3).contains(parts.count), values.count == parts.count,
              values.allSatisfy({ $0.isFinite && $0 >= 0 }), days.isFinite, days >= 0 else { return nil }
        return days * 86_400 + values.reduce(0) { $0 * 60 + $1 }
    }
}
```

`Sources/HungryCore/ProcessCPUTracker.swift`:

```swift
public struct ProcessUsage: Equatable, Sendable {
    public var pid: Int32
    public var path: String
    public var percent: Double

    public init(pid: Int32, path: String, percent: Double) {
        self.pid = pid
        self.path = path
        self.percent = percent
    }
}

public struct ProcessCPUTracker: Sendable {
    private var lastCPUSeconds: [Int32: Double] = [:]
    private var lastTime: Double?

    public init() {}

    public var hasBaseline: Bool { lastTime != nil }
    public var trackedCount: Int { lastCPUSeconds.count }

    public mutating func update(samples: [ProcessSample], at time: Double) -> [ProcessUsage] {
        let elapsed = lastTime.map { time - $0 } ?? 0
        var next: [Int32: Double] = [:]
        next.reserveCapacity(samples.count)
        var usages: [ProcessUsage] = []
        usages.reserveCapacity(samples.count)
        for sample in samples {
            next[sample.pid] = sample.cpuSeconds
            guard elapsed > 0, let previous = lastCPUSeconds[sample.pid] else { continue }
            let used = sample.cpuSeconds - previous
            let percent = used >= 0 ? used / elapsed * 100 : 0
            usages.append(ProcessUsage(pid: sample.pid, path: sample.path, percent: percent))
        }
        lastCPUSeconds = next
        lastTime = time
        return usages
    }

    public mutating func reset() {
        lastCPUSeconds.removeAll()
        lastTime = nil
    }
}
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `scripts/test.sh`

Expected: `Test run with 22 tests in 4 suites passed`. 0 warnings from our code.

- [ ] **Step 5: Commit (ask the user first)**

```bash
git add Sources/HungryCore/PSParser.swift Sources/HungryCore/ProcessCPUTracker.swift Sources/HungryCore/ProcessSample.swift Tests/HungryCoreTests/PSParserTests.swift Tests/HungryCoreTests/ProcessCPUTrackerTests.swift
git commit -m "feat(core): add ps parser and process CPU tracker"
```

---

### Task 3: App grouping and stable ranking

**Requirements:** F7 (spec 5.3 steps 4–5)

**Files:**
- Create or replace: `Sources/HungryCore/AppGrouper.swift`
- Create or replace: `Sources/HungryCore/RankStabilizer.swift`
- Test: `Tests/HungryCoreTests/AppGrouperTests.swift`
- Test: `Tests/HungryCoreTests/RankStabilizerTests.swift`

**Interfaces:**
- Consumes: `ProcessUsage` (Task 2).
- Produces: `AppIdentity(name: String, bundlePath: String?)` (`Hashable`); `AppUsage(identity: AppIdentity, percent: Double)` (`Identifiable`, `id` = bundle path or name); `AppGrouper.identity(forPath:) -> AppIdentity`; `AppGrouper.topApps(_: [ProcessUsage], limit: Int) -> [AppUsage]`; `RankStabilizer.stabilize(previousOrder: [String], current: [AppUsage], threshold: Double) -> [AppUsage]`.

- [ ] **Step 1: Write the failing tests**

`Tests/HungryCoreTests/AppGrouperTests.swift`:

```swift
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
```

`Tests/HungryCoreTests/RankStabilizerTests.swift`:

```swift
import Testing
@testable import HungryCore

struct RankStabilizerTests {
    private func app(_ name: String, _ percent: Double) -> AppUsage {
        AppUsage(identity: AppIdentity(name: name, bundlePath: nil), percent: percent)
    }

    @Test func firstListKeepsSortedOrder() {
        let current = [app("a", 30), app("b", 20)]
        #expect(RankStabilizer.stabilize(previousOrder: [], current: current, threshold: 1).map(\.id) == ["a", "b"])
    }

    @Test func smallDifferenceKeepsPreviousOrder() {
        let current = [app("b", 20.5), app("a", 20)]
        #expect(RankStabilizer.stabilize(previousOrder: ["a", "b"], current: current, threshold: 1).map(\.id) == ["a", "b"])
    }

    @Test func largeDifferenceChangesOrder() {
        let current = [app("b", 25), app("a", 20)]
        #expect(RankStabilizer.stabilize(previousOrder: ["a", "b"], current: current, threshold: 1).map(\.id) == ["b", "a"])
    }

    @Test func newcomerMovesUpOnlyPastClearlyLowerRows() {
        let current = [app("c", 50), app("a", 49.5), app("b", 10)]
        #expect(RankStabilizer.stabilize(previousOrder: ["a", "b"], current: current, threshold: 1).map(\.id) == ["a", "c", "b"])
    }

    @Test func droppedAppsDisappear() {
        let current = [app("b", 5)]
        #expect(RankStabilizer.stabilize(previousOrder: ["a", "b"], current: current, threshold: 1).map(\.id) == ["b"])
    }
}
```

- [ ] **Step 2: Run the tests and see them fail**

Run: `scripts/test.sh`

Expected: the build fails with `error: cannot find 'AppGrouper' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/HungryCore/AppGrouper.swift`:

```swift
public struct AppIdentity: Hashable, Sendable {
    public var name: String
    public var bundlePath: String?

    public init(name: String, bundlePath: String?) {
        self.name = name
        self.bundlePath = bundlePath
    }
}

public struct AppUsage: Equatable, Sendable, Identifiable {
    public var identity: AppIdentity
    public var percent: Double

    public init(identity: AppIdentity, percent: Double) {
        self.identity = identity
        self.percent = percent
    }

    public var id: String { identity.bundlePath ?? identity.name }
}

public enum AppGrouper {
    public static func identity(forPath path: String) -> AppIdentity {
        let components = path.split(separator: "/")
        if path.hasPrefix("/"), let index = components.firstIndex(where: { $0.hasSuffix(".app") && $0.count > 4 }) {
            let bundlePath = "/" + components[...index].joined(separator: "/")
            return AppIdentity(name: String(components[index].dropLast(4)), bundlePath: bundlePath)
        }
        return AppIdentity(name: components.last.map(String.init) ?? path, bundlePath: nil)
    }

    public static func topApps(_ usages: [ProcessUsage], limit: Int) -> [AppUsage] {
        var totals: [AppIdentity: Double] = [:]
        for usage in usages {
            totals[identity(forPath: usage.path), default: 0] += usage.percent
        }
        let sorted = totals
            .map { AppUsage(identity: $0.key, percent: $0.value) }
            .sorted { $0.percent != $1.percent ? $0.percent > $1.percent : $0.identity.name < $1.identity.name }
        return Array(sorted.prefix(max(limit, 0)))
    }
}
```

`Sources/HungryCore/RankStabilizer.swift`:

```swift
public enum RankStabilizer {
    public static func stabilize(previousOrder: [String], current: [AppUsage], threshold: Double) -> [AppUsage] {
        let previousRank = Dictionary(previousOrder.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        let known = current
            .filter { previousRank[$0.id] != nil }
            .sorted { (previousRank[$0.id] ?? 0) < (previousRank[$1.id] ?? 0) }
        let newcomers = current.filter { previousRank[$0.id] == nil }
        var result: [AppUsage] = []
        result.reserveCapacity(current.count)
        for item in known + newcomers {
            var index = result.count
            while index > 0, item.percent - result[index - 1].percent > threshold {
                index -= 1
            }
            result.insert(item, at: index)
        }
        return result
    }
}
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `scripts/test.sh`

Expected: `Test run with 35 tests in 6 suites passed`. 0 warnings from our code.

- [ ] **Step 5: Commit (ask the user first)**

```bash
git add Sources/HungryCore/AppGrouper.swift Sources/HungryCore/RankStabilizer.swift Tests/HungryCoreTests/AppGrouperTests.swift Tests/HungryCoreTests/RankStabilizerTests.swift
git commit -m "feat(core): add app grouping and stable ranking"
```

---

### Task 4: Speed curve, formatter, and animation themes

**Requirements:** F3, F4, F14 (spec 4.3, 5.4, 6.2)

**Files:**
- Create or replace: `Sources/HungryCore/SpeedCurve.swift`
- Create or replace: `Sources/HungryCore/UsageFormatter.swift`
- Create or replace: `Sources/HungryCore/Themes/AnimationTheme.swift`
- Create or replace: `Sources/HungryCore/Themes/CatTheme.swift`
- Create or replace: `Sources/HungryCore/Themes/PushUpTheme.swift`
- Create or replace: `Sources/HungryCore/Themes/PullUpTheme.swift`
- Create or replace: `Sources/HungryCore/Themes/ThemeRegistry.swift`
- Test: `Tests/HungryCoreTests/SpeedCurveTests.swift`
- Test: `Tests/HungryCoreTests/ThemeRegistryTests.swift`
- Test: `Tests/HungryCoreTests/UsageFormatterTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `SpeedCurve.minimumTimerInterval` (0.03), `smooth(previous:new:)`, `interval(forCPU:maxInterval:minInterval:)`, `shouldReplaceTimer(current:new:)`; `UsageFormatter.percent(_: Double?) -> String`, `tooltip(cpu:memory:)`, `memoryDetail(usedBytes:totalBytes:)`; `protocol AnimationTheme` (`id`, `displayName`, `frameCount`, `maxInterval`, `minInterval`) with extension `frameNames: [String]` and `frameInterval(forCPU:)`; `CatTheme`, `PushUpTheme`, `PullUpTheme`; `ThemeRegistry.all`, `.fallback`, `.theme(withID: String?)`.

- [ ] **Step 1: Write the failing tests**

`Tests/HungryCoreTests/SpeedCurveTests.swift`:

```swift
import Testing
@testable import HungryCore

struct SpeedCurveTests {
    @Test(arguments: [(0.0, 0.20), (50.0, 0.115), (100.0, 0.03), (-20.0, 0.20), (250.0, 0.03), (Double.nan, 0.20)])
    func catIntervalFollowsCPU(cpu: Double, expected: Double) {
        #expect(abs(CatTheme().frameInterval(forCPU: cpu) - expected) < 0.000_001)
    }

    @Test func intervalNeverGoesBelowMinimumTimer() {
        #expect(SpeedCurve.interval(forCPU: 100, maxInterval: 0.1, minInterval: 0.001) == SpeedCurve.minimumTimerInterval)
    }

    @Test func smoothingMovesThirtyPercentTowardNewValue() {
        #expect(abs(SpeedCurve.smooth(previous: 0, new: 100) - 30) < 0.000_001)
        #expect(abs(SpeedCurve.smooth(previous: 50, new: 50) - 50) < 0.000_001)
    }

    @Test func smoothingIgnoresInvalidInput() {
        #expect(SpeedCurve.smooth(previous: 10, new: .infinity) == 7)
    }

    @Test func timerIsReplacedOnlyAboveFiveMilliseconds() {
        #expect(!SpeedCurve.shouldReplaceTimer(current: 0.100, new: 0.104))
        #expect(SpeedCurve.shouldReplaceTimer(current: 0.100, new: 0.110))
    }
}
```

`Tests/HungryCoreTests/ThemeRegistryTests.swift`:

```swift
import Testing
@testable import HungryCore

struct ThemeRegistryTests {
    @Test func registryHasThreeThemesInPickerOrder() {
        #expect(ThemeRegistry.all.map(\.id) == ["cat", "pushup", "pullup"])
    }

    @Test(arguments: ["cat", "pushup", "pullup"])
    func findsThemeByID(id: String) {
        #expect(ThemeRegistry.theme(withID: id).id == id)
    }

    @Test(arguments: [nil, "", "dragon"] as [String?])
    func unknownIDFallsBackToCat(id: String?) {
        #expect(ThemeRegistry.theme(withID: id).id == "cat")
    }

    @Test func everyThemeHasValidFramesAndIntervals() {
        for theme in ThemeRegistry.all {
            #expect(theme.frameCount > 0)
            #expect(theme.frameNames.count == theme.frameCount)
            #expect(theme.frameNames.first == "frame-1")
            #expect(theme.minInterval < theme.maxInterval)
            #expect(theme.minInterval >= SpeedCurve.minimumTimerInterval)
        }
    }

    @Test func themeIDsAreUnique() {
        let ids = ThemeRegistry.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
```

`Tests/HungryCoreTests/UsageFormatterTests.swift`:

```swift
import Testing
@testable import HungryCore

struct UsageFormatterTests {
    @Test(arguments: [(72.4, "72%"), (72.5, "73%"), (0.0, "0%"), (100.0, "100%")] as [(Double?, String)])
    func formatsPercent(value: Double?, expected: String) {
        #expect(UsageFormatter.percent(value) == expected)
    }

    @Test func missingOrInvalidValueShowsDashes() {
        #expect(UsageFormatter.percent(nil) == "--")
        #expect(UsageFormatter.percent(.nan) == "--")
    }

    @Test func tooltipNamesBothValues() {
        #expect(UsageFormatter.tooltip(cpu: 72, memory: nil) == "CPU 72% · RAM --")
    }

    @Test func memoryDetailShowsUsedAndTotalGigabytes() {
        #expect(UsageFormatter.memoryDetail(usedBytes: 10_522_669_875, totalBytes: 17_179_869_184) == "9.8 / 16 GB")
    }
}
```

- [ ] **Step 2: Run the tests and see them fail**

Run: `scripts/test.sh`

Expected: the build fails with `error: cannot find 'CatTheme' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/HungryCore/SpeedCurve.swift`:

```swift
import Foundation

public enum SpeedCurve {
    public static let minimumTimerInterval: TimeInterval = 0.03
    public static let replaceThreshold: TimeInterval = 0.005

    public static func smooth(previous: Double, new: Double) -> Double {
        0.7 * clampPercent(previous) + 0.3 * clampPercent(new)
    }

    public static func interval(forCPU cpu: Double, maxInterval: TimeInterval, minInterval: TimeInterval) -> TimeInterval {
        let share = clampPercent(cpu) / 100
        return max(maxInterval - (maxInterval - minInterval) * share, minimumTimerInterval)
    }

    public static func shouldReplaceTimer(current: TimeInterval, new: TimeInterval) -> Bool {
        abs(current - new) > replaceThreshold
    }

    static func clampPercent(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 100) : 0
    }
}
```

`Sources/HungryCore/UsageFormatter.swift`:

```swift
public enum UsageFormatter {
    public static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    public static func tooltip(cpu: Double?, memory: Double?) -> String {
        "CPU \(percent(cpu)) · RAM \(percent(memory))"
    }

    public static func memoryDetail(usedBytes: UInt64, totalBytes: UInt64) -> String {
        let gigabyte = 1_073_741_824.0
        let used = (Double(usedBytes) / gigabyte * 10).rounded() / 10
        let total = (Double(totalBytes) / gigabyte).rounded()
        return "\(used) / \(Int(total)) GB"
    }
}
```

`Sources/HungryCore/Themes/AnimationTheme.swift`:

```swift
import Foundation

public protocol AnimationTheme: Sendable {
    var id: String { get }
    var displayName: String { get }
    var frameCount: Int { get }
    var maxInterval: TimeInterval { get }
    var minInterval: TimeInterval { get }
}

public extension AnimationTheme {
    var frameNames: [String] {
        frameCount > 0 ? (1...frameCount).map { "frame-\($0)" } : []
    }

    func frameInterval(forCPU cpu: Double) -> TimeInterval {
        SpeedCurve.interval(forCPU: cpu, maxInterval: maxInterval, minInterval: minInterval)
    }
}
```

`Sources/HungryCore/Themes/CatTheme.swift`:

```swift
import Foundation

public struct CatTheme: AnimationTheme {
    public let id = "cat"
    public let displayName = "Cat"
    public let frameCount = 5
    public let maxInterval: TimeInterval = 0.20
    public let minInterval: TimeInterval = 0.03

    public init() {}
}
```

`Sources/HungryCore/Themes/PushUpTheme.swift`:

```swift
import Foundation

public struct PushUpTheme: AnimationTheme {
    public let id = "pushup"
    public let displayName = "Push-ups"
    public let frameCount = 6
    public let maxInterval: TimeInterval = 0.25
    public let minInterval: TimeInterval = 0.04

    public init() {}
}
```

`Sources/HungryCore/Themes/PullUpTheme.swift`:

```swift
import Foundation

public struct PullUpTheme: AnimationTheme {
    public let id = "pullup"
    public let displayName = "Pull-ups"
    public let frameCount = 6
    public let maxInterval: TimeInterval = 0.25
    public let minInterval: TimeInterval = 0.04

    public init() {}
}
```

`Sources/HungryCore/Themes/ThemeRegistry.swift`:

```swift
public enum ThemeRegistry {
    public static let all: [any AnimationTheme] = [CatTheme(), PushUpTheme(), PullUpTheme()]

    public static var fallback: any AnimationTheme { CatTheme() }

    public static func theme(withID id: String?) -> any AnimationTheme {
        all.first { $0.id == id } ?? fallback
    }
}
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `scripts/test.sh`

Expected: `Test run with 49 tests in 9 suites passed`. 0 warnings from our code.

- [ ] **Step 5: Commit (ask the user first)**

```bash
git add Sources/HungryCore/SpeedCurve.swift Sources/HungryCore/Themes/AnimationTheme.swift Sources/HungryCore/Themes/CatTheme.swift Sources/HungryCore/Themes/PullUpTheme.swift Sources/HungryCore/Themes/PushUpTheme.swift Sources/HungryCore/Themes/ThemeRegistry.swift Sources/HungryCore/UsageFormatter.swift Tests/HungryCoreTests/SpeedCurveTests.swift Tests/HungryCoreTests/ThemeRegistryTests.swift Tests/HungryCoreTests/UsageFormatterTests.swift
git commit -m "feat(core): add speed curve, formatter, and themes"
```

---

### Task 5: Temperature logic

**Requirements:** F15, F16, F17 (spec 5.6, 6.2, 6.3)

**Files:**
- Create or replace: `Sources/HungryCore/TemperatureReading.swift`
- Create or replace: `Sources/HungryCore/ChipFamily.swift`
- Create or replace: `Sources/HungryCore/TemperatureSensors.swift`
- Create or replace: `Sources/HungryCore/UsageFormatter.swift`
- Test: `Tests/HungryCoreTests/TemperatureTests.swift`

**Interfaces:**
- Consumes: `UsageFormatter` (Task 4, replaced here with the temperature version).
- Produces: `TemperatureReading(cpu: Double?, gpu: Double?)`; `ChipFamily` (`m1`…`m4`) with `detect(brand:) -> ChipFamily?`; `SensorKeys(cpu:gpu:)` with `isEmpty`; `TemperatureSensors.keys(for:)`, `.hottest(_:) -> Double?`, `.smooth(previous:new:) -> TemperatureReading?`, `.smoothingWeight` (0.3); `UsageFormatter.tooltip(cpu:memory:temperature:)` (new optional parameter), `.temperature(_:)`, `.temperatureDetail(_:)`.

**Note:** the M1 table is verified on an M1 Pro. The M2, M3, and M4 tables come from the open-source Stats app and are not verified (spec 5.6).

- [ ] **Step 1: Write the failing tests**

`Tests/HungryCoreTests/TemperatureTests.swift`:

```swift
import Testing
@testable import HungryCore

struct TemperatureTests {
    @Test(arguments: [
        ("Apple M1", ChipFamily.m1),
        ("Apple M1 Pro", .m1),
        ("Apple M2 Max", .m2),
        ("Apple M3", .m3),
        ("Apple M4 Pro", .m4),
    ] as [(String, ChipFamily)])
    func detectsAppleSiliconFamily(brand: String, expected: ChipFamily) {
        #expect(ChipFamily.detect(brand: brand) == expected)
    }

    @Test(arguments: ["Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz", "", "Apple M", "Apple M10", "Apple M9 Ultra"])
    func unknownChipHasNoFamily(brand: String) {
        #expect(ChipFamily.detect(brand: brand) == nil)
    }

    @Test(arguments: ChipFamily.allCases)
    func everyFamilyHasValidUniqueKeys(family: ChipFamily) {
        let keys = TemperatureSensors.keys(for: family)
        #expect(!keys.cpu.isEmpty)
        #expect(!keys.gpu.isEmpty)
        for key in keys.cpu + keys.gpu {
            #expect(key.utf8.count == 4)
            #expect(key.hasPrefix("T"))
        }
        #expect(Set(keys.cpu).count == keys.cpu.count)
        #expect(Set(keys.gpu).count == keys.gpu.count)
    }

    @Test func m1TableMatchesVerifiedM1ProKeys() {
        let keys = TemperatureSensors.keys(for: .m1)
        #expect(Set(["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0T", "Tp0X", "Tp0b"]).isSubset(of: Set(keys.cpu)))
        #expect(Set(["Tg05", "Tg0D"]).isSubset(of: Set(keys.gpu)))
    }

    @Test func hottestIgnoresInvalidValues() {
        #expect(TemperatureSensors.hottest([66.8, 73.6, 0, -5, 200, .nan, .infinity]) == 73.6)
    }

    @Test func hottestOfNothingIsNil() {
        #expect(TemperatureSensors.hottest([]) == nil)
        #expect(TemperatureSensors.hottest([0, 151]) == nil)
    }

    @Test func firstReadingIsUsedAsIs() {
        let reading = TemperatureReading(cpu: 60, gpu: 50)
        #expect(TemperatureSensors.smooth(previous: nil, new: reading) == reading)
    }

    @Test func smoothingMovesThirtyPercentTowardNewReading() throws {
        let smoothed = try #require(TemperatureSensors.smooth(previous: TemperatureReading(cpu: 60, gpu: 50), new: TemperatureReading(cpu: 70, gpu: 60)))
        #expect(abs(try #require(smoothed.cpu) - 63) < 0.000_001)
        #expect(abs(try #require(smoothed.gpu) - 53) < 0.000_001)
    }

    @Test func missingReadingKeepsPreviousValues() {
        let previous = TemperatureReading(cpu: 61, gpu: 52)
        #expect(TemperatureSensors.smooth(previous: previous, new: nil) == previous)
        #expect(TemperatureSensors.smooth(previous: previous, new: TemperatureReading(cpu: nil, gpu: 62))?.cpu == 61)
    }

    @Test func formatsMenuBarTemperature() {
        #expect(UsageFormatter.temperature(68.4) == "68°")
        #expect(UsageFormatter.temperature(nil) == "--")
        #expect(UsageFormatter.temperature(.nan) == "--")
    }

    @Test func formatsPopoverDetail() {
        #expect(UsageFormatter.temperatureDetail(TemperatureReading(cpu: 68.4, gpu: 64.5)) == "CPU 68°C  GPU 65°C")
        #expect(UsageFormatter.temperatureDetail(TemperatureReading(cpu: 70, gpu: nil)) == "CPU 70°C")
        #expect(UsageFormatter.temperatureDetail(TemperatureReading(cpu: nil, gpu: nil)) == "")
    }

    @Test func tooltipAddsTemperatureOnlyWhenKnown() {
        #expect(UsageFormatter.tooltip(cpu: 72, memory: 61, temperature: 68.4) == "CPU 72% · RAM 61% · 68°C")
        #expect(UsageFormatter.tooltip(cpu: 72, memory: 61) == "CPU 72% · RAM 61%")
    }
}
```

- [ ] **Step 2: Run the tests and see them fail**

Run: `scripts/test.sh`

Expected: the build fails with `error: cannot find 'ChipFamily' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/HungryCore/TemperatureReading.swift`:

```swift
public struct TemperatureReading: Equatable, Sendable {
    public var cpu: Double?
    public var gpu: Double?

    public init(cpu: Double?, gpu: Double?) {
        self.cpu = cpu
        self.gpu = gpu
    }
}
```

`Sources/HungryCore/ChipFamily.swift`:

```swift
public enum ChipFamily: Int, Sendable, CaseIterable {
    case m1 = 1
    case m2 = 2
    case m3 = 3
    case m4 = 4

    public static func detect(brand: String) -> ChipFamily? {
        let lower = brand.lowercased()
        let prefix = "apple m"
        guard lower.hasPrefix(prefix) else { return nil }
        let digits = lower.dropFirst(prefix.count).prefix(while: \.isNumber)
        guard let generation = Int(digits) else { return nil }
        return ChipFamily(rawValue: generation)
    }
}
```

`Sources/HungryCore/TemperatureSensors.swift`:

```swift
public struct SensorKeys: Equatable, Sendable {
    public var cpu: [String]
    public var gpu: [String]

    public init(cpu: [String], gpu: [String]) {
        self.cpu = cpu
        self.gpu = gpu
    }

    public var isEmpty: Bool { cpu.isEmpty && gpu.isEmpty }
}

public enum TemperatureSensors {
    public static func keys(for family: ChipFamily) -> SensorKeys {
        switch family {
        case .m1:
            SensorKeys(
                cpu: ["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0T", "Tp0X", "Tp0b"],
                gpu: ["Tg05", "Tg0D", "Tg0L", "Tg0T"]
            )
        case .m2:
            SensorKeys(
                cpu: ["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j", "Tp1h", "Tp1l", "Tp1p", "Tp1t"],
                gpu: ["Tg0f", "Tg0j"]
            )
        case .m3:
            SensorKeys(
                cpu: ["Te05", "Te0L", "Te0P", "Te0S", "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E", "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E"],
                gpu: ["Tf14", "Tf18", "Tf19", "Tf1A", "Tf24", "Tf28", "Tf29", "Tf2A"]
            )
        case .m4:
            SensorKeys(
                cpu: ["Te05", "Te09", "Te0H", "Te0S", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e"],
                gpu: ["Tg0G", "Tg0H", "Tg0K", "Tg0L", "Tg0d", "Tg0e", "Tg0j", "Tg0k", "Tg1U", "Tg1k"]
            )
        }
    }

    public static let smoothingWeight = 0.3

    public static func hottest(_ values: [Double]) -> Double? {
        values.filter { $0.isFinite && $0 > 0 && $0 < 150 }.max()
    }

    public static func smooth(previous: TemperatureReading?, new: TemperatureReading?) -> TemperatureReading? {
        guard let new else { return previous }
        return TemperatureReading(
            cpu: smooth(previous?.cpu, new.cpu),
            gpu: smooth(previous?.gpu, new.gpu)
        )
    }

    private static func smooth(_ previous: Double?, _ new: Double?) -> Double? {
        guard let new else { return previous }
        guard let previous else { return new }
        return (1 - smoothingWeight) * previous + smoothingWeight * new
    }
}
```

`Sources/HungryCore/UsageFormatter.swift`:

```swift
public enum UsageFormatter {
    public static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    public static func tooltip(cpu: Double?, memory: Double?, temperature: Double? = nil) -> String {
        let base = "CPU \(percent(cpu)) · RAM \(percent(memory))"
        guard let temperature, temperature.isFinite else { return base }
        return base + " · \(Int(temperature.rounded()))°C"
    }

    public static func temperature(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        return "\(Int(value.rounded()))°"
    }

    public static func temperatureDetail(_ reading: TemperatureReading) -> String {
        [("CPU", reading.cpu), ("GPU", reading.gpu)]
            .compactMap { label, value in
                guard let value, value.isFinite else { return nil }
                return "\(label) \(Int(value.rounded()))°C"
            }
            .joined(separator: "  ")
    }

    public static func memoryDetail(usedBytes: UInt64, totalBytes: UInt64) -> String {
        let gigabyte = 1_073_741_824.0
        let used = (Double(usedBytes) / gigabyte * 10).rounded() / 10
        let total = (Double(totalBytes) / gigabyte).rounded()
        return "\(used) / \(Int(total)) GB"
    }
}
```

- [ ] **Step 4: Run the tests and see them pass**

Run: `scripts/test.sh`

Expected: `Test run with 61 tests in 10 suites passed`. 0 warnings from our code.

- [ ] **Step 5: Commit (ask the user first)**

```bash
git add Sources/HungryCore/ChipFamily.swift Sources/HungryCore/TemperatureReading.swift Sources/HungryCore/TemperatureSensors.swift Sources/HungryCore/UsageFormatter.swift Tests/HungryCoreTests/TemperatureTests.swift
git commit -m "feat(core): add chip detection, sensor tables, and temperature formatting"
```

---

### Task 6: HungrySystem samplers and SMC temperature

**Requirements:** F2, F8, F9, F15, N2 (spec 4.1, 5.1–5.3, 5.5, 5.6, 7)

**Files:**
- Create or replace: `Package.swift`
- Create or replace: `Sources/HungrySystem/SystemSampler.swift`
- Create or replace: `Sources/HungrySystem/PSRunner.swift`
- Create or replace: `Sources/HungrySystem/LibprocReader.swift`
- Create or replace: `Sources/HungrySystem/ProcessSampler.swift`
- Create or replace: `Sources/HungrySystem/SMCReader.swift`
- Create or replace: `Sources/HungrySystem/TemperatureSampler.swift`
- Create or replace: `Sources/HungrySystem/SamplingEngine.swift`
- Test: `Tests/HungrySystemTests/SamplerIntegrationTests.swift`
- Test: `Tests/HungrySystemTests/TemperatureIntegrationTests.swift`

**Interfaces:**
- Consumes: `CoreTicks`, `CPUCalculator`, `MemoryPages`, `MemoryUsage`, `MemoryCalculator` (Task 1); `ProcessSample`, `PSParser`, `ProcessCPUTracker` (Task 2); `AppGrouper`, `AppUsage` (Task 3); `TemperatureReading`, `ChipFamily`, `SensorKeys`, `TemperatureSensors` (Task 5).
- Produces (all `public`): `SystemSampler` (`init()`, `mutating sampleCPU() -> Double?`, `sampleMemory() -> MemoryUsage?`); `PSRunner.run(timeout:) -> String?`; `LibprocReader.samples() -> [ProcessSample]`; `ProcessSnapshot(apps:isReady:isLimited:)`; `ProcessSampler` (`psTimeout` = 0.8, `init()`, `mutating sample(limit:) -> ProcessSnapshot`, `mutating reset()`); `SMCReader` (`init?()`, `floatKeys(from:)`, `value(of:)`, internal `SMCParam` that must be 80 bytes); `TemperatureSampler` (`init(brand:)`, `isAvailable`, `sample() -> TemperatureReading?`, `cpuBrand()`); `SystemSnapshot(cpuPercent:memory:temperature:)`; `actor SamplingEngine` (`init()`, `sampleSystem()` with 1 smoothed temperature read every 2nd call, `sampleProcesses(limit:)`, `resetProcesses()`).

**Read first:** spec section 5.6. The `SMCKeyInfo.padding` field is required: without it the struct is 76 bytes and every SMC read fails.

- [ ] **Step 1: Create the setup files**

`Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacHungry",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "HungryCore"),
        .target(name: "HungrySystem", dependencies: ["HungryCore"]),
        .testTarget(name: "HungryCoreTests", dependencies: ["HungryCore"]),
        .testTarget(name: "HungrySystemTests", dependencies: ["HungrySystem", "HungryCore"]),
    ]
)
```

- [ ] **Step 2: Write the failing tests**

`Tests/HungrySystemTests/SamplerIntegrationTests.swift`:

```swift
import Foundation
import Testing
import HungryCore
import HungrySystem

extension Tag {
    @Tag static var integration: Self
}

@Suite(.tags(.integration))
struct SamplerIntegrationTests {
    @Test func systemSamplerGivesValuesInRange() async throws {
        var sampler = SystemSampler()
        let first = sampler.sampleCPU()
        #expect(first == nil)
        try await Task.sleep(for: .milliseconds(300))
        let second = sampler.sampleCPU()
        let cpu = try #require(second)
        #expect((0...100).contains(cpu))
        let memory = try #require(sampler.sampleMemory())
        #expect((0...100).contains(memory.percent))
        #expect(memory.totalBytes > 0)
    }

    @Test func psRunnerReadsRootProcesses() throws {
        let output = try #require(PSRunner.run(timeout: ProcessSampler.psTimeout))
        let samples = PSParser.parse(output)
        #expect(samples.count > 50)
        #expect(samples.contains { $0.pid == 1 })
    }

    @Test func libprocFallbackReadsOwnProcesses() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        #expect(LibprocReader.samples().contains { $0.pid == ownPID })
    }

    @Test func processSamplerIsReadyOnSecondSample() async throws {
        var sampler = ProcessSampler()
        let first = sampler.sample(limit: 10)
        #expect(!first.isReady)
        try await Task.sleep(for: .milliseconds(500))
        let snapshot = sampler.sample(limit: 10)
        #expect(snapshot.isReady)
        #expect(!snapshot.isLimited)
        #expect(!snapshot.apps.isEmpty)
        #expect(snapshot.apps.count <= 10)
    }
}
```

`Tests/HungrySystemTests/TemperatureIntegrationTests.swift`:

```swift
import Testing
import HungryCore
@testable import HungrySystem

@Suite(.tags(.integration))
struct TemperatureIntegrationTests {
    @Test func smcParamMatchesTheCLayout() {
        #expect(MemoryLayout<SMCParam>.stride == SMCReader.expectedParamSize)
    }

    @Test func readsPlausibleTemperatureOnSupportedMacs() throws {
        let sampler = TemperatureSampler()
        guard ChipFamily.detect(brand: TemperatureSampler.cpuBrand()) != nil else { return }
        #expect(sampler.isAvailable)
        let reading = try #require(sampler.sample())
        let cpu = try #require(reading.cpu)
        #expect((15...120).contains(cpu))
    }

    @Test func unknownChipGivesNoTemperature() {
        let sampler = TemperatureSampler(brand: "Intel(R) Core(TM) i7")
        #expect(!sampler.isAvailable)
        #expect(sampler.sample() == nil)
    }
}
```

- [ ] **Step 3: Run the tests and see them fail**

Run: `scripts/test.sh`

Expected: the build fails with a build error, because the `HungrySystem` target has no source files yet (or `no such module 'HungrySystem'`).

- [ ] **Step 4: Write the implementation**

`Sources/HungrySystem/SystemSampler.swift`:

```swift
import Darwin
import HungryCore

public struct SystemSampler {
    private let host = mach_host_self()
    private let totalMemory = Self.readTotalMemory()
    private let pageSize = UInt64(getpagesize())
    private var previousTicks: [CoreTicks]?

    public init() {}

    public mutating func sampleCPU() -> Double? {
        guard let ticks = readCoreTicks() else { return nil }
        defer { previousTicks = ticks }
        guard let previousTicks else { return nil }
        return CPUCalculator.usagePercent(previous: previousTicks, current: ticks)
    }

    public func sampleMemory() -> MemoryUsage? {
        guard totalMemory > 0, let pages = readMemoryPages() else { return nil }
        return MemoryCalculator.usage(pages: pages, pageSize: pageSize, totalBytes: totalMemory)
    }

    private func readCoreTicks() -> [CoreTicks]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else { return nil }
        defer {
            let size = vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), size)
        }
        let stateCount = Int(CPU_STATE_MAX)
        return (0..<Int(cpuCount)).map { core in
            let base = core * stateCount
            return CoreTicks(
                user: UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                nice: UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]),
                idle: UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)])
            )
        }
    }

    private func readMemoryPages() -> MemoryPages? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return MemoryPages(
            internalPages: UInt64(stats.internal_page_count),
            purgeablePages: UInt64(stats.purgeable_count),
            wiredPages: UInt64(stats.wire_count),
            compressedPages: UInt64(stats.compressor_page_count)
        )
    }

    private static func readTotalMemory() -> UInt64 {
        var size: UInt64 = 0
        var length = MemoryLayout<UInt64>.size
        return sysctlbyname("hw.memsize", &size, &length, nil, 0) == 0 ? size : 0
    }
}
```

`Sources/HungrySystem/PSRunner.swift`:

```swift
import Foundation

public enum PSRunner {
    public static func run(timeout: TimeInterval) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,time=,comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let watchdog = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: watchdog)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()
        guard process.terminationReason == .exit, process.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
```

`Sources/HungrySystem/LibprocReader.swift`:

```swift
import Darwin
import HungryCore

public enum LibprocReader {
    private static let pathBufferSize = Int(MAXPATHLEN) * 4

    public static func samples() -> [ProcessSample] {
        let estimated = proc_listallpids(nil, 0)
        guard estimated > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimated) + 64)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride))
        guard filled > 0 else { return [] }
        let scale = timebaseScale()
        var pathBuffer = [CChar](repeating: 0, count: pathBufferSize)
        var result: [ProcessSample] = []
        result.reserveCapacity(Int(filled))
        for pid in pids.prefix(Int(filled)) where pid > 0 {
            guard let cpuTicks = cpuTicks(of: pid) else { continue }
            let length = proc_pidpath(pid, &pathBuffer, UInt32(pathBufferSize))
            guard length > 0 else { continue }
            let path = String(decoding: pathBuffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
            result.append(ProcessSample(pid: pid, cpuSeconds: Double(cpuTicks) * scale / 1_000_000_000, path: path))
        }
        return result
    }

    private static func cpuTicks(of pid: pid_t) -> UInt64? {
        var info = rusage_info_v2()
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V2, $0)
            }
        }
        return status == 0 ? info.ri_user_time + info.ri_system_time : nil
    }

    private static func timebaseScale() -> Double {
        var timebase = mach_timebase_info_data_t()
        guard mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.denom > 0 else { return 1 }
        return Double(timebase.numer) / Double(timebase.denom)
    }
}
```

`Sources/HungrySystem/ProcessSampler.swift`:

```swift
import Foundation
import HungryCore

public struct ProcessSnapshot: Sendable {
    public var apps: [AppUsage]
    public var isReady: Bool
    public var isLimited: Bool
}

public struct ProcessSampler {
    public static let psTimeout: TimeInterval = 0.8

    private var tracker = ProcessCPUTracker()

    public init() {}

    public mutating func sample(limit: Int) -> ProcessSnapshot {
        let wasReady = tracker.hasBaseline
        let output = PSRunner.run(timeout: Self.psTimeout)
        let now = ProcessInfo.processInfo.systemUptime
        let samples = output.map(PSParser.parse) ?? LibprocReader.samples()
        let usages = tracker.update(samples: samples, at: now)
        return ProcessSnapshot(
            apps: AppGrouper.topApps(usages, limit: limit),
            isReady: wasReady,
            isLimited: output == nil
        )
    }

    public mutating func reset() {
        tracker.reset()
    }
}
```

`Sources/HungrySystem/SMCReader.swift`:

```swift
import Darwin
import IOKit

struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

struct SMCPowerLimit {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpu: UInt32 = 0
    var gpu: UInt32 = 0
    var memory: UInt32 = 0
}

struct SMCKeyInfo {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var attributes: UInt8 = 0
    var padding: (UInt8, UInt8, UInt8) = (0, 0, 0)
}

struct SMCParam {
    var key: UInt32 = 0
    var version = SMCVersion()
    var powerLimit = SMCPowerLimit()
    var keyInfo = SMCKeyInfo()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var command: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
}

public final class SMCReader {
    static let expectedParamSize = 80
    private static let selector: UInt32 = 2
    private static let readKeyCommand: UInt8 = 5
    private static let keyInfoCommand: UInt8 = 9
    private static let floatType = fourCharCode("flt ")

    private let connection: io_connect_t

    public init?() {
        guard MemoryLayout<SMCParam>.stride == Self.expectedParamSize else { return nil }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var opened: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &opened) == KERN_SUCCESS else { return nil }
        connection = opened
    }

    deinit {
        IOServiceClose(connection)
    }

    public func floatKeys(from candidates: [String]) -> [String] {
        candidates.filter { keyInfo(for: $0).map(Self.isFloat) ?? false }
    }

    public func value(of key: String) -> Double? {
        guard let info = keyInfo(for: key), Self.isFloat(info) else { return nil }
        var input = SMCParam()
        input.key = Self.fourCharCode(key)
        input.keyInfo.dataSize = info.dataSize
        input.command = Self.readKeyCommand
        guard let output = call(&input) else { return nil }
        let bytes = output.bytes
        let bits = UInt32(bytes.0) | UInt32(bytes.1) << 8 | UInt32(bytes.2) << 16 | UInt32(bytes.3) << 24
        return Double(Float(bitPattern: bits))
    }

    private func keyInfo(for key: String) -> SMCKeyInfo? {
        var input = SMCParam()
        input.key = Self.fourCharCode(key)
        input.command = Self.keyInfoCommand
        return call(&input)?.keyInfo
    }

    private func call(_ input: inout SMCParam) -> SMCParam? {
        var output = SMCParam()
        var outputSize = MemoryLayout<SMCParam>.stride
        let result = IOConnectCallStructMethod(connection, Self.selector, &input, MemoryLayout<SMCParam>.stride, &output, &outputSize)
        return result == KERN_SUCCESS && output.result == 0 ? output : nil
    }

    private static func isFloat(_ info: SMCKeyInfo) -> Bool {
        info.dataType == floatType && info.dataSize == 4
    }

    static func fourCharCode(_ text: String) -> UInt32 {
        text.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }
}
```

`Sources/HungrySystem/TemperatureSampler.swift`:

```swift
import Darwin
import HungryCore

public struct TemperatureSampler {
    private let reader: SMCReader?
    private let keys: SensorKeys

    public init(brand: String = TemperatureSampler.cpuBrand()) {
        guard let family = ChipFamily.detect(brand: brand), let reader = SMCReader() else {
            self.reader = nil
            self.keys = SensorKeys(cpu: [], gpu: [])
            return
        }
        let table = TemperatureSensors.keys(for: family)
        self.reader = reader
        self.keys = SensorKeys(cpu: reader.floatKeys(from: table.cpu), gpu: reader.floatKeys(from: table.gpu))
    }

    public var isAvailable: Bool {
        reader != nil && !keys.isEmpty
    }

    public func sample() -> TemperatureReading? {
        guard let reader, !keys.isEmpty else { return nil }
        let reading = TemperatureReading(
            cpu: TemperatureSensors.hottest(keys.cpu.compactMap(reader.value)),
            gpu: TemperatureSensors.hottest(keys.gpu.compactMap(reader.value))
        )
        return reading.cpu == nil && reading.gpu == nil ? nil : reading
    }

    public static func cpuBrand() -> String {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 else { return "" }
        return String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
    }
}
```

`Sources/HungrySystem/SamplingEngine.swift`:

```swift
import HungryCore

public struct SystemSnapshot: Sendable {
    public var cpuPercent: Double?
    public var memory: MemoryUsage?
    public var temperature: TemperatureReading?
}

public actor SamplingEngine {
    public static let temperatureEvery = 2

    private var system = SystemSampler()
    private var processes = ProcessSampler()
    private let temperature = TemperatureSampler()
    private var temperatureTick = 0
    private var lastTemperature: TemperatureReading?

    public init() {}

    public func sampleSystem() -> SystemSnapshot {
        if temperatureTick % Self.temperatureEvery == 0 {
            lastTemperature = TemperatureSensors.smooth(previous: lastTemperature, new: temperature.sample())
        }
        temperatureTick += 1
        return SystemSnapshot(cpuPercent: system.sampleCPU(), memory: system.sampleMemory(), temperature: lastTemperature)
    }

    public func sampleProcesses(limit: Int) -> ProcessSnapshot {
        processes.sample(limit: limit)
    }

    public func resetProcesses() {
        processes.reset()
    }
}
```

- [ ] **Step 5: Run the tests and see them pass**

Run: `scripts/test.sh`

Expected: `Test run with 7 tests in 2 suites passed (and the 61 core tests pass)`. 0 warnings from our code.

- [ ] **Step 6: Commit (ask the user first)**

```bash
git add Package.swift Sources/HungrySystem/LibprocReader.swift Sources/HungrySystem/PSRunner.swift Sources/HungrySystem/ProcessSampler.swift Sources/HungrySystem/SMCReader.swift Sources/HungrySystem/SamplingEngine.swift Sources/HungrySystem/SystemSampler.swift Sources/HungrySystem/TemperatureSampler.swift Tests/HungrySystemTests/SamplerIntegrationTests.swift Tests/HungrySystemTests/TemperatureIntegrationTests.swift
git commit -m "feat(system): add CPU, memory, process, and temperature samplers"
```

---

### Task 7: Menu bar item with animation, art, and bundle script

**Requirements:** F1, F2, F3, F5, F14, F15, N1, N2, N5, N7, N8 (spec 6.1, 6.2, 10, 11, 12)

**Files:**
- Create or replace: `Package.swift`
- Create or replace: `scripts/draw-frames.swift`
- Create or replace: `Resources/Info.plist`
- Create or replace: `scripts/make-app.sh`
- Create or replace: `Sources/MacHungry/StatsStore.swift`
- Create or replace: `Sources/MacHungry/StatsMonitor.swift`
- Create or replace: `Sources/MacHungry/TemplateImageRenderer.swift`
- Create or replace: `Sources/MacHungry/StatusImageComposer.swift`
- Create or replace: `Sources/MacHungry/StatusContentView.swift`
- Create or replace: `Sources/MacHungry/FrameLoader.swift`
- Create or replace: `Sources/MacHungry/MenuBarAnimator.swift`
- Create or replace: `Sources/MacHungry/ThemePreference.swift`
- Create or replace: `Sources/MacHungry/StatusItemController.swift`
- Create or replace: `Sources/MacHungry/AppDelegate.swift`
- Create or replace: `Sources/MacHungry/MacHungryApp.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–6.
- Produces: `StatsStore` (`cpuPercent`, `memory`, `temperature`, `topApps`, `hasTopSample`, `isLimited`); `StatsMonitor(store:)` with `onSystemSample`, `start()`, `startProcessSampling()`, `stopProcessSampling()`; `TemplateImageRenderer.render(size:draw:) -> NSImage`; `StatusImageComposer.statsImage(cpu:memory:temperature:) -> NSImage`; `StatusContentView` (`contentSize`, `showFrame(_:)`, `showStats(_:)`, `setAnimationFrameSize(_:)`); `FrameLoader.frames(for:bundle:)`; `MenuBarAnimator(theme:)` with `currentFrame`, `frameSize`, `onFrame`, `onThemeApplied`, `setTheme(_:)`, `update(cpu:)`, `start()`; `ThemePreference.load(from:)`, `.save(_:to:)`; `StatusItemController(monitor:animator:)` (Task 8 changes this initializer); `AppDelegate`; `MacHungryApp`.

**Read first:** spec sections 6.1, 6.2, and 12. The layer drawing in `StatusContentView` is the result of measurements: do not change it to `button.image` per frame.

- [ ] **Step 1: Create the setup files**

`Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacHungry",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "HungryCore"),
        .target(name: "HungrySystem", dependencies: ["HungryCore"]),
        .executableTarget(name: "MacHungry", dependencies: ["HungryCore", "HungrySystem"]),
        .testTarget(name: "HungryCoreTests", dependencies: ["HungryCore"]),
        .testTarget(name: "HungrySystemTests", dependencies: ["HungrySystem", "HungryCore"]),
    ]
)
```

`scripts/draw-frames.swift`:

```swift
import AppKit

struct FrameSpec {
    let theme: String
    let size: NSSize
    let count: Int
    let scale: CGFloat
    let yShift: CGFloat
    let lineBoost: CGFloat
    let draw: (Int, Int) -> Void
}

nonisolated(unsafe) var lineBoost: CGFloat = 1

func stroke(_ points: [CGPoint], width: CGFloat = 1.6) {
    guard let first = points.first else { return }
    let path = NSBezierPath()
    path.move(to: first)
    points.dropFirst().forEach { path.line(to: $0) }
    path.lineWidth = width * lineBoost
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

func dot(_ center: CGPoint, radius: CGFloat) {
    NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
}

func leg(from hip: CGPoint, length: CGFloat, degrees: CGFloat) -> CGPoint {
    let radians = degrees * .pi / 180
    return CGPoint(x: hip.x + length * sin(radians), y: hip.y - length * cos(radians))
}

func drawCat(frame: Int, count: Int) {
    let phase = CGFloat(frame) / CGFloat(count) * 2 * .pi
    let swing = 32 * sin(phase)
    let lift = 0.7 * abs(sin(phase))
    NSBezierPath(ovalIn: CGRect(x: 5, y: 7 + lift, width: 11, height: 5)).fill()
    dot(CGPoint(x: 17, y: 11.5 + lift), radius: 2.8)
    let ears = NSBezierPath()
    ears.move(to: CGPoint(x: 15.0, y: 13.4 + lift))
    ears.line(to: CGPoint(x: 15.6, y: 16.2 + lift))
    ears.line(to: CGPoint(x: 17.0, y: 14.2 + lift))
    ears.close()
    ears.move(to: CGPoint(x: 17.4, y: 14.2 + lift))
    ears.line(to: CGPoint(x: 18.8, y: 16.2 + lift))
    ears.line(to: CGPoint(x: 19.2, y: 13.2 + lift))
    ears.close()
    ears.fill()
    let tail = NSBezierPath()
    tail.move(to: CGPoint(x: 5.5, y: 10 + lift))
    tail.curve(to: CGPoint(x: 1.2, y: 14 + lift - swing / 40), controlPoint1: CGPoint(x: 2.5, y: 9 + lift), controlPoint2: CGPoint(x: 1, y: 11 + lift))
    tail.lineWidth = 1.4 * lineBoost
    tail.lineCapStyle = .round
    tail.stroke()
    let hips: [(CGPoint, CGFloat)] = [
        (CGPoint(x: 14.2, y: 8 + lift), swing),
        (CGPoint(x: 12.8, y: 8 + lift), -swing),
        (CGPoint(x: 8.2, y: 8 + lift), -swing),
        (CGPoint(x: 6.8, y: 8 + lift), swing),
    ]
    for (hip, angle) in hips {
        stroke([hip, leg(from: hip, length: 5, degrees: angle)], width: 1.4)
    }
}

func drawPushUp(frame: Int, count: Int) {
    let phase = CGFloat(frame) / CGFloat(count) * 2 * .pi
    let up = (cos(phase) + 1) / 2
    stroke([CGPoint(x: 1, y: 1), CGPoint(x: 23, y: 1)], width: 1)
    let feet = CGPoint(x: 3, y: 2.5)
    let hand = CGPoint(x: 17, y: 2.5)
    let shoulder = CGPoint(x: 17, y: 4.5 + 6 * up)
    stroke([feet, shoulder], width: 2)
    let elbow = CGPoint(x: 17 - 3 * (1 - up), y: (shoulder.y + hand.y) / 2)
    stroke([shoulder, elbow, hand], width: 1.4)
    dot(CGPoint(x: shoulder.x + 3, y: shoulder.y + 1.2), radius: 2.2)
}

func drawPullUp(frame: Int, count: Int) {
    let phase = CGFloat(frame) / CGFloat(count) * 2 * .pi
    let up = (1 - cos(phase)) / 2
    let barY: CGFloat = 16.5
    stroke([CGPoint(x: 1, y: barY), CGPoint(x: 17, y: barY)], width: 1.5)
    let shoulderY = 9.5 + 4.5 * up
    let bend = 2.5 * up
    let elbowY = (barY + shoulderY) / 2
    stroke([CGPoint(x: 6, y: barY), CGPoint(x: 6 - bend, y: elbowY), CGPoint(x: 7.5, y: shoulderY)], width: 1.3)
    stroke([CGPoint(x: 12, y: barY), CGPoint(x: 12 + bend, y: elbowY), CGPoint(x: 10.5, y: shoulderY)], width: 1.3)
    stroke([CGPoint(x: 7.5, y: shoulderY), CGPoint(x: 10.5, y: shoulderY)], width: 1.6)
    let hip = CGPoint(x: 9, y: shoulderY - 5)
    stroke([CGPoint(x: 9, y: shoulderY), hip], width: 1.8)
    stroke([hip, CGPoint(x: 7.5, y: shoulderY - 9)], width: 1.4)
    stroke([hip, CGPoint(x: 10.5, y: shoulderY - 9)], width: 1.4)
    dot(CGPoint(x: 9, y: shoulderY + 2.3), radius: 2)
}

func writePNG(size: NSSize, scale: CGFloat, contentScale: CGFloat, yShift: CGFloat, to url: URL, draw: () -> Void) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width * scale),
        pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }
    rep.size = size
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        throw CocoaError(.fileWriteUnknown)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor.black.setStroke()
    NSColor.black.setFill()
    let transform = NSAffineTransform()
    transform.translateX(by: 0, yBy: yShift)
    transform.scale(by: contentScale)
    transform.concat()
    draw()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url)
}

let specs = [
    FrameSpec(theme: "cat", size: NSSize(width: 31, height: 20), count: 5, scale: 1.4, yShift: -3.5, lineBoost: 1.1, draw: drawCat),
    FrameSpec(theme: "pushup", size: NSSize(width: 35, height: 20), count: 6, scale: 1.45, yShift: -0.8, lineBoost: 1.05, draw: drawPushUp),
    FrameSpec(theme: "pullup", size: NSSize(width: 20, height: 20), count: 6, scale: 1.1, yShift: 0, lineBoost: 1.0, draw: drawPullUp),
]

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources/Themes", isDirectory: true)

for spec in specs {
    let directory = root.appendingPathComponent(spec.theme, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    lineBoost = spec.lineBoost
    for frame in 0..<spec.count {
        for (scale, suffix) in [(CGFloat(1), ""), (CGFloat(2), "@2x")] {
            let url = directory.appendingPathComponent("frame-\(frame + 1)\(suffix).png")
            try writePNG(size: spec.size, scale: scale, contentScale: spec.scale, yShift: spec.yShift, to: url) { spec.draw(frame, spec.count) }
        }
    }
    print("\(spec.theme): \(spec.count) frames")
}
```

`Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MacHungry</string>
    <key>CFBundleIdentifier</key>
    <string>com.machungry.app</string>
    <key>CFBundleName</key>
    <string>MacHungry</string>
    <key>CFBundleDisplayName</key>
    <string>MacHungry</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

`scripts/make-app.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

IDENTITY="-"
PROFILE="machungry-notary"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --identity) IDENTITY="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 64 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/MacHungry.app"
DMG="$BUILD/MacHungry.dmg"
cd "$ROOT"

for ARCH in arm64 x86_64; do
  swift build -c release --triple "$ARCH-apple-macosx14.0" --scratch-path ".build/$ARCH"
done

rm -rf "$APP" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create \
  ".build/arm64/release/MacHungry" \
  ".build/x86_64/release/MacHungry" \
  -output "$APP/Contents/MacOS/MacHungry"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/Themes "$APP/Contents/Resources/Themes"

if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify --strict "$APP"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname MacHungry -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

if [[ "$IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"
  xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

echo "App: $APP"
echo "DMG: $DMG"
```

Make the script executable and draw the frames:

```bash
chmod +x scripts/make-app.sh
swift scripts/draw-frames.swift .
```

Expected output: `cat: 5 frames`, `pushup: 6 frames`, `pullup: 6 frames`. Check: `ls Resources/Themes/cat` lists `frame-1.png` … `frame-5.png` and the `@2x` files (10 files).

- [ ] **Step 2: Write the implementation**

`Sources/MacHungry/StatsStore.swift`:

```swift
import Observation
import HungryCore

@MainActor
@Observable
final class StatsStore {
    var cpuPercent: Double?
    var memory: MemoryUsage?
    var temperature: TemperatureReading?
    var topApps: [AppUsage] = []
    var hasTopSample = false
    var isLimited = false
}
```

`Sources/MacHungry/StatsMonitor.swift`:

```swift
import Foundation
import HungryCore
import HungrySystem

@MainActor
final class StatsMonitor {
    static let topLimit = 10
    static let rankThreshold = 1.0

    private let engine = SamplingEngine()
    private let store: StatsStore
    private var systemTask: Task<Void, Never>?
    private var processTask: Task<Void, Never>?
    private var previousOrder: [String] = []

    var onSystemSample: ((SystemSnapshot) -> Void)?

    init(store: StatsStore) {
        self.store = store
    }

    func start() {
        guard systemTask == nil else { return }
        systemTask = Task {
            while !Task.isCancelled {
                await refreshSystem()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func startProcessSampling() {
        guard processTask == nil else { return }
        previousOrder = []
        store.topApps = []
        store.hasTopSample = false
        processTask = Task {
            await engine.resetProcesses()
            var delay: Duration = .milliseconds(500)
            while !Task.isCancelled {
                await refreshProcesses()
                try? await Task.sleep(for: delay)
                delay = .seconds(1)
            }
        }
    }

    func stopProcessSampling() {
        processTask?.cancel()
        processTask = nil
        previousOrder = []
        store.topApps = []
        store.hasTopSample = false
        Task { await engine.resetProcesses() }
    }

    private func refreshSystem() async {
        let snapshot = await engine.sampleSystem()
        store.cpuPercent = snapshot.cpuPercent
        store.memory = snapshot.memory
        store.temperature = snapshot.temperature
        onSystemSample?(snapshot)
    }

    private func refreshProcesses() async {
        let snapshot = await engine.sampleProcesses(limit: Self.topLimit)
        guard !Task.isCancelled else { return }
        store.isLimited = snapshot.isLimited
        guard snapshot.isReady else { return }
        let ordered = RankStabilizer.stabilize(previousOrder: previousOrder, current: snapshot.apps, threshold: Self.rankThreshold)
        previousOrder = ordered.map(\.id)
        store.topApps = ordered
        store.hasTopSample = true
    }
}
```

`Sources/MacHungry/TemplateImageRenderer.swift`:

```swift
import AppKit

enum TemplateImageRenderer {
    static let scale: CGFloat = 2

    static func render(size: NSSize, draw: () -> Void) -> NSImage {
        let image = NSImage(size: size)
        guard size.width > 0, size.height > 0,
              let rep = NSBitmapImageRep(
                  bitmapDataPlanes: nil,
                  pixelsWide: Int((size.width * scale).rounded(.up)),
                  pixelsHigh: Int((size.height * scale).rounded(.up)),
                  bitsPerSample: 8,
                  samplesPerPixel: 4,
                  hasAlpha: true,
                  isPlanar: false,
                  colorSpaceName: .deviceRGB,
                  bytesPerRow: 0,
                  bitsPerPixel: 0
              ) else { return image }
        rep.size = size
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return image }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        draw()
        NSGraphicsContext.restoreGraphicsState()
        image.addRepresentation(rep)
        image.isTemplate = true
        return image
    }
}
```

`Sources/MacHungry/StatusImageComposer.swift`:

```swift
import AppKit
import HungryCore

enum StatusImageComposer {
    static var height: CGFloat { NSStatusBar.system.thickness }
    static let iconGap: CGFloat = 1
    static let groupGap: CGFloat = 4
    static let weight: NSFont.Weight = .semibold

    private enum Part {
        case image(NSImage)
        case text(NSAttributedString, slotWidth: CGFloat)
        case space(CGFloat)

        var width: CGFloat {
            switch self {
            case .image(let image): image.size.width
            case .text(_, let slotWidth): slotWidth
            case .space(let width): width
            }
        }
    }

    static func statsImage(cpu: Double?, memory: Double?, temperature: Double? = nil) -> NSImage {
        let fontSize = NSFont.menuBarFont(ofSize: 0).pointSize
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: NSColor.black,
        ]
        let slotWidth = ceil(NSAttributedString(string: "99%", attributes: attributes).size().width)
        let temperatureSlotWidth = ceil(NSAttributedString(string: "99°", attributes: attributes).size().width)
        var parts: [Part] = []
        if let icon = symbol("cpu", pointSize: fontSize) { parts += [.image(icon), .space(iconGap)] }
        parts.append(.text(NSAttributedString(string: UsageFormatter.percent(cpu), attributes: attributes), slotWidth: slotWidth))
        parts.append(.space(groupGap))
        if let icon = symbol("memorychip", pointSize: fontSize) { parts += [.image(icon), .space(iconGap)] }
        parts.append(.text(NSAttributedString(string: UsageFormatter.percent(memory), attributes: attributes), slotWidth: slotWidth))
        if let temperature {
            parts.append(.space(groupGap))
            if let icon = symbol("thermometer.medium", pointSize: fontSize) { parts += [.image(icon), .space(iconGap)] }
            parts.append(.text(NSAttributedString(string: UsageFormatter.temperature(temperature), attributes: attributes), slotWidth: temperatureSlotWidth))
        }
        let width = parts.reduce(0) { $0 + $1.width }
        return TemplateImageRenderer.render(size: NSSize(width: width, height: height)) {
            var x: CGFloat = 0
            for part in parts {
                switch part {
                case .image(let image):
                    image.draw(in: NSRect(x: x, y: (height - image.size.height) / 2, width: image.size.width, height: image.size.height))
                case .text(let text, _):
                    let textSize = text.size()
                    text.draw(at: NSPoint(x: x, y: (height - textSize.height) / 2))
                case .space:
                    break
                }
                x += part.width
            }
        }
    }

    private static func symbol(_ name: String, pointSize: CGFloat) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight, scale: .medium)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
    }
}
```

`Sources/MacHungry/StatusContentView.swift`:

```swift
import AppKit
import QuartzCore

@MainActor
final class StatusContentView: NSView {
    static let frameGap: CGFloat = 2

    private let tintLayer = CALayer()
    private let maskLayer = CALayer()
    private let frameLayer = CALayer()
    private let statsLayer = CALayer()
    private var frameCache: [ObjectIdentifier: CGImage] = [:]
    private var frameSize = NSSize.zero
    private var statsSize = NSSize.zero

    var contentSize: NSSize {
        let frameWidth = frameSize.width > 0 ? frameSize.width + Self.frameGap : 0
        return NSSize(width: frameWidth + statsSize.width, height: max(frameSize.height, statsSize.height))
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        for sublayer in [frameLayer, statsLayer] {
            sublayer.contentsGravity = .resize
            maskLayer.addSublayer(sublayer)
        }
        tintLayer.mask = maskLayer
        layer?.addSublayer(tintLayer)
        updateTint()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateTint()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        frameLayer.contentsScale = scale
        statsLayer.contentsScale = scale
    }

    func showFrame(_ image: NSImage?) {
        withoutAnimation {
            frameLayer.contents = image.flatMap(cachedCGImage)
        }
    }

    func showStats(_ image: NSImage) {
        withoutAnimation {
            statsLayer.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        if image.size != statsSize {
            statsSize = image.size
            layoutContent()
        }
    }

    func setAnimationFrameSize(_ size: NSSize) {
        frameCache.removeAll()
        guard size != frameSize else { return }
        frameSize = size
        layoutContent()
    }

    private func cachedCGImage(for image: NSImage) -> CGImage? {
        let key = ObjectIdentifier(image)
        if let cached = frameCache[key] { return cached }
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        frameCache[key] = cgImage
        return cgImage
    }

    private func layoutContent() {
        let size = contentSize
        withoutAnimation {
            tintLayer.frame = NSRect(origin: .zero, size: size)
            maskLayer.frame = tintLayer.bounds
            frameLayer.frame = NSRect(x: 0, y: (size.height - frameSize.height) / 2, width: frameSize.width, height: frameSize.height)
            let statsX = frameSize.width > 0 ? frameSize.width + Self.frameGap : 0
            statsLayer.frame = NSRect(x: statsX, y: (size.height - statsSize.height) / 2, width: statsSize.width, height: statsSize.height)
        }
    }

    private func updateTint() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        tintLayer.backgroundColor = isDark ? CGColor(gray: 1, alpha: 1) : CGColor(gray: 0, alpha: 1)
    }

    private func withoutAnimation(_ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changes()
        CATransaction.commit()
    }
}
```

`Sources/MacHungry/FrameLoader.swift`:

```swift
import AppKit
import HungryCore

enum FrameLoader {
    static func frames(for theme: any AnimationTheme, bundle: Bundle = .main) -> [NSImage] {
        guard let directory = bundle.resourceURL?.appendingPathComponent("Themes/\(theme.id)", isDirectory: true) else { return [] }
        let images = theme.frameNames.compactMap { loadFrame(named: $0, in: directory) }
        return images.count == theme.frameCount ? images : []
    }

    private static func loadFrame(named name: String, in directory: URL) -> NSImage? {
        guard let base = NSImageRep(contentsOf: directory.appendingPathComponent("\(name).png")) else { return nil }
        let size = NSSize(width: base.pixelsWide, height: base.pixelsHigh)
        base.size = size
        let image = NSImage(size: size)
        image.addRepresentation(base)
        if let retina = NSImageRep(contentsOf: directory.appendingPathComponent("\(name)@2x.png")) {
            retina.size = size
            image.addRepresentation(retina)
        }
        image.isTemplate = true
        return image
    }
}
```

`Sources/MacHungry/MenuBarAnimator.swift`:

```swift
import AppKit
import HungryCore

@MainActor
final class MenuBarAnimator {
    private(set) var theme: any AnimationTheme
    private var frames: [NSImage] = []
    private var frameIndex = 0
    private var smoothedCPU = 0.0
    private var timer: Timer?
    private var currentInterval: TimeInterval = 0

    var onFrame: ((NSImage?) -> Void)?
    var onThemeApplied: (() -> Void)?

    var currentFrame: NSImage? {
        frames.isEmpty ? nil : frames[frameIndex]
    }

    var frameSize: NSSize {
        frames.first?.size ?? .zero
    }

    init(theme: any AnimationTheme) {
        self.theme = theme
        apply(theme)
    }

    func setTheme(_ newTheme: any AnimationTheme) {
        apply(newTheme)
        onThemeApplied?()
        restartTimer(force: true)
        onFrame?(currentFrame)
    }

    func update(cpu: Double) {
        smoothedCPU = SpeedCurve.smooth(previous: smoothedCPU, new: cpu)
        restartTimer(force: false)
    }

    func start() {
        restartTimer(force: true)
    }

    private func apply(_ candidate: any AnimationTheme) {
        var loaded = FrameLoader.frames(for: candidate)
        var chosen = candidate
        if loaded.isEmpty, candidate.id != ThemeRegistry.fallback.id {
            chosen = ThemeRegistry.fallback
            loaded = FrameLoader.frames(for: chosen)
        }
        theme = chosen
        frames = loaded
        frameIndex = 0
    }

    private func restartTimer(force: Bool) {
        let interval = theme.frameInterval(forCPU: smoothedCPU)
        guard force || timer == nil || SpeedCurve.shouldReplaceTimer(current: currentInterval, new: interval) else { return }
        timer?.invalidate()
        currentInterval = interval
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance() }
        }
        newTimer.tolerance = interval * 0.1
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func advance() {
        guard !frames.isEmpty else { return }
        frameIndex = (frameIndex + 1) % frames.count
        onFrame?(frames[frameIndex])
    }
}
```

`Sources/MacHungry/ThemePreference.swift`:

```swift
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
```

`Sources/MacHungry/StatusItemController.swift`:

```swift
import AppKit
import HungryCore
import HungrySystem

@MainActor
final class StatusItemController: NSObject {
    static let horizontalPadding: CGFloat = 2

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let monitor: StatsMonitor
    private let animator: MenuBarAnimator
    private let contentView = StatusContentView(frame: .zero)
    private var placeholderSize = NSSize.zero

    init(monitor: StatsMonitor, animator: MenuBarAnimator) {
        self.monitor = monitor
        self.animator = animator
        super.init()
        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.toolTip = UsageFormatter.tooltip(cpu: nil, memory: nil)
            button.addSubview(contentView)
        }
        animator.onFrame = { [weak self] frame in self?.contentView.showFrame(frame) }
        animator.onThemeApplied = { [weak self] in self?.applyThemeSize() }
        monitor.onSystemSample = { [weak self] snapshot in self?.apply(snapshot) }
        applyThemeSize()
        contentView.showFrame(animator.currentFrame)
        contentView.showStats(StatusImageComposer.statsImage(cpu: nil, memory: nil))
        updatePlaceholder()
    }

    private func apply(_ snapshot: SystemSnapshot) {
        let cpuTemperature = snapshot.temperature?.cpu
        contentView.showStats(StatusImageComposer.statsImage(cpu: snapshot.cpuPercent, memory: snapshot.memory?.percent, temperature: cpuTemperature))
        updatePlaceholder()
        statusItem.button?.toolTip = UsageFormatter.tooltip(cpu: snapshot.cpuPercent, memory: snapshot.memory?.percent, temperature: cpuTemperature)
        if let cpu = snapshot.cpuPercent {
            animator.update(cpu: cpu)
        }
    }

    private func applyThemeSize() {
        contentView.setAnimationFrameSize(animator.frameSize)
        updatePlaceholder()
    }

    private func updatePlaceholder() {
        guard let button = statusItem.button else { return }
        let size = contentView.contentSize
        guard size != placeholderSize else { return }
        placeholderSize = size
        let placeholder = NSImage(size: size)
        placeholder.isTemplate = true
        button.image = placeholder
        statusItem.length = size.width + Self.horizontalPadding * 2
        button.layoutSubtreeIfNeeded()
        contentView.frame = NSRect(
            x: Self.horizontalPadding,
            y: ((button.bounds.height - size.height) / 2).rounded(),
            width: size.width,
            height: size.height
        )
    }
}
```

`Sources/MacHungry/AppDelegate.swift`:

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = StatsStore()
        let monitor = StatsMonitor(store: store)
        let animator = MenuBarAnimator(theme: ThemePreference.load())
        controller = StatusItemController(monitor: monitor, animator: animator)
        animator.start()
        monitor.start()
    }
}
```

`Sources/MacHungry/MacHungryApp.swift`:

```swift
import AppKit

@main
@MainActor
enum MacHungryApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
```

- [ ] **Step 3: Build, test, and bundle**

Run:

```bash
swift build
scripts/test.sh
scripts/make-app.sh
lipo -info build/MacHungry.app/Contents/MacOS/MacHungry
```

Expected: `Build complete!`, the 68 tests pass, the script prints `App: …/build/MacHungry.app` and `DMG: …/build/MacHungry.dmg`, and `lipo` prints `x86_64 arm64`.

- [ ] **Step 4: Check the menu bar item (Review Focus 1 and 2)**

Run `open build/MacHungry.app`. Ask the user to check:
1. A walking cat, the CPU icon + %, the memory-chip icon + %, and (on Apple Silicon) the thermometer icon + CPU °, show in 1 item. The size matches the system text.
2. The values change each second. The item does not jump in width.
3. Switch the appearance 2 times: `osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to not dark mode'`. The content changes between white and black each time.
4. If an external display is connected: move the menu bar to it (System Settings → Displays → main display). The content stays sharp and the same size.

- [ ] **Step 5: Check the budget and the 100% case (Review Focus 3)**

Ask the `perf-auditor` agent to measure 60 s with the popover closed. Then run 12 `yes > /dev/null &` processes for 30 s, measure again, and stop them with `pkill -x yes`.

Expected (prototype values): about 0.39% CPU normal (with temperature), about 0.5% at full load, about 15 MB. Pass: CPU < 1%, RAM < 30 MB. At full load the cat runs fast. If the CPU shows `100%`, the item grows by 1 digit, and the text does not overlap the RAM icon.

- [ ] **Step 6: Commit (ask the user first)**

```bash
git add Package.swift Resources/Info.plist Resources/Themes Sources/MacHungry/AppDelegate.swift Sources/MacHungry/FrameLoader.swift Sources/MacHungry/MacHungryApp.swift Sources/MacHungry/MenuBarAnimator.swift Sources/MacHungry/StatsMonitor.swift Sources/MacHungry/StatsStore.swift Sources/MacHungry/StatusContentView.swift Sources/MacHungry/StatusImageComposer.swift Sources/MacHungry/StatusItemController.swift Sources/MacHungry/TemplateImageRenderer.swift Sources/MacHungry/ThemePreference.swift scripts/draw-frames.swift scripts/make-app.sh
git commit -m "feat(app): add animated menu bar item, frames, and bundle script"
```

---

### Task 8: Popover: top 10 apps, theme picker, quit, launch at login

**Requirements:** F4–F13, F16, N3 (spec 5.3 step 6, 6.3–6.5, 7)

**Files:**
- Create or replace: `Sources/MacHungry/LoginItemManager.swift`
- Create or replace: `Sources/MacHungry/AppTerminator.swift`
- Create or replace: `Sources/MacHungry/IconCache.swift`
- Create or replace: `Sources/MacHungry/PopoverModel.swift`
- Create or replace: `Sources/MacHungry/UsageGaugeRow.swift`
- Create or replace: `Sources/MacHungry/AppRowView.swift`
- Create or replace: `Sources/MacHungry/TemperatureRow.swift`
- Create or replace: `Sources/MacHungry/PopoverView.swift`
- Create or replace: `Sources/MacHungry/StatusItemController.swift`
- Create or replace: `Sources/MacHungry/AppDelegate.swift`

**Interfaces:**
- Consumes: `StatsStore`, `StatsMonitor`, `MenuBarAnimator`, `ThemePreference`, `StatusContentView` (Task 7); `UsageFormatter`, `ThemeRegistry`, `AppUsage`, `TemperatureReading` (Tasks 3–5).
- Produces: `LoginItemManager.isEnabled`, `.setEnabled(_:) throws`; `AppTerminator.canQuit(_:)`, `.confirmAndQuit(_:)`; `IconCache` (`icon(for:)`, `retainOnly(_:)`, `removeAll()`); `PopoverModel(onThemeChange:)` (`themeID`, `launchAtLogin`, `loginError`, `selectTheme(id:)`, `setLaunchAtLogin(_:)`); `UsageGaugeRow`; `AppRowView`; `TemperatureRow(reading:)`; `PopoverView(store:iconCache:model:)`; `StatusItemController(store:monitor:animator:iconCache:)` (replaces the Task 7 initializer).

- [ ] **Step 1: Write the implementation**

`Sources/MacHungry/LoginItemManager.swift`:

```swift
import ServiceManagement

@MainActor
enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
```

`Sources/MacHungry/AppTerminator.swift`:

```swift
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
```

`Sources/MacHungry/IconCache.swift`:

```swift
import AppKit
import HungryCore
import UniformTypeIdentifiers

@MainActor
final class IconCache {
    static let iconSize = NSSize(width: 13, height: 13)

    private var icons: [String: NSImage] = [:]
    private lazy var genericIcon: NSImage = {
        let icon = NSWorkspace.shared.icon(for: .unixExecutable)
        icon.size = Self.iconSize
        return icon
    }()

    func icon(for app: AppUsage) -> NSImage {
        guard let path = app.identity.bundlePath else { return genericIcon }
        if let cached = icons[path] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = Self.iconSize
        icons[path] = icon
        return icon
    }

    func retainOnly(_ apps: [AppUsage]) {
        let keep = Set(apps.compactMap(\.identity.bundlePath))
        icons = icons.filter { keep.contains($0.key) }
    }

    func removeAll() {
        icons.removeAll()
    }
}
```

`Sources/MacHungry/PopoverModel.swift`:

```swift
import Observation
import HungryCore

@MainActor
@Observable
final class PopoverModel {
    private(set) var themeID: String
    private(set) var launchAtLogin: Bool
    private(set) var loginError: String?

    @ObservationIgnored private let onThemeChange: (any AnimationTheme) -> Void

    init(onThemeChange: @escaping (any AnimationTheme) -> Void) {
        self.themeID = ThemePreference.load().id
        self.launchAtLogin = LoginItemManager.isEnabled
        self.onThemeChange = onThemeChange
    }

    func selectTheme(id: String) {
        let theme = ThemeRegistry.theme(withID: id)
        guard theme.id != themeID else { return }
        themeID = theme.id
        ThemePreference.save(theme)
        onThemeChange(theme)
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
```

`Sources/MacHungry/UsageGaugeRow.swift`:

```swift
import SwiftUI
import HungryCore

struct UsageGaugeRow: View {
    let label: String
    let percent: Double?
    let detail: String?

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.callout.weight(.semibold))
                .frame(width: 38, alignment: .leading)
            Text(UsageFormatter.percent(percent))
                .monospacedDigit()
                .frame(width: 38, alignment: .trailing)
            ProgressView(value: min(max(percent ?? 0, 0), 100), total: 100)
                .frame(width: 70)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}
```

`Sources/MacHungry/AppRowView.swift`:

```swift
import SwiftUI
import HungryCore

struct AppRowView: View {
    let app: AppUsage
    let icon: NSImage
    let canQuit: Bool
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 13, height: 13)
            Text(String(format: "%.1f%%", app.percent))
                .monospacedDigit()
                .frame(width: 46, alignment: .trailing)
            Text(app.identity.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 150, alignment: .leading)
            Spacer(minLength: 0)
            Button(action: onQuit) {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.small)
            }
            .buttonStyle(.borderless)
            .help("Quit \(app.identity.name)")
            .opacity(canQuit ? 1 : 0)
            .disabled(!canQuit)
        }
        .frame(height: 15)
    }
}
```

`Sources/MacHungry/TemperatureRow.swift`:

```swift
import SwiftUI
import HungryCore

struct TemperatureRow: View {
    let reading: TemperatureReading

    var body: some View {
        HStack(spacing: 4) {
            Text("Temp")
                .font(.callout.weight(.semibold))
                .frame(width: 38, alignment: .leading)
            Text(UsageFormatter.temperatureDetail(reading))
                .monospacedDigit()
        }
    }
}
```

`Sources/MacHungry/PopoverView.swift`:

```swift
import SwiftUI
import HungryCore

struct PopoverView: View {
    let store: StatsStore
    let iconCache: IconCache
    let model: PopoverModel

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            UsageGaugeRow(label: "CPU", percent: store.cpuPercent, detail: nil)
            UsageGaugeRow(
                label: "RAM",
                percent: store.memory?.percent,
                detail: store.memory.map { UsageFormatter.memoryDetail(usedBytes: $0.usedBytes, totalBytes: $0.totalBytes) }
            )
            if let temperature = store.temperature {
                TemperatureRow(reading: temperature)
            }
            Divider()
            topAppsSection
            Divider()
            controls
        }
        .padding(10)
        .fixedSize()
        .font(.callout)
        .controlSize(.small)
        .onChange(of: store.topApps) { _, apps in
            iconCache.retainOnly(apps)
        }
    }

    @ViewBuilder
    private var topAppsSection: some View {
        HStack {
            Text("Top apps by CPU").font(.callout.weight(.semibold))
            Spacer()
            if store.isLimited {
                Text("limited")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help("/bin/ps failed. The list shows only your own processes.")
            }
        }
        if !store.hasTopSample {
            Text("Measuring…").foregroundStyle(.secondary)
        } else if store.topApps.isEmpty {
            Text("No activity").foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(store.topApps) { app in
                    AppRowView(
                        app: app,
                        icon: iconCache.icon(for: app),
                        canQuit: AppTerminator.canQuit(app),
                        onQuit: { AppTerminator.confirmAndQuit(app) }
                    )
                }
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 3) {
            Picker("Animation", selection: Binding(get: { model.themeID }, set: { model.selectTheme(id: $0) })) {
                ForEach(ThemeRegistry.all, id: \.id) { theme in
                    Text(theme.displayName).tag(theme.id)
                }
            }
            Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            if let loginError = model.loginError {
                Text(loginError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Quit MacHungry") { NSApp.terminate(nil) }
            }
        }
    }
}
```

`Sources/MacHungry/StatusItemController.swift`:

```swift
import AppKit
import SwiftUI
import HungryCore
import HungrySystem

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    static let horizontalPadding: CGFloat = 2

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let store: StatsStore
    private let monitor: StatsMonitor
    private let animator: MenuBarAnimator
    private let iconCache: IconCache
    private let contentView = StatusContentView(frame: .zero)
    private var placeholderSize = NSSize.zero

    init(store: StatsStore, monitor: StatsMonitor, animator: MenuBarAnimator, iconCache: IconCache) {
        self.store = store
        self.monitor = monitor
        self.animator = animator
        self.iconCache = iconCache
        super.init()
        popover.behavior = .transient
        popover.delegate = self
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.imagePosition = .imageOnly
            button.toolTip = UsageFormatter.tooltip(cpu: nil, memory: nil)
            button.addSubview(contentView)
        }
        animator.onFrame = { [weak self] frame in self?.contentView.showFrame(frame) }
        animator.onThemeApplied = { [weak self] in self?.applyThemeSize() }
        monitor.onSystemSample = { [weak self] snapshot in self?.apply(snapshot) }
        applyThemeSize()
        contentView.showFrame(animator.currentFrame)
        contentView.showStats(StatusImageComposer.statsImage(cpu: nil, memory: nil))
        updatePlaceholder()
    }

    private func apply(_ snapshot: SystemSnapshot) {
        let cpuTemperature = snapshot.temperature?.cpu
        contentView.showStats(StatusImageComposer.statsImage(cpu: snapshot.cpuPercent, memory: snapshot.memory?.percent, temperature: cpuTemperature))
        updatePlaceholder()
        statusItem.button?.toolTip = UsageFormatter.tooltip(cpu: snapshot.cpuPercent, memory: snapshot.memory?.percent, temperature: cpuTemperature)
        if let cpu = snapshot.cpuPercent {
            animator.update(cpu: cpu)
        }
    }

    private func applyThemeSize() {
        contentView.setAnimationFrameSize(animator.frameSize)
        updatePlaceholder()
    }

    private func updatePlaceholder() {
        guard let button = statusItem.button else { return }
        let size = contentView.contentSize
        guard size != placeholderSize else { return }
        placeholderSize = size
        let placeholder = NSImage(size: size)
        placeholder.isTemplate = true
        button.image = placeholder
        statusItem.length = size.width + Self.horizontalPadding * 2
        button.layoutSubtreeIfNeeded()
        contentView.frame = NSRect(
            x: Self.horizontalPadding,
            y: ((button.bounds.height - size.height) / 2).rounded(),
            width: size.width,
            height: size.height
        )
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        let model = PopoverModel { [weak self] theme in
            self?.animator.setTheme(theme)
        }
        let view = PopoverView(store: store, iconCache: iconCache, model: model)
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        monitor.startProcessSampling()
        NSApp.activate()
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    func popoverDidClose(_ notification: Notification) {
        monitor.stopProcessSampling()
        iconCache.removeAll()
        popover.contentViewController = nil
    }
}
```

`Sources/MacHungry/AppDelegate.swift`:

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = StatsStore()
        let monitor = StatsMonitor(store: store)
        let animator = MenuBarAnimator(theme: ThemePreference.load())
        controller = StatusItemController(store: store, monitor: monitor, animator: animator, iconCache: IconCache())
        animator.start()
        monitor.start()
    }
}
```

- [ ] **Step 2: Build, test, and bundle**

Run:

```bash
swift build
scripts/test.sh
scripts/make-app.sh
```

Expected: `Build complete!`, 68 tests pass (61 core, 7 integration), `App:` and `DMG:` lines.

- [ ] **Step 3: Check the popover (Review Focus 4 and 5)**

Run `pkill -x MacHungry; open build/MacHungry.app`. Ask the user to check:
1. A click opens the popover: CPU and RAM bars, a "Temp  CPU NN°C  GPU NN°C" row on 1 line, "Measuring…" for about 0.5 s, then 10 rows with icons. Each row shows the CPU % before the name, with no gap.
2. Open TextEdit. Its row (if in the top 10) has `(×)`. Rows like `kernel_task` or `logd` have no `(×)`.
3. Click `(×)` on TextEdit → the dialog "Quit TextEdit?" appears → `Cancel` → TextEdit still runs. Click again → `Quit` → TextEdit quits normally.
4. Select "Push-ups", then "Pull-ups". The animation changes at once, and the width changes once. Run `pkill -x MacHungry; open build/MacHungry.app`. The last theme is still selected.
5. Turn on "Launch at login". If macOS asks for approval, the toggle shows the real state and an error text if it fails. Log out and in: the app starts.
6. Press `Esc` or click outside: the popover closes.

- [ ] **Step 4: Check the open-popover budget**

Ask the `perf-auditor` agent to measure 60 s with the popover open. Pass: CPU < 5%, RAM < 30 MB. Then ask the `spec-reviewer` agent to review the whole branch against the spec.

- [ ] **Step 5: Commit (ask the user first)**

```bash
git add Sources/MacHungry/AppDelegate.swift Sources/MacHungry/AppRowView.swift Sources/MacHungry/AppTerminator.swift Sources/MacHungry/IconCache.swift Sources/MacHungry/LoginItemManager.swift Sources/MacHungry/PopoverModel.swift Sources/MacHungry/PopoverView.swift Sources/MacHungry/StatusItemController.swift Sources/MacHungry/TemperatureRow.swift Sources/MacHungry/UsageGaugeRow.swift
git commit -m "feat(app): add popover with top apps, theme picker, and quit"
```

---
