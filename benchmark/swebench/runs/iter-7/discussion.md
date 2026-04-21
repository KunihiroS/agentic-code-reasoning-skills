# iter-7 discussion

## 総評
提案は、STRUCTURAL TRIAGE を「即時結論ゲート」から「反例探索の優先順位付け」へ再配置するものとして一貫している。説明強化だけでなく、compare 実行時の分岐を実際に変える案になっており、監査 PASS の下限を満たしたまま停滞している premature NOT_EQUIVALENT を減らす方向として妥当。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md のコアは「番号付き前提・仮説駆動探索・手続き間トレース・必須反証」であり、この提案はその4本柱を削らず、compare における反証可能性を assertion-level witness に寄せて強める。原論文翻訳としても、構造差だけで結論を急ぐより「具体的な反例境界を追う」方が certificate 的な運用に整合的。

## 2. Exploration Framework のカテゴリ選定
選定カテゴリ A（推論の順序・構造を変える）は適切。

理由:
- 主変更は「STRUCTURAL TRIAGE の位置づけ」と「NOT_EQUIV へ進む順序」の入替であり、主に order / control-flow の変更。
- 情報取得方法そのものよりも、結論までの分岐順序を変える提案なので B より A が中心。
- 反証を強める副作用はあるが、主眼は D ではなく A。

## 3. compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - これまで structural gap を見た時点で ANSWER: NO に直行しえたケースが、変更後は「candidate diverging test/assertion を先に書く」「trace できなければ UNVERIFIED を明示して ANALYSIS 継続」に変わる。
  - 観測可能差は少なくとも 3 つある: 早期 NO の減少、追加探索の増加、UNVERIFIED 明示の増加。

- 1) Decision-point delta:
  - Before: IF structural gap is detected THEN direct NOT_EQUIVALENT may be issued before full ANALYSIS.
  - After: IF structural gap is detected THEN first propose and trace a diverging test/assertion; only if witness is traceable conclude NOT_EQUIVALENT, else mark UNVERIFIED and continue.
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Trigger line の自己引用が差分プレビューにあるか: YES
  - コメント: 条件も行動も変わっており、理由の言い換えではない。

- 2) Failure-mode target:
  - 主対象: 偽 NOT_EQUIV
  - 副次対象: 真の NOT_EQUIV を assertion-level witness でより健全に立証すること
  - メカニズム: 「構造差それ自体」を十分証拠とみなす誤りを減らし、test oracle への到達を要件化する。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？: YES
  - impact witness を要求しているか？: YES
  - 根拠: “candidate diverging test/assertion” と “trace it before concluding” があり、ファイル差だけの NOT_EQUIV へ退化しにくい。

- 3) Non-goal:
  - 構造差の検出自体は残し、探索優先度として使う点は維持している。
  - compare 全体を「常に保留へ倒す」規則にはしていない。
  - 証拠の主軸を既存の test/assertion ベースから別物へ変えていない。

## 4. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
### EQUIVALENT 側
明確に効く。変更前は missing file / missing module update などの structural gap を見つけた瞬間に premature NOT_EQUIV へ倒れうる。変更後は、その gap が relevant tests の assertion 差へ届くかを先に問うため、下流で吸収される差やテスト非到達の差で誤って NO を出す率を下げられる。

### NOT_EQUIVALENT 側
片方向最適化ではない。真に NOT_EQUIV であるケースでは、構造差を assertion-level witness に接続できれば従来より根拠の強い NO になる。特に「どの relevant test のどの assertion が割れるか」を先に書かせるので、NO の質は上がる。

### 逆方向の悪化リスク
一定のリスクはある。真の NOT_EQUIV でも witness の特定が難しいケースでは、即断 NO が減る代わりに UNVERIFIED / 追加探索へ流れやすくなる。ただしこれは false EQUIV を増やす設計ではなく、早すぎる NO を遅らせる設計であり、compare の停滞主因が premature NOT_EQUIV なら許容範囲。提案文も “only conclude if that witness can be traced” としており、EQUIV へ短絡するわけではない。

