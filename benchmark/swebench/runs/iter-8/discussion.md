# Iteration 8 — Proposal Discussion

## 総評
提案は、compare における「差分を見つけた直後の次の探索先」を具体化するもので、結論条件そのものではなく探索順序を変える案として一貫しています。Objective.md の Exploration Framework では B「情報の取得方法を改善する」に素直に収まり、README.md / docs/design.md の interprocedural tracing・incomplete reasoning chains 防止とも整合します。

この案の良い点は、監査に刺さる一般論ではなく、compare 実行時に「差分発見 → まずどこを読むか」という分岐を実際に変えようとしている点です。しかも payment が明示されており、必須ゲート純増を避ける意識もあります。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md と docs/design.md から確認できる研究コアは、番号付き前提・仮説駆動探索・手続き間トレース・必須反証です。本提案はそのいずれも削らず、特に docs/design.md の「incomplete reasoning chains」「interprocedural tracing as structure, not advice」に沿って、局所差分の直後に下流解釈点を読むことを促しています。したがって研究コアからの逸脱ではなく、既存 guardrail の運用具体化に近いです。

## 2. Exploration Framework のカテゴリ選定
判定: 適切。

理由:
- 提案は「何を結論せよ」ではなく「差分を見つけた後、どこを先に読むか」を変える。
- これは Objective.md の B「何を探すかではなく、どう探すかを改善する」「探索の優先順位付けを変える」に一致する。
- A（順序・構造）との境界もあるが、提案の核はテンプレ全体の順序再編ではなく、局所探索の取得順序変更なので B 寄りという整理で妥当。

## 3. compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 観測可能に変わる点は少なくとも 1 つある。差分発見後の追加探索先が「差分箇所そのもの」から「その値/例外/状態を最初に解釈する下流コード」に変わる。
  - その結果、EQUIV を出す前に正規化・例外吸収・ガード節の有無を先に確認しやすくなり、NOT_EQUIV を出す前に assertion boundary へつながる分岐を先に確認しやすくなる。
  - CONFIDENCE の上下、追加探索要求の向き、結論保留の減少が実行時に観測可能。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか？ YES
  - Trigger line（発火する文言の自己引用）が含まれているか？ YES
  - 評価: これは理由の言い換えではなく、差分発見時の次アクションを変える分岐になっている。

- 2) Failure-mode target:
  - 対象: 両方
  - 偽 NOT_EQUIV の低減: 局所差分を見つけた瞬間に test outcome 差へ短絡する誤りを減らす。
  - 偽 EQUIV の低減: 「どうせ下流で吸収される」と安易にみなす前に、実際の最初の interpreter を読ませることで、分岐化・例外化・assertion 伝播を見落としにくくする。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ NO
  - 本提案は structural triage の早期 NOT_EQUIV 条件を広げも狭めもしない。

- 3) Non-goal:
  - structural triage の結論条件は変更しない。
  - 新判定モードは追加しない。
  - 必須ゲート総量は payment で相殺し、純増させない。
  - 「下流で吸収されるはず」を既定結論にしない。

- Discriminative probe:
  - 抽象ケースとして、中間表現は異なるが最初の下流 consumer で同じ predicate に正規化される 2 変更を考える。変更前は局所差分だけを見て偽 NOT_EQUIV になりやすい。
  - 逆に、同じく局所差分があるが下流 consumer で別の branch に送られ assertion outcome が分かれる場合、変更前は「大差ない」と早合点して偽 EQUIV になりうる。
  - 変更後は「まず最初の interpreter を読む」に置換されるだけで、新たな必須ゲート増設ではなく既存 tracing 義務の読み順を入れ替える形で両誤判定を減らせる。

- 追加チェック（停滞対策の検証）:
  - 「支払い（必須ゲート総量不変）」の A/B 対応付けが proposal 内で明示されているか？ YES
  - add MUST と remove MUST の対応が書かれており、この点はクリア。

## 4. EQUIVALENT / NOT_EQUIVALENT への両方向作用
### EQUIVALENT 側への作用
局所差分を見つけても、最初の下流 interpreter が両者を同じ条件・同じ例外種別・同じ観測値へ正規化するなら、EQUIV の根拠が強くなる。これは Guardrail #5 の「downstream code does not already handle ...」を compare 用に前倒しして使うイメージで、偽 NOT_EQUIV を減らす方向に効く。

