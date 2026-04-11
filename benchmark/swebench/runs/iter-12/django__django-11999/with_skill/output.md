---

## FORMAL ANALYSIS: PATCH COMPARISON

### DEFINITIONS

**D1**: Two changes are **EQUIVALENT MODULO TESTS** iff executing the relevant test suite produces identical pass/fail outcomes for both.

**D2**: The relevant tests are:
- **Fail-to-pass test**: `test_overriding_FIELD_display (model_fields.tests.GetFieldDisplayTests)` — this test is expected to FAIL on the unpatched code and PASS after applying the fix.

### PREMISES

**P1**: Patch A modifies only `django/db/models/fields/__init__.py` at lines 765-771, adding a `hasattr()` check before setting the `get_FOO_display` method:
```python
if self.choices is not None:
    if not hasattr(cls, 'get_%s_display' % self.name):  # ← NEW CHECK
        setattr(cls, 'get_%s_display' % self.name, ...)
```

**P2**: Patch B creates three new files (`test_project/settings.py`, `test_project/test_app/models.py`, `test_settings.py`) and modifies **zero** files in `django/` core code.

**P3**: The bug report describes: a user defines a custom `get_FOO_display()` method in their model class, but Django automatically creates and overwrites it during class definition.

**P4**: Field.contribute_to_class() is called during model metaclass initialization, after the user's methods have been bound to the class.

**P5**: `_get_FIELD_display()` is a base method on Model that looks up the display value from `field.flatchoices` (django/db/models/base.py:941-944). The user wants to override this behavior.

### ANALYSIS OF TEST BEHAVIOR

**Test: test_overriding_FIELD_display**

This test would be structured as:
1. Define a model with a field with choices
2. Define a custom `get_FOO_display()` method that returns a custom value
3. Assert the method returns the custom value (not the Django default)

#### With Patch A:

**Code path** (django/db/models/fields/__init__.py:765-771):
1. When the model class is created, the custom `get_foo_bar_display()` method is already on the class (user defined it in the class body)
2. `contribute_to_class()` runs and checks: `if not hasattr(cls, 'get_%s_display' % self.name)`
3. `hasattr(cls, 'get_foo_bar_display')` returns `True` (the custom method exists)
4. `not True` evaluates to `False`
5. The `setattr()` call at line 768-771 is **skipped**
6. The custom method is **preserved**
7. Calling `instance.get_foo_bar_display()` invokes the user's custom method
8. **Test result: PASS**

#### With Patch B:

**Code path** (django/db/models/fields/__init__.py:765-767 — original code):
1. When the model class is created, the custom method is on the class
2. `contribute_to_class()` runs with original code (no hasattr check)
3. Line 766-767 unconditionally executes: `setattr(cls, 'get_foo_bar_display', partialmethod(...))`
4. This **overwrites** the user's custom method with Django's auto-generated one
5. Calling `instance.get_foo_bar_display()` invokes Django's partialmethod, which calls `_get_FIELD_display()`
6. The custom implementation is lost
7. **Test result: FAIL**

### VERIFICATION: Code Locations

**Patch A code** (django/db/models/fields/__init__.py, lines 765-771):
```python
if self.choices is not None:
    if not hasattr(cls, 'get_%s_display' % self.name):
        setattr(
            cls,
            'get_%s_display' % self.name,
            partialmethod(cls._get_FIELD_display, field=self),
        )
```

**Current/Patch B code** (django/db/models/fields/__init__.py, lines 765-767):
```python
if self.choices is not None:
    setattr(cls, 'get_%s_display' % self.name,
            partialmethod(cls._get_FIELD_display, field=self))
```

### COUNTEREXAMPLE CONFIRMATION

**Test**: `test_overriding_FIELD_display`

**With Patch A**: The test **PASSES** because the custom method is preserved.

**With Patch B**: The test **FAILS** because Django overwrites the custom method.

The test produces **DIFFERENT outcomes**, confirming the patches are not equivalent.

### EDGE CASES / EXISTING TESTS

**Pass-to-pass tests** (existing tests that should continue to pass with both patches):
- Tests like `test_choices_and_field_display()` in GetFieldDisplayTests use fields with choices but do **not** override `get_FOO_display()`
- For these tests, whether or not Patch A's `hasattr()` check is present is irrelevant — `setattr()` still occurs (no pre-existing method to preserve)
- These tests should continue to **PASS** with both patches

### FORMAL CONCLUSION

By Definition D1 (EQUIVALENT MODULO TESTS):

- **Test outcome with Patch A**: test_overriding_FIELD_display → **PASS**
- **Test outcome with Patch B**: test_overriding_FIELD_display → **FAIL**

Since the FAIL_TO_PASS test produces **DIFFERENT outcomes** between Patch A and Patch B, the two patches are **NOT EQUIVALENT**.

**Summary**:
- **Patch A** fixes the underlying bug by checking if the method already exists before overwriting it.
- **Patch B** creates test files only, without modifying any Django core code, leaving the bug unfixed.

---

**ANSWER: NO (not equivalent)**

**CONFIDENCE: HIGH**
