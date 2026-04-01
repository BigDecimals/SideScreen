## 2024-05-24 - Expensive MediaCodecList Initialization
**Learning:** Iterating `MediaCodecList` and calling `getCapabilitiesForType` is an expensive hardware operation that blocks execution and should not be performed repeatedly.
**Action:** Cache the results of codec discovery globally during the application lifecycle, as the system's available decoders do not change while the app is running.
