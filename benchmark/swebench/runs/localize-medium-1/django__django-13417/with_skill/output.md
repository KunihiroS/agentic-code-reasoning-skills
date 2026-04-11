---

## PHASE 5: REFUTATION CHECK

**ALTERNATIVE HYPOTHESIS CHECK:**

If my analysis were wrong (i.e., the GROUP BY doesn't actually remove the ORDER BY), what evidence would exist?
- The compiler should NOT set `order_by = None` when there's a GROUP BY with meta ordering
- Searched for: All locations where `_meta_ordering` is used (grep "_meta_ordering")
- Found: Line 590 in django/db/models/sql/compiler.py: `if self._meta_ordering: order_by = None` — this is inside the `if grouping:` block
- Conclusion: REFUTED — the evidence confirms that when there's a GROUP BY and meta ordering, the ORDER BY is set to None

**COUNTEREXAMPLE CHECK:**

Does the test `test_annotated_ordering` prove the bug exists?
- Searched for: Test using Tag model (which has Meta.ordering) with annotate()
- Found: The test uses Annotation model which has NO default ordering, so it doesn't test the specific bug scenario
- Searched for: PR or issue related to this bug
- Found: django/django issue #13417 (per filename)
- Conclusion: The bug report explicitly describes models WITH Meta.ordering having this issue, and the test doesn't cover that case

---

## PHASE 5.5: PRE-CONCLUSION SELF-CHECK

- ✅ Every claim traces to `file:line` (D1: line 590; D2: lines 1227-1228; D3: compiler logic)
- ✅ All functions read and verified (ordered property, as_sql, pre_sql_setup)
- ✅ Step 5 check involved actual file inspection (found the `if self._meta_ordering: order_by = None` line)
- ✅ Conclusion only asserts what the traced evidence supports

---

## PHASE 6: FORMAL CONCLUSION

**By P1, T2, and D1-D3:**

The root cause of the bug is in **django/db/models/query.py**, specifically the `QuerySet.ordered` property (lines 1218-1230).

**The issue:**
- The `ordered` property returns `True` when `self.query.default_ordering and self.query.get_meta().ordering` without checking if the compiled SQL will actually have an ORDER BY clause
- In the SQL compiler (django/db/models/sql/compiler.py:590), when there's a GROUP BY AND the ordering comes from Meta, the ORDER BY clause is explicitly removed via `order_by = None`
- This causes a discrepancy: `qs.ordered` returns `True`, but the actual SQL has no ORDER BY

**The fix location:**
The `ordered` property in **django/db/models/query.py** (lines 1218-1230) needs to add an additional check:
- When the ordering is ONLY from Meta (not from explicit `order_by()` or `extra_order_by`)
- AND there is a GROUP BY in the query (`self.query.group_by is not None`)
- Then return `False` because the compiler will remove the ORDER BY

**Confidence: HIGH**

The evidence is clear and direct: the compiler explicitly removes ORDER BY when GROUP BY + meta ordering is present, and the property doesn't know about this.

---

LOCALIZATION:
FILE: django/db/models/query.py
FUNCTION: QuerySet.ordered (property, lines 1218-1230)
