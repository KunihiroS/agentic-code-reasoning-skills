Perfect! My analysis is confirmed. Let me now write the comprehensive localization summary:

## Analysis Summary

I've identified the bug in the Django template tag system that prevents keyword-only arguments with default values from being used in custom template tags.

### Root Cause

The bug is in the `parse_bits` function in `/tmp/bench_workspace/worktrees/django__django-12262/django/template/library.py` at **line 264**.

When a keyword-only argument with a default value is supplied to a template tag:
1. `unhandled_kwargs` is initialized (lines 254-257) with only keyword-only arguments that **don't have defaults** (required ones)
2. When parsing template tag bits, the check at line 264 verifies if the supplied keyword argument is valid:
   ```python
   if param not in params and param not in unhandled_kwargs and varkw is None:
   ```
3. For keyword-only arguments **with defaults**, they are NOT in `unhandled_kwargs`, so the condition evaluates to True and incorrectly raises a "received unexpected keyword argument" error

### The Fix

The check at line 264 should validate against the complete list of keyword-only arguments (`kwonly`) instead of just required ones (`unhandled_kwargs`):

**Current (buggy):**
```python
if param not in params and param not in unhandled_kwargs and varkw is None:
```

**Fixed:**
```python
if param not in params and param not in kwonly and varkw is None:
```

This ensures:
1. All keyword-only arguments (both with and without defaults) are accepted
2. Truly unexpected keyword arguments are still rejected
3. The duplicate keyword argument check (line 271) still works correctly
4. Both `simple_tag` and `inclusion_tag` are fixed since they both use `parse_bits`

---

**LOCALIZATION:**
**FILE:** django/template/library.py
**FUNCTION:** parse_bits
