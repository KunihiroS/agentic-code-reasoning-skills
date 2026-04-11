# Iteration 13 — 変更理由

## 前イテレーションの分析

- 前回スコア: 80% (16/20)
- 失敗ケース: django__django-15368, django__django-13821, django__django-15382, django__django-12663
- 失敗原因の分析:
  - **15368（持続的失敗）**: EQUIVALENT なのに NOT_EQUIVALENT と誤判定（16 ターン）。Patch B がテストメソッドを削除するケース。iter-10 の D2 注記「削除されたテストには結果がない」を経ても改善されず。エージェントは「削除されたテスト → pytest が collection error を出す → FAIL」という独自のフレームワーク解釈を適用し、D2 注記を上書きしている。
  - **13821（持続的失敗）**: EQUIVALENT なのに NOT_EQUIVALENT と誤判定（22 ターン）。Patch A は SQLite のバージョンチェックを更新し、Patch B は同チェック更新に加えて feature フラグを動的チェックからハードコード True に変更する。エージェントは「最小バージョン 3.9.0 の環境で SQLite 3.10.0 上で実行した場合、Patch B では feature フラグが True になり、3.10.0 では未対応の機能テストが SKIP ではなく FAIL になる」という仮想環境（SQLite 3.10.0）を構築して NOT_EQUIVALENT と結論づけた。しかし実際のテスト実行環境が 3.10.0 であることを示す証拠はどこにも存在しない。
  - **15382（持続的失敗）**: EQUIVALENT なのに NOT_EQUIVALENT と誤判定（20 ターン）。エージェントが Patch B のコードを誤トレースし、`WHERE 1=0` を返すと誤結論（HIGH 信頼度）。ground truth は EQUIVALENT であり、実際には両パッチはテスト結果に差異をもたらさない。
  - **12663（持続的失敗）**: NOT_EQUIVALENT なのに UNKNOWN（31 ターン、is_error: True）。iter-11 の「UNKNOWN 禁止」チェックリスト追加と iter-12 の「反例確認後 STOP」追加にもかかわらず、31 ターンで API エラーとなり有効な回答を返せなかった。ターン上限に到達している可能性が高い。

  **重要な観察**: 4 件の失敗のうち 3 件（15368, 13821, 15382）は全て EQUIVALENT なのに NOT_EQUIVALENT と誤判定するパターンである。13821 の失敗原因は明確に「仮想テスト環境の構築による反例の捏造」であり、これは他の2件とは異なる独立した失敗モードである。今回はこの失敗モードを対象とする。

## 改善仮説

**Guardrails セクションに「仮想テスト環境を反例の根拠にしてはならない」という汎用的なガードレール（Guardrail 10）を追加することで、13821 のような「実際には存在しない環境での動作差異に基づく誤った NOT_EQUIVALENT 判定」を汎用的に防止できる。**

根拠:
- 13821 において、エージェントは P3「最小 SQLite バージョン 3.9.0」という前提から「SQLite 3.10.0 環境」という仮想シナリオを構築した。この環境がリポジトリの実際のテスト環境であることを示す証拠（CI 設定、tox.ini、requirements ファイル等）は一切確認されていない。
- D1 の定義「関連するテストスイートを実行した際に同一の PASS/FAIL 結果を生む」は、「実際のテスト環境での実行」を前提としており、「考えられるあらゆる環境での実行」ではない。しかし現在の SKILL.md には「仮想環境を反例として使ってはならない」という明示的な制約がない。
- 「テスト結果の差異は実際のテスト環境で発生するものに限定する」という原則は、データベースバージョン、OS バージョン、Python バージョン、ライブラリバージョン等、あらゆる環境依存のコードに適用可能な汎用的な推論規律である。特定のベンチマークケースに依存しない。
- この変更は NOT_EQUIVALENT 判定（COUNTEREXAMPLE セクションを使うケース）の一部にのみ影響し、EQUIVALENT 判定（NO COUNTEREXAMPLE EXISTS セクション）や他のモードには影響しない。

## 変更内容

Guardrails セクションの General 部分に Guardrail 10 を追加:

```
10. **Do not construct counterexamples using hypothetical test environments.**
    A counterexample asserting test outcome differences must be grounded in
    the repository's actual test environment — not in environments that
    *could* exist (e.g., a database version between an old minimum and a new
    minimum, or a runtime version not pinned by the project). If a behavioral
    difference only manifests on a version, platform, or configuration not
    established by the test setup (CI config, tox.ini, pinned requirements,
    version constraint files), do not treat it as a confirmed counterexample.
    Instead, determine the actual environment from available configuration
    files, or mark the claim UNVERIFIED and set CONFIDENCE to LOW.
```

変更規模: 7 行追加（≤ 20 行の制約内）。

## 期待効果

- **13821**: Guardrail 10 により、エージェントが「SQLite 3.10.0 仮想環境」のような、リポジトリの設定ファイルに根拠のない仮想環境を反例として使用できなくなる。エージェントは実際の CI 設定（存在すれば）を確認するか、環境不明として LOW 信頼度で処理することを強制される。ground truth が EQUIVALENT であることから、実際の環境では両パッチの動作は同一であり、正しく EQUIVALENT と判定できることを期待する。
- **15368, 15382**: 本イテレーションの主仮説ではなく（これらはフレームワーク解釈誤りとコードトレース誤りであり異なる失敗モード）、今回の変更では直接的な改善を期待しない。
- **12663**: 本イテレーションの変更は 12663 の推論に無関係（ターン枯渇によるエラー）のため、影響なし。
- **回帰リスク**: Guardrail 10 はガードレールセクションへの追記のみであり、compare モードの探索プロセス・証明書テンプレート・反証プロセスに変更を加えない。仮想環境を反例として使用していない 16 件の正解ケースには影響しないため、回帰リスクは極めて低い。
