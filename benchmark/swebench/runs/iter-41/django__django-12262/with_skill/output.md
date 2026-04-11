## FORMAL ANALYSIS: Compare Mode

### DEFINITIONS:
**D1**: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.

**D2**: The relevant tests are:
- FAIL_TO_PASS tests:
  - `test_simple_tags` — must render `{% simple_keyword_only_default %}` 
  - `test_simple_tag_errors` — error checking for keyword-only args
  - `test_inclusion_tags` — same for inclusion tags
  - `test_inclusion_tag_errors` — error checking for inclusion tags

### PREMISES:

**P1**: Change A modifies only `django/template/library.py` line 264: changes `unhandled_kwargs` check to `kwonly` check.

**P2**: Change B modifies:
- `django/template/library.py` line 257: `unhandled_kwargs = list(kwonly)` (ADDS ALL kwonly, not just those without defaults)
- Adds `handled_kwargs = set()` to track which kwonly args were parsed
- Line 264: Also changes to `kwonly` check (same as Patch A)
- Lines 312-317: **ADDS RAW PYTHON VALUES TO kwargs** when defaults exist but arg wasn't provided
- Adds `get_resolved_arguments()` override to SimpleNode

**P3**: Parent class `TagHelperNode.get_resolved_arguments()` (line 176-181) calls `.resolve(context)` on all kwargs values:
```python
resolved_kwargs = {k: v.resolve(context) for k, v in self.kwargs.items()}
```

**P4**: Original `parse_bits` returns kwargs containing only FilterExpression objects (from `token_kwargs`), not raw Python values.

**P5**: The critical test case is:
```python
@register.simple_tag
def simple_keyword_only_default(*, kwarg=42):
    return "simple_keyword_only_default - Expected result: %s" % kwarg
```
Template: `{% simple_keyword_only_default %}` (no kwarg provided)

### ANALYSIS OF TEST BEHAVIOR:

**Test: test_simple_tags, case `{% simple_keyword_only_default %}`**

**Claim C1.1 (Patch A):**
- `parse_bits` is called with `kwonly=['kwarg']`, `kwonly_defaults={'kwarg': 42}`
- `unhandled_kwargs` is still filtered (line 254-257 unchanged): `unhandled_kwargs = [kwarg for kwarg in kwonly if kwarg not in kwonly_defaults]` → `[]`
- No kwarg provided in template, returns `kwargs = {}`
- At render: `SimpleNode.render()` calls `get_resolved_arguments()` (parent version)
- `resolved_kwargs = {k: v.resolve(context) for k, v in {}.items()}` → `{}`
- Calls `simple_keyword_only_default(**{})` which is equivalent to `simple_keyword_only_default()`
- Python's function machinery supplies default: `kwarg=42`
- Returns `'simple_keyword_only_default - Expected result: 42'`
- **PASSES** ✓

**Claim C1.2 (Patch B):**
- Line 257 CHANGED: `unhandled_kwargs = list(kwonly)` → `['kwarg']`
- No kwarg provided in template
- Line 312-317 executes: `for kwarg, default_value in kwonly_defaults.items():` where `default_value = 42`
- Since 'kwarg' not in `handled_kwargs`: adds `kwargs['kwarg'] = 42` (raw integer)
- Returns `kwargs = {'kwarg': 42}` (now contains raw Python integer, not FilterExpression)
- At render: `SimpleNode.render()` is called
- **SimpleNode in Patch B overrides `get_resolved_arguments()`**:
  ```python
  for k, v in self.kwargs.items():
      if isinstance(v, str):
          resolved_kwargs[k] = v
      else:
          resolved_kwargs[k] = v.resolve(context)
  ```
- For `k='kwarg', v=42`:
  - `isinstance(42, str)` → False
  - Calls `(42).resolve(context)` → **AttributeError: 'int' object has no attribute 'resolve'**
- **FAILS** with exception ✗

**Comparison: C1.1 vs C1.2**

- **Patch A outcome: PASS**
- **Patch B outcome: FAIL (crashes with AttributeError)**
- Comparison: **DIFFERENT outcome**

### COUNTEREXAMPLE (REQUIRED for NOT EQUIVALENT):

**Test**: `test_simple_tags` line 63-64  
**Template**: `{% load custom %}{% simple_keyword_only_default %}`  
**Expected**: Render successfully with output `'simple_keyword_only_default - Expected result: 42'`

**Patch A behavior**: 
- `parse_bits` returns `kwargs={}`
- At render, Python's default mechanism supplies `kwarg=42`
- **Result: PASSES** ✓

**Patch B behavior**:
- `parse_bits` returns `kwargs={'kwarg': 42}` (raw int)
- At render, tries to call `(42).resolve(context)`
- **Result: CRASHES with AttributeError** ✗

This is a concrete counterexample where the patches produce different test outcomes.

### ROOT CAUSE OF BUG IN PATCH B:

Patch B's `get_resolved_arguments()` override assumes that:
- `isinstance(v, str)` detects literal strings that shouldn't be resolved
- All other values `v` have a `.resolve(context)` method

But raw Python defaults (integers, etc.) are neither strings nor FilterExpressions. They lack `.resolve()`, causing a crash.

**The isinstance(v, str) check is insufficient** — it should be `hasattr(v, 'resolve')`:
```python
if hasattr(v, 'resolve'):
    resolved_kwargs[k] = v.resolve(context)
else:
    resolved_kwargs[k] = v
```

But Patch B doesn't have this fix.

### FORMAL CONCLUSION:

By Definition D1, two changes are equivalent modulo tests if they produce identical pass/fail outcomes.

- **Patch A outcome on FAIL_TO_PASS tests**: 
  - test_simple_tags: PASS (line 63-64 case works correctly)
  - test_simple_tag_errors: PASS (error checks work)
  - test_inclusion_tags: PASS
  - test_inclusion_tag_errors: PASS

- **Patch B outcome on FAIL_TO_PASS tests**:
  - test_simple_tags: FAIL (line 63-64 crashes with AttributeError when rendering)
  - test_simple_tag_errors: FAIL/UNKNOWN (may fail before reaching these if earlier tests crash)

Since test outcomes differ, the changes are **NOT EQUIVALENT**.

**CONFIDENCE**: HIGH

- The bug in Patch B's `get_resolved_arguments()` override is concrete (file:line verified in analysis)
- The test case that fails is explicitly listed in the repository and directly exercises this code path
- The failure mode (AttributeError on resolve) is deterministic

---

ANSWER: **NO (not equivalent)**
