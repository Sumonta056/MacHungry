# MacHungry — Menu Bar System Monitor: Design Spec

- Date: 2026-10-02
- Status: Approved in conversation. Waiting for written-spec review.

## 1. Goal

MacHungry is a macOS menu bar app. It shows the live CPU % and RAM % in the menu bar, next to an animation. A high CPU value makes the animation move faster. A click opens a popover with the top 10 apps by CPU usage.

The user shares the app with friends and a team, outside the Mac App Store.

## 2. Requirements

### 2.1 Functional

| ID | Requirement |
|---|---|
| F1 | The menu bar item shows: animation frame, CPU icon + CPU %, RAM icon + RAM %. |
| F2 | The menu bar values update every 1 s. |
| F3 | The animation speed follows CPU % only. RAM % shows as a number only. |
| F4 | The user selects 1 animation theme. Version 1 has 3 themes: Cat (runs), Push-ups, Pull-ups. |
| F5 | The selected theme stays after a restart. |
| F6 | A click on the menu bar item opens a popover. |
| F7 | The popover shows the top 10 apps by CPU %. Helper processes add into their parent app. A process without an app bundle shows by its process name. |
| F8 | The top 10 list includes processes of all users, including root. |
| F9 | The top 10 list updates every 1 s while the popover is open. The first result shows 0.5 s after open. |
| F10 | Each row shows the app icon, the name, and the CPU %. |
| F11 | A row of a quittable app has a quit button. A click shows a confirmation dialog. `Quit` sends a normal (not forced) quit request. |
| F12 | The popover has a "Launch at login" toggle. |
| F13 | The popover has a "Quit App" button that quits MacHungry. |
| F14 | A tooltip on the menu bar item shows "CPU NN% · RAM NN%". |

### 2.2 Non-functional

| ID | Requirement |
|---|---|
| N1 | RAM use of MacHungry is less than 30 MB. |
| N2 | CPU use of MacHungry is less than 1% of 1 core when the popover is closed. |
| N3 | While the popover is open, CPU use is less than 5% of 1 core. |
| N4 | Minimum macOS version: 14 (Sonoma). |
| N5 | The app has no Dock icon (`LSUIElement = true`). |
| N6 | The app builds with the Xcode Command Line Tools only. Full Xcode is not necessary. |
| N7 | The app works in light mode and dark mode. |

### 2.3 Out of scope (version 1)

- Mac App Store release and the App Sandbox.
- A privileged root helper.
- Force quit.
- History graphs, alerts, or notifications.
- A rep counter for the push-ups or pull-ups themes.
- Any animation that follows RAM.

## 3. Definitions

- **CPU % (menu bar):** The busy share of all cores over the last 1 s. Range 0–100%.
- **CPU % (top 10 row):** The CPU time of the app over the last sample window ÷ the wall time × 100. 1 full core = 100%, so 1 app can show more than 100%. This matches Activity Monitor.
- **RAM %:** "Memory Used" as in Activity Monitor ÷ total physical memory × 100.

## 4. Architecture

Approach: native AppKit `NSStatusItem` for the menu bar item, and an `NSPopover` that holds a SwiftUI view. Reason: only AppKit animates the menu bar image reliably. SwiftUI `MenuBarExtra` can freeze or stutter the label.

```
            ┌─────────── Sampling (background actor) ──────────┐
 timer 1s → │ SystemSampler  → CPU %, RAM %                     │
 timer 1s → │ ProcessSampler → ps → per-PID CPU → AppGrouper    │
 (popover   │                                                   │
  open only)└──────────────────────┬────────────────────────────┘
                                   ▼
                        StatsStore (@MainActor, @Observable)
                     ┌─────────────┴──────────────┐
                     ▼                            ▼
          StatusItemController             PopoverView (SwiftUI)
          ├ MenuBarAnimator                ├ Top 10 rows + icons
          │   └ AnimationTheme (protocol)  ├ Theme picker
          └ icon + text                    ├ Quit row → AppTerminator
                                           └ Toggle → LoginItemManager
```

### 4.1 Units

