# iter-35 discussion

## 総評
提案の核は、compare における詳細 tracing の開始点を「changed code から前向き」ではなく「relevant test の concrete assertion/check から逆向き」に置き換えることです。これは結論そのものの指示ではなく、どこから証拠を取りに行くかという推論手順の変更であり、compare 実行時の探索先と保留条件を実際に変えうる提案です。さらに Payment で既存 MUST を落として総量を相殺しており、停滞しやすい単純な追加主義にも寄っていません。

## 1. 既存研究との整合性
検索なし（理由: 提案の依拠概念は「判別力の高い観測点から逆向きに辿る」という一般的な推論順序の原則であり、README.md / docs/design.md / SKILL.md の範囲で自己完結して評価可能）。

研究コアとの整合性は概ね良好です。番号付き前提・仮説駆動探索・手続き間トレース・必須反証は維持され、変わるのは compare 内の per-test tracing の開始点だけです。README.md の「structured templates act as certificates」および docs/design.md の「per-item iteration as the anti-skip mechanism」とも矛盾しません。per-test ループを保ったまま、test verdict に最短で届く経路を先に辿らせる調整だからです。

## 2. Exploration Framework のカテゴリ選定
カテゴリ選定は A「推論の順序・構造を変える」が適切です。
理由:
- 変えているのは比較単位ではなく tracing の開始順序
- 「結論から逆算して必要な証拠を特定する（逆方向推論）」にかなり近い
- 情報取得方法の改善（B）的な副作用はあるが、主成分は order / structure の変更

したがってカテゴリ誤認はありません。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
片方向最適化ではなく、両方向に作用する提案です。

- EQUIVALENT 側への効き方:
  上流 helper や中間表現の差分を先に大きく見てしまうと、実際には同一 assertion outcome に収束するケースで偽 NOT_EQUIVALENT や過度な保留が出やすい。assertion-first にすると、まず verdict-carrying branch を確定してから周辺差分を扱うため、判定に効かない差分の過大評価を減らせます。
- NOT_EQUIVALENT 側への効き方:
  changed code を広く眺めるだけだと、どの差分が test outcome を割るかに到達できず、偽 EQUIVALENT や弱い保留が出やすい。assertion/check から最寄りの changed branch へ逆向きに辿ると、どの分岐が PASS/FAIL を分けるかを早く特定でき、反例の具体化がしやすくなります。

実効的差分はあるか:
- あります。追加探索の要求先が changed code 周辺から assertion-boundary 周辺へ変わるため、compare 実行時に読む関数・比較する枝・UNVERIFIED の残り方が観測可能に変わります。

## 4. failed-approaches.md との照合
本質的な再演ではありません。

- 原則1「再収束の前景化」: 該当しません。提案は downstream での吸収確認を既定化するのではなく、tracing の開始点を assertion 側へ寄せるだけです。
- 原則2「未確定性を常に保留側へ倒す」: 該当しません。新しい保留優先規則や conclusion blocker は追加していません。
- 原則3「差分昇格条件の新ラベル化・強ゲート化」: 該当しません。差分の昇格前に別ラベルへ再分類させる案ではなく、既存の per-test tracing をどこから始めるかの変更です。
- 原則4「終盤チェックを confidence に吸収」: 該当しません。既存の self-check / refutation を弱めていません。

## 5. 汎化性チェック
汎化性違反は見当たりません。

- 具体的な数値 ID: なし（proposal 自身の iter-35 文脈は出力先管理であり、提案内容の規則には埋め込まれていない）
- 特定リポジトリ名: なし
- 特定テスト名: なし
- ベンチマーク実コード断片: なし
- 特定言語・特定フレームワーク前提: なし

また、assertion/check 起点という表現は言語非依存です。unit test の assert 文に限らず、check / expectation / matcher / predicate など任意の test oracle に一般化できます。暗黙に特定ドメインへ閉じる案ではありません。

