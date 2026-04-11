## CERTIFICATE: COMPARING PATCH A VS PATCH B

### DEFINITIONS:

**D1**: Two patches are **EQUIVALENT MODULO TESTS** iff applying either patch would produce identical pass/fail outcomes for the test suite, specifically for the FAIL_TO_PASS test `test_subquery_filter_by_lazy (expressions.tests.BasicExpressionsTests)`.

**D2**: The test scope includes:
- The FAIL_TO_PASS test (must transition from FAIL to PASS)
- All existing tests that already pass (must remain PASS)

### PREMISES:

**P1**: The bug manifests as `TypeError: int() argument must be a string, a bytes-like object or a number, not 'SimpleLazyObject'` at `django/db/models/fields/__init__.py:972` in `IntegerField.get_prep_value()`

**P2**: The error occurs because `SimpleLazyObject` is being passed to `int(value)` without being unwrapped first. `SimpleLazyObject` is a lazy wrapper that defers evaluation until accessed.

**P3**: `Patch A` modifies `Query.output_field` property (django/db/models/sql/query.py:233-239) to return `getattr(select, 'target', None) or select.field` instead of `select.field`

**P4**: `Patch B` modifies:
- `IntegerField.get_prep_value()` to explicitly check `isinstance(value, SimpleLazyObject)` and unwrap it with `value._wrapped`
- `IntegerField` class signature and validators property
- Creates test infrastructure files (test_app, test_settings.py, db.sqlite3)

**P5**: The test case uses `SimpleLazyObject(lambda: User.objects.create_user("testuser"))` as a filter value on an annotation backed by a nested subquery.

### CONTRACT SURVEY:

**Symbol 1: Query.output_field** (query.py:233-239)
- **Contract**: Returns the output field (type: Field) of a single-select query or annotation
- **Patch A diff scope**: Changes which field object is returned when select[0] has a target attribute
- **Patch B diff scope**: None (no change to this function)

**Symbol 2: IntegerField.get_prep_value()** (fields/__init__.py:1767-1776)
- **Contract**: Takes value, returns prepped value for database (or None), may raise TypeError/ValueError
- **Patch A diff scope**: None (no change to this method)
- **Patch B diff scope**: Adds unwrapping of SimpleLazyObject and extraction of .pk from model instances before int() conversion

### INTERPROCEDURAL TRACE TABLE:

| Function/Method | File:Line | Behavior (VERIFIED) |
|---|---|---|
| Lookup.__init__ | lookups.py:22-23 | Calls get_prep_lookup() |
| Lookup.get_prep_lookup() | lookups.py:70-75 | If prepare_rhs=True and lhs.output_field has get_prep_value, calls `lhs.output_field.get_prep_value(rhs)` |
| IntegerField.get_prep_value() | fields/__init__.py:1767-1776 | Calls super().get_prep_value(), then int(value) |
| SimpleLazyObject | functional.py | Lazy proxy; accessing ._wrapped or calling methods triggers evaluation |

### ANALYSIS OF TEST BEHAVIOR:

**Test Case Flow** (from bug report):
1. Creates nested subquery: `owner_user = B.objects.filter(a=OuterRef("pk")).annotate(...).values(...)`
2. Uses it in annotation: `A.objects.annotate(owner_user=Subquery(owner_user))`
3. Filters with SimpleLazyObject: `.filter(owner_user=user)` where `user = SimpleLazyObject(...)`
4. During filter, Query.build_lookup() is called
5. Lookup.__init__ calls get_prep_lookup()
6. get_prep_lookup() calls `self.lhs.output_field.get_prep_value(self.rhs)` where self.rhs = SimpleLazyObject instance
7. IntegerField.get_prep_value() is called with SimpleLazyObject
8. IntegerField calls int(SimpleLazyObject) → **TypeError**

**Claim C1.1** (Patch A): With Patch A applied, `Query.output_field` returns the correct Field object by using `.target` if available
- Evidence: query.py:236-237 uses `getattr(select, 'target', None) or select.field`
- This ensures the Field returned is appropriate for the subquery expression
- However, **the Field's get_prep_value() method is unchanged**
- Outcome: Call chain still reaches IntegerField.get_prep_value(SimpleLazyObject) → still calls int(SimpleLazyObject) → **Test FAILS**

