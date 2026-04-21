The root cause is that calendar import work is **not tracked as one continuous, operation-scoped progress flow**.

What the code does instead:

1. **Most of the import runs under generic loading dialogs with no progress stream**
   - In `handleCalendarImport()`, parsing the file and loading existing events are both wrapped in `showProgressDialog("loading_msg", ...)` with **no `progressStream` argument**:
     - `src/common/calendar/gui/CalendarImporterDialog.ts:47-50`
   - In `showProgressDialog()`, if no stream is passed, the UI shows only a generic spinner icon, not percentage progress:
     - `src/common/gui/dialogs/ProgressDialog.ts:16-19, 52-53`

2. **Only the final “save” phase is attached to `OperationProgressTracker`**
   - `importEvents()` starts a new operation and passes `operation.progress` to the dialog:
     - `src/common/calendar/gui/CalendarImporterDialog.ts:98-114`
   - That means only the persistence step is actually tracked per operation.

3. **Even that save phase updates progress only in coarse hard-coded jumps**
   - `saveImportedCalendarEvents()` forwards updates to `OperationProgressTracker.onProgress()`:
     - `src/common/api/worker/facades/lazy/CalendarFacade.ts:121-123`
   - But `saveCalendarEvents()` reports only a few phase markers: `10`, `33`, then per calendar list, then `100`:
     - `src/common/api/worker/facades/lazy/CalendarFacade.ts:224-255`
   - So progress is not continuous; it advances in large steps rather than reflecting actual import work.

4. **One calendar-import path bypasses operation tracking entirely**
   - In `CalendarModel.processExternalCalendarOperations()`, imported events are saved with a literal `0` operation id:
     - `src/calendar-app/calendar/model/CalendarModel.ts:703-704`
   - `OperationProgressTracker` only updates streams for IDs that were registered via `startNewOperation()`:
     - `src/common/api/main/OperationProgressTracker.ts:32-41`
   - Passing `0` here means there is no registered operation stream to update, so progress is effectively invisible for that path.

### Net effect
The codebase currently treats calendar import as:
- generic spinner UI for parsing/loading,
- a separately tracked save step only,
- and in at least one path, **no tracked operation at all**.

That is why users would see **non-specific indicators**, no clear distinction between concurrent operations, and only **coarse or absent progress** during large calendar imports.
