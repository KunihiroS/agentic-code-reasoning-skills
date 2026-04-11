# Iteration 23 — 変更理由

## 前イテレーションの分析

- 前回スコア: 85% (17/20)
- 失敗ケース: django__django-15368, django__django-15382, django__django-14787
- 失敗原因の分析:

  **持続的失敗ケース（EQUIV 3 件）の共通パターン:**
  - エージェントが Compare テンプレートの `because [trace through code — cite file:line]` 指示に従ってトレースする際、assert 文の前後だけをトレースして満足する傾向がある。
  - その結果、例外・setup/teardown 失敗・副作用・後続検査など、assert 以外のテスト結果決定要因を見落とし、pass/fail 判定を誤る。
  - 特に EQUIV ケース（正答 EQUIVALENT に対して NOT_EQUIVALENT と誤判定）では、「コード差異を発見 → その差異が assert に届くと推論 → NOT_EQ」というショートカットが繰り返されている。

## 改善仮説

Compare テンプレートの `ANALYSIS OF TEST BEHAVIOR` における `because [trace through code — cite file:line]` という指示は、「何をトレースするか」を限定していない。現状の文言では assert 文前後のコードだけをトレースしても形式上要件を満たせてしまい、例外・setup/teardown 失敗・副作用・control-flow 分岐など assert 以外のテスト結果決定要因を見落とすリスクがある。

この指示を「テスト結果を決定する具体的なメカニズム（assertion、raised exception、setup/teardown failure、後続チェックの side effect）をトレースせよ」と明確化することで、assert 以外のメカニズムを通じてもテスト結果が変わらないと判定できる EQUIV ケースの分析精度を向上させる。

## 変更内容

Compare モードの Certificate template 内、`ANALYSIS OF TEST BEHAVIOR` ブロック冒頭に、per-test ループの前に 1 文の注釈を追加した。

**変更前:**
```
ANALYSIS OF TEST BEHAVIOR:

For each relevant test:
```

**変更後:**
```
ANALYSIS OF TEST BEHAVIOR:
For each test, trace the concrete mechanism that determines pass/fail — this may be an assertion, a raised exception, a setup/teardown failure, or a side effect checked later in the test. Do not reduce the trace to a single assert statement unless that is truly the only outcome determinant.

For each relevant test:
```

変更規模: 2行追加。他セクション・他モードへの変更なし。

## 期待効果

- **EQUIV（現状: 7/10 = 70%）**: ±0〜+2 の改善を予測。トレース対象の説明を明確化することで「assert に届くか」の問いを「pass/fail を決定するメカニズム全体に届くか」に精緻化し、assert 以外のメカニズムで結果が変わらないと分かるケースでの誤った NOT_EQ 判定を抑止する。
- **NOT_EQ（現状: 10/10 = 100%）**: 0（維持）。本案はトレース対象を広げる方向の変更であり、NOT_EQ の証拠を減らすのではなく assert 以外のメカニズムで失敗するケースの検出力を補完する。既に正しくトレースしているケースへの影響は最小。