**Claim C1.2** (Patch B): With Patch B applied, `IntegerField.get_prep_value()` explicitly handles SimpleLazyObject
- Evidence: fields/__init__.py (modified version) checks `isinstance(value, SimpleLazyObject)` and calls `value._wrapped`
- This unwraps the lazy object before int() conversion
- Outcome: Unwrapped User instance flows to next check `hasattr(value, 'pk')` → returns `value.pk` → **Test PASSES**

**Comparison**: 
- **Patch A (C1.1)**: Does NOT unwrap SimpleLazyObject → **Test FAILS**
- **Patch B (C1.2)**: DOES unwrap SimpleLazyObject → **Test PASSES**

### EDGE CASES RELEVANT TO EXISTING TESTS:

**E1**: Regular integer values (not SimpleLazyObject)
- **Patch A behavior**: Returns the correct field, int() succeeds normally → PASS (unchanged)
- **Patch B behavior**: isinstance check fails, proceeds to int() normally → PASS (unchanged)
- **Outcome**: SAME

**E2**: None values
- **Patch A behavior**: Field's get_prep_value() returns None → PASS
- **Patch B behavior**: Explicit `if value is None: return None` check → PASS
- **Outcome**: SAME

**E3**: Model instances with .pk attribute
- **Patch A behavior**: int(model_instance) → TypeError
- **Patch B behavior**: hasattr check succeeds, returns value.pk → int succeeds
- **Outcome**: **DIFFERENT** - Patch B allows model instances, Patch A does not

### REFUTATION CHECK (REQUIRED):

**Counterexample If Patch A Were Sufficient**:
If Patch A alone fixed the bug, the test would PASS when run with:
- Only query.py modified (Patch A)
- IntegerField.get_prep_value() unchanged

To verify this is NOT the case, I searched for:
- Evidence that Patch A changes how SimpleLazyObject is handled → Not found
- Evidence that .target vs .field changes SimpleLazyObject handling → Not found (both are Field objects, both call get_prep_value())
- Evidence that Query.output_field affects SimpleLazyObject evaluation before get_prep_value → Not found (output_field is only used to select which field's get_prep_value to call, not to evaluate the value itself)

**Conclusion**: Patch A does NOT prevent SimpleLazyObject from reaching IntegerField.get_prep_value(). Therefore, Patch A alone is **NOT SUFFICIENT** to make the test pass.

**Counterexample If Patch B Were Unnecessary**:
If SimpleLazyObject never reached IntegerField.get_prep_value(), Patch B's handling would be unnecessary.

To test this hypothesis, I would need to find:
- Evidence that Patch A prevents the value flow to get_prep_value() → Not found
- Evidence that SimpleLazyObject is evaluated before get_prep_value() → Not found (it's only evaluated when ._wrapped is accessed or methods are called)

**Conclusion**: SimpleLazyObject DOES reach IntegerField.get_prep_value() even with Patch A. Therefore Patch B's handling **IS NECESSARY** to fix the test.

### FORMAL CONCLUSION:

By Definition D1 (EQUIVALENT MODULO TESTS):

**Test Outcomes with Patch A**:
- `test_subquery_filter_by_lazy`: **FAILS** (SimpleLazyObject still reaches int())
- Existing passing tests: **PASS** (no change to normal value handling)

**Test Outcomes with Patch B**:
- `test_subquery_filter_by_lazy`: **PASSES** (SimpleLazyObject is unwrapped before int())
- Existing passing tests: **PASS** (normal values unaffected)

**Since test outcomes are DIFFERENT** (test_subquery_filter_by_lazy FAILS with Patch A but PASSES with Patch B), the patches are **NOT EQUIVALENT**.

Additionally, Patch B introduces a behavioral difference for model instances with .pk attributes (E3), which Patch A does not handle.

---

**ANSWER: NO (not equivalent)**

**CONFIDENCE: HIGH**
