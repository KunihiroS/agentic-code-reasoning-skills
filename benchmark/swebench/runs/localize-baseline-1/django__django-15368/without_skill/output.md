Based on my analysis of the code and the bug report, I've identified the root cause of the issue. Let me summarize my findings:

## Analysis

1. **The Problem**: The `bulk_update()` method checks if an attribute is an `Expression` instance to determine whether to wrap it with `Value()`. However, `F()` expressions inherit from `Combinable`, not `Expression`, so they fail this type check and get incorrectly wrapped with `Value()`, causing them to be serialized as strings.

2. **Class Hierarchy**:
   - `F` inherits only from `Combinable`
   - `Expression` inherits from both `BaseExpression` and `Combinable`
   - `Subquery` also has the same issue - inherits from `BaseExpression` and `Combinable`, but not `Expression`

3. **Verification**:
   - `isinstance(F('name'), Expression)` returns `False` (this is the bug!)
   - Both `F` and `Expression` objects have the `resolve_expression()` method from `Combinable`
   - The codebase already uses `hasattr(attr, 'resolve_expression')` elsewhere for similar checks (e.g., in `Combinable._combine()`)

4. **The Fix Location**: Line 673 in `django/db/models/query.py` in the `QuerySet.bulk_update()` method.

The problematic code is:
```python
if not isinstance(attr, Expression):
    attr = Value(attr, output_field=field)
```

This should be changed to use duck typing (like the rest of the codebase does):
```python
if not hasattr(attr, 'resolve_expression'):
    attr = Value(attr, output_field=field)
```

---

LOCALIZATION:
FILE: django/db/models/query.py
FUNCTION: QuerySet.bulk_update