## 5. failed-approaches.md との照合
本質的再演ではないと判断する。

- 原則1「再収束を比較規則として前景化しすぎない」:
  - 本提案は「後段で吸収されるかもしれないから EQUIV 寄りに見る」規範を足していない。
  - むしろ structural gap を見たときに、吸収説明ではなく “どの assertion が割れるか” という反例ターゲットを先に要求している。

- 原則2「未確定 relevance を常に保留側へ倒す既定動作を増やしすぎない」:
  - 懸念はゼロではないが、広い fallback の新設ではなく structural-gap 分岐に限定した局所ルールである。
  - したがって failed-approaches の本質的再演とは言いにくい。

## 6. 汎化性チェック
汎化性違反は見当たらない。

- 具体的な数値 ID: なし
- リポジトリ名: なし
- テスト名: なし
- 実コード断片: なし
- 特定言語・特定フレームワーク前提: 明示なし

また、提案の中心概念は「relevant test」「assertion」「structural gap」で、compare の定義 D1/D2 に既に内在する一般概念の範囲。特定ドメインの暗黙前提も弱い。

## 7. 停滞診断（必須）
- 懸念点を 1 点だけ: 監査向け説明は十分だが、実装時に “candidate diverging test/assertion” が単なる作文欄になり、実探索の要求として弱く入ると compare の実行時アウトカム差が薄まる危険はある。今回は Trigger line と Before/After があるので現時点では許容だが、実装では「trace できなければ UNVERIFIED and continue」が必ず行動差になるよう文言を落とし込む必要がある。

### failed-approaches 該当性の YES/NO
- 探索経路の半固定: NO
  - structural gap が出た場合の分岐だけを変えており、全探索の読み順を広く固定していない。
- 必須ゲート増: NO
  - Payment で “STRUCTURAL TRIAGE (required before detailed tracing)” を弱める/外す対価が明示されているため、総量不変の置換提案になっている。
- 証拠種類の事前固定: NO
  - compare の定義自体が test outcome / assertion divergence を中心にしており、新しい証拠型を固定するのではなく既存の観測境界へ結論基準を戻している。

## 8. 追加チェック
### Discriminative probe
抽象ケース: 片方だけが補助ファイルを追加しているが、relevant tests は公開 API の最終正規化結果しか見ない。変更前は missing-file を強い差分シグナルとして false NOT_EQUIV を出しやすい。変更後は「どの assertion が割れるか」を先に要求するため、書けなければ structural gap は優先探索の手掛かりに留まり、premature NO を避けられる。

### 支払い（必須ゲート総量不変）
A/B の対応付けは proposal 内で明示されている: 新 MUST の追加と引き換えに “STRUCTURAL TRIAGE (required before detailed tracing)” を demote/remove すると書かれている。ここは明確。

## 9. 改善後に期待できる推論品質
- NO 判定の根拠が「ファイル差がある」から「この assertion が割れる」へ具体化し、反証可能性が上がる。
- EQUIV ケースでの premature NOT_EQUIV を減らせるため、比較の判別点が test-observable behavior に近づく。
- 真の NOT_EQUIV でも、構造差を assertion witness に接続することで、より説明責任の高い NO になる。
- 変更範囲は局所的で、研究コアを維持したまま compare の実効分岐だけを動かしている。

## 修正指示（最小限）
1. Trigger line の末尾 “continue ANALYSIS” を、単なる説明でなく行動義務として残すこと。ここが弱いと監査には刺さっても compare 実行時差が薄くなる。
2. “candidate diverging test/assertion” は 1 つで十分と明記してよい。複数列挙を暗黙要求すると認知負荷が増える。
3. 実装時は “directly to FORMAL CONCLUSION” の旧文を確実に削るか optional 扱いへ落とすこと。新旧が併存すると分岐が競合する。

承認: YES