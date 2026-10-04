# MacHungry — Menu Bar System Monitor: Design Spec

- Date: 2026-10-02 (revised 2026-10-03 after the prototype, and again on 2026-10-03 for the layout menu, top-N setting, and app icon)
- Status: Approved in conversation. The prototype verified all decisions in section 13. Temperature added on 2026-10-03.

## 1. Goal

MacHungry is a macOS menu bar app. It shows the live CPU %, RAM %, and CPU temperature in the menu bar, next to an animation. A high CPU value makes the animation move faster. A click opens a popover with the top 10 or 20 apps by CPU usage. A right-click opens a menu that sets which parts show and their order.

The user shares the app with friends and a team, outside the Mac App Store.

## 2. Requirements

### 2.1 Functional

| ID | Requirement |
|---|---|
| F1 | The menu bar item shows 4 parts: animation frame, `C` + CPU %, `R` + RAM %, and the CPU temperature (`68°`, no letter). It shows no icons. The user sets the order and which parts show (F18). Default: all 4, in this order. |
| F2 | The menu bar values update every 1 s. |
| F3 | The animation speed follows CPU % only. RAM % shows as a number only. |
| F4 | The user selects 1 animation theme. Version 1 has 3 themes: Cat (runs), Push-ups, Pull-ups. |
| F5 | The selected theme stays after a restart. |
| F6 | A left-click on the menu bar item opens a popover. |
| F7 | The popover shows the top N apps by CPU % (N from F19). The CPU % of each process adds into its owner process (section 3). Helper processes add into their parent app. A child process of a command-line tool adds into that tool (example: the `node` processes that `claude` starts add into `claude`). An owner without an app bundle shows by its process name. |
| F8 | The top N list includes processes of all users, including root. |
| F9 | The top N list updates every 1 s while the popover is open. The first result shows 0.5 s after open. |
| F10 | Each row shows the app icon, the CPU %, and the name. |
| F11 | A row of a quittable app has a quit button. A click shows a confirmation dialog. `Quit` sends a normal (not forced) quit request. |
| F12 | The popover has a "Launch at login" toggle. |
| F13 | The popover has a "Quit MacHungry" button. |
| F14 | A tooltip on the menu bar item shows "CPU NN% · RAM NN%", plus " · NN°C" when the temperature is known. |
| F15 | On Apple Silicon, the menu bar temperature part shows the CPU temperature (smoothed hottest CPU core). |
| F16 | The popover shows a "Temp" row: CPU °C and GPU °C. |
| F17 | If the Mac has no known sensors (Intel, unknown chip), the app hides the temperature. It never shows a guess. |
| F18 | A right-click (or Control-click) on the menu bar item opens a menu. Each of the 4 parts has a submenu: **Show**, **Move Left**, **Move Right**. **Reset Layout** sets the default. The order and the hidden parts stay after a restart. The last visible part cannot be hidden. A hidden animation runs no timer. A hidden temperature does no SMC read. |
| F19 | The popover has a "Show 10 / 20" control. It sets N for the top apps list. Default 10. The value stays after a restart and applies from the next sample. |
| F20 | The app bundle has an icon (a cat on a CPU chip) for Finder, the DMG, and Login Items. |

### 2.2 Non-functional

| ID | Requirement |
|---|---|
| N1 | RAM use of MacHungry is less than 30 MB before the first popover open, and less than 35 MB after it (open or closed). Measure the physical footprint (`top` MEM, the "Memory" column of Activity Monitor). RSS is not used, because it counts shared system framework pages. The RAM must not grow with more popover opens. Reason for 2 limits: the first open loads SwiftUI, AppKit popover, and IconServices caches (about 15 MB, measured 2026-10-03). The frameworks keep these caches after the close, so the app cannot free them. |
| N2 | CPU use of MacHungry is less than 1% of 1 core when the popover is closed, also at full system load. |
| N3 | While the popover is open, CPU use is less than 5% of 1 core. |
| N4 | Minimum macOS version: 14 (Sonoma). |
| N5 | The app has no Dock icon (`LSUIElement = true`). |
| N6 | The app builds with the Xcode Command Line Tools only. Full Xcode is not necessary. |
| N7 | The app works in light mode and dark mode. |
| N8 | The app is a universal binary (Apple Silicon and Intel). |

