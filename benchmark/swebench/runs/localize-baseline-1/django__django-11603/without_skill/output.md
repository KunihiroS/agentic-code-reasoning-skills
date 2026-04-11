Based on my analysis of the bug report and code exploration, here's what I found:

## Analysis

The bug report indicates that `Avg` and `Sum` aggregate classes should support the `DISTINCT` keyword, but currently throw a TypeError when `distinct=True` is passed to them.

### Root Cause
When examining the code:
1. The base `Aggregate` class has `allow_distinct = False` by default
2. Only the `Count` class has `allow_distinct = True` explicitly set
3. The `Avg` and `Sum` classes inherit from `Aggregate` but don't override `allow_distinct`
4. The `__init__` method of `Aggregate` checks `if distinct and not self.allow_distinct` and raises a TypeError

I confirmed this by running a test:
- `Avg('rating', distinct=True)` raises: "Avg does not allow distinct."
- `Sum('rating', distinct=True)` raises: "Sum does not allow distinct."
- `Count('rating', distinct=True)` works (because it has `allow_distinct = True`)

### Test Structure
The failing test `test_distinct_on_aggregate` expects to test `Avg`, `Count`, and `Sum` aggregates with `distinct=True` parameter, but:
- The test doesn't exist yet in the current version
- When it's added, it should pass after setting `allow_distinct = True` on `Avg` and `Sum`

## Localization

LOCALIZATION:
FILE: django/db/models/aggregates.py
FUNCTION: Avg (class definition)
FILE: django/db/models/aggregates.py
FUNCTION: Sum (class definition)
