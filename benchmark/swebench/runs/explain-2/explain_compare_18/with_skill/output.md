Selected mode: **explain**

QUESTION: What code paths and logic are responsible for `rules.segment` only accepting a string, not a nested object with `keys` and `operator`?

PREMISES:
P1: The user is asking about the YAML/document format for `flags[].rules[]`, not the top-level app config.
P2: The repository has two relevant file-based paths for this format: CLI import/export and filesystem snapshot loading.
P3: The current code already supports multiple segment references at the API/storage layer via `segmentKey` / `segmentKeys`; the likely limitation is in the YAML document model and its mapping code.
P4: A nested `segment: { keys, operator }` shape exists for rollouts, so that shape is a useful comparison point.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `snapshotFromReaders` | `internal/storage/fs/snapshot.go:104-131` | `(...io.Reader)` | `(*storeSnapshot, error)` | Decodes YAML into `ext.Document` with `yaml.v3`, normalizes empty namespace to `"default"`, then calls `addDoc`. |
| `(*storeSnapshot).addDoc` | `internal/storage/fs/snapshot.go:140-355` | `(*ext.Document)` | `error` | Builds rules from `ext.Rule.SegmentKey`, `ext.Rule.SegmentKeys`, and `ext.Rule.SegmentOperator`; there is no branch for a nested rule-segment object. |
| `(*Importer).Import` | `internal/ext/importer.go:60-381` | `(context.Context, io.Reader)` | `error` | Decodes YAML into `ext.Document`, then converts each `ext.Rule` into `CreateRuleRequest` using either `SegmentKey` or `SegmentKeys`; rejects both together. |
| `(*Exporter).Export` | `internal/ext/exporter.go:52-190` | `(context.Context, io.Writer)` | `error` | Writes rules back to YAML using `Rule.SegmentKey` or `Rule.SegmentKeys`; writes rollouts using nested `SegmentRule`. |
| `(*CreateRuleRequest).Validate` | `rpc/flipt/validation.go:182-199` | `(*CreateRuleRequest)` | `error` | Requires exactly one of `SegmentKey` or `SegmentKeys`; no nested object shape is modeled. |
| `sanitizeSegmentKeys` | `internal/storage/sql/common/util.go:47-58` | `(string, []string)` | `[]string` | Collapses the request’s singular/plural segment fields into a deduplicated slice for persistence. |
| `(*Store).CreateRule` | `internal/storage/sql/common/rule.go:366-437` | `(*flipt.CreateRuleRequest)` | `(*flipt.Rule, error)` | Persists segment references into `rule_segments`, then returns `Rule.SegmentKey` or `Rule.SegmentKeys` depending on count. |
| `(*Store).UpdateRule` | `internal/storage/sql/common/rule.go:439-515` | `(*flipt.UpdateRuleRequest)` | `(*flipt.Rule, error)` | Updates `segment_operator`, rewrites `rule_segments`, then reloads the rule. |
| `flipt.Rule` / `CreateRuleRequest` schema | `rpc/flipt/flipt.proto:384-423` | N/A | N/A | `Rule` and `CreateRuleRequest` contain `segment_key`, `segment_keys`, and `segment_operator`; there is no object-typed `segment` field for rules. |
| `RolloutSegment` schema | `rpc/flipt/flipt.proto:350-358` | N/A | N/A | The nested object form (`segment` with keys/operator/value) exists for rollouts, not rules. |

DATA FLOW ANALYSIS:
Variable: `ext.Rule.SegmentKey`
  - Created at: `internal/ext/common.go:28-33`
  - Modified at: `internal/ext/importer.go:266-267`, `internal/storage/fs/snapshot.go:299-300`, `internal/ext/exporter.go:133-137`
  - Used at: `internal/ext/importer.go:258-277`, `internal/storage/fs/snapshot.go:318-322`, `internal/ext/exporter.go:133-137`
  - Meaning: the scalar YAML key `segment` for rules.

Variable: `ext.Rule.SegmentKeys`
  - Created at: `internal/ext/common.go:28-33`
  - Modified at: `internal/ext/importer.go:268-276`, `internal/storage/fs/snapshot.go:299-300`, `internal/ext/exporter.go:133-137`
  - Used at: `internal/ext/importer.go:258-277`, `internal/storage/fs/snapshot.go:318-322`, `internal/ext/exporter.go:133-137`
  - Meaning: the plural YAML key `segments` for rules.

