## PHASE 3: DIVERGENCE ANALYSIS

| # | METHOD | LOCATION | BEHAVIOR | RELEVANT |
|---|--------|----------|----------|----------|
| 1 | QuerySet.bulk_update(objs, fields, batch_size=None) | django/db/models/query.py:636 | Iterates through model instances and creates CASE statements for SQL UPDATE | Entry point for the test |
| 2 | getattr(obj, field.attname) | django/db/models/query.py:673 | Retrieves the F('name') object from the model instance field | Gets the F expression assigned by user |
| 3 | isinstance(attr, Expression) | django/db/models/query.py:674 | Returns False for F('name') because F is Combinable, not Expression | BUG: causes unwanted wrapping |
| 4 | Value(attr, output_field=field) | django/db/models/query.py:675 | Wraps F('name') object as a value | CONSEQUENCE: F object is converted to string |
| 5 | Value.as_sql(compiler, connection) | django/db/models/expressions.py:758 | Calls output_field.get_db_prep_save(val, ...) on the F object | CONSEQUENCE: F object converted to 'F(name)' string |

Now let me formalize the divergence claims:

**CLAIM D1**: At django/db/models/query.py:674, the code checks `if not isinstance(attr, Expression):`, which returns True for `attr = F('name')` because F is a Combinable (line 582 of expressions.py), NOT an Expression (line 394 of expressions.py). This contradicts PREMISE T3 (expecting the F expression to be resolved to a column reference).

**CLAIM D2**: At django/db/models/query.py:675, when `attr = F('name')` (a Combinable), the code wraps it in `Value(attr, output_field=field)`. The Value class then converts the F object to its string representation 'F(name)' (via get_db_prep_save), which contradicts PREMISE T3 and causes PREMISE T4 (the observed failure).

**CLAIM D3**: The fix at django/db/models/expressions.py:59 shows the correct pattern: `if not hasattr(other, 'resolve_expression'):` which properly handles Combinable objects like F. This same pattern should be applied to django/db/models/query.py:674.

## PHASE 4: RANKED PREDICTIONS

**Rank 1 (HIGH CONFIDENCE)**: django/db/models/query.py:674
- **Location**: Line 674 in QuerySet.bulk_update method
- **Description**: Replace `if not isinstance(attr, Expression):` with `if not hasattr(attr, 'resolve_expression'):`
- **Supporting claims**: D1, D2, D3
- **Root cause**: The type check is too narrow - it doesn't recognize F as an expression-like object
- **Evidence**: 
  - F is a Combinable (expressions.py:582), not an Expression (expressions.py:394)
  - The same pattern with hasattr is used in Combinable._combine (expressions.py:59)
  - The test at test_bulk_update.py:210 works because F('num') + 1 is a CombinedExpression (which IS an Expression)

## PHASE 5: REFUTATION CHECK

Let me verify this conclusion by checking if there are any other possible explanations:

**ALTERNATIVE HYPOTHESIS CHECK:**
If the root cause were NOT in line 674, what evidence would exist?
- Searched for: Other uses of isinstance(attr, Expression) in bulk_update related code
- Found: Only one occurrence at django/db/models/query.py:674 (via grep)
- Searched for: Tests that already pass with plain F expressions in bulk_update
- Found: NONE - the existing test uses F('num') + 1, not plain F('num')
- Searched for: Documentation of resolve_expression as duck type check
- Found: Multiple uses of `hasattr(x, 'resolve_expression')` in expressions.py (lines 59, 186, 1033, 1245)
- Conclusion: SUPPORTED - the root cause IS the narrow type check at line 674

**COUNTEREXAMPLE VERIFICATION:**
Test: bulk_update with F('name')
- With current code: isinstance(F('name'), Expression) = False, so F('name') gets wrapped in Value(), resulting in 'F(name)' string
- With fixed code: hasattr(F('name'), 'resolve_expression') = True, so F('name') stays as-is and gets resolved properly
- Diverging point: Line 674 check

## PHASE 5.5: PRE-CONCLUSION SELF-CHECK

- [x] Every claim traces to specific `file:line` — verified for lines 674, 675, 582, 394, 59
- [x] Every function behavior marked VERIFIED — all verified by reading source code
- [x] Refutation check involved code inspection — checked multiple files and patterns
- [x] Conclusion asserts only what traced evidence supports — root cause is specific type check, solution is specific fix

## PHASE 6: FORMAL CONCLUSION

By P1-P5 and C1-C3:

The root cause of the bug is a **too-narrow type check** at `django/db/models/query.py:674`. The code checks `isinstance(attr, Expression)` to determine whether to wrap the attribute value in a `Value()` object. However:

1. `F('name')` is a `Combinable` (expressions.py:582), NOT an `Expression` (expressions.py:394)
2. The `isinstance(attr, Expression)` check returns `False` for plain F objects
3. This causes the code to incorrectly wrap F('name') in `Value(F('name'), ...)`, which converts the F object to the string representation `'F(name)'`
4. The existing test with `F('num') + 1` passes because `CombinedExpression` IS an `Expression`, so it bypasses the Value wrapping

The fix is to replace the type check with duck typing: `if not hasattr(attr, 'resolve_expression'):`, which is the pattern already used in `Combinable._combine()` (expressions.py:59) and is the canonical way to check if something is expression-like in the Django codebase.

**CONFIDENCE: HIGH**

---

## LOCALIZATION:

**FILE**: django/db/models/query.py
**FUNCTION**: QuerySet.bulk_update

**SPECIFIC LINE**: Line 674 (the conditional check)

The exact change needed is on line 674:
- Current: `if not isinstance(attr, Expression):`
- Fix to: `if not hasattr(attr, 'resolve_expression'):`
