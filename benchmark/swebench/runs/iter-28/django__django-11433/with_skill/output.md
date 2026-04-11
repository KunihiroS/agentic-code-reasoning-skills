---

## FORMAL ANALYSIS: PATCH EQUIVALENCE

### DEFINITIONS

**D1:** Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.

**D2:** Relevant tests are:
- FAIL_TO_PASS: `test_default_not_populated_on_non_empty_value_in_cleaned_data` — expected to fail on unpatched code, pass on patched code
- PASS_TO_PASS: Tests affected by the changed code path, especially:
  - `test_default_populated_on_optional_field` (line 567)
  - `test_default_not_populated_on_optional_checkbox_input` (line 588)
  - Other default-related tests in model_forms.tests

---

### PREMISES

**P1:** The current code at `django/forms/models.py:51-52` skips setting an instance field if:
- `f.has_default() == True` AND
- `form[f.name].field.widget.value_omitted_from_data(...)` == True

**P2:** Patch A modifies this condition to additionally require:
- `cleaned_data.get(f.name) in form[f.name].field.empty_values` == True
- where `empty_values = (None, '', [], (), {})`

**P3:** Patch B replaces the entire condition with:
- `f.name not in cleaned_data`

**P4:** Code at line 43 already skips fields not in cleaned_data:
```python
if not f.editable or isinstance(f, models.AutoField) or f.name not in cleaned_data:
    continue
```
Therefore, any field reaching line 51 MUST be in cleaned_data.

