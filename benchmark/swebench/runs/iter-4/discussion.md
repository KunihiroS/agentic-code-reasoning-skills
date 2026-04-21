# Iteration 4 Discussion

## 総評
この proposal は、曖昧だった pass-to-pass tests の既定動作を明示して、compare 実行時の分岐を実際に変える提案になっています。特に「call-path relevance 未検証なら黙って除外」ではなく、「暫定 relevant として trace で除外するか、できなければ UNVERIFIED / 追加探索 / 保留へ倒す」という分岐が明文化されるため、説明の言い換えだけに留まっていません。加えて、その“支払い”として強すぎる MUST を緩める対応も proposal 内で明示されており、必須ゲート総量不変の条件も満たしています。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

補足:
- 研究コアの「番号付き前提・仮説駆動探索・手続き間トレース・必須反証」は維持されている。
- 変更は compare テンプレート内の曖昧な omission default を明文化するもので、README.md / docs/design.md の certificate-based reasoning と整合的。
- 特に docs/design.md の「per-item iteration as the anti-skip mechanism」「interprocedural tracing as structure, not advice」と相性がよい。relevant か未確定のテストを黙って落としにくくするため、anti-skip の方向に沿っている。

## 2. Exploration Framework のカテゴリ選定
カテゴリ E（表現・フォーマット改善）で妥当です。

理由:
- 主変更は D2(b) の inclusion 条件に「未検証時の既定動作」を 1 行で追加する wording の明確化。
- 併せて「Complete every section...」の強すぎる MUST を、structural triage 例外と衝突しない wording へ圧縮しており、これも表現・フォーマット改善の範囲。
- ただし payment の部分には G（認知負荷の削減）の成分もある。主カテゴリは E、従カテゴリとして G を含む、という理解が最も正確。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
この proposal は片方向最適化ではなく、両方向に作用します。

- EQUIVALENT 側:
  未検証の pass-to-pass relevance を黙殺できなくなるため、影響しうる既存 PASS テストの見落としによる偽 EQUIV を減らせる。
- NOT_EQUIVALENT 側:
  relevance 未確定のまま speculative に「影響しそう」と語る代わりに、trace で除外するか UNVERIFIED を明示する流れになるため、偽 NOT_EQUIV も減らせる。
- 実効的差分:
  変更前は omission default が暗黙で、モデルが“除外してよい”側に流れやすい。変更後は omission に trace か UNVERIFIED が必要になり、結論保留や追加探索の条件が観測可能に変わる。

## 4. failed-approaches.md との照合
本質的再演ではありません。

- failed-approaches.md の禁止は、「再収束を優先する規範を新たな既定動作にして、途中差分シグナルを弱める」こと。
- 今回は逆で、未確定な pass-to-pass relevance を黙って落とさない既定動作を足す提案。
- 「下流で再収束するなら差を弱める」とは言っておらず、比較粒度を緩める提案でもない。

## 5. 汎化性チェック
汎化性違反は見当たりません。

- 具体的な数値 ID: なし
- リポジトリ名: なし
- テスト名: なし
- ベンチマーク固有コード断片: なし
- 特定言語・特定ドメイン依存: 明白にはなし

軽い所見:
- 「API の前処理位置をずらす」という discriminative probe はややアプリケーションコード寄りの典型例だが、関数呼出し経路が問題になる一般ケースとして十分抽象化されており、R1 を落とすほどではない。

## 6. 全体の推論品質への期待効果
期待効果はあります。

- relevance 未確定の PASS テストを silent exclusion しづらくなるため、見落とし型の誤判定を減らせる。
- “結論を急ぐ”より“trace で除外できたか”を問うため、compare の行動が証拠駆動に寄る。
- payment により、既存の矛盾した MUST を弱めるので、認知負荷の純増も比較的小さい。
- 変更規模が小さく、研究コアに手を入れないため、回帰リスクも限定的。

## 停滞診断
- 懸念 1 点: 「UNVERIFIED を明示する」という監査受けのよい説明だけが強まり、実際にはモデルが trace を増やさず低 confidence を添えるだけで compare の最終判定をあまり変えない危険はある。ただし今回は trigger line が omission を禁じており、少なくとも“黙って落とす”行動は変わるので、停滞懸念は限定的。

### failed-approaches 該当性チェック
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

理由:
- trace か UNVERIFIED への分岐を明示するだけで、読む順番や探索順序は固定していない。
- payment により MUST の追加を既存 MUST の緩和で相殺している。
- 要求している証拠も新種ではなく、既存の tracing / UNVERIFIED / scope 明示の延長。

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  relevance 未確定の pass-to-pass test を、変更前のように無言で分析対象から落としにくくなる。観測可能な差として、追加 tracing、UNVERIFIED 明示、保留/低 confidence の増加が起こる。

- 1) Decision-point delta:
  Before: IF pass-to-pass test の call-path relevance が未検証 THEN irrelevant 扱いで落とし、そのまま結論へ進みうる。
  After: IF pass-to-pass test の call-path relevance が未検証 THEN 暫定 relevant として trace で除外するか、除外不能なら scope を UNVERIFIED にして保留/追加探索/低 confidence へ倒す。
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - 条件も行動も同じで理由だけ言い換えか: NO
  - Trigger line（発火する文言の自己引用）が差分プレビューにあるか: YES

- 2) Failure-mode target:
  両方。主に「未確認の PASS テストを落としてしまう偽 EQUIV」を減らしつつ、「未確認の影響を過剰に語る偽 NOT_EQUIV」も減らす。メカニズムは omission default の明示的置換。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か:
  NO

- 3) Non-goal:
  structural gap からの早期 NOT_EQUIV 条件そのものは変えない。探索順序の固定、新しい必須ゲートの増設、証拠種類の固定は行わない。

## Discriminative probe
抽象ケースとして、2 変更が failing path では同じ修正をしている一方、片方だけ既存 PASS テストが通る共通 API の前処理位置をずらしている場合を考える。変更前はその PASS テストの relevance 未確認のまま除外して偽 EQUIV、または影響を憶測して偽 NOT_EQUIV になりやすい。変更後は D2(b) の既定動作置換により、trace で除外できるなら結論、できなければ UNVERIFIED / 保留へ倒れるため、早計な二択を避けられる。

## 支払い（必須ゲート総量不変）チェック
A/B の対応付けは proposal 内で明示されています。

- Add: unresolved call-path relevance の provisional-relevant / trace-or-UNVERIFIED ルール
- Pay by demote/remove: 「Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS.」の強い MUST を、structural triage 例外と両立する wording に緩和

このため、「compare に効く必須 1 行を足すが、別の必須 1 行を弱める」という支払いが見えており、停滞対策の条件を満たします。

## 最終判断
承認: YES

理由:
- compare 実行時の分岐を実際に変える Decision-point delta が具体的。
- Trigger line と payment が proposal 内で明示されている。
- failed-approaches.md の本質的再演ではなく、EQUIV / NOT_EQUIV の両側に効く。
- 汎化性違反も見当たらない。

実装時の最小修正指示:
1. Trigger line の「or mark the scope UNVERIFIED」の後に、結論側の挙動が読み取れるよう「and avoid omitting the test from analysis」を残すこと。
2. 緩和後の「Complete every applicable section...」は、structural triage 例外との整合だけに留め、追加の条件分岐を増やしすぎないこと。
3. D2(b) 追加文は pass-to-pass tests にのみ適用されると読めるように置き場所を固定し、他の test category へ誤拡張しないこと.
