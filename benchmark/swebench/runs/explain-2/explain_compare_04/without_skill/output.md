The root cause is that NodeBB’s hash adapters only implement **single-field increments** per call, and the bulk API the issue asks for does not exist in the base implementation.

### What the current code does

In the existing adapters, `incrObjectFieldBy` accepts only:

- one `key`
- one `field`
- one `value`

and then performs exactly one increment map:

- **MongoDB** builds `{ $inc: { [field]: value } }` and, for array keys, just repeats that same single-field increment for each key.  
  See `src/database/mongo/hash.js` in the existing implementation around the `incrObjectFieldBy` helper: it sets `increment[field] = value` and then either `bulk.find({ _key: key }).upsert().update({ $inc: increment })` for each key or `findOneAndUpdate` for a single key.  
  Evidence from the code path is shown in the diff hunk at `@@ -828, ... @@` in `benchmark/.../without_skill/prompt.txt`.

- **Redis** has the same shape: `incrObjectFieldBy(key, field, value)` and the array-key path just does `batch.hincrby(k, field, value)` for each key.  
  See the hunk at `@@ -1472, ... @@` in `benchmark/.../without_skill/prompt.txt`.

- **PostgreSQL** also only exposes `incrObjectFieldBy`; there is **no `incrObjectFieldByBulk`** in the base code. The fix adds that method at `src/database/postgres/hash.js` (`@@ -372,4 +372,17 @@`), which implies it was missing before.

### How this leads to the bug

Because the codebase has no native bulk increment path:

1. callers must do increments **one field at a time** and **one object at a time**, or loop externally;
2. that causes extra round trips / latency;
3. coordinated multi-field updates across many objects cannot be expressed as one operation;
4. on PostgreSQL, calling the new bulk API fails outright because the method does not exist.

### Bottom line

The issue is caused by the **absence of a bulk increment implementation** and by the fact that the existing increment helpers are designed around a **single field per call**. That design is why the current behavior is slow for scale and why the bulk test fails.
