---
paths:
  - "Sources/HungryCore/**"
---

# HungryCore must stay pure

`HungryCore` holds the logic that the tests check. It must give the same output for the same input every time.

1. Import only `Foundation`. Do not import `AppKit`, `SwiftUI`, `Darwin` Mach APIs, or `ServiceManagement`.
2. Do not call the system: no `host_processor_info`, `host_statistics64`, `sysctl`, `libproc`, `Process`, file reads, or `Date()`.
3. Pass time, tick snapshots, page counts, and `ps` text in as parameters.
4. Every public function in this module has unit tests in `Tests/HungryCoreTests/`.
5. If new logic needs a system call, put the call in `Sources/MacHungry/` and pass the result into `HungryCore`.
