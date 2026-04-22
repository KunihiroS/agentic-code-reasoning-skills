# iter-36 discussion

## 総評
この提案は、semantic difference 発見後に「まず下流を深掘りする」既定動作を、「relevant test への接続可否を先に確かめる」読点優先へ置換する案として明確です。結論規則そのものを増やさず、compare 実行時の次アクション選択を変える提案なので、監査に刺さる説明補強だけでなく、実際の比較アウトカム差も見込みやすいです。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md / SKILL.md の範囲では、研究コアは「番号付き前提」「仮説駆動探索」「手続き間トレース」「必須反証」です。本提案はそのどれも削らず、Step 3 の discriminative power を compare モードでより具体化するだけなので、研究コアとの整合性は良好です。

## 2. Exploration Framework のカテゴリ選定
カテゴリ B「情報の取得方法を改善する」は適切です。
理由:
- 提案の本体は verdict 規則の追加ではなく、「relevance 未確定時に何を先に読むか」という取得順序の変更です。
- A（推論順序）とも近いですが、ここで変えているのは全体の段階順ではなく、探索中の局所的な優先読点です。
- C（比較の枠組み変更）ほど大きく比較単位や判定概念を変えていません。

したがって B としての整理は妥当です。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
両方向に作用します。片方向最適化ではありません。

- EQUIVALENT 側:
  relevance 未確定の差分を内部で掘りすぎると、irrelevant difference を過大評価して偽 NOT_EQUIV に寄りやすいです。提案後は reachability / test relevance を先に確かめるため、未到達差分を早く irrelevant と扱いやすくなり、偽 NOT_EQUIV を減らせます。
- NOT_EQUIVALENT 側:
  逆に、relevant path につながる差分でも内部 detail を先に追っていると、テスト接続の確認が後回しになり、差分が verdict に効く点を取り逃して偽 EQUIV や過度な保留が起きえます。提案後は caller / dispatch / test reference を先に見るので、relevant test に接続する差分を早めに確定しやすくなります。

実効的差分としては、「差分発見後のデフォルト探索先」が変わる点が本質です。これは両側の誤判定メカニズムに効いています。

## 4. failed-approaches.md との照合
本質的再演には当たりません。

- 原則1「再収束の前景化」:
  該当しません。提案は downstream absorption や shared observation への再収束を verdict 規則化していません。むしろ relevance 解決を先にするだけです。
- 原則2「未確定を保留側へ倒す既定動作」:
  該当しません。UNVERIFIED / 保留へ倒す新ルールではなく、未確定性を減らすための局所的な読み順変更です。
- 原則3「差分の昇格条件を新しい抽象ラベルや必須言い換えで強ゲート」:
  ぎりぎり注意は必要ですが、現状文面なら非該当です。理由は、差分を verdict 証拠へ昇格するための新ラベル導入ではなく、「関連性が未解決なら reachability を先に調べる」という探索優先順位の置換に留まっているためです。
- 原則4「終盤の証拠十分性チェックを confidence に吸収しすぎる」:
  無関係です。終盤チェックの削減案ではありません。

## 5. 汎化性チェック
汎化性は概ね良好です。

- 具体的な数値 ID, リポジトリ名, テスト名, コード断片:
  提案文中にベンチマーク固有の識別子はありません。SKILL.md 自身の文言引用は Objective.md の基準上許容範囲です。
- ドメイン依存性:
  caller / test / dispatch という表現は一般的で、特定言語や特定テストフレームワークに固定されていません。
- 暗黙の想定:
  若干、明示的な dispatch site を持つコードを想起させますが、proposal 内で caller/test/dispatch を reachability を決める近傍証拠の例として使っている限り、汎化性違反とまでは言えません。

## 6. 全体の推論品質への期待効果
期待効果はあります。

- semantic difference の「発見」そのものと「relevant tests への接続」を分けて考えさせるため、差分の情報価値をより判別的に扱えます。
- Step 3 の discriminative power という既存原則を compare に接続し直しており、推論の局所選択がより一貫します。
- 既存の core structure を崩さず、少数行の置換で探索ノイズを下げられるので、複雑性コストも比較的低いです。

## 停滞診断
- 懸念点を 1 点だけ挙げると、「relevance を先に解くべき」という説明は監査 rubric には刺さりやすい一方、実装時に Trigger line が弱いと単なる説明強化で終わり、実際の next action が変わらない危険はあります。ただし今回は Trigger line と Before/After が書かれており、その懸念はかなり抑えられています。

### failed-approaches 該当性チェック
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

補足:
「nearest caller/test/dispatch site」は証拠の例示としては十分限定的ですが、verdict のための唯一の証拠型を要求しているわけではなく、relevance 未確定時の優先読点を示しているだけなので NO 判定でよいです。

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  semantic difference 発見後、深い内部 trace を伸ばす前に relevance-deciding site を読みに行く行動が増える。結果として、irrelevant difference では EQUIV に戻りやすくなり、relevant difference では追加で test trace を取りに行く条件が早く発火する。

- 1) Decision-point delta:
  IF/THEN 形式で 2 行（Before/After）になっているか？ YES
  Trigger line（発火する文言の自己引用）が差分プレビューに含まれているか？ YES
  評価: 条件も行動も変わっている。Before は「未解決でも deeper tracing 継続」、After は「未解決なら relevance-deciding site を先読」なので、理由の言い換えに留まっていません。

- 2) Failure-mode target:
  両方。偽 NOT_EQUIV は irrelevant difference の過読みにより起きる。偽 EQUIV は relevant path 接続の見落としにより起きる。提案は両者の原因である「差分発見後の次探索先の誤り」を狙っています。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ NO

- 3) Non-goal:
  verdict 規則の追加、STRUCTURAL TRIAGE の強化、UNVERIFIED への既定退避、特定アンカーへの必須固定は変えない。あくまで relevance 未確定時の優先読点だけを置換する。

## Discriminative probe
抽象ケースとして、両変更とも同一 helper の実装を変えるが、relevant tests から実際に到達するのは片方の branch だけという状況を考える。変更前は helper 内の意味差を先に掘って偽 NOT_EQUIV か保留に寄りやすい。変更後は branch を決める caller/dispatch/test reference を先に見て未到達差分を早く irrelevant と判定でき、到達する場合のみ test trace を深掘りするので、誤判定を避けやすい。これは新ゲート追加ではなく既存の優先読点の置換で説明できています。

## 支払い（必須ゲート総量不変）の確認
A/B の対応付けは明示されています。追加する MUST と、demote/remove する既存 MUST のペアが proposal 内に書かれているため、比較停滞を招く「純増」提案にはなっていません。

## 最小限の修正指示
1. Trigger line の caller/test/dispatch を「e.g.」相当に扱えるようにし、到達性を決める近傍証拠の例示であって固定メニューではないことを明文化してください。
2. 置換先の checklist 行では、「relevant or relevance-deciding path」の語を残しつつ、深掘り禁止ではなく優先順変更だと分かる表現にしてください。

## 結論
この提案は、監査 rubic に刺さる説明だけでなく compare の局所分岐を実際に変える案になっています。failed-approaches.md の本質的再演でもなく、両方向の誤判定に効くメカニズムも示されています。さらに Trigger line、Before/After の IF/THEN、Discriminative probe、Payment が揃っており、停滞対策上の必須条件も満たしています。

承認: YES