Variable: `segmentKeys` in `sanitizeSegmentKeys`
  - Created at: `internal/storage/sql/common/util.go:47-58`
  - Modified at: `internal/storage/sql/common/util.go:51-55`
  - Used at: `internal/storage/sql/common/rule.go:368-433`, `:441-514`
  - Meaning: the normalized slice sent to the DB.

SEMANTIC PROPERTIES:
Property 1: Rules YAML is modeled as scalar/list, not nested object.
- Evidence: `internal/ext/common.go:28-33` defines `Rule.SegmentKey string yaml:"segment,omitempty"` and `Rule.SegmentKeys []string yaml:"segments,omitempty"`.
- Evidence: `internal/ext/importer.go:258-277` reads only those two fields and never looks for `segment.keys` or `segment.operator`.

Property 2: Multiple segment references are already supported after parsing.
- Evidence: `rpc/flipt/validation.go:182-199` accepts either `SegmentKey` or `SegmentKeys`.
- Evidence: `internal/storage/sql/common/util.go:47-58` turns either form into a slice.
- Evidence: `internal/storage/sql/common/rule.go:398-436` stores each segment key in `rule_segments`.

Property 3: The nested object shape already exists, but only for rollouts.
- Evidence: `internal/ext/common.go:41-52` defines `Rollout.Segment *SegmentRule` with `Key`, `Keys`, `Operator`, `Value`.
- Evidence: `internal/ext/importer.go:334-364` maps `rollouts.segment.keys` and `rollouts.segment.operator` into `RolloutSegment`.
- Evidence: `internal/ext/exporter.go:166-180` reconstructs the nested rollout segment object on export.

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, I would expect to find a rules-side nested segment struct or parsing branch.
- Searched for: `segment.keys`, `segment.operator`, `SegmentRule`, and nested rule-shaped parsing under `rules`
- Found: those patterns only in rollout code paths and rollout schema, not in rule parsing (`internal/ext/importer.go:334-364`, `internal/ext/exporter.go:166-180`, `internal/ext/common.go:41-52`)
- Conclusion: REFUTED — the nested object form is not implemented for rules.

FINAL ANSWER:
The behavior is caused by the **file/document model**, not by rule evaluation logic.

Specifically:

1. **The YAML rule schema is hard-coded as two separate fields**:
   - `segment` → `ext.Rule.SegmentKey string`
   - `segments` → `ext.Rule.SegmentKeys []string`
   in `internal/ext/common.go:28-33`.

2. **Both YAML entry points consume that exact shape**:
   - CLI import: `(*Importer).Import` decodes into `ext.Document` and only maps `SegmentKey` / `SegmentKeys` into `CreateRuleRequest` (`internal/ext/importer.go:60-77`, `:251-277`).
   - Filesystem snapshot loading: `snapshotFromReaders` decodes into `ext.Document`, and `addDoc` copies only `SegmentKey` / `SegmentKeys` into `flipt.Rule` (`internal/storage/fs/snapshot.go:104-131`, `:293-355`).

3. **The API/storage layer already supports multiple segment refs**:
   - `CreateRuleRequest.Validate` accepts either singular or plural, and `sanitizeSegmentKeys` + `Store.CreateRule` persist them (`rpc/flipt/validation.go:182-199`, `internal/storage/sql/common/util.go:47-58`, `internal/storage/sql/common/rule.go:366-436`).
   - So the limitation is **not** in the database or request validation; it is in the YAML document shape and its import/export mapping.

4. **The nested object form already exists only for rollouts**, via `SegmentRule` (`internal/ext/common.go:41-52`) and its importer/exporter handling (`internal/ext/importer.go:334-364`, `internal/ext/exporter.go:166-180`).

So the exact code paths responsible are:
- `internal/ext/common.go` rule struct tags,
- `internal/ext/importer.go` and `internal/storage/fs/snapshot.go` rule conversion,
- `rpc/flipt/validation.go` / `internal/storage/sql/common/*` for the already-supported singular/plural backend model.

In short: **rules currently support `segment` as a string and `segments` as a list; there is no code path that interprets `rules.segment` as an object with `keys` and `operator`.**

CONFIDENCE: HIGH