### 2.3 Out of scope (version 1)

- Mac App Store release and the App Sandbox.
- A privileged root helper.
- Force quit.
- History graphs, alerts, or notifications.
- A rep counter for the push-ups or pull-ups themes.
- Any animation that follows RAM or temperature.
- A "hottest sensor anywhere" value (as the Hot app shows). It reads all `T` SMC keys and costs about 0.4% CPU.

## 3. Definitions

- **CPU % (menu bar):** The busy share of all cores over the last 1 s. Range 0–100%.
- **CPU % (top N row):** The CPU time of the app over the last sample window ÷ (the wall time × the active core count) × 100. Range 0–100%. 100% means that the app keeps all cores busy.
- **Owner process:** the process that a top N row counts a process under. Make the parent chain from the process up to `launchd` (PID 1), then read it from the top down. If the chain has a shell, the owner is the first non-shell process after the first shell. If the chain has no shell, or no non-shell process follows the first shell, the owner is the first process below `launchd`. `launchd` owns itself. Shell names: `sh`, `bash`, `zsh`, `fish`, `dash`, `ksh`, `tcsh`, `csh`, `login`.

  | Chain (top → down) | Owner |
  |---|---|
  | `launchd > Orca > zsh > claude > sh > node` | `claude` |
  | `launchd > Orca > zsh > node` | `node` |
  | `launchd > tmux > zsh > claude > node` | `claude` |
  | `launchd > Claude.app > Claude Helper` | `Claude` |
  | `launchd > Orca > Orca Helper` | `Orca` |
  | `launchd > Orca > zsh` | `Orca` |
  | `launchd > WindowServer` | `WindowServer` |

- **RAM %:** "Memory Used" as in Activity Monitor ÷ total physical memory × 100.
- **CPU temperature:** the hottest of the CPU core sensors in the chip's key table (5.6), smoothed. It is not the hottest sensor of the whole Mac, so it is 7–9 °C lower than the Hot app on the test Mac.

## 4. Architecture

```
            ┌──────── HungrySystem (background actor) ─────────┐
 timer 1s → │ SystemSampler  → CPU %, RAM %                     │
 timer 1s → │ ProcessSampler → ps → per-PID CPU → AppGrouper    │
 (popover   │                                                   │
  open only)└──────────────────────┬────────────────────────────┘
                                   ▼
                    StatsMonitor → StatsStore (@MainActor, @Observable)
                     ┌─────────────┴──────────────┐
                     ▼                            ▼
          StatusItemController             PopoverView (SwiftUI)
          ├ StatusContentView (layers)     ├ PopoverModel (@Observable)
          ├ MenuBarAnimator                ├ Top N rows + icons
          │   └ AnimationTheme (protocol)  ├ Theme picker
          └ StatusImageComposer            ├ Quit row → AppTerminator
                                           └ Toggle → LoginItemManager
```

### 4.1 Modules

| Module | Kind | Contents | May import |
|---|---|---|---|
| `HungryCore` | library | Pure logic. Unit tests target it. | `Foundation` only |
| `HungrySystem` | library | Samplers that call Mach, `libproc`, `/bin/ps`, and the SMC. | `Darwin`, `Foundation`, `IOKit`, `HungryCore` |
| `MacHungry` | executable | AppKit and SwiftUI. | all |

Reason for `HungrySystem`: a test target that imports an **executable** target breaks the Swift Testing macros with the Command Line Tools. A library target can be tested.

### 4.2 Units

