---

## FINAL LOCALIZATION

Based on my analysis using the localize mode, I have identified the root cause:

**PHASE 1: SYMPTOM SEMANTICS**
- The bug manifests when running `python -m custom.module.path` for modules (not packages)
- The autoreloader receives `-m custom.module` instead of `-m custom.module.path`
- This causes incorrect reloading behavior

**PHASE 2: CODE PATH**
- Entry: `run_with_reloader()` → `restart_with_reloader()` → `get_child_arguments()`
- The critical function is `get_child_arguments()` in `django/utils/autoreload.py`

**PHASE 3: DIVERGENCE**
The code at lines 219-220 unconditionally uses `__main__.__spec__.parent`:
```python
if getattr(__main__, '__spec__', None) is not None and __main__.__spec__.parent:
    args += ['-m', __main__.__spec__.parent]
```

This fails to distinguish between:
- A package with `__main__.py` (e.g., `-m foo.bar` where foo/bar/__main__.py exists)
- A standalone module (e.g., `-m foo.bar.baz` where foo/bar/baz.py exists)

For packages: `__spec__.parent` is correct (returns `foo` for `foo.bar.__main__`)
For modules: `__spec__.name` is needed (returns `foo.bar.baz` not `foo.bar`)

**PHASE 4: ROOT CAUSE**
The logic needs to check if `__spec__.name` represents a `__main__` module. If it's a package's `__main__.py`, use `__spec__.parent`. Otherwise, use `__spec__.name`.

---

## LOCALIZATION:

**FILE:** django/utils/autoreload.py
**FUNCTION:** get_child_arguments

**Specific location:** Lines 219-220 (the condition and argument construction)

**Root Cause:** The code uses `__main__.__spec__.parent` unconditionally for all `-m` invocations, but should instead check whether the module is a package's `__main__.py` versus a standalone module file, and use:
- `__spec__.parent` when `__spec__.name` is `__main__` or ends with `.__main__` (package case)
- `__spec__.name` otherwise (standalone module case)
