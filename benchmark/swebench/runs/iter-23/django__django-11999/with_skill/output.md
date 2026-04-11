---

## FORMAL ANALYSIS: PATCH EQUIVALENCE

### DEFINITIONS:

**D1:** Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.

**D2:** The relevant tests are:
- (a) **FAIL_TO_PASS**: `test_overriding_FIELD_display` (model_fields.tests.GetFieldDisplayTests) — tests that a custom `get_FOO_display()` override in a model subclass is preserved and called correctly
- (b) **PASS_TO_PASS**: Existing tests in `GetFieldDisplayTests` (test_choices_and_field_display, test_get_FIELD_display_translated, test_iterator_choices, test_empty_iterator_choices) — tests that normal `get_FOO_display()` behavior works when no override exists

### PREMISES:

**P1:** Patch A modifies `django/db/models/fields/__init__.py` lines 765-768 to insert a `if not hasattr(cls, 'get_%s_display' % self.name):` guard before calling `setattr()`, allowing subclass overrides to be preserved.

**P2:** Patch B creates three new files (`test_project/settings.py`, `test_project/test_app/models.py`, `test_settings.py`) but does **NOT** modify any existing Django core code, specifically does not modify `django/db/models/fields/__init__.py`.

**P3:** The bug occurs in `Field.contribute_to_class()` at lines 766-767 of the unpatched code, where `setattr()` unconditionally overwrites any existing `get_FOO_display` method on the model class.

**P4:** The fail-to-pass test expects that when a model subclass explicitly defines a `get_FOO_display()` method, calling that method returns the custom value, not the framework-generated value from `_get_FIELD_display()`.

**P5:** The pass-to-pass tests (Whiz, WhizDelayed, WhizIter, WhizIterEmpty models) do **not** override `get_c_display()`, so both patches treat them identically.

### ANALYSIS OF TEST BEHAVIOR:

#### Test: test_overriding_FIELD_display (FAIL_TO_PASS)

This test (expected to exist but currently failing) would create a model like:
```python
class CustomDisplayModel(models.Model):
    foo_bar = models.CharField(choices=[(1, 'foo'), (2, 'bar')])
    def get_foo_bar_display(self):
        return "custom_override"
```

Then assert: `CustomDisplayModel(foo_bar=1).get_foo_bar_display() == "custom_override"`

**Claim C1.1 — With Patch A:**
- Code path: `Field.contribute_to_class()` at patched lines 766-768
- Check: `if not hasattr(cls, 'get_foo_bar_display')` evaluates to **False** (the method exists in the model class definition)
- Action: `setattr()` is **skipped**
- Result: The model's `get_foo_bar_display` method is preserved in `cls.__dict__`
- Method call: `instance.get_foo_bar_display()` → calls the **custom override** → returns `"custom_override"`
- **Test outcome: PASS** ✓

**Claim C1.2 — With Patch B:**
- Patch B creates no changes to `django/db/models/fields/__init__.py`
- Code path: Unpatched `Field.contribute_to_class()` at original lines 766-767
- Action: `setattr(cls, 'get_foo_bar_display', partialmethod(cls._get_FIELD_display, field=self))` executes **unconditionally**
- Result: The custom `get_foo_bar_display` method in the model class is **overwritten** with the partialmethod
- Method call: `instance.get_foo_bar_display()` → calls the **partialmethod** → calls `_get_FIELD_display()` → returns `"foo"` (the choice display)
- **Test outcome: FAIL** ✗
- Assertion `self.assertEqual(result, "custom_override")` fails because result is `"foo"`

**Comparison: DIFFERENT outcome** — PASS vs FAIL

#### Test: test_choices_and_field_display (PASS_TO_PASS)

Tests: `Whiz(c=1).get_c_display() == 'First'` (no override defined in Whiz model)

**Claim C2.1 — With Patch A:**
- Code path: Patched `Field.contribute_to_class()` at lines 766-768
- Check: `if not hasattr(Whiz, 'get_c_display')` evaluates to **True** (no custom override exists)
- Action: `setattr(Whiz, 'get_c_display', partialmethod(...))` executes
- Result: `get_c_display` is set normally
- Method call: `instance.get_c_display()` → calls the **partialmethod** → returns `'First'`
- **Test outcome: PASS** ✓

**Claim C2.2 — With Patch B:**
- Code path: Unpatched `Field.contribute_to_class()` at lines 766-767
- Action: `setattr(Whiz, 'get_c_display', partialmethod(...))` executes
- Result: `get_c_display` is set normally (identical to Patch A)
- Method call: `instance.get_c_display()` → returns `'First'`
- **Test outcome: PASS** ✓

**Comparison: SAME outcome** — both PASS

#### Test: test_get_FIELD_display_translated (PASS_TO_PASS)

Tests: `Whiz(c=5).get_c_display()` returns a string (no override)

**Claim C3.1 & C3.2:** Both patches set the method identically (no override exists) → both PASS ✓

**Comparison: SAME outcome**

### EDGE CASES RELEVANT TO EXISTING TESTS:

**E1:** Field with choices, no model override (e.g., Whiz.get_c_display)
- Patch A: hasattr() → False, method set normally
- Patch B: method set normally
- Outcome: SAME (both PASS)

**E2:** Field with choices, explicit model override (the bug case)
- Patch A: hasattr() → True, method NOT overwritten, override preserved
- Patch B: method unconditionally overwritten, override lost
- Outcome: DIFFERENT (A passes, B fails)

### COUNTEREXAMPLE (required since claiming NOT EQUIVALENT):

**Test:** `test_overriding_FIELD_display`

**With Patch A:**
- Input: Model with `foo_bar` CharField(choices=...) and custom `get_foo_bar_display()`
- Execution: `if not hasattr(cls, 'get_foo_bar_display')` → False → setattr skipped
- Output: `instance.get_foo_bar_display()` returns custom value
- Result: **PASS**

**With Patch B:**
- Input: Same model
- Execution: Original code: `setattr(cls, 'get_foo_bar_display', partialmethod(...))` unconditionally executes
- Output: `instance.get_foo_bar_display()` returns choice display value (not custom value)
- Result: **FAIL**

**Conclusion:** These two patches produce **DIFFERENT test outcomes** for `test_overriding_FIELD_display`.

### FORMAL CONCLUSION:

By Definition D1 and P1–P2:
- **Patch A test outcomes:** FAIL_TO_PASS test → **PASS**, PASS_TO_PASS tests → **PASS**
- **Patch B test outcomes:** FAIL_TO_PASS test → **FAIL**, PASS_TO_PASS tests → **PASS**

Since the FAIL_TO_PASS test outcome differs between Patch A (PASS) and Patch B (FAIL), the patches are **NOT EQUIVALENT MODULO TESTS**.

**Root cause:** Patch A fixes the underlying bug by guarding the `setattr()` call with a hasattr check, allowing subclass overrides to be preserved. Patch B does not modify the code that causes the bug, so the mechanism remains broken.

**ANSWER: NO (not equivalent)**

**CONFIDENCE: HIGH**

The evidence is concrete:
1. Patch A modifies the exact code path that causes the bug (line 766-767 of __init__.py)
2. Patch B leaves that code path unchanged
3. The fail-to-pass test directly exercises this code path with a custom override
4. Only Patch A's guard prevents the override from being overwritten
