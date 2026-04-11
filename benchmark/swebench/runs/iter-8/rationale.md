# Iteration 8 — 変更理由

## 前イテレーションの分析

- 前回スコア: 70% (14/20)
- 失敗ケース: django__django-15368, django__django-13821, django__django-15382（EQUIV → NOT_EQUIVALENT 誤判定）、django__django-14787, django__django-11433, django__django-12663（NOT_EQUIVALENT → UNKNOWN）
- 失敗原因の分析:
  - **15368, 13821, 15382（持続的 EQUIV 偽陽性）**: コードパス上に構造的な分岐や変更を発見した時点で NOT_EQUIVALENT と結論付ける「ショートカット」が継続している。Change A と Change B が当該コードパスで実際に異なる値を返すかどうかを確認せず、コード差異の存在 → テスト結果の相違 というジャンプが起きている。現行テンプレートの `Claim C[N].1 / C[N].2` 形式は2つの独立トレースを並べるだけで、「どの時点で値が分岐するか」の証拠を明示させる要求がなかった。
  - **14787, 11433, 12663（UNKNOWN 異常終了）**: NOT_EQUIVALENT ケースだが 31 ターン上限でターン枯渇。トレース中に値差異の特定に集中できず、冗長な2重独立トレースにターンを消費した可能性がある。

## 改善仮説

**compare モードのテスト分析ブロックを「乖離点ファースト（Divergence-First）トレース」構造に変更することで、エージェントが Change A と Change B の実際の値レベルでの相違点を明示せずに NOT_EQUIVALENT 結論を出す誤判定（EQUIV 偽陽性）を防ぎ、かつ NOT_EQUIVALENT 判定に必要な証拠収集を現在の2重独立トレースより効率化できる。**

根拠: `localize` モードの PHASE 3（DIVERGENCE ANALYSIS）には「実装がテストの期待からどこで逸脱するかを特定する」という手法が定義されているが、`compare` モードのテンプレートにはこの「乖離点の特定」視点が組み込まれていない。論文の localize テンプレートにある「乖離点の明示」を compare モードに応用することで、両者が実際にどこで異なる値を生じるかを証拠として要求できる（カテゴリ F: 原論文の未活用アイデアを導入する）。

## 変更内容

`compare` モード Certificate template 内の `ANALYSIS OF TEST BEHAVIOR` セクションにある2つのブロックを置き換えた。

**fail-to-pass ブロック**: `Claim C[N].1 / C[N].2` の2重独立トレース形式を廃止し、`Divergence`（乖離点の明示）+ 条件付き `Claim C[N]`（1本）形式に変更した。`Divergence` 欄では「Change A と Change B がこのテストのコードパス上で初めて異なる値または振る舞いを示す箇所」を `A at [file:line]: [specific value]` / `B at [file:line]: [specific value]` として VERIFIED 証拠とともに記述することを要求する。値が全トレースポイントで同一の場合は Comparison を SAME としてそのまま終了する。

**pass-to-pass ブロック**: 同様に `Claim C[N].1 / C[N].2` を廃止し、`Divergence` 欄 + 条件付き `Claim C[N]` 形式に変更した。

変更規模: fail-to-pass ブロック +10/-6 行、pass-to-pass ブロック +7/-5 行（合計約 17 行の置き換え）。DEFINITIONS、PREMISES、EDGE CASES、COUNTEREXAMPLE/NO COUNTEREXAMPLE、FORMAL CONCLUSION、Step 1–5.5、Guardrails、他モードはすべて変更なし。

## 期待効果

- **15368, 13821, 15382（EQUIV 偽陽性）**: `Divergence` 欄は `A at [file:line]: [specific value]` vs `B at [file:line]: [specific value]` という値レベルの明示を要求する。Change A と Change B が当該コードパスで同じ値を返す（EQUIV ケースの実態）ならば、エージェントは "values are identical at every traced point" と記録して Comparison を SAME にせざるを得ない。コード構造上の差異だけでは DIFFERENT と書けないため、偽陽性を抑制できると予測する（EQUIV 正答率 7/10 → 8〜9/10）。
- **14787, 11433, 12663（UNKNOWN ターン枯渇）**: 1テストあたりの分析が「Claim A + Claim B」の2重独立トレース（5行）から「Divergence 確認 + 条件付き Claim」（5〜6行）に変わる。差異を発見した時点で Claim は1本のみ書けばよく、不要なトレースを省ける。NOT_EQUIVALENT ケースでは乖離点に実際の値差異が存在するため Divergence 欄が自然に埋まり、証拠発見の早期化が期待できる。NOT_EQUIVALENT 正答率の回帰はないと予測する。
