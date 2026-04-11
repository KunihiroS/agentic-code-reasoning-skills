# Iteration 49 — 変更理由

## 前イテレーションの分析

- 前回スコア: 85% (17/20)
- 失敗ケース: 15368, 13821, 11433
- 失敗原因の分析:
  - **15368**: Patch B がテストを削除しており、削除されたテストをそのまま counterexample に採用したため誤判定（EQUIV → NOT_EQUIVALENT）
  - **13821**: 「SQLite 3.9.0–3.25.x という特定バージョン範囲でのみ異なる挙動」を counterexample に使用したが、その環境前提はリポジトリのテストの skip 条件・fixtures・CI 設定に存在しない未検証前提であり、EQUIV → NOT_EQUIVALENT と誤判定
  - **11433**: 31 ターン消費後に収束失敗（UNKNOWN）

## 改善仮説

13821 の誤判定は「SQLite 3.9.0–3.25.x」という特定バージョン範囲でのみ異なる挙動を counterexample として使ったことが原因である。この環境前提はリポジトリのテストに存在しないにもかかわらず VERIFIED 証拠として扱われた。現行 Guardrail 6 が「ソース非公開の関数挙動の推測を禁止」しているように、実行環境バージョン固有の挙動の仮定も「未検証前提」として禁止する Guardrail を追加することで、この種の誤判定を防げる。

## 変更内容

`## Guardrails` → `### From the paper's error analysis` セクションの末尾（項目 6 の直後）に項目 10 を追加した（3 行）。

> 10. **Do not use unverified runtime-environment claims as evidence.** If a behavioral difference between changes is attributed to a specific database version, OS, interpreter version, or library version, that version constraint must be explicitly encoded in the test's skip decorators, setup fixtures, or CI configuration, cited at a specific file:line. A version range or environment assumption that cannot be grounded in the repository is UNVERIFIED and must not determine EQUIVALENT or NOT_EQUIVALENT conclusions.

既存行の変更・削除なし。新規セクション追加なし。

## 期待効果

- **13821（改善見込み）**: 「SQLite 3.9.0–3.25.x」のバージョン前提が file:line で検証されなければ UNVERIFIED と判定され counterexample として使用不可となる。誤った NOT_EQUIVALENT 結論が防がれ、EQUIVALENT に正しく収束する可能性が高い。
- **その他ケース（影響軽微）**: Django テストスイートでは環境依存テストは `@skipIf` や `@skipUnlessDBFeature` 等で明示されており、file:line 検証を自然に満たす。真の NOT_EQUIVALENT ケースへの影響はない。
- **全体予測**: 85%（17/20）→ 90%（18/20）