**P5:** The bug being fixed: when a form field with a model default is omitted from form data but `cleaned_data` is explicitly set (e.g., by form's `clean()` method), the current code incorrectly uses the model default instead of the cleaned_data value.

**P6:** `empty_values` includes None, '', [], (), {}—standard "empty" values. False is NOT in empty_values.

---

### ANALYSIS OF TEST BEHAVIOR

#### Test 1: FAIL_TO_PASS — `test_default_not_populated_on_non_empty_value_in_cleaned_data`

Scenario: Model field has default; field omitted from form data; form's clean() sets cleaned_data to a non-empty value.

**Claim C1.1 (Patch A):**
```
With Patch A:
- f.has_default() = True (model field has default)
- value_omitted_from_data() = True (field not in form.data)
- cleaned_data.get(f.name) = some_value (non-empty, e.g., 'computed_value')
- some_value IN empty_values? NO → overall condition = False
- → DON'T skip → SET instance field to some_value ✓ PASS
```

**Claim C1.2 (Patch B):**
```
With Patch B:
- f.name not in cleaned_data? NO (we set it in clean())
- → condition = False → DON'T skip
- → SET instance field to some_value ✓ PASS
```

**Comparison:** SAME outcome (PASS for both)

---

#### Test 2: PASS_TO_PASS — `test_default_populated_on_optional_field`

Scenario: Optional form field, empty form data {}, field has model default 'di'.

After form.clean(): `cleaned_data['mode'] = ''` (empty string, the field's empty_value)

**Claim C2.1 (Patch A):**
```
Trace:
- Line 43: 'mode' IN cleaned_data? YES → don't skip line 43
- Line 51 (Patch A):
  - f.has_default() = True
  - value_omitted_from_data() = True (not in {})
  - cleaned_data.get('mode') = '' (empty string)
  - '' IN empty_values? YES → condition = True
  - → SKIP (continue)
- Instance field keeps model default 'di'
Expected: m1.mode == 'di' ✓ PASS
```

**Claim C2.2 (Patch B):**
```
Trace:
- Line 43: 'mode' IN cleaned_data? YES → don't skip line 43
- Line 51 (Patch B): if 'mode' not in cleaned_data?
  - By P4, 'mode' IS in cleaned_data → condition = False
  - → DON'T skip
- Line 59: f.save_form_data(instance, cleaned_data['mode'])
  - Sets instance.mode = '' (empty string)
Expected: m1.mode == 'di' ✗ FAIL
```

**Comparison:** DIFFERENT outcome (PASS vs. FAIL)

---

#### Test 3: PASS_TO_PASS — `test_default_not_populated_on_optional_checkbox_input`

Scenario: BooleanField with default=True; CheckboxInput; empty form data.

After form.clean(): `cleaned_data['active'] = False` (unchecked checkbox state, NOT in empty_values)

**Claim C3.1 (Patch A):**
```
Trace:
- Line 43: 'active' IN cleaned_data? YES → don't skip
- Line 51 (Patch A):
  - f.has_default() = True
  - value_omitted_from_data() = True (checkbox not in {})
  - cleaned_data.get('active') = False
  - False IN empty_values? NO → condition = False
  - → DON'T skip
- Line 59: f.save_form_data(instance, cleaned_data['active'])
  - Sets instance.active = False
Expected: m1.active == False ✓ PASS
```

**Claim C3.2 (Patch B):**
```
Trace:
- Line 43: 'active' IN cleaned_data? YES → don't skip
- Line 51 (Patch B): if 'active' not in cleaned_data?
  - 'active' IS in cleaned_data → condition = False
  - → DON'T skip
- Line 59: f.save_form_data(instance, cleaned_data['active'])
  - Sets instance.active = False
Expected: m1.active == False ✓ PASS
```

**Comparison:** SAME outcome (PASS for both)

---

### EDGE CASES RELEVANT TO EXISTING TESTS

**E1: Required field, value omitted from data (validation error)**
- Form validation fails before reaching construct_instance
- Not evaluated by either patch

**E2: Field not in form (excluded or non-editable)**
- Skipped at line 43 (P4)
- Neither patch affects this path

**E3: Field in form data with non-empty value**
- value_omitted_from_data() = False
- Both patches DON'T skip (condition never evaluates to true)
- SAME behavior ✓

---

### COUNTEREXAMPLE (REQUIRED — PATCHES NOT EQUIVALENT)

**Test:** `test_default_populated_on_optional_field`

**Patch A behavior:**
- Form field 'mode' is in cleaned_data with value ''
- has_default=True, value_omitted_from_data=True, empty_check=True
- SKIP → instance.mode = 'di' (default)
- Result: PASS ✓

**Patch B behavior:**
- Form field 'mode' is in cleaned_data
- 'mode' not in cleaned_data = False
- DON'T skip → instance.mode = '' (cleaned_data value)
- Result: FAIL ✗

**Divergence:** By P1 and P4, when a field reaches line 51, it MUST be in cleaned_data. Patch B's condition `f.name not in cleaned_data` will ALWAYS be False, effectively removing all default-skipping logic. This causes `test_default_populated_on_optional_field` to fail because optional fields with empty values will no longer use model defaults.

---

### FORMAL CONCLUSION

By Definition D1 and the analysis above:

**Test outcomes with Patch A:**
- test_default_not_populated_on_non_empty_value_in_cleaned_data: PASS ✓
- test_default_populated_on_optional_field: PASS ✓
- test_default_not_populated_on_optional_checkbox_input: PASS ✓

**Test outcomes with Patch B:**
- test_default_not_populated_on_non_empty_value_in_cleaned_data: PASS ✓
- test_default_populated_on_optional_field: FAIL ✗ (would set field to empty string instead of default)
- test_default_not_populated_on_optional_checkbox_input: PASS ✓

Since test outcomes differ for `test_default_populated_on_optional_field`, the patches produce **DIFFERENT test outcomes**.

**Why this happens:** Patch B's condition `f.name not in cleaned_data` is logically redundant with the check at line 43, because any field reaching line 51 is guaranteed to be in cleaned_data. Therefore, Patch B's condition always evaluates to False, which means it never skips—effectively removing the entire default-preservation logic. Patch A, by contrast, adds an additional constraint (`cleaned_data.get(f.name) in empty_values`) that correctly distinguishes between:
- Empty values (where defaults should be used) 
- Non-empty values set in cleaned_data (where defaults should NOT be used)

---

**ANSWER: NO (not equivalent)**

**CONFIDENCE: HIGH**
