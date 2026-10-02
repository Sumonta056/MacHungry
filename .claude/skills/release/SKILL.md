---
name: release
description: Make a shareable MacHungry DMG, ad-hoc signed or signed and notarized with a Developer ID. Use when the user wants to share the app with friends or the team.
disable-model-invocation: true
---

# Release MacHungry

1. Check that the working tree is clean: `git status`. If it is not clean, ask the user before you continue.
2. Ask the user for the version number. Set `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
3. Run `scripts/test.sh`. Stop if a test fails.
4. Ask the `perf-auditor` agent to measure. Stop if a budget check fails.
5. Ask the user which signing to use:
   - **Ad-hoc:** `scripts/make-app.sh`. Tell the user that friends must right-click the app and select **Open** the first time.
   - **Developer ID:** `scripts/make-app.sh --identity "<Developer ID Application: …>"`. The script signs with the hardened runtime, sends the app to `xcrun notarytool`, and staples the ticket. Notarization needs a stored keychain profile; if it is missing, tell the user to run `! xcrun notarytool store-credentials`.
6. Check the result:
   - `codesign --verify --deep --strict build/MacHungry.app`
   - For Developer ID: `spctl --assess --type execute -v build/MacHungry.app` must say `accepted`.
7. Report the DMG path and its size.

Do not commit, tag, or push. Ask the user first.
