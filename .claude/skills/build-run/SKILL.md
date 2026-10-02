---
name: build-run
description: Build, bundle, and launch MacHungry locally, then show its logs. Use when the user says "run the app", "build and launch", or wants to see a change in the menu bar.
---

# Build and run MacHungry

1. Stop a running copy: `pkill -x MacHungry` (an error is OK if no copy runs).
2. Run the tests: `swift test`. If a test fails, stop and report the failure.
3. Build the bundle: `scripts/make-app.sh`. The result is `build/MacHungry.app`.
4. Launch it: `open build/MacHungry.app`.
5. Check that it runs: `pgrep -x MacHungry`. If there is no PID, read the crash log in `~/Library/Logs/DiagnosticReports/` (newest `MacHungry-*.ips`) and report it.
6. Show live logs if the user asks: `log stream --predicate 'process == "MacHungry"' --level info`.

Tell the user to look at the menu bar. Do not say that the change works until the user confirms it, or until you verify it in a different way.
