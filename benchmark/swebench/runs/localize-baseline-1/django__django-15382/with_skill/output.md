Based on my systematic localization analysis using the agentic-code-reasoning skill's `localize` mode, I have identified the root cause of bug #15382.

## Summary of Findings

**PHASE 1 & 2: Test Semantics & Code Path Tracing**
- The failing test `test_negated_empty_exists` expects `filter(~Exists(empty_qs), name='test')` to work correctly
- Semantically: `~Exists(empty_qs)` is TRUE (NOT EXISTS of empty = true), so the filter should be: WHERE name='test'
- The bug occurs because `EmptyResultSet` exceptions from the empty subquery propagate unhandled

**PHASE 3: Divergence Analysis**
- The exception propagates through: NothingNode.as_sql() → WhereNode (empty query) → Subquery.as_sql() → **Exists.as_sql()** → WhereNode (main query) → compiler.as_sql()
- The critical issue is at **Exists.as_sql()** line 1212-1221, which does NOT catch `EmptyResultSet` from `super().as_sql()`
- Without catching it, the exception breaks the entire WHERE clause

**PHASE 4: Root Cause vs Symptom**
- **Root Cause**: `Exists.as_sql()` doesn't handle `EmptyResultSet` 
- **Symptom Site**: `WhereNode.as_sql()` at line 95-99 where it raises the exception that breaks the query

**PHASE 5: Refutation Check**
- No evidence found that this is intentional or that WhereNode can distinguish negated expressions
- The fix IS needed in `Exists.as_sql()`

---

## LOCALIZATION:

FILE: `django/db/models/expressions.py`
FUNCTION: `Exists.as_sql`

The root cause is in the `Exists.as_sql()` method (lines 1212-1221) which fails to catch `EmptyResultSet` exceptions from `super().as_sql()`. When the subquery is empty, an `EmptyResultSet` is raised and propagates uncaught, causing the entire WHERE clause to fail. The fix should catch `EmptyResultSet` at this location and return `'', ()` when `self.negated` is True (meaning NOT EXISTS of empty = TRUE, matches everything).
