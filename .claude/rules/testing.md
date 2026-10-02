---
paths:
  - "Tests/**"
---

# Testing

1. Use Swift Testing: `import Testing`, `@Test`, `#expect`, `#require`. Do not use XCTest.
2. Write the failing test first, then the code (TDD).
3. Use fixed input data: tick snapshots, page counts, and `ps` text as literals. Do not read the live system in unit tests.
4. Use `@Test(arguments:)` for tables of cases, for example the `ps` time formats.
5. Name tests by behavior: `pidReuseShowsZeroForThatSample`, not `testTracker2`.
6. The only live-system test is the integration test in spec section 9.2. Mark it with a `.tags(.integration)` tag.
7. Never change a test to make it pass. If a test is wrong, tell the user and explain why.
8. Run `swift test` and read the output before you say that a task is done.