| Unit | Module | Job | Depends on |
|---|---|---|---|
| `CPUCalculator` | HungryCore | Pure function: 2 tick snapshots → CPU %. | nothing |
| `MemoryCalculator` | HungryCore | Pure function: page counts + page size + total → RAM %. | nothing |
| `PSParser` | HungryCore | Parses `ps` output lines into `(pid, cpuSeconds, path)`. | nothing |
| `ProcessCPUTracker` | HungryCore | Keeps the last CPU time for each PID. Computes the % per PID. Removes PIDs that stopped. | nothing |
| `AppGrouper` | HungryCore | Maps a path to an app name and a bundle path. Sums the % of each app. Returns the top N. | nothing |
| `AnimationTheme` | HungryCore | Protocol for 1 theme. | nothing |
| `SpeedCurve` | HungryCore | Smoothing + CPU → frame interval. | nothing |
| `ThemeRegistry` | HungryCore | Holds the list of themes and the default theme. | `AnimationTheme` |
| `CatTheme`, `PushUpTheme`, `PullUpTheme` | HungryCore | Theme values and frame names. | `AnimationTheme` |
| `SystemSampler` | MacHungry | Reads `host_processor_info`, `host_statistics64`, `hw.memsize`. | Mach APIs |
| `ProcessSampler` | MacHungry | Runs `/bin/ps`. Falls back to `libproc`. | `PSParser`, `ProcessCPUTracker` |
| `StatsStore` | MacHungry | Holds the latest values for the UI. | samplers |
| `MenuBarAnimator` | MacHungry | Changes the frame on a timer. Knows only `AnimationTheme`. | `SpeedCurve`, `ThemeRegistry` |
| `StatusItemController` | MacHungry | Owns the `NSStatusItem` and the popover. | AppKit |
| `PopoverView` | MacHungry | The SwiftUI popover. | `StatsStore` |
| `IconCache` | MacHungry | App icons for the visible rows. Clears on popover close. | `NSWorkspace` |
| `AppTerminator` | MacHungry | Sends a normal quit request to all instances of 1 app. | `NSRunningApplication` |
| `LoginItemManager` | MacHungry | Registers or unregisters `SMAppService.mainApp`. | ServiceManagement |

### 4.2 Theme interface

```swift
protocol AnimationTheme {
    var id: String { get }
    var displayName: String { get }
    var frameNames: [String] { get }
    var maxInterval: TimeInterval { get }
    var minInterval: TimeInterval { get }
}
```

To add a theme:
1. Add 1 file that conforms to `AnimationTheme`, and add its frame PNG files in `Resources/Themes/<id>/`.
2. Add 1 line in `ThemeRegistry`.

`MenuBarAnimator` does not change.

## 5. Data flow and calculations

### 5.1 Total CPU % (every 1 s, always)

1. Read the ticks of each core with `host_processor_info(PROCESSOR_CPU_LOAD_INFO)`: `user`, `system`, `nice`, `idle`.
2. For each core: `busy = Δuser + Δsystem + Δnice`, `total = busy + Δidle`.
3. `CPU % = Σ busy ÷ Σ total × 100`. If `Σ total = 0`, the result is 0.
4. Free the buffer from `host_processor_info` with `vm_deallocate` after each read.

### 5.2 RAM % (every 1 s, always)

1. Read `vm_statistics64` with `host_statistics64(HOST_VM_INFO64)`.
2. `usedPages = (internal_page_count − purgeable_count) + wire_count + compressor_page_count`.
3. `RAM % = usedPages × vm_kernel_page_size ÷ hw.memsize × 100`.
4. The popover also shows used GB / total GB.

### 5.3 Top 10 apps (every 1 s, popover open only)

1. Run `/bin/ps -axo pid=,time=,comm=`. `ps` is setuid root, so it can read all processes. A normal app with `libproc` cannot read root processes (test result on 2026-10-02: 247 of 762 processes denied with `EPERM`).
2. `PSParser` converts the `time` column to seconds. It accepts `m:ss.cc`, `mmmm:ss.cc` (minutes can be more than 59), `hh:mm:ss.cc`, and `dd-hh:mm:ss.cc`. The path can contain spaces, so the parser takes the rest of the line after the 2nd column.
3. `ProcessCPUTracker`:
   - For a known PID: `CPU % = (cpuSeconds − lastCpuSeconds) ÷ (now − lastSampleTime) × 100`.
   - For a new PID: store the value. It shows from the next sample.
   - If `cpuSeconds < lastCpuSeconds` (PID reuse), store the new value and show 0 for this sample.
   - Remove PIDs that are not in the current output.
