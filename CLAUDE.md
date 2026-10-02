# MacHungry

macOS menu bar app. It shows live CPU % and RAM %, an animation whose speed follows CPU, and a popover with the top 10 apps by CPU.

Spec (source of truth): `docs/superpowers/specs/2026-10-02-mac-hungry-menubar-design.md`. Requirement ids (F1–F14, N1–N8) come from it.

## Toolchain

- Xcode Command Line Tools only. There is no full Xcode, so do not use `xcodebuild` or `.xcodeproj` files.
- Swift 6 language mode, Swift Package Manager, macOS 14 minimum.
- Tests use Swift Testing (`import Testing`), not XCTest.

## Commands

| Task | Command |
|---|---|
| Build (debug) | `swift build` |
| Test | `scripts/test.sh` (never plain `swift test`, see spec section 12) |
| Make `.app` + DMG | `scripts/make-app.sh` |
| Signed + notarized | `scripts/make-app.sh --identity "<Developer ID>"` |

## Module map

- `Sources/HungryCore/` — pure logic. No AppKit, no SwiftUI, no system calls. All unit tests target this module.
- `Sources/HungrySystem/` — samplers that call Mach, `libproc`, `/bin/ps`, and the SMC (IOKit). Integration tests target this module.
- `Sources/MacHungry/` — AppKit + SwiftUI app. Do not add test targets that import it.
- `Resources/Themes/<theme-id>/frame-N.png` — animation frames.

## Hard rules

1. Do not write code comments unless the user asks for them.
2. Plan before code. Get the user's approval for each significant step.
3. Do not run `git commit`, `git push`, or any destructive git command without an explicit instruction from the user.
4. Keep the resource budget: RAM < 30 MB, CPU < 1% with the popover closed, < 5% with it open.
5. Never call `forceTerminate()`. Quit uses `terminate()` only.
6. Follow spec section 12 (toolchain rules): no SwiftUI `@State`, set `rep.size` before creating a bitmap context, never set `button.image` for each animation frame.

## Helpers

- Agents: `macos-developer` (build 1 plan task), `spec-reviewer` (check code against the spec), `perf-auditor` (measure RAM and CPU).
- Skills: `/build-run`, `/add-theme`, `/release`.
