## PHASE 5: REFUTATION CHECK

**ALTERNATIVE HYPOTHESIS**: Could the bug be elsewhere (e.g., in how keyword-only arguments are extracted or registered)?

*Searched for*: Tests for keyword-only parameters and their current behavior
*Found*: 
- Template tests include `simple_keyword_only_param` (required) and `simple_keyword_only_default` (with default) - see `/tmp/bench_workspace/worktrees/django__django-12262/tests/template_tests/templatetags/custom.py`
- Tests show `{% simple_keyword_only_param kwarg=37 %}` works (required kwonly)
- Tests show `{% simple_keyword_only_default %}` works (optional kwonly, not supplied)
- But NO test exercises passing a keyword argument to the optional kwonly parameter (the bug case)

*Conclusion*: The bug is NOT in extraction (that works fine for required kwonly args) or in initialization (getfullargspec works correctly). It's specifically in the validation at line 264 that incorrectly rejects kwonly args WITH defaults.

## FORMAL CONCLUSION

By the evidence traced in Phase 2 and claims verified in Phase 3:

The root cause is a single line in the `parse_bits()` function in `/tmp/bench_workspace/worktrees/django__django-12262/django/template/library.py` at **line 264**.

The condition:
```python
if param not in params and param not in unhandled_kwargs and varkw is None:
```

Should be changed to:
```python
if param not in params and param not in kwonly and varkw is None:
```

**Explanation**: 
- `unhandled_kwargs` only contains keyword-only parameters WITHOUT defaults (required keyword-only args)
- `kwonly` contains ALL keyword-only parameters (both required and optional)
- The validation should accept all keyword-only parameters, not just the required ones
- This single change fixes both bug scenarios:
  1. Keyword-only parameters with defaults can now accept supplied values
  2. Duplicate keyword-only arguments now correctly raise "multiple values" instead of "unexpected keyword argument" because the duplicate check (line 266-270) is reached before the first check rejects valid args

**Confidence**: HIGH
- Issue is localized to one condition
- Root cause verified with argument inspection traces
- Both reported bugs explained by the same root cause
- Fix maintains all other validation logic intact

---

## LOCALIZATION:

FILE: django/template/library.py
FUNCTION: parse_bits