## 6. 推論品質の改善見込み
期待できる改善は次の通りです。
- 判定に効く観測境界へ早く到達するため、比較の「証拠密度」が上がる
- irrelevant な上流差分の読み過ぎを減らし、認知資源を relevant branch に寄せられる
- NOT_EQUIVALENT では diverging assertion を具体化しやすくなる
- EQUIVALENT では「差はあるが verdict は同じ」を、より狭い根拠で主張しやすくなる
- 保留の質が上がる。単なる広い未探索ではなく「assertion から最寄り changed branch までは追ったが、そこから先が UNVERIFIED」という形に寄せやすい

## 停滞診断
- 懸念点（1点だけ）: 監査 rubic には刺さりやすいが、実装文言が弱いと「assertion から見よ」という説明追加で終わり、実際には従来どおり changed code から読み始める運用が残る恐れはあります。したがって Trigger line を MUST 寄りに明示する点が重要です。

### failed-approaches 該当性
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

補足:
- assertion/check を起点にするのは compare の per-test tracing に限った開始点の指定であり、以後の証拠収集まで固定していません。
- しかも Payment で既存 MUST を demote/remove しており、総量不変を明示しています。

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 追加探索の要求先が changed code 周辺から test assertion/check 周辺へ変わる。
  - NOT_EQUIVALENT 時は diverging assertion の提示に早く到達しやすくなる。
  - EQUIVALENT 時は「上流差分はあるが outcome 同一」の結論を、より狭い traced branch で出しやすくなる。

- 1) Decision-point delta:
  - Before: IF relevant tests are identified and several changed paths are plausible THEN changed code から外向きに trace しがちで、verdict-carrying branch が未確定でもそのまま周辺読みに進む。
  - After: IF relevant tests are identified but the verdict-carrying branch is unresolved THEN concrete assertion/check から最寄り changed branch へ逆向きに trace して、そこを先に A/B 比較する。
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Trigger line（発火する文言の自己引用）が差分プレビューに含まれているか: YES

- 2) Failure-mode target:
  - 対象: 両方
  - 偽 NOT_EQUIV を減らす機構: verdict に無関係な上流差分の過大評価を抑える
  - 偽 EQUIV を減らす機構: actual assertion boundary を割る changed branch へ早く辿り着かせる

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？: NO
  - したがって「ファイル差があるだけ」で NOT_EQUIV に退化させる方向のリスクは、この提案自体にはありません
  - impact witness 要求の有無: N/A（早期結論変更案ではないため）

- 3) Non-goal:
  - STRUCTURAL TRIAGE の結論条件や early NOT_EQUIV の許可条件は変えない
  - compare の比較単位を per-test から別単位へ移さない
  - 反証や self-check を optional 化しない
  - 証拠の種類や探索終点を固定化しない

## 追加チェック
- Discriminative probe:
  抽象ケースとして、A/B が同じ test oracle を満たすが upstream helper の実装差だけは大きいケースを考える。変更前は helper 差分を先に拾って偽 NOT_EQUIV か保留に傾きやすい。変更後は assertion/check から最寄り predicate へ逆向きに入り、その predicate 上でのみ A/B を比較するので、判定に効かない差分を切り離しやすい。これは新しい必須ゲート追加ではなく、既存 tracing の開始点の置換で説明できている。

- 支払い（必須ゲート総量不変）の A/B 対応付けが proposal 内で明示されているか:
  YES
  - add MUST: "For each relevant test, start from the concrete assertion/check and trace backward to the nearest changed branch before expanding outward."
  - demote/remove MUST: "Complete each section in order. Do not write a later section before completing earlier ones."

## 軽微な修正提案（承認前提）
1. Trigger line の "nearest changed branch" は、branch が存在しないケースに備えて "nearest changed decision point or value-producing statement" へ少し一般化すると言語横断性がさらに上がります。
2. "assertion/check" は test oracle を意味することを 1 語補足し、assert 文がないテストスタイルにも適用できるようにするとよいです。

## 結論
この提案は、監査に刺さる説明追加に留まらず、compare 実行時の探索開始点・追加探索先・反例具体化のしやすさを実際に変える提案です。failed-approaches.md の本質的再演でもなく、汎化性違反も見当たりません。Payment と Trigger line も明示されており、停滞しやすい「よさそうだが効き目が観測不能」型ではありません。

承認: YES
