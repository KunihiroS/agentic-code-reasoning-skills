---

## Step 4: Interprocedural Tracing

Now I'll trace through the relevant functions in both patches as I examine them.

| Function/Method | File:Line | Behavior (VERIFIED) |
|-----------------|-----------|---------------------|
| `construct_instance()` | django/forms/models.py:28 | Iterates model fields and populates instance from form.cleaned_data, with special handling for defaults |
| `Widget.value_omitted_from_data()` | django/forms/widgets.py:260 | Returns `name not in data` (True if field not in POST) |
| `CheckboxInput.value_omitted_from_data()` | django/forms/widgets.py:542 | Returns `False` (always, to handle unchecked checkbox case) |
| `CheckboxSelectMultiple.value_omitted_from_data()` | django/forms/widgets.py:776 | Returns `False` (always, to handle unselected checkboxes) |
| `Field.empty_values` | django/forms/fields.py:55 | List of validators.EMPTY_VALUES = (None, '', [], (), {}) |

---

## Step 3: Hypothesis-Driven Exploration

**HYPOTHESIS H1**: Both patches pass the fail-to-pass test because both allow cleaned_data to override defaults.
**EVIDENCE**: P1, P2 — bug requires overriding defaults with cleaned_data  
**CONFIDENCE**: Medium (needs test trace)

**HYPOTHESIS H2**: Patch B breaks existing tests that expect defaults to be used when POST data is empty for regular input fields.
**EVIDENCE**: test_default_populated_on_optional_field expects m1.mode='di' (default) when form bound with {}
**CONFIDENCE**: High

Let me verify H2 by tracing through the test:

**Test: test_default_populated_on_optional_field** (line 566-583)

Form setup:
- Model field: PublicationDefaults.mode with default='di'
- Form field: CharField(max_length=255, required=False)
- Bound with empty data: PubForm({})

**OBSERVATIONS from test trace**:

O1: When form bound with {}, cleaned_data['mode'] will be '' (empty string), because the CharField processes missing POST data as empty string for optional fields (django/forms/fields.py:130)

O2: For a regular CharField widget, value_omitted_from_data({}, files, 'mode') returns True (name not in data) (django/forms/widgets.py:260)

O3: The test expects: m1.mode == 'di' (the default), not ''

**Trace Original Code** (line 50-52):
```python
if (f.has_default() and
        form[f.name].field.widget.value_omitted_from_data(form.data, form.files, form.add_prefix(f.name))):
    continue  # SKIP this field, use default
```
- f.has_default() = True ✓
- value_omitted_from_data({}, {}, 'mode') = True ✓  
- Condition = True → **SKIP** → instance.mode uses default 'di' ✓ **TEST PASSES**

**Trace Patch A** (line 50-54):
```python
if (
    f.has_default() and
    form[f.name].field.widget.value_omitted_from_data(form.data, form.files, form.add_prefix(f.name)) and
    cleaned_data.get(f.name) in form[f.name].field.empty_values
):
    continue  # SKIP this field, use default
```
- f.has_default() = True ✓
- value_omitted_from_data({}, {}, 'mode') = True ✓
- cleaned_data.get('mode') = '' ✓
- '' in empty_values = True ✓
- Condition = True → **SKIP** → instance.
