Excellent! I now have a complete understanding of the issue. Let me create a summary:

## Summary of Analysis

### Bug Description
The issue is that when a form field is not included in the submitted form data but has a default value on the model, Django's form handling prevents `cleaned_data` from overwriting that default value. This breaks the paradigm of allowing users to modify data in `cleaned_data` (e.g., through custom `clean()` methods).

### Root Cause Location

The issue is in the **`construct_instance` function** in `django/forms/models.py` at **lines 51-53**.

**Current problematic code:**
```python
if (f.has_default() and
        form[f.name].field.widget.value_omitted_from_data(form.data, form.files, form.add_prefix(f.name))):
    continue
```

### How the Bug Works

1. When a field is omitted from form data AND has a default value on the model
2. The code skips setting the field's value in the instance (continues the loop)
3. This means the value from `cleaned_data` is never applied to the instance
4. Even if a user sets a non-empty value in `cleaned_data` (e.g., through `clean()` method), it's ignored

### Call Chain

- `BaseModelForm._post_clean()` (line 395 in models.py)
  - ↓ calls
  - `construct_instance()` (line 31 in models.py)
    - ↓ at the problematic condition (lines 51-53)
    - **BUG: Prevents cleaned_data from overwriting model defaults**

### The Fix

The condition needs an additional check to verify if the value in `cleaned_data` is actually empty before skipping it. The fix should be to add:
```python
and cleaned_data.get(f.name) in form[f.name].field.empty_values
```

This way, if `cleaned_data` contains a non-empty value, it will NOT be skipped and will properly overwrite the model default.

LOCALIZATION:
FILE: django/forms/models.py
FUNCTION: construct_instance