4. `AppGrouper`:
   - Find the **outermost** `.app` component in the path. Example: `/Applications/Google Chrome.app/Contents/Frameworks/.../Google Chrome Helper.app/.../Google Chrome Helper` → `Google Chrome.app`.
   - The app name is the bundle file name without `.app`.
   - If there is no `.app`, the name is the last path component.
   - Sum the % of each group. Sort from high to low. Keep 10.
5. On popover open: take the 1st sample at once, the 2nd sample after 0.5 s, then 1 sample each 1 s.
6. Measured cost: 1 `ps` run ≈ 40 ms. At 1 run each second, this is about 4% of 1 core, only while the popover is open.

### 5.4 Animation speed

1. Smoothing: `smoothCPU = 0.7 × smoothCPU + 0.3 × newCPU`, once each 1 s sample.
2. `interval = maxInterval − (maxInterval − minInterval) × (smoothCPU ÷ 100)`. Clamp `smoothCPU` to 0–100.
3. Default values:

| Theme | maxInterval (0%) | minInterval (100%) |
|---|---|---|
| Cat | 0.20 s | 0.03 s |
| Push-ups | 0.25 s | 0.04 s |
| Pull-ups | 0.25 s | 0.04 s |

4. 1 repetition (push-up or pull-up) uses all frames of the theme.
5. A main-thread timer shows the next frame. When the interval changes by more than 5 ms, the animator replaces the timer.

### 5.5 Thread model

- `SystemSampler` and `ProcessSampler` run in 1 background Swift `actor`.
- `ps` runs with `Process`. The sampler reads its output on the background actor. The timeout is 0.8 s.
- `StatsStore` is `@MainActor`. The UI reads only from `StatsStore`.

## 6. User interface

### 6.1 Menu bar item

```
 [frame] [cpu]72% [memorychip]61%
```

- The frame is a monochrome template image, 18 pt high. macOS colors it for light and dark menu bars.
- The CPU and RAM icons are the SF Symbols `cpu` and `memorychip`, about 11 pt wide. They go inside the title with `NSTextAttachment`.
- The numbers use a monospaced-digit system font. The width stays the same when the values change.
- If a value is not available, it shows `--`.

### 6.2 Popover

```
┌──────────────────────────────────────┐
│  CPU 72%   ████████░░                │
│  RAM 61%   ██████░░░░   9.8 / 16 GB  │
├──────────────────────────────────────┤
│  Top apps by CPU                     │
│  [icon] Google Chrome     84.2%  [×] │
│  [icon] Xcode             31.0%  [×] │
│  [icon] com.eset.endpoint 28.4%      │
│  ...  (10 rows)                      │
├──────────────────────────────────────┤
│  Animation: [ Cat         ▾ ]        │
│  [✓] Launch at login                 │
│                          [Quit App]  │
└──────────────────────────────────────┘
```

### 6.3 Row behavior

1. The icon comes from `NSWorkspace.shared.icon(forFile:)` with the bundle path. A row without a bundle shows a generic icon.
2. The `[×]` button shows only if `NSRunningApplication.runningApplications(withBundleIdentifier:)` returns 1 or more apps, the processes belong to the current user, and the app is not MacHungry.
3. A click on `[×]` shows a dialog "Quit <name>?" with `Cancel` and `Quit`.
4. `Quit` calls `terminate()` on each running instance. It does not call `forceTerminate()`.
5. The list changes the order of 2 rows only when their CPU difference is more than 1%.
6. Before the 2nd sample, the list shows "Measuring…".

### 6.4 Popover open and close

1. Open: start `ProcessSampler`.
2. Close (click outside or `Esc`): stop `ProcessSampler`, clear `ProcessCPUTracker`, and clear `IconCache`. The SwiftUI view is destroyed.

