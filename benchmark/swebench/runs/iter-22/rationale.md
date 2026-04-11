# Iteration 22 — 変更理由

## 前イテレーションの分析

- 前回スコア: 85% (17/20)
- 失敗ケース: django__django-15368, django__django-15382, django__django-14787
- 失敗原因の分析:

  **失敗パターンの内訳:**
  - EQUIVALENT → NOT_EQUIVALENT（1 件）: 15368
  - EQUIVALENT → UNKNOWN（1 件）: 15382（31 ターン消費）
  - NOT_EQUIVALENT → EQUIVALENT（1 件）: 14787

  **15368（EQUIVALENT → NOT_EQUIVALENT、持続的失敗）:**
  - ほぼ全イテレーションで失敗し続けている最古の失敗ケース。
  - 失敗パターン: エージェントが2つのパッチ間に意味的差異（semantic difference）を発見した後、その差異が既存テストの実行経路で実際に影響するか確認せずに NOT_EQUIVALENT と結論付ける「浅い反例（shallow counterexample）」。
  - 現在の Guardrail #4「Do not dismiss subtle differences」は逆方向（差異を過小評価して EQUIVALENT と誤判定）を防ぐものであり、この「差異を過大評価して NOT_EQUIVALENT と誤判定」には対応していない。
  - Compare テンプレートの COUNTEREXAMPLE セクションは「Test [name] will PASS/FAIL...」という形式を要求しているが、エージェントは意味的差異を根拠に結論を出し、テストの完全トレースをスキップする傾向がある。

  **15382（EQUIVALENT → UNKNOWN）:**
  - iter-21 で追加されるべきだった Guardrail #10（コミット義務）が SKILL.md に反映されていなかったため、UNKNOWN 禁止の指針が欠如した状態で実行された。
  - Guardrail #10 の復元により改善が期待される。

  **14787（NOT_EQUIVALENT → EQUIVALENT）:**
  - エージェントが実際に存在する差異を見逃したケース。今回の仮説の直接対象ではない（別イテレーションで対処）。

  **今回の焦点:**
  - 3 件のうち、15368 は最も長期にわたる持続的失敗であり、かつ Guardrail #4 と対称な原則を追加するだけで解決可能な構造的問題。これを今回の改善仮説とする。

## 改善仮説

**意味的差異の発見は NOT_EQUIVALENT の結論に十分ではない。差異がテストの実行経路に到達し、テスト結果を変化させることを確認するまで COUNTEREXAMPLE を宣言してはならない、という対称ガードレールを追加することで、15368 パターンの「浅い反例」による誤判定を防ぐことができる。**

根拠:
- Guardrail #4 は「差異を見つけたらテストに影響がないと言う前にトレースせよ」（差異を過小評価して EQUIVALENT に誤判定するパターンを防ぐ）。
- 今回追加する Guardrail #11 はその対称版:「差異を見つけてもテスト影響を確認するまで NOT_EQUIVALENT と言うな」（差異を過大評価して NOT_EQUIVALENT に誤判定するパターンを防ぐ）。
- この原則はどのプログラミング言語・フレームワークにも適用可能な汎用的な推論規律であり、overfitting ではない。
- Guardrail #10（コミット義務、iter-21 設計分）も同時に復元することで、UNKNOWN=0 だった iter-21 設計の成果を引き継ぐ。

## 変更内容

Guardrails セクションの「General」節にガードレール #10 と #11 を 2 行追加。

```diff
 9. Do not skip the refutation check. It is mandatory in every mode.
+10. **Commit to a conclusion.** Do not answer UNKNOWN. When evidence is incomplete or exhausted before full tracing is possible, answer with the strongest conclusion the traced evidence supports and assign LOW confidence. An incomplete trace that strongly favors one answer is more useful than no answer.
+11. **Do not conclude NOT_EQUIVALENT from semantic differences alone.** A semantic difference between two patches is necessary but not sufficient for NOT_EQUIVALENT. Before writing a COUNTEREXAMPLE claim, trace at least one specific existing test through the diverging code path in both changes and confirm the test outcome actually differs. A semantic difference that no existing test exercises does not constitute a counterexample.
```

変更規模: 2 行追加（≤ 20 行の制約内）。  
変更箇所: Guardrails の General 節のみ。テンプレート・ステップ・他モードへの影響なし。

- **Guardrail #10**: iter-21 で設計・検証済みのガードレール（UNKNOWN 禁止、コミット義務）。SKILL.md に未反映だったため復元。
- **Guardrail #11**: iter-22 の新仮説。Guardrail #4 の対称版として「浅い反例」パターンを防ぐ。

## 期待効果

- **15368（EQUIVALENT → NOT_EQUIVALENT 誤判定 → 正解を期待）**: Guardrail #11 により、意味的差異を発見した後も具体的なテストをトレースしてテスト結果が変わることを確認するまで COUNTEREXAMPLE を宣言できなくなる。15368 は意味的差異を根拠に浅く結論していたため、このガードレールで NOT_EQUIVALENT への誤判定が抑制される可能性が高い。
- **15382（EQUIVALENT → UNKNOWN → 正解を期待）**: Guardrail #10（コミット義務）の復元により、31 ターンを消費しても UNKNOWN ではなく LOW confidence の YES/NO にコミットするよう誘導される。
- **14787（NOT_EQUIVALENT → EQUIVALENT 誤判定）**: 今回の仮説の直接対象ではないが、Guardrail #11 は EQUIVALENT 誤判定を防ぐものではなくターゲット外。回帰リスクは低い。
- **回帰リスク**: Guardrail #10 は iter-21 設計で検証済み（意図的な UNKNOWN=0 達成実績）。Guardrail #11 は「COUNTEREXAMPLE 宣言前に必ずテストトレース」を要求するだけであり、現在の 17 件の正解（特に NOT_EQUIVALENT 10 件）はすでに適切なテストトレースを行っているため悪化しない可能性が高い。
