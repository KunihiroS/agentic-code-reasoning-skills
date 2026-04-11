| # | METHOD | LOCATION | BEHAVIOR | RELEVANT |
|---|--------|----------|----------|----------|
| 1 | Model.delete(self, using, keep_parents) | django/db/models/base.py:910 | Instantiates Collector, calls collect() and delete() | Entry point for user code |
| 2 | Collector.collect(objs, source, nullable, collect_related, source_attr, reverse_dependency, keep_parents) | django/db/models/deletion.py:193 | Recursively gathers objects to be deleted; may trigger fast_delete path | Determines if fast_delete is possible |
| 3 | Collector.can_fast_delete(objs, from_field) | django/db/models/deletion.py:127 | Returns True if obj(s) can be fast-deleted (no cascades, no signal listeners, no parent/child relationships) | Determines eligibility for fast delete |
| 4 | Collector.delete() | django/db/models/deletion.py:257 | Main deletion orchestration; has two paths: fast-delete (lines 274-279) and normal (lines 280-327) | WHERE THE BUG IS |

## PHASE 3: DIVERGENCE ANALYSIS

Let me examine both paths in Collector.delete():

**FAST-DELETE PATH (lines 274-279):**

```python
# Optimize for the case with a single obj and no dependencies
if len(self.data) == 1 and len(instances) == 1:
    instance = list(instances)[0]
    if self.can_fast_delete(instance):
        with transaction.mark_for_rollback_on_error():
            count = sql.DeleteQuery(model).delete_batch([instance.pk], self.using)
        return count, {
