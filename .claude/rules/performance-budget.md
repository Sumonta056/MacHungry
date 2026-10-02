---
paths:
  - "Sources/**/*.swift"
---

# Performance budget

A monitor app must not load the machine. These limits come from spec N1–N3:

| Condition | RAM | CPU (1 core) |
|---|---|---|
| Popover closed | < 30 MB | < 1% |
| Popover open | < 30 MB | < 5% |

1. Run `/bin/ps` only while the popover is open. Stop the process sampler on close.
2. Reuse sampler buffers. Do not create new large arrays each second.
3. After `host_processor_info`, free the buffer with `vm_deallocate`. A missed free leaks memory each second.
4. Load the animation frames 1 time. Do not load images in the timer callback.
5. Replace the animation timer only when the interval changes by more than 5 ms.
6. Clear `IconCache` and `ProcessCPUTracker` when the popover closes.
7. Do not use `Timer` intervals below 0.03 s.
8. For a change to a sampler, the animator, or the popover, ask the `perf-auditor` agent to measure before you say the task is done.