| Unit | Module | Job |
|---|---|---|
| `CoreTicks`, `CPUCalculator` | HungryCore | 2 tick snapshots → CPU %. Handles counter wrap-around. |
| `MemoryPages`, `MemoryUsage`, `MemoryCalculator` | HungryCore | Page counts + page size + total → RAM %. |
| `ProcessSample`, `PSParser` | HungryCore | `ps` output → `(pid, parentPid, cpuSeconds, path)`. |
| `ProcessUsage`, `ProcessCPUTracker` | HungryCore | CPU % per PID from 2 samples. Removes PIDs that stopped. |
| `ProcessTree` | HungryCore | All samples of 1 sample run → the owner path of each PID (section 3). |
| `AppIdentity`, `AppUsage`, `AppGrouper` | HungryCore | Owner path → app. Sums each app. Returns the top N. |
| `RankStabilizer` | HungryCore | Changes the row order only when the difference is more than 1%. |
| `SpeedCurve` | HungryCore | Smoothing, CPU → frame interval, timer replace rule. |
| `UsageFormatter` | HungryCore | `72%`, `--`, `68°`, tooltip text, `9.8 / 16 GB`, `CPU 68°C  GPU 64°C`. |
| `TemperatureReading`, `ChipFamily`, `SensorKeys`, `TemperatureSensors` | HungryCore | Chip detection, SMC key tables, hottest value, smoothing. |
| `AnimationTheme`, `ThemeRegistry`, `CatTheme`, `PushUpTheme`, `PullUpTheme` | HungryCore | Theme values. |
| `SystemSampler` | HungrySystem | `host_processor_info`, `host_statistics64`, `hw.memsize`. |
| `PSRunner` | HungrySystem | Runs `/bin/ps` with a 0.8 s watchdog. |
| `LibprocReader` | HungrySystem | Fallback: own processes only. |
| `ProcessSampler`, `ProcessSnapshot` | HungrySystem | `ps` or fallback → tracker + process tree → top N. |
| `SMCReader` | HungrySystem | Opens `AppleSMC` and reads `flt ` keys. |
| `TemperatureSampler` | HungrySystem | Detects the chip, keeps the keys that exist, reads the hottest CPU and GPU value. |
| `SamplingEngine`, `SystemSnapshot` | HungrySystem | 1 `actor` that owns all samplers. |
| `StatsStore` | MacHungry | Latest values for the UI. |
| `StatsMonitor` | MacHungry | Runs the 1 s loops, writes `StatsStore`. |
| `TemplateImageRenderer` | MacHungry | Draws a 2× bitmap image. |
| `StatusSegment`, `StatusLayoutSettings`, `StatusLabels`, `TopAppsLimit` | HungryCore | Menu bar parts, their order and visibility, label text, and the top-N value. |
| `StatusImageComposer` | MacHungry | The stats image (labels + numbers), with an empty slot for the animation. |
| `StatusLayout` | MacHungry | All menu bar drawing constants. |
| `SegmentMenu`, `LayoutPreference`, `TopAppsPreference` | MacHungry | Right-click menu and the saved settings. |
| `StatusContentView` | MacHungry | Layer-backed view that shows the frame and the stats. |
| `FrameLoader` | MacHungry | Loads the theme PNG files. |
| `MenuBarAnimator` | MacHungry | Changes the frame on a timer. |
| `ThemePreference` | MacHungry | Saves the theme id in `UserDefaults`. |
| `StatusItemController` | MacHungry | Owns the status item and the popover. |
| `PopoverModel`, `PopoverView`, `UsageGaugeRow`, `TemperatureRow`, `AppRowView` | MacHungry | The popover. |
| `IconCache`, `AppTerminator`, `LoginItemManager` | MacHungry | Icons, quit, launch at login. |
| `AppDelegate`, `MacHungryApp` | MacHungry | Start-up. |

### 4.3 Theme interface

```swift
public protocol AnimationTheme: Sendable {
    var id: String { get }
    var displayName: String { get }
    var frameCount: Int { get }
    var maxInterval: TimeInterval { get }
    var minInterval: TimeInterval { get }
}
```

An extension gives `frameNames` (`frame-1` … `frame-N`) and `frameInterval(forCPU:)`.

To add a theme:
1. Add 1 file that conforms to `AnimationTheme`, and add its PNG files in `Resources/Themes/<id>/`.
2. Add 1 line in `ThemeRegistry`.

