---

## FORMAL ANALYSIS (AGENTIC CODE REASONING - COMPARE MODE)

### DEFINITIONS:
**D1:** Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.

**D2:** The relevant tests are:
- **(a) Fail-to-pass tests**: `test_overriding_FIELD_display (model_fields.tests.GetFieldDisplayTests)` — must PASS after fix
- **(b) Pass-to-pass tests**: All existing GetFieldDisplayTests and model_fields tests that currently PASS must continue to PASS

### PREMISES:

**P1:** Patch A modifies `django/db/models/fields/__init__.py` at lines 765-767 by adding a conditional check:
```python
# BEFORE (current code - BUG):
if self.choices is not None:
    setattr(cls, 'get_%s_display' % self.name,
            partialmethod(cls._get_FIELD_display, field=self))

# AFTER (Patch A):
if self.choices is not None:
    if not hasattr(cls, 'get_%s_display' % self.name):
        setattr(cls, 'get_%s_display' % self.name,
                partialmethod(cls._get_FIELD_display, field=self))
```
The check prevents unconditional overwriting of an existing `get_*_display` method on the model class.

**P2:** Patch B creates three new files:
- `test_project/settings.py` (test Django settings)
- `test_project/test_app/models.py` (example model with custom display method)  
- `test_settings.py` (additional test settings)

Patch B **does not modify** any Django source code files.

**P3:** The bug report describes: User-defined `get_foo_bar_display()` method is overridden by auto-generated method, returning the choice label instead of the custom return value.

**P4:** The fail-to-pass test expects: When a model class defines a custom `get_*_display()` method before the field adds its own, calling the method on an instance should return the custom implementation's result, not the auto-generated one.

**P5:** The current (unpatched) behavior is: `Field.contribute_to_class()` unconditionally executes `setattr(cls, 'get_%s_display' % self.name, ...)`, overriding any pre-existing method with a `partialmethod` bound to `cls._get_FIELD_display`.

### ANALYSIS OF TEST BEHAVIOR:

**Test:** `test_overriding_FIELD_display` (expected structure based on bug report)

The test model would be defined as:
```python
class FooBar(models.Model):
    foo_bar = models.CharField(choices=[(1, 'foo'), (2, 'bar')])
    def get_foo_bar_display(self):
        return "something"  # Custom override
```

The test expectation:
```python
instance = FooBar(foo_bar=1)
self.assertEqual(instance.get_foo_bar_display(), "something")  # Custom, not 'foo'
```

**Claim C1.1 (With Patch A):**
- Model class definition is executed first; `get_foo_bar_display` method is set on `FooBar`
- Field's `contribute_to_class()` is called; reaches line 766 check: `if not hasattr(cls, 'get_foo_bar_display'):`
- `hasattr(FooBar, 'get_foo_bar_display')` returns `True` (user method exists)
- Conditional block is skipped; `setattr` is **not** called
- User-defined method remains intact on the class
- **Test PASSES**: Calling `instance.get_foo_bar_display()` returns `"something"` ✓

**Claim C1.2 (With Patch B):**
- No changes to Django source code; the bug remains unfixed
- Model class definition is executed; `get_foo_bar_display` method is set on `FooBar`
- Field's `contribute_to_class()` is called; reaches line 765 unconditional `if self.choices is not None:` (no hasattr check)
- Line 766-767 **unconditionally** executes `setattr(cls, 'get_foo_bar_display', partialmethod(...))`
- User-defined method is **overwritten** by `partialmethod` bound to `_get_FIELD_display`
- When called on instance, `partialmethod` executes `cls._get_FIELD_display(field=...)`, returning the choice display value ('foo' for value 1)
- **Test FAILS**: `instance.get_foo_bar_display()` returns `'foo'`, not `"something"` ✗

**Comparison:** DIFFERENT test outcomes
- Patch A: test_overriding_FIELD_display **PASSES**
- Patch B: test_overriding_FIELD_display **FAILS**

### INTERPROCEDURAL TRACE TABLE:

