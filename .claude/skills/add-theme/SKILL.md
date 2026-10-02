---
name: add-theme
description: Add a new menu bar animation theme to MacHungry (for example a runner, a cyclist, or a bouncing ball). Use when the user wants a new animation option in the theme picker.
---

# Add an animation theme

Ask the user for these values first. Use the defaults if they do not care:
- Theme id (lowercase, for example `cyclist`) and display name.
- Number of frames (default 6).
- `maxInterval` at 0% CPU (default 0.25 s) and `minInterval` at 100% CPU (default 0.04 s).
- Art source: the user gives PNG files, or you draw frames in `scripts/draw-frames.swift`.

Steps:
1. Add the frames to `Resources/Themes/<id>/frame-1.png` … `frame-N.png`. Each frame is 18 pt high, @1x and @2x, black on transparent.
2. Create `Sources/HungryCore/Themes/<Name>Theme.swift` that conforms to `AnimationTheme`. Copy the shape of `CatTheme.swift`.
3. Add the theme to the list in `ThemeRegistry`.
4. Add a test in `Tests/HungryCoreTests/` that checks: the registry finds the id, the frame count is correct, and `minInterval < maxInterval`.
5. Run `swift test`.
6. Run the `/build-run` skill. Ask the user to select the theme in the popover and to check it at low and high CPU (`yes > /dev/null` in 4 terminals).

Do not change `MenuBarAnimator`. If a theme needs a change to it, stop and tell the user, because the theme interface then needs a new design.