`MenuBarAnimator` does not change.

## 5. Data flow and calculations

### 5.1 Total CPU % (every 1 s, always)

1. Read the ticks of each core with `host_processor_info(PROCESSOR_CPU_LOAD_INFO)`.
2. For each core: `busy = Δuser + Δsystem + Δnice`, `total = busy + Δidle`. Use wrapping subtraction (`&-`) on the 32-bit counters.
3. `CPU % = Σ busy ÷ Σ total × 100`. If `Σ total = 0`, or the core count changed, the result is 0.
4. Free the buffer with `vm_deallocate` after each read.

### 5.2 RAM % (every 1 s, always)

1. Read `vm_statistics64` with `host_statistics64(HOST_VM_INFO64)`.
2. `usedPages = max(internal − purgeable, 0) + wire + compressor`.
3. `RAM % = min(usedPages × getpagesize(), hw.memsize) ÷ hw.memsize × 100`.

### 5.3 Top N apps (every 1 s, popover open only)

1. Run `/bin/ps -axo pid=,ppid=,time=,comm=`. `ps` is setuid root, so it reads all processes. A normal app with `libproc` cannot read root processes (test on 2026-10-02: 247 of 762 processes denied with `EPERM`). `comm` must be the last column.
2. `PSParser` reads the parent PID and converts the `time` column to seconds. It accepts `m:ss.cc`, `mmmm:ss.cc` (minutes can be more than 59), `hh:mm:ss.cc`, and `dd-hh:mm:ss.cc`. The path is the rest of the line, so it can contain spaces. The fallback `LibprocReader` reads the parent PID from `proc_pidinfo(PROC_PIDTBSDINFO)` (`pbi_ppid`).
3. `ProcessCPUTracker`:
   - Known PID: `CPU % = Δ cpuSeconds ÷ Δ wall seconds × 100`. The wall clock is `ProcessInfo.systemUptime`.
   - New PID: store the value. It shows from the next sample.
   - `cpuSeconds` goes down (PID reuse): show 0 for this sample.
   - Remove PIDs that are not in the current output.
4. `ProcessTree`: make it from **all** samples of this run, not only from the PIDs that have a CPU %, so that each chain is complete. It gives the owner path of each PID (section 3).
5. `AppGrouper`: for each CPU %, take the owner path. The **outermost** `.app` component of an absolute owner path gives the app name and the bundle path. Otherwise the name is the last path component. Sum, sort (ties by name), keep N (10 or 20).
6. `RankStabilizer` keeps the previous order unless a row beats the row above it by more than 1%.
7. On popover open: reset the tracker, take the 1st sample at once, the 2nd sample after 0.5 s, then 1 sample each 1 s.
8. Measured cost of 1 `ps` run: about 40 ms.
9. Known limit: a process that starts and stops between 2 samples (for example a short `git` command) is not counted.

### 5.4 Animation speed

1. Smoothing: `smoothCPU = 0.7 × smoothCPU + 0.3 × newCPU`, once each 1 s. Invalid values (NaN, infinite) count as 0. Values clamp to 0–100.
2. `interval = max(maxInterval − (maxInterval − minInterval) × smoothCPU ÷ 100, 0.03 s)`.

| Theme | Frames | maxInterval (0%) | minInterval (100%) |
|---|---|---|---|
| Cat | 5 | 0.20 s | 0.03 s |
| Push-ups | 6 | 0.25 s | 0.04 s |
| Pull-ups | 6 | 0.25 s | 0.04 s |

3. 1 repetition (push-up or pull-up) uses all frames of the theme.
4. The animator replaces its timer only when the interval changes by more than 5 ms. Timer tolerance: 10% of the interval.

### 5.5 Thread model

- `SamplingEngine` is 1 background `actor` that owns the system, process, and temperature samplers.
- `StatsStore`, `StatsMonitor`, and all UI types are `@MainActor`.

### 5.6 Temperature (every 2 s, while the temperature part shows)