### NOT_EQUIVALENT 側への作用
逆に、最初の下流 interpreter が差分を別分岐・別例外・別 return category に変換するなら、その時点で test outcome 差へつながる証拠を得やすい。したがって「changed function/class/variable への表層参照だけで relevance が薄そう」と切ってしまう偽 EQUIV を減らす方向にも効く。

### 片方向最適化の懸念
限定的。提案文は「まず interpreter を読め」としているが、「下流で吸収されるなら EQUIV 寄り」といった結論規範にはしていないので、EQUIV 片方向の最適化にはなっていない。NOT_EQUIV 側でも interpreter が assertion-relevant boundary になるケースを拾えるため、両方向に作用しうる。

## 5. failed-approaches.md との照合
本質的再演か: いいえ。ただし境界は近いので文言運用に注意が必要です。

- 原則 1「再収束を比較規則として前景化しすぎない」
  - 今回は「再収束したら EQUIV とみなす規則」の追加ではなく、「差分発見後に最初の下流 interpreter を先に読む」という探索優先順位の指定です。
  - そのため本質は異なる。
  - ただし “consumes or interprets” が広すぎると、実装時に「まず吸収箇所を探す」癖へ流れ、結果として再収束前景化に寄る危険はある。ここは修正文で「差分が観測可能な分岐/正規化/例外変換になる最初の地点」と少しだけ寄せると安全。

- 原則 2「未確定な relevance を常に保留側へ倒す既定動作を増やしすぎない」
  - 提案は UNVERIFIED 既定や保留 fallback を増やしていない。
  - よって本質的再演ではない。

## 6. 汎化性チェック
判定: 概ね良好。

- proposal 内に、具体的な数値 ID、ベンチマーク対象リポジトリ名、特定テスト名、実コード断片の引用は見当たらない。
- 用語は value / exception / state / downstream interpreter / predicate といった一般化された抽象語で、特定言語・特定テストフレームワークに依存していない。
- 暗黙の前提として「下流 consumer / interpreter」という概念はやや imperative code 寄りだが、値変換・例外処理・状態判定・ガード節という広い表現なので、関数型・OO・スクリプト系でも十分適用可能な範囲にある。

## 7. 停滞診断（必須）
- 監査 rubic に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
  - 1 点だけ言うと、「immediate downstream code」が広すぎると、監査上はもっともらしくても compare 実行時にはどの consumer を先に読むかが曖昧で、結局いつもの読み方に戻る恐れがある。今回は Trigger line と Before/After があるので最低限クリアだが、実装では “最初に test-impact を分岐化/正規化する地点” としてさらに狭めると停滞しにくい。

- failed-approaches 該当性:
  - 探索経路の半固定: NO
  - 必須ゲート増: NO
  - 証拠種類の事前固定: NO

## 8. 期待される推論品質向上
- 局所差分から test outcome までの reasoning chain が短絡しにくくなる。
- 「差分を見つけたが relevance が曖昧」という場面で、次に読むべき箇所が明示されるため探索の迷走が減る。
- downstream handling を “最後の反省” ではなく “差分直後の確認ポイント” に移すことで、incomplete chain の誤りを早く潰せる。
- しかも structural triage や counterexample obligation は温存されるため、改善の焦点が狭く回帰範囲も比較的限定的。

## 最小修正指示
1. Trigger line の “immediate downstream code that interprets ...” を、「その差分を最初に test-impact relevant な branch / normalization / exception mapping に変える地点」のように少しだけ operational に狭めてください。広すぎる consumer 解釈だと監査には通っても実行差が弱くなります。
2. After 文の 2 行目で “Then trace at least one relevant test through that interpreted path ...” とあるので、payment で削る旧 MUST と新 MUST の役割分担がぶれないよう、「旧 MUST の削除後も per-test tracing 義務自体は別行で維持される」ことを明示してください。
3. Guardrail 側に置くなら、「下流で吸収されうる」方向だけでなく「下流で assertion-relevant 差へ拡大しうる」方向も同じ一文で対称に書いてください。これで EQUIV 側への片寄り疑念をさらに下げられます。

## 結論
この proposal は、failed-approaches.md の本質的再演ではなく、compare の実行時分岐を実際に変える提案になっています。Trigger line、Before/After の IF/THEN、payment、discriminative probe が揃っており、監査 PASS の下限を満たしつつ compare の改善に結びつく具体性もあります。

承認: YES
