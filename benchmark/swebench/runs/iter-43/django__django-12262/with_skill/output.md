## COMPARISON ANALYSIS

### DEFINITIONS

**D1**: Two patches are **EQUIVALENT MODULO TESTS** iff both produce identical pass/fail outcomes on the fail-to-pass tests listed in the task.

**D2**: The fail-to-pass tests include:
- `test_simple_tag_errors` — tests error handling for simple tags
- `test_simple_tags` — tests valid simple tag usage including keyword-only defaults
- `test_inclusion_tag_errors` — tests error handling for inclusion tags
- `test_inclusion_tags` — tests valid inclusion tag usage

### PREMISES

**P1**: The bug is that keyword-only arguments WITH defaults cannot be used in template tags because line 264 of parse_bits checks against `unhandled_kwargs`, which excludes kwonly args that have defaults (line 254-257 initial list).

**P2**: The failing test at line 63-64 of test_custom.py tests:
```
'{% load custom %}{% simple_keyword_only_default %}'
→ 'simple_keyword_only_default - Expected result: 42'
```
where `simple_keyword_only_default(*, kwarg=42)` has a default value of integer `42`.

**P3**: Patch A changes line 264 from checking `param not in unhandled_kwargs` to `param not in kwonly`, allowing all keyword-only args (with or without defaults) to pass validation.

**P4**: Patch B (in addition to the Patch A fix at line 272) also:
- Adds default values as raw Python objects directly into the `kwargs` dict at line 315
- Overrides `SimpleNode.get_resolved_arguments()` to handle these raw values differently
- Changes error messages for missing keyword-only args

**P5**: In the original `TagHelperNode.get_resolved_arguments()` (line 176-181), all values in `self.kwargs` are expected to be `FilterExpression` objects with a `.resolve(context)` method. When rendering SimpleNode, this is called at line 191.

### ANALYSIS OF TEST BEHAVIOR

**Test Case 1: `test_simple_tags` with keyword-only default (line 63-64)**

```
Test: simple_keyword_only_default without arguments
Input: '{% load custom %}{% simple_keyword_only_default %}'
Expected output: 'simple_keyword_only_default - Expected result: 42'
```

**Claim C1.1 (Patch A)**:
- parse_bits is called with `kwonly=['kwarg']`, `kwonly_defaults={'kwarg': 42}`
- `unhandled_kwargs = []` (empty, because kwarg has a default)
- bits is empty (no template arguments)
- The for loop doesn't execute (no bits)
- No defaults handling code is reached for kwonly args
- At line 304: `if unhandled_params or unhandled_kwargs:` → False (both empty)
- Return: `args=[], kwargs={}`
- When SimpleNode.render() calls `self.func(*[], **{})` → Python function call provides default kwarg=42
- **Expected result: PASS** ✓

**Claim C1.2 (Patch B)**:
- parse_bits is called with same parameters
- Line 255: `unhandled_kwargs = list(kwonly) = ['kwarg']` (ALL kwonly args, not filtered)
- Line 256: `handled_kwargs = set()`
- bits is empty, for loop doesn't execute
- At line 312-318 (new code):
  ```python
  if kwonly_defaults:  # True: {'kwarg': 42}
      for kwarg, default_value in kwonly_defaults.items():
          if kwarg not in handled_kwargs:  # True: 'kwarg' not in {}
              kwargs[kwarg] = default_value  # kwargs['kwarg'] = 42
              unhandled_kwargs.remove(kwarg)  # unhandled_kwargs = []
  ```
- At line 322: `if unhandled_params:` → False
- At line 327: `if unhandled_kwargs:` → False
- Return: `args=[], kwargs={'kwarg': 42}`
- When SimpleNode.render() calls `get_resolved_arguments(context)`:
  - Patch B's override (line 197-209) iterates over kwargs
  - For `k='kwarg', v=42`:
    - `isinstance(42, str)` → False
    - Tries: `(42).resolve(context)` 
    - **AttributeError: 'int' object has no attribute 'resolve'**
- **Expected result: FAIL** ✗

**Claim C1.3 (Comparison)**:
- Patch A: PASS (output matches expected 'simple_keyword_only_default - Expected result: 42')
- Patch B: FAIL (AttributeError during render)
- **Outcomes: DIFFERENT**

### COUNTEREXAMPLE FOUND

**Test**: test_simple_tags at line 63-64 (simple_keyword_only_default)
- **Patch A result**: PASS (as expected — test is in fail-to-pass list)
- **Patch B result**: FAIL with AttributeError (not as expected)
- **Conclusion**: Patches produce different test outcomes.

### CRITICAL ISSUE IN PATCH B

The root cause is in Patch B's `SimpleNode.get_resolved_arguments()` override (lines 197-209):

```python
def get_resolved_arguments(self, context):
    ...
    resolved_kwargs = {}
    for k, v in self.kwargs.items():
        if isinstance(v, str):
            resolved_kwargs[k] = v
        else:
            resolved_kwargs[k] = v.resolve(context)
```

This code assumes that non-string values in `self.kwargs` are `FilterExpression` objects with a `.resolve()` method. However:
- Patch B adds raw default values (e.g., `kwargs[kwarg] = 42` at line 315:file:line)
- The integer `42` does not have a `.resolve()` method
- The `isinstance(v, str)` check only handles string defaults, not int, bool, float, etc.
- **Evidence**: Line 315 of Patch B adds `default_value` (a raw Python object from `kwonly_defaults`) directly to `kwargs`.

### VERIFICATION OF PATCH A CORRECTNESS

Patch A makes a minimal change: line 264 changes the validation condition from:
```python
if param not in params and param not in unhandled_kwargs and varkw is None:
```
to:
```python
if param not in params and param not in kwonly and varkw is None:
```

**Why this fixes the bug** (Claim A1):
- Old code: `unhandled_kwargs` only includes kwonly args WITHOUT defaults, so kwonly args WITH defaults are not recognized as valid keyword-only params.
- New code: `kwonly` includes ALL keyword-only args (with or without defaults), so they're all validated correctly.
- Does not add raw values to kwargs; all values in kwargs remain FilterExpressions created by `parser.compile_filter()`.

---

### FORMAL CONCLUSION

**By Definition D1 (equivalence modulo tests) and Claim C1.3**:
- Test `test_simple_tags` (line 63-64, simple_keyword_only_default):
  - **Patch A**: PASS (correctly uses default value provided by Python function call)
  - **Patch B**: FAIL (AttributeError: 'int' object has no attribute 'resolve')
  
Since test outcomes are **DIFFERENT**, the patches are **NOT EQUIVALENT**.

**Why Patch B fails**:
- Patch B attempts to populate `kwargs` with raw default values at parse time (line 315).
- SimpleNode's overridden `get_resolved_arguments()` expects all values to be FilterExpressions.
- For default values of type int, bool, float, etc., calling `.resolve(context)` fails.
- The `isinstance(v, str)` check (line 203) only works for strings, not other scalar types.

**ANSWER: NO (not equivalent)**

**CONFIDENCE: HIGH**

The counterexample is concrete and traceable: test_simple_tags with `simple_keyword_only_default()` and a default value of type `int` fails under Patch B with AttributeError.
