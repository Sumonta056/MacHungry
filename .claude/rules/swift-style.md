---
paths:
  - "Sources/**/*.swift"
  - "Tests/**/*.swift"
---

# Swift style

1. Use Swift 6 strict concurrency. Fix all concurrency warnings. Do not use `@unchecked Sendable` or `nonisolated(unsafe)` unless there is no other way, and then tell the user why.
2. UI types are `@MainActor`. Samplers run in 1 background `actor`.
3. Use `@Observable` for `StatsStore`. Do not use `ObservableObject` or Combine.
4. Do not write code comments unless the user asks for them. Use clear names in place of comments.
5. Names: types `UpperCamelCase`, members `lowerCamelCase`, 1 main type per file, the file name equals the type name.
6. Keep files small and focused. If a file has more than about 200 lines, propose a split.
7. Prefer `struct` and `enum` over `class`. Use `final class` only for AppKit objects or identity.
8. No force unwrap (`!`) and no `try!` in `Sources/`. Handle the failure as the spec section 7 says.
9. Do not add third-party dependencies without the user's approval.
10. Do not use SwiftUI `@State`, `@Entry`, or `@Previewable`. Their macro plugin needs full Xcode. Keep view state in an `@Observable` model and use `Binding(get:set:)`.
11. With `NSBitmapImageRep`, set `rep.size` before you call `NSGraphicsContext(bitmapImageRep:)`. The other order draws at half size.
12. Do not name methods of `NSView` subclasses like AppKit methods (for example `setFrameSize(_:)`).