1. Source: the SMC (System Management Controller) through IOKit (`AppleSMC`, `IOConnectCallStructMethod`, selector 2). No admin password. Read key info (command 9), then the value (command 5). Use only keys of type `flt ` with 4 bytes (little-endian `Float32`).
2. The request struct must be exactly **80 bytes** like the C `SMCKeyData_t`. `SMCKeyInfo` needs 3 padding bytes after `attributes`, because Swift places the next field after the nested struct's size (9), not its padded size (12). Without the padding, every read fails.
3. At start: read `machdep.cpu.brand_string`, detect `ChipFamily` (`Apple M<n>` → m1…m4; anything else → none), take the key table, and keep only the keys that exist as `flt ` on this Mac.

| Family | CPU keys | GPU keys | Status |
|---|---|---|---|
| M1 (incl. Pro, Max) | Tp01 Tp05 Tp09 Tp0D Tp0H Tp0L Tp0P Tp0T Tp0X Tp0b | Tg05 Tg0D Tg0L Tg0T | verified on M1 Pro (Tg0L, Tg0T do not exist there) |
| M2 | Tp01 Tp05 Tp09 Tp0D Tp0X Tp0b Tp0f Tp0j Tp1h Tp1l Tp1p Tp1t | Tg0f Tg0j | from the Stats app, not verified |
| M3 | Te05 Te0L Te0P Te0S Tf04 Tf09 Tf0A Tf0B Tf0D Tf0E Tf44 Tf49 Tf4A Tf4B Tf4D Tf4E | Tf14 Tf18 Tf19 Tf1A Tf24 Tf28 Tf29 Tf2A | from the Stats app, not verified |
| M4 | Te05 Te09 Te0H Te0S Tp01 Tp05 Tp09 Tp0D Tp0V Tp0Y Tp0b Tp0e | Tg0G Tg0H Tg0K Tg0L Tg0d Tg0e Tg0j Tg0k Tg1U Tg1k | from the Stats app, not verified |

4. Each read: CPU = hottest valid CPU key, GPU = hottest valid GPU key. Valid: finite, > 0, < 150 °C.
5. Smoothing: `new = 0.7 × old + 0.3 × reading` for each value. The first reading is used as is. A missing reading keeps the old value.
6. The engine reads the temperature on every 2nd system sample (every 2 s). When the temperature part is hidden, it does no read and clears the value. The next read after show happens at once.
7. Measured on the M1 Pro: 1 read ≈ 3.2 ms, total app CPU 0.39% (+0.15%). Under full load the hottest core rose from about 63 to 73 °C within 2 s.
8. Rejected: the HID sensors (`IOHIDEventSystemClient`, `PMU tdie…`) did not change under full load and cost 32–71 ms per read. Discovery of all `Tp`/`Te` keys found 33 keys, some at 85 °C at idle, and cost 8.3 ms.

## 6. User interface

### 6.1 Menu bar item: how it draws (important)

Measured on macOS 27: each change of `NSStatusBarButton.image` costs about 0.3% CPU, because AppKit lays out and redraws the status bar. An animation at 7 fps then costs about 5%, and at 33 fps about 10–25%.

So the item draws this way:
1. 1 status item. `button.image` is a **transparent placeholder** with the content size. The app sets it only when the content size changes.
2. `statusItem.length = content width + 4 pt` (2 pt padding on each side).
3. A layer-backed `StatusContentView` on top of the button shows the content: 1 tint layer, masked by 2 sublayers (frame, stats). The stats image has an empty slot where the animation shows. The frame sublayer moves to that slot. A hidden animation hides the frame sublayer and stops the timer.
4. A frame change only sets the frame sublayer's `contents` to a **cached** `CGImage`. This needs no layout and no color conversion.
5. The stats sublayer gets a new image 1 time each second.
6. The tint is solid white when the appearance best matches `.darkAqua`, else solid black.
7. `StatusContentView.hitTest` returns `nil`, so clicks go to the button.

Measured result: 0.23% CPU normal, 0.31% at full load (fastest animation), 15 MB.

### 6.2 Menu bar item: layout

