## 2024-05-28 - Zero-allocation patterns for high-frequency networking in Kotlin
**Learning:** Found a performance bottleneck where per-event allocation of `ByteBuffer` for touch inputs and ping operations, as well as `ByteArray` for reading ping responses, caused noticeable GC churn.
**Action:** Reused a pre-allocated `ByteBuffer` constrained to a single-threaded dispatcher (`touchScope`) for sending, and utilized primitive operations (`java.lang.Long.reverseBytes`) to avoid allocations entirely on the receive path.
