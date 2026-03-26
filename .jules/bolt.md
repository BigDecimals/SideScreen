## 2024-03-26 - [Zero-cost abstractions for C callbacks in Swift]
**Learning:** In high-frequency CoreMedia/VideoToolbox paths, Swift's `UnsafeMutableRawPointer.allocate` creates unnecessary GC/heap pressure (1 malloc per frame).
**Action:** Use `UnsafeMutableRawPointer(bitPattern:)` to pass integer values like timestamps directly through the pointer's memory address space (zero-cost allocation) instead of heap allocations.