```
 [frame] C 72%  R 61%  68°          (default order; the user can reorder)
```

Right-click menu:

```
✓ Animation      ▸ ┬ ✓ Show
✓ CPU            ▸ ├ Move Left
✓ RAM            ▸ └ Move Right
✓ Temperature    ▸
──────────────────
Reset Layout
```

| Value | Setting |
|---|---|
| Item height | `NSStatusBar.system.thickness` (22 pt on the test Mac) |
| Text | `monospacedDigitSystemFont`, size `NSFont.menuBarFont(ofSize: 0).pointSize` (13 pt), weight `.semibold` |
| Labels | `C` (CPU), `R` (RAM), no label for the temperature. 1 space between label and value. Constants in `StatusLabels`. |
| Number slot | width of the label text with the value 99 (`C 99%`, `R 99%`, `99°`). The text is left-aligned in the slot. The width changes only at exactly 100% or 100 °C. |
| Temperature part | shows when it is not hidden (F18) and the Mac has temperature sensors. It shows `--` until the first reading. On a Mac without sensors (F17), the part is not drawn and its menu item is not in the right-click menu. |
| Gaps | 2 pt next to the animation, 4 pt between 2 text parts. Constants in `StatusLayout`. |
| Disabled menu items | **Show** on the last visible part, **Move Left** on the first part, **Move Right** on the last part, **Reset Layout** when the layout is the default. |
| Missing value | `--` |

### 6.3 Popover layout

```
┌─────────────────────────────────────┐
│ CPU   72%  ▬▬▬▬▬▬▬                   │
│ RAM   61%  ▬▬▬▬▬▬▬  9.8 / 16 GB      │
│ Temp  CPU 68°C  GPU 64°C            │
│─────────────────────────────────────│
│ Top 10 apps · % of total CPU limited│
│ [ic] 84.0% Google Chrome        (×) │
│ [ic]  4.2% logd                     │
│ ... (10 or 20 rows)                 │
│─────────────────────────────────────│
│ Animation [ Cat            ⌄ ]      │
│ Show      [ 10 | 20 ]               │
│ [ ] Launch at login                 │
│                    [Quit MacHungry] │
└─────────────────────────────────────┘
```

| Value | Setting |
|---|---|
| Size | fits the content (`.fixedSize()`), about 257 × 310 pt with 10 rows, about 460 pt high with 20 rows |
| Show control | segmented `Picker`, values 10 and 20 (F19) |
| Constants | all sizes in `PopoverLayout` |
| Font | `.callout`; headings `.callout.weight(.semibold)`; RAM detail `.caption` |
| Control size | `.small` |
| Padding / section spacing | 10 pt / 3 pt |
| App rows | 15 pt high, 0 pt spacing, 4 pt between items |
| Row items | icon 13 pt → CPU % (46 pt, right-aligned) → name (max 150 pt, truncated in the middle) |
| Gauges and Temp row | label 38 pt (so "Temp" stays on 1 line), value 38 pt, bar 70 pt. The Temp row shows only when a reading exists. |

### 6.4 Row behavior

1. The icon comes from `NSWorkspace.shared.icon(forFile:)` with the bundle path. A row without a bundle shows the generic executable icon.
2. The `(×)` button shows only if the bundle has a bundle id, `NSRunningApplication` finds 1 or more instances, they belong to the current user, and the app is not MacHungry.
3. A click on `(×)` shows an `NSAlert`: "Quit <name>?" with `Quit` and `Cancel`.
4. `Quit` calls `terminate()` on each instance. It never calls `forceTerminate()`.
5. Before the 2nd sample, the list shows "Measuring…". An empty list shows "No activity".

### 6.5 Popover open and close

1. Open: create a new `PopoverModel` and `PopoverView`, start the process sampling, activate the app, show the popover.
2. Close: stop the process sampling, clear the tracker and `IconCache`, set `contentViewController = nil`.

## 7. Error handling

