---

## CERTIFICATE-BASED CODE REASONING: COMPARE MODE

### DEFINITIONS

**D1**: Two patches are **EQUIVALENT MODULO TESTS** if applying either patch to the codebase produces identical pass/fail outcomes for all relevant test cases in the repository.

**D2**: Relevant tests are:
- (a) **Fail-to-pass tests**: Tests that currently fail and are expected to pass after the fix
  - `test_simple_tags` (SimpleTagTests)
  - `test_simple_tag_errors` (SimpleTagTests)
  - `test_inclusion_tags` (InclusionTagTests)
  - `test_inclusion_tag_errors` (InclusionTagTests)
- (b) **Pass-to-pass tests**: Tests that already pass and must continue to pass (not modified by either patch's core logic)

---

### PREMISES

**P1**: Patch A modifies only `django/template/library.py:264`, changing the condition from:
```python
if param not in params and param not in unhandled_kwargs and varkw is None:
```
to:
```python
if param not in params and param not in kwonly and varkw is None:
```

**P2**: Patch B modifies `django/template/library.py` at multiple locations:
- Changes unhandled_kwargs initialization (line 254) from "kwargs without defaults only" to "all kwonly"
- Adds tracked handling via `handled_kwargs` set (line 255 in Patch B)
- Explicitly applies kwonly defaults to kwargs dict (lines 314-317 in Patch B)
- Splits final error checking into separate clauses (lines 319-326 in Patch B)
- Also modifies unrelated files (test files, removes blank line in SimpleNode)

**P3**: The bug being fixed is that keyword-only parameters WITH default values are incorrectly flagged as "unexpected keyword arguments" when supplied in templates (line 264 in current code uses `unhandled_kwargs`, which excludes params with defaults).

**P4**: Error message tests (test_custom.py:90-108) expect specific error text:
- For missing required kwonly args: `"'%s' did not receive value(s) for the argument(s): %s"`
- Example: `"'simple_keyword_only_param' did not receive value(s) for the argument(s): 'kwarg'"`

---

### ANALYSIS OF TEST BEHAVIOR

#### **Test 1: test_simple_tags (line 63-64)**
Template: `{% load custom %}{% simple_keyword_only_default %}`

Function: `simple_keyword_only_default(*, kwarg=42)` (keyword-only arg WITH default)

**With Patch A:**
1. `parse_bits()` called with `bits=[]`, `kwonly=['kwarg']`, `kwonly_defaults={'kwarg': 42}`
2. `unhandled_kwargs = []` (kwarg is excluded because it's in kwonly_defaults, per line 254-257)
3. Loop doesn't execute (bits is empty)
4. Check at line 304: `unhandled_params=[]` and `unhandled_kwargs=[]` → **no error**
5. Returns `args=[], kwargs={}`
6. At render time: `SimpleNode.render()` calls `self.func(*[], **{})` which invokes `simple_keyword_only_default()`. Python supplies the default `kwarg=42`
7. **Result: PASS** ✓

**With Patch B:**
1. `parse_bits()` called with same inputs
2. `unhandled_kwargs = ['kwarg']` (ALL kwonly, per line 254 in Patch B)
3. `handled_kwargs = set()`
4. Loop doesn't execute
5. At lines 314-317: `if kwonly_defaults:` → True. Since `'kwarg' not in handled_kwargs`, adds `kwargs['kwarg'] = 42` and removes from `unhandled_kwargs`
6. Returns `args=[], kwargs={'kwarg': 42}`
7. At render time: calls `self.func(*[], **{'kwarg': 42})` which invokes `simple_keyword_only_default(kwarg=42)`
8. **Result: PASS** ✓

**Comparison**: Both PASS but with different internal representations (`kwargs={}`  vs `kwargs={'kwarg': 42}`). Test output is identical.

---

#### **Test 2: test_simple_tag_errors - Case: simple_keyword_only_param (line 98-99)**
Template: `{% load custom %}{% simple_keyword_only_param %}`

Function: `simple_keyword_only_param(*, kwarg)` (keyword-only arg WITHOUT default)

Expected error: `"'simple_keyword_only_param' did not receive value(s) for the argument(s): 'kwarg'"`

**With Patch A:**
1. `parse_bits()` called with `bits=[]`, `kwonly=['kwarg']`, `kwonly_defaults=None`
2. `unhandled_kwargs = ['kwarg']` (kwarg is included because kwonly_defaults is None, per line 254-257)
3. Loop doesn't execute
4. Check at line 304: `unhandled_params=[]` or `unhandled_kwargs=['kwarg']` → **TRUE, raise error**
5. Error message (line 306-308): `"'simple_keyword_only_param' did not receive value(s) for the argument(s): 'kwarg'"`
6. **Result: PASS** ✓ (matches expected error message exactly)

**With Patch B:**
1. Same inputs as above
2. `unhandled_kwargs = ['kwarg']` (ALL kwonly)
3. `handled_kwargs = set()`
4. Loop doesn't execute
5. At line 314: `if kwonly_defaults:` → False (None or empty), **skip**
6. At line 319: `if unhandled_params:` → False, **skip**
7. At line 323: `if unhandled_kwargs:` → True, **raise error**
8. Error message (lines 325-326): `"'simple_keyword_only_param' did not receive value(s) for the keyword-only argument(s) without default values: 'kwarg'"`
9. **Result: FAIL** ✗ (error message is DIFFERENT from expected)

**Comparison**: **DIFFERENT TEST OUTCOMES**
- Patch A: Error message matches test expectation
- Patch B: Error message does NOT match (uses "keyword-only argument(s) without default values" instead of "argument(s)")

The test at line 107 uses `assertRaisesMessage(TemplateSyntaxError, entry[0])`, which requires the exception message to contain the substring in `entry[0]`. The strings are incompatible:
- Expected: `"did not receive value(s) for the argument(s):"`
- Patch B produces: `"did not receive value(s) for the keyword-only argument(s) without default values:"`

---

#### **Test 3: test_simple_tags - Case with kwarg supplied (line 61-62)**
Template: `{% load custom %}{% simple_keyword_only_param kwarg=37 %}`

Function: `simple_keyword_only_param(*, kwarg)`

Expected output: `"simple_keyword_only_param - Expected result: 37"`

**With Patch A:**
1. `parse_bits()` called with `bits=["kwarg=37"]`, `kwonly=['kwarg']`, `kwonly_defaults=None`
2. `unhandled_kwargs = ['kwarg']`
3. Loop extracts: `param='kwarg'`, `value=<filter>`
4. Line 264 check: `param not in params` (True) AND `param not in unhandled_kwargs` (**FALSE** - 'kwarg' is in unhandled_kwargs) → condition is **False, doesn't raise**
   - With Patch A: `param not in params` (True) AND `param not in kwonly` (**FALSE** - 'kwarg' is in kwonly) → condition is **False, doesn't raise** ✓
5. Line 269: param not already in kwargs, so proceeds
6. Line 276: `kwargs['kwarg'] = value`
7. Line 281: `param in unhandled_kwargs` → True, removes 'kwarg'
8. Returns `args=[], kwargs={'kwarg': <filter>}`
9. Render time: calls with resolved kwargs
10. **Result: PASS** ✓

**With Patch B:**
1-3. Same as Patch A
4. Line 272 check (Patch B): `param not in params` (True) AND `param not in kwonly` (**FALSE**) → condition is **False, doesn't raise** ✓
5-7. Same as Patch A, but also adds `handled_kwargs.add(param)` at line 293 (Patch B)
8. Returns `args=[], kwargs={'kwarg': <filter>}`
9. Render time: same
10. **Result: PASS** ✓

**Comparison**: Both PASS ✓

---

### EDGE CASES RELEVANT TO EXISTING TESTS

**E1**: Multiple supplied values for same kwarg (test_simple_tag_errors, line 102-103)

Template: `{% simple_unlimited_args_kwargs 37 eggs="scrambled" eggs="scrambled" %}`

Expected error: `"'simple_unlimited_args_kwargs' received multiple values for keyword argument 'eggs'"`

**Both patches**: The check at line 269 (`elif param in kwargs:`) catches this BEFORE the final validation. Both patches leave this code unchanged.
- **Result: SAME** ✓

---

### COUNTEREXAMPLE (CRITICAL)

**If patches were EQUIVALENT, the following test would produce identical outcomes:**

**Test**: `test_simple_tag_errors`, case at line 98-99
- Input: `{% load custom %}{% simple_keyword_only_param %}`
- Expected error substring: `"did not receive value(s) for the argument(s): 'kwarg'"`

**With Patch A**: Exception message CONTAINS expected substring → **assertRaisesMessage PASSES**

**With Patch B**: Exception message is `"did not receive value(s) for the keyword-only argument(s) without default values: 'kwarg'"` which does NOT contain the expected substring → **assertRaisesMessage FAILS**

This is a concrete counterexample showing different test outcomes.

---

### ALTERNATIVE EVIDENCE CHECK

If the error messages were compatible (i.e., if my analysis of Patch B's error message were wrong), what evidence would prove it?

**Search performed**: Examined lines 319-326 in Patch B diff → confirmed the new error message text uses "keyword-only argument(s) without default values"

**Searched for**: Whether existing tests might be updated alongside Patch B → Found that Patch B does NOT modify `tests/template_tests/test_custom.py`

**Conclusion**: The error message change is real and unaccounted for in the existing test suite.

---

### FORMAL CONCLUSION

By Definition D1 (identical test outcomes), the patches are **NOT EQUIVALENT**.

**Key evidence:**
1. **P4** specifies that the error message test expects: `"'%s' did not receive value(s) for the argument(s): %s"`
2. **Patch A**: Preserves this error message (line 306-308 unchanged) → test passes
3. **Patch B**: Changes the error message to `"'%s' did not receive value(s) for the keyword-only argument(s) without default values: %s"` (lines 325-326) → test fails with `assertRaisesMessage`
4. **Critical test failure**: `test_simple_tag_errors` (line 98-99) will FAIL with Patch B due to error message mismatch

For other test cases (e.g., `test_simple_tags` with kwarg supplied or default used), both patches produce PASS outcomes, but the error validation test creates a decisive divergence.

**ANSWER: NO (not equivalent)**

**CONFIDENCE: HIGH**

The error message discrepancy is unambiguous and confirmed by direct examination of the diff. The test framework's `assertRaisesMessage` requires exact substring matching, which fails for Patch B.