## 7. Error handling

| Problem | Behavior |
|---|---|
| `host_processor_info` or `host_statistics64` fails | Show `--` for that value. Try again on the next sample. |
| `ps` fails, exits with an error, or takes more than 0.8 s | Use `libproc` (`proc_listallpids`, `proc_pid_rusage`, `proc_pidpath`) for that sample. Show a "limited" label in the popover. |
| `libproc` CPU time | `ri_user_time + ri_system_time` are in Mach time units. Convert to ns with `mach_timebase_info`. |
| Malformed `ps` line | Skip the line. |
| PID stops between samples | Remove it from the tracker. |
| PID reuse (CPU time goes down) | Store as new. Show 0 for this sample. |
| Quit request fails or the app ignores it | No message. The row stays while the app runs. |
| `SMAppService` register or unregister fails | Set the toggle back. Show the error text below the toggle. |
| Theme frame image is missing | Use the Cat theme. |
| Saved theme id is unknown | Use the Cat theme. |

## 8. Project structure

```
mac-hungry/
├─ Package.swift                 (swift-tools-version 6.0, macOS 14)
├─ Sources/
│  ├─ HungryCore/                (library, no AppKit)
│  └─ MacHungry/                 (executable, AppKit + SwiftUI)
├─ Resources/
│  ├─ Info.plist                 (LSUIElement, bundle id, version)
│  └─ Themes/{cat,pushup,pullup}/frame-N.png
├─ Tests/HungryCoreTests/
└─ scripts/make-app.sh
```

## 9. Testing

Framework: Swift Testing (`import Testing`), run with `swift test`.

### 9.1 Unit tests (HungryCore)

1. `CPUCalculator`: idle machine = 0%, full load = 100%, mixed cores, `Σ total = 0`.
2. `MemoryCalculator`: known page counts → expected %.
3. `PSParser`: `mm:ss.cc`, `hh:mm:ss.cc`, `dd-hh:mm:ss.cc`, paths with spaces, malformed lines.
4. `ProcessCPUTracker`: normal delta, new PID, PID reuse, PID removal.
5. `AppGrouper`: plain app, nested helper `.app`, daemon path, top-N sort, sum of a group.
6. `SpeedCurve`: interval at 0%, 50%, 100%, values out of range, smoothing.
7. `ThemeRegistry`: unknown id → Cat.

### 9.2 Integration test

Run the real `SystemSampler` and `ProcessSampler` 2 times. Check: CPU % and RAM % are in 0–100, and the top list is not empty.

### 9.3 Manual checks

1. Run the app for 10 minutes. Measure with `top -pid <pid>`. Pass: RAM < 30 MB, CPU < 1% with the popover closed, CPU < 5% with it open.
2. Run `yes > /dev/null` on 4 terminals. Check that the animation becomes faster and `yes` shows in the top 10.
3. Check the menu bar in light mode and dark mode.
4. Check that the quit dialog appears, and that `Cancel` does nothing.
5. Turn "Launch at login" on, log out, log in, and check that the app starts.

## 10. Build and distribution

1. `scripts/make-app.sh` runs `swift build -c release`, builds `MacHungry.app` (binary, `Info.plist`, theme resources), signs it, and makes a DMG with `hdiutil`.
2. Default signing: ad-hoc (`codesign -s -`). The friends must right-click the app and select **Open** the first time.
3. With the flag `--identity "<Developer ID>"`, the script signs with the hardened runtime and sends the app to Apple with `xcrun notarytool`, then staples the ticket.
4. Bundle id: `com.machungry.app`. Minimum macOS: 14.0.

## 11. Animation art

1. Do not copy RunCat art or any other art that has a copyright.
2. Draw simple monochrome frames: Cat 5 frames, Push-ups 6 frames, Pull-ups 6 frames.
3. Size: 18 pt high, @1x and @2x PNG, black on transparent. Mark them as template images at load time.
4. A Swift script, `scripts/draw-frames.swift`, draws the version 1 frames with Core Graphics and writes the PNG files. The PNG files go into git, so a normal build does not run the script.
5. A later art change replaces only the PNG files. The code does not change.
