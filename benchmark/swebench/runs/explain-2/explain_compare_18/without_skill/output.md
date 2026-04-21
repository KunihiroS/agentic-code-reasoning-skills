The behavior comes from the whole “rules config → importer/exporter → RPC/storage” pipeline, which models rule segments as **string/list fields**, not as an object.

### 1) The YAML model for rules only defines a scalar `segment` field
In `internal/ext/common.go:28-33`, the rule config type is:

```go
type Rule struct {
    SegmentKey      string          `yaml:"segment,omitempty"`
    Rank            uint            `yaml:"rank,omitempty"`
    SegmentKeys     []string        `yaml:"segments,omitempty"`
    SegmentOperator string          `yaml:"operator,omitempty"`
    Distributions   []*Distribution `yaml:"distributions,omitempty"`
}
```

So `rules[].segment` is backed by `string`, and the alternate multi-segment form is a separate `segments:` list. There is **no object type** for `rules[].segment` here.

For contrast, the code **does** define an object-shaped segment for rollouts:

- `internal/ext/common.go:41-52`  
  `Rollout.Segment` is `*SegmentRule`, which has `Key`, `Keys`, `Operator`, and `Value`.

That explains why object syntax exists for rollouts but not for rules.

---

### 2) Import path: YAML is decoded into that struct, then mapped only from string/list fields
The import command uses `internal/ext/importer.go`:

- `cmd/flipt/import.go` calls `ext.NewImporter(...).Import(...)`
- `internal/ext/importer.go:60-67` decodes YAML into `ext.Document`
- `internal/ext/importer.go:251-277` builds `flipt.CreateRuleRequest` from only:
  - `r.SegmentKey` → `SegmentKey`
  - `r.SegmentKeys` → `SegmentKeys`

It also explicitly rejects having both:

- `internal/ext/importer.go:258-264`

And it only allows `segments` in version 1.2+:

- `internal/ext/importer.go:268-276`

So even in the importer, rules are only handled as **string or list**, never as a nested object.

---

### 3) File-system snapshot import uses the same model and the same logic
The FS snapshot loader also decodes into `ext.Document`:

- `internal/storage/fs/snapshot.go:114-127`

Then, when it constructs rules, it again copies only:

- `internal/storage/fs/snapshot.go:293-354`

Specifically:

- `r.SegmentKey`
- `r.SegmentKeys`
- `r.SegmentOperator`

There is no branch that interprets `rules[].segment` as a map/object there either.

---

### 4) Export path only writes back the string/list forms for rules
The exporter reverses the same model:

- `internal/ext/exporter.go:118-150`

For each rule it does:

- if `r.SegmentKey != ""` → write `segment: <string>`
- else if `len(r.SegmentKeys) > 0` → write `segments: [...]`

And for operator:

- `internal/ext/exporter.go:139-141` writes the operator only when it is `AND`

Again, no object form is emitted for rules.

For rollouts, though, the exporter does emit the object form through `SegmentRule`:

- `internal/ext/exporter.go:166-180`

---

### 5) The underlying API/storage contract also expects key(s), not an object
The protobuf/API layer for rules only supports:

- `rpc/flipt/flipt.proto:416-423`  
  `CreateRuleRequest` has `segment_key` and `segment_keys`

Validation enforces exactly one of those:

- `rpc/flipt/validation.go:182-199`

And SQL storage normalizes those fields with:

- `internal/storage/sql/common/util.go:47-56` → `sanitizeSegmentKeys(...)`
- `internal/storage/sql/common/rule.go:367-417` → persists the normalized keys

So the rest of the stack is built around **segment key(s) + operator**, not a nested `segment` object.

---

## Bottom line
The behavior is caused by these code paths:

1. **Config model**: `internal/ext/common.go:28-33`  
   `rules[].segment` is a `string`, not a union/object.
2. **Import path**: `internal/ext/importer.go:60-67`, `251-277`  
   Only `SegmentKey` / `SegmentKeys` are consumed.
3. **FS snapshot import**: `internal/storage/fs/snapshot.go:114-127`, `293-354`  
   Same decoding and same rule mapping.
4. **Export path**: `internal/ext/exporter.go:118-150`  
   Only string/list forms are written for rules.
5. **RPC/storage contract**: `rpc/flipt/flipt.proto:416-423`, `rpc/flipt/validation.go:182-199`, `internal/storage/sql/common/util.go:47-56`

And importantly: the **object-shaped `segment` syntax already exists for rollouts** (`SegmentRule`), which is why the requested rule behavior is inconsistent with the current code.
