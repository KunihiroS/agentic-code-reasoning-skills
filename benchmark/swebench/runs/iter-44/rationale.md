# Iteration 44 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A（この作業入力では未提供）
- 失敗ケース: N/A（この作業入力では未提供）
- 失敗原因の分析: compare における pass-to-pass relevance が direct call path 基準に寄りすぎると、変更された契約を間接的に消費するテストを比較対象から外しやすく、EQUIVALENT 判定前の比較母集団が狭くなる。

## 改善仮説

pass-to-pass relevance を「変更コードが直接 call path にあるか」ではなく「テストの確認対象が changed return/state/exception contract を消費するか」で判定すると、wrapper や indirection 越しの回帰感度を持つテストを relevant set に戻せる。これにより、direct path 偏重による偽 EQUIVALENT を減らしつつ、構造差だけで偽 NOT EQUIVALENT を増やしにくい。

## 変更内容

- Compare の D2(b) を、direct call-path 基準から changed-contract consumption 基準へ置換した。
- 同じ箇所に、direct call-path overlap がない場合でも changed-contract consumers を比較してから除外する Trigger line を挿入した。
- Compare checklist の pass-to-pass test 特定条件も同じ粒度へ置換し、旧 wording を統合した。
- 追加より置換を優先し、compare の意思決定点だけを局所変更した。

Trigger line (final): "When direct call-path overlap is absent, compare changed-contract consumers before excluding pass-to-pass tests as irrelevant."

この Trigger line は proposal の差分プレビューにあった Trigger line と一致しており、direct path 不在時に changed-contract comparison を発火させる一般化された分岐としてそのまま反映されている。

## 期待効果

- fail-to-pass が同じでも、変更契約を間接消費する pass-to-pass tests を relevant に含めるべき場面で比較を継続しやすくなる。
- relevance 判定の条件自体が変わるため、理由の言い換えではなく compare の分岐行動が変わる。
- checklist と定義文の粒度を揃えたため、実行時に旧 direct-path 規則へ戻る回帰を減らせる。