| Problem | Behavior |
|---|---|
| `host_processor_info` or `host_statistics64` fails | Show `--` for that value. Try again on the next sample. |
| `ps` fails, exits with an error, or takes more than 0.8 s | Use `LibprocReader` for that sample. Show "limited" in the popover. |
| `libproc` CPU time | `ri_user_time + ri_system_time` are in Mach time units. Convert with `mach_timebase_info`. |
| Malformed `ps` line | Skip the line. |
| PID stops between samples | Remove it from the tracker. |
| PID reuse | Show 0 for this sample. |
| Parent PID is not in the samples (for example in limited mode) | The chain stops there. The highest known process counts as the first process below `launchd`. |
| Parent chain has a loop or is longer than 64 steps | The process owns itself. |
| Quit request fails or the app ignores it | No message. The row stays while the app runs. |
| `SMAppService` register or unregister fails | Show the real status, and show the error text below the toggle. |
| Theme frame images are missing | Use the Cat theme. If Cat is missing too, show the stats only. |
| Saved theme id is unknown | Use the Cat theme. |
| Unknown chip, Intel Mac, or `AppleSMC` cannot open | No temperature: the menu bar group and the Temp row do not show. |
| `SMCParam` is not 80 bytes | `SMCReader.init` returns `nil` (no temperature). |
| 1 SMC key fails or gives an invalid value | Ignore that key for this read. |

## 8. Project structure

```
mac-hungry/
├─ Package.swift                 (swift-tools-version 6.0, macOS 14)
├─ Sources/
│  ├─ HungryCore/                (+ Themes/)
│  ├─ HungrySystem/
│  └─ MacHungry/
├─ Resources/
│  ├─ Info.plist
│  └─ Themes/{cat,pushup,pullup}/frame-N.png, frame-N@2x.png
├─ Tests/
│  ├─ HungryCoreTests/
│  └─ HungrySystemTests/
└─ scripts/
   ├─ draw-frames.swift
   ├─ make-app.sh
   └─ test.sh
```

## 9. Testing

Framework: Swift Testing (`import Testing`), run with `scripts/test.sh`.

### 9.1 Unit tests (HungryCore) — 61 tests

1. `CPUCalculator`: idle, full load, mixed cores, no elapsed ticks, core count change, counter wrap-around.
2. `MemoryCalculator`: normal, purgeable > internal, used > total, total = 0.
3. `PSParser`: 5 time formats, 8 malformed times, a path with spaces, 6 malformed lines, mixed output, parent PID column, missing parent PID.
4. `ProcessCPUTracker`: baseline, normal delta, new PID, PID reuse, PID removal, zero elapsed time, reset.
5. `AppGrouper`: plain app, nested helper, daemon, bare name, `.app.backup` folder, sum + sort + limit, ties, negative limit, child process adds into its owner.
6. `ProcessTree`: the 7 chains in section 3, parent not in the samples, a parent loop, a chain longer than 64 steps, nested shells (`zsh > bash > claude`).
7. `RankStabilizer`: first list, small difference, large difference, newcomer, dropped app.
8. `SpeedCurve`: interval at 0/50/100/out-of-range/NaN, floor, smoothing, invalid input, timer replace rule.
9. `ThemeRegistry`: order, lookup, unknown id, frame and interval rules, unique ids.
10. `UsageFormatter`: percent, `--`, tooltip, memory detail.
11. Temperature: chip detection (5 families, 5 unknown brands), key table rules, verified M1 keys, hottest filter, smoothing (first, normal, missing), `68°`, popover detail, tooltip with temperature.

### 9.2 Integration tests (HungrySystem) — 7 tests, tag `integration`

1. `SystemSampler` values are in range.
2. `PSRunner` reads root processes (PID 1).
3. `LibprocReader` reads the test's own process and its parent PID (`getppid()`).
4. `ProcessSampler` is ready on the 2nd sample and gives 1–10 apps.
5. `SMCParam` is 80 bytes.
6. On a known chip, `TemperatureSampler` is available and the CPU value is 15–120 °C.
7. An Intel brand string gives no temperature.

### 9.3 Manual checks