| Function/Method | File:Line | Behavior (VERIFIED) |
|---|---|---|
| `Field.contribute_to_class()` | `django/db/models/fields/__init__.py:754-768` | Registers field with model class; calls setattr on choices check (lines 765-767) |
| `Model._get_FIELD_display()` | `django/db/models/base.py:941-943` | Returns display value from field.flatchoices dict or the value itself |
| `partialmethod` (builtin) | Python stdlib | Binds method call; when called on instance, invokes `cls._get_FIELD_display(field=...)` |
| `hasattr()` builtin | Python stdlib | Returns True if class has attribute (user-defined method) before field setup |

### PASS-TO-PASS TESTS (Existing tests must continue to pass):

**Test:** `test_choices_and_field_display` (line 153)

Models: `Whiz`, `WhizDelayed`, `WhizIter` with choices but **no custom override**

- With Patch A: No user-defined `get_c_display` exists; `hasattr` returns False; setattr is called; auto-generated method works normally → **PASSES** ✓
- With Patch B: No changes to Django; auto-generated method works normally → **PASSES** ✓

**Comparison:** SAME outcome for pass-to-pass tests

**Test:** `test_get_FIELD_display_translated` (line 165)

- With Patch A: No override; setattr called; translated value returned correctly → **PASSES** ✓
- With Patch B: No changes; translated value returned → **PASSES** ✓

**Comparison:** SAME outcome

All existing GetFieldDisplayTests work on models without custom `get_*_display` overrides; both patches preserve auto-generation for these cases.

### EDGE CASES RELEVANT TO EXISTING TESTS:

**E1: Multiple fields with choices on same model**

```python
class Model(models.Model):
    field1 = models.CharField(choices=[(1, 'A')])
    field2 = models.CharField(choices=[(2, 'B')])
    def get_field1_display(self):
        return "custom1"
```

- Patch A: Only `get_field1_display` skipped (exists); `get_field2_display` auto-generated → Both work correctly ✓
- Patch B: No change to behavior; `get_field1_display` overwritten by auto-generated → Not fixed ✗

**E2: Field with no choices**

- Patch A: The `if self.choices is not None:` condition prevents both branches; no method added → Correct ✓
- Patch B: Same behavior → Correct ✓

### COUNTEREXAMPLE (REQUIRED IF NOT EQUIVALENT):

**Counterexample Found:**

Test: `test_overriding_FIELD_display`

```python
class FooBar(models.Model):
    foo_bar = models.CharField(choices=[(1, 'foo'), (2, 'bar')])
    def get_foo_bar_display(self):
        return "something"

instance = FooBar(foo_bar=1)
# With Patch A: instance.get_foo_bar_display() == "something" ✓ TEST PASSES
# With Patch B: instance.get_foo_bar_display() == "foo" ✗ TEST FAILS
```

- Patch A produces: **PASS** on fail-to-pass test
- Patch B produces: **FAIL** on fail-to-pass test

**Therefore: Changes produce DIFFERENT test outcomes.**

### NO COUNTEREXAMPLE EXISTS CHECK: [Not applicable — counterexample found]

### FORMAL CONCLUSION:

**By Definition D1 and the test outcomes established above:**

**Fail-to-pass test outcome:**
- Patch A: `test_overriding_FIELD_display` → **PASS**
- Patch B: `test_overriding_FIELD_display` → **FAIL**

**Pass-to-pass test outcomes:**
- Patch A: All existing GetFieldDisplayTests → **PASS** (no override cases work)
- Patch B: All existing GetFieldDisplayTests → **PASS** (no override cases work)

**Since the fail-to-pass test outcome DIFFERS between patches:**
- Patch A fixes the reported bug by respecting pre-existing `get_*_display` methods
- Patch B does NOT modify Django source; the bug remains unfixed

**These changes are NOT EQUIVALENT modulo the test suite.** Patch A causes the fail-to-pass test to transition from FAIL to PASS. Patch B leaves the test in FAIL state.

**ANSWER: NO (not equivalent)**

**CONFIDENCE: HIGH**

Justification: The distinction is deterministic and verified by code inspection. Patch A adds a `hasattr` check before `setattr`; Patch B adds no changes to Django source. The test outcome follows directly from this structural difference.

---
