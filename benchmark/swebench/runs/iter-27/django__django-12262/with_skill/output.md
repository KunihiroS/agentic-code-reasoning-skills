**Test C1.1 (PATCH A):** `{% simple_keyword_only_default %}`  
- `bits = []` (no arguments provided)
- `kwonly = ['kwarg']`, `kwonly_defaults = {'kwarg': 42}`
- Line 254: `unhandled_kwargs = []` (since 'kwarg' is in kwonly_defaults)
- No iterations in the for loop (bits is empty)
- Line 300-303: defaults is None for kwonly, so unhandled_params stays as `[]`
- Line 304: `if unhandled_params or unhandled_kwargs:` → `if [] or []:` → **FALSE** ✓
- Returns `args=[], kwargs={}`
- **PROBLEM:** Function is called as `func(*[], **{})` but `kwarg=42` is a required parameter! This will fail at runtime with "missing 1 required keyword-only argument: 'kwarg'"

**Test C1.2 (PATCH B):** `{% simple_keyword_only_default %}`  
- Same setup
- Line 254: `unhandled_kwargs = list(kwonly) = ['kwarg']`
- No iterations in for loop
- Lines 311-318: Since `kwonly_defaults = {'kwarg': 42}` is not None:
  - For each kwarg in kwonly_defaults, if not in handled_kwargs (which is empty), add it to kwargs
  - `kwargs['kwarg'] = 42`
  - Remove 'kwarg' from unhandled_kwargs
- Line 319: `if unhandled_params:` → FALSE
- Line 321: `if unhandled_kwargs:` → FALSE (it was removed at line 317)
- Returns `args=[], kwargs={'kwarg': 42}`
- **SUCCESS:** Function is called as `func(*[], **{'kwarg': 42})` ✓

---

**COUNTEREXAMPLE CHECK (Step 5):**

If Patch A were equivalent to Patch B, both would need to pass the test at line 63-64:
```
Template("{% load custom %}{% simple_keyword_only_default %}")
.render(Context({}))
expecting: 'simple_keyword_only_default - Expected result: 42'
```

**With Patch A:** Fails at runtime with `TypeError: simple_keyword_only_default() missing 1 required keyword-only argument: 'kwarg'`

**With Patch B:** Passes because it adds `kwarg=42` to kwargs before calling the function.

I searched for this test pattern in the actual test file and confirmed it exists at test_custom.py:63-64.

---

## Pre-Conclusion Self-Check (Step 5.5)

- [x] Every PASS/FAIL claim traces to file:line (test_custom.py:63-64, library.py:254-309)
- [x] Every function in trace table is VERIFIED (read actual definitions)
- [x] Refutation check involved actual file inspection (test file and source code inspection)
- [x] Conclusion doesn't exceed what evidence supports

---

## FORMAL CONCLUSION

**By Definition D1**, two changes are equivalent modulo tests iff executing the relevant test suite produces identical pass/fail outcomes for both.

**By P1 and P2**, the fail-to-pass test at test_custom.py:63-64 requires:
- Input: Template string `"{% load custom %}{% simple_keyword_only_default %}"`
- Expected: Renders as `'simple_keyword_only_default - Expected result: 42'`

**By Claims C1.1 and C1.2**:
- **Patch A:** At parse_bits return, `kwargs={}` (no kwonly defaults are injected). The function call fails with `TypeError: missing required keyword-only argument 'kwarg'`. **Test FAILS.**
- **Patch B:** At parse_bits return, `kwargs={'kwarg': 42}` (kwonly defaults are injected). The function call succeeds. **Test PASSES.**

**Conclusion:**
- Test outcomes with Patch A: FAIL on `test_simple_tags` (line 63-64)
- Test outcomes with Patch B: PASS on `test_simple_tags` (line 63-64)  
- Since outcomes are DIFFERENT, changes are **NOT EQUIVALENT** modulo the existing tests.

**ANSWER: NO (not equivalent)**

**CONFIDENCE: HIGH**

The evidence is concrete: Patch A leaves `kwargs` empty for defaults on kwonly args, while Patch B explicitly injects them. The test at test_custom.py:63-64 requires the default injection and will only pass with Patch B.
