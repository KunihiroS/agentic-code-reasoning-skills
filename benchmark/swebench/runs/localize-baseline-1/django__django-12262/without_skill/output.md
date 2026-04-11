Perfect! I've identified the root cause of the bug. Let me create a summary of my findings:

## Analysis Summary

### Bug Root Cause
The issue is in the `parse_bits` function in `django/template/library.py`, specifically at line 264. 

**The Problem:**
1. When a custom template tag has a keyword-only argument WITH a default value (e.g., `def tag(*, kwarg=42)`), the `unhandled_kwargs` list is initialized to only contain keyword-only arguments WITHOUT defaults
2. Line 264 checks: `if param not in params and param not in unhandled_kwargs and varkw is None` to detect unexpected keyword arguments
3. When a keyword-only argument with a default is provided in a template, it's not in `unhandled_kwargs` (since it has a default), so this check incorrectly raises an error

**Why This Matters:**
- `unhandled_kwargs` is initialized as: `[kwarg for kwarg in kwonly if not kwonly_defaults or kwarg not in kwonly_defaults]`
- This list only contains REQUIRED keyword-only arguments (those without defaults)
- Optional keyword-only arguments (with defaults) are excluded from this list
- The check at line 264 fails to recognize optional keyword-only arguments as valid parameters

### The Fix
Change line 264 from checking `param not in unhandled_kwargs` to checking `param not in kwonly`:

```python
# FROM:
if param not in params and param not in unhandled_kwargs and varkw is None:

# TO:
if param not in params and param not in kwonly and varkw is None:
```

This way, the check properly accepts:
- Regular positional parameters (in `params`)
- ALL keyword-only arguments, both required and optional (in `kwonly`)
- Or any keyword argument if `**kwargs` is present (`varkw is not None`)

### Impact
Since both `simple_tag` and `inclusion_tag` decorators use the same `parse_bits` function, this single fix resolves the bug for both decorator types.

---

LOCALIZATION:
FILE: django/template/library.py
FUNCTION: parse_bits