1. Run the app for 60 s with `top`, before the first popover open. Pass: RAM < 30 MB, CPU < 1%.
2. Run 12 `yes > /dev/null` processes. Check that the animation runs faster, `yes` shows in the top N, and CPU stays < 1%. Stop all `yes` processes.
3. Keep the popover open for 60 s. Pass: CPU < 5%, RAM < 35 MB. Then open and close the popover 10 times. Pass: RAM < 35 MB and no growth for each cycle.
4. Check the menu bar item in light mode and dark mode.
5. Click `(×)`, check the dialog, and select `Cancel`.
6. Turn "Launch at login" on, log out, log in, and check that the app starts.
7. Compare the temperature with another app for 30 s. Expect a difference if that app shows the hottest sensor of the whole Mac (see section 3).
8. Run `claude` in a terminal while it uses MCP servers. Check that the `claude` row includes its `node` child processes, and that no separate `node` row shows for them.

## 10. Build and distribution

1. `scripts/make-app.sh` builds release binaries for `arm64` and `x86_64` (`--triple … --scratch-path .build/<arch>`), joins them with `lipo`, builds `build/MacHungry.app`, signs it, and makes `build/MacHungry.dmg`.
2. Default signing: ad-hoc (`codesign -s -`). Friends must right-click the app and select **Open** the first time.
3. With `--identity "<Developer ID>"`, the script signs with the hardened runtime, sends the DMG to `xcrun notarytool` (keychain profile `machungry-notary`, or `--profile`), and staples it.
4. Bundle id: `com.machungry.app`. Version `0.1.0`, build `1`.

## 11. Animation art

1. Do not copy RunCat art or any other art that has a copyright.
2. `scripts/draw-frames.swift` draws the frames with Core Graphics and writes @1x and @2x PNG files. The PNG files go into git.
3. Sizes: Cat 31 × 20 pt (5 frames), Push-ups 35 × 20 pt (6 frames), Pull-ups 20 × 20 pt (6 frames). Black on transparent.
4. A later art change replaces only the PNG files, or changes the script. The app code does not change.

## 12. Toolchain rules (found in the prototype)

1. **Do not use SwiftUI `@State`, `@Entry`, or `@Previewable`.** In this SDK they are macros, and their plugin ships only with full Xcode. Keep view state in an `@Observable` model and use `Binding(get:set:)`. `@Observable` works.
2. **Bitmap drawing order:** set `rep.size` **before** `NSGraphicsContext(bitmapImageRep:)`. The other order draws the content at half size.
3. **Do not name a method `setFrameSize(_:)`** on an `NSView` subclass. It overrides `NSView.setFrameSize(_:)`.
4. Do not change `button.image` for each animation frame (section 6.1).
5. **Run tests with `scripts/test.sh`, not plain `swift test`.** The default build system (swiftbuild) omits the Swift Testing plugin path in about 50% of clean builds (`plugin for module 'TestingMacros' not found`). The script passes `-plugin-path <toolchain>/lib/swift/host/plugins/testing`. It passed 4 of 4 clean builds. The native build system cannot find the `Testing` module at all.

## 13. Prototype record (2026-10-03)

| Decision | Evidence |
|---|---|
| Layer drawing, not `button.image` per frame | `button.image` at 2/5/10/30 fps: 0.84/1.75/3.38/9.38% CPU. Layers at up to 33 fps: 0.31%. |
| Sizes in 6.2 | Selected by the user from side-by-side variants in the real menu bar. |
| Popover layout in 6.3 | Selected by the user from snapshots and the running app. |
| `HungrySystem` module | Test target that imports the executable fails with the Command Line Tools. |
| No `@State` | Build error: `plugin for module 'SwiftUIMacros' not found`. |
| Universal binary | `lipo -info`: `x86_64 arm64`. App 1.1 MB, DMG 576 KB. |
| Temperature from SMC core keys | Load test 63 → 73 °C in 2 s; HID sensors flat at 48 °C. Hot app reads all sensors (its `ThermalLog.swift`), so it shows 7–9 °C more. User chose CPU cores. |
