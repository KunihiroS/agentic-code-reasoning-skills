# Iteration 36 — 変更理由

## 前イテレーションの分析

- 前回スコア: 85%（17/20）
- 失敗ケース: 15368, 13821, 11433
- 失敗原因の分析:
  - **15368**: Patch B がテストファイルから約 14 件のテストを削除。エージェントはその削除を「テストが実行されなくなる = NOT_EQ の反例」として即断したが、それらのテストが変更コード（`BaseDatabaseSchemaEditor`）のコールパス上にあったかを確認しなかった。証拠採用前の情報収集が不足していた。
  - **13821**: 「SQLite 3.9.0–3.25.x という仮想環境」でのみ異なる挙動を COUNTEREXAMPLE として採用した。実際の CI は SQLite >= 3.26.0 であり、D2 に列挙されていない環境仮定を証拠に使った。
  - **11433**: 31 ターン消費後に収束失敗。本イテレーションの主対象外。

## 改善仮説

Compare checklist に 1 項目を追加し、「削除・スキップされたテストをリポジトリ確認なしに counterexample として採用する」という短絡を防ぐ。

具体的には、どちらかの patch がテストを削除またはスキップしている場合、そのテストが変更コードのコールパス上にあったかをリポジトリ検索で確認することを義務付ける。確認できた場合は依然として有効な counterexample として使える。確認できなかった場合は P[N] の scope constraint として記録し、counterexample には使わない。

これは D2 の定義を変えず、**証拠採用前の情報取得改善**（カテゴリ B）として実現する。

## 変更内容

Compare checklist の既存項目「When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact」の直後に 1 行追加:

```
- If either patch removes or skips a test, search the repository to confirm that test called the changed code path before treating it as a counterexample; if unconfirmed, record it as a scope constraint in P[N] instead
```

- 追加: 1 行
- 削除: 0 行
- 影響範囲: Compare checklist のみ

## 期待効果

- **EQUIV 偽陰性の抑制（15368 パターン）**: テスト削除・スキップを発見したとき、エージェントが変更コードへの call path をリポジトリ検索で確認することが強制される。変更コードを呼び出していないことが判明した場合、counterexample として採用せずに P[N] 制約として記録することで、誤った NOT_EQUIVALENT 判定を防げる。
- **NOT_EQ 正答の維持**: 真の NOT_EQ ケースでテスト削除が反例になるとしても、変更コードを exercise しているテストの削除であれば、リポジトリ検索で確認できる。確認できれば依然として有効な counterexample として使えるため、NOT_EQ 側の正答率に対する影響は最小限。
- **全体予測**: EQUIV 正答率 80% → 85–90%、NOT_EQ 正答率 100% → 95–100%、全体 85% → 88–90%。
