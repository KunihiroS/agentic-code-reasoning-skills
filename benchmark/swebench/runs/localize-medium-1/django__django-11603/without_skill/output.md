Perfect! I now have a complete understanding of the bug. Let me provide the localization analysis:

## Analysis

The bug report indicates that Django 3.0 now raises an exception when using the `distinct` parameter with `Avg` and `Sum` aggregates, whereas previously (before 2.2) these would just ignore the parameter.

**Root Cause:**
The infrastructure for DISTINCT support was added to the `Aggregate` base class (commit `bc05547cd8` for issue #28658), which includes:
- A `template` with `%(distinct)s` placeholder
- An `allow_distinct` class attribute (defaults to `False`)
- A check in `__init__` that raises `TypeError` if `distinct=True` is passed but `allow_distinct=False`

Currently, only the `Count` class has `allow_distinct = True`. The `Avg` and `Sum` classes do NOT have this attribute set, so they raise a `TypeError` when `distinct=True` is passed.

**The Fix:**
Add `allow_distinct = True` class attribute to the `Avg` and `Sum` aggregate classes. This will allow them to accept the `distinct` parameter, just like `Count` does. The bug report also mentions that this *could* be applied to `Min` and `Max` (though it says this is "pointless").

---

## LOCALIZATION:

FILE: django/db/models/aggregates.py
FUNCTION: Avg (class attribute)

FILE: django/db/models/aggregates.py
FUNCTION: Sum (class attribute)
