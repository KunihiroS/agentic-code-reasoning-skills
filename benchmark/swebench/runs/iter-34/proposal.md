過去提案との差異: 直近の却下案のように探索境界や証拠種別を“狭める/固定する”のではなく、compare テンプレート内の矛盾する指示を1行だけ解消して認知負荷と停滞を減らす。
Target: 両方（偽 EQUIV と過度な保留/誤診断を減らす）
Mechanism (抽象): 同一テンプレート内の「禁止」と「例外許可」の衝突を除去し、分岐（結論に進む/追加探索へ進む）のデフォルト挙動を安定化させる。
Non-goal: 構造差→NOT_EQUIV の条件を新しく定義したり、観測境界（テスト/オラクル/VERIFIED 接続など）へ還元して探索自由度を削ることはしない。

(ステップ1) 禁止された方向（failed-approaches.md + 却下履歴の要約）
- 探すべき証拠の種類や読解順序をテンプレートで事前固定し、探索自由度を削る変更（確認バイアス・局所貪欲化の誘発）。
- 既存の判定基準を特定の観測境界へ過度に還元して“その境界に写像できたときだけ有効”のように狭める変更（構造差の扱いの狭窄を含む）。
- 結論直前の新しい必須メタ判断や確信度調整を純増し、既存の反証義務と機能重複させる変更（萎縮・停滞を招く）。

カテゴリG内でのメカニズム選択理由
- Gの目的は「性能に寄与していない/重複/矛盾する指示」を減らして、モデルがテンプレ遵守に引っ張られて停滞したり、例外規定を見落として不安定な分岐を起こすのを抑えること。
- compare は “STRUCTURAL TRIAGE で早期に結論へ進める” 例外が既にある一方、直前に「ANALYSIS を必ず埋めよ」という強い禁止が置かれており、同一ブロック内で衝突している。この衝突は「追加探索/結論」の分岐を実行時にぶらす（過度な保留、あるいは無理な ANALYSIS での推測）ため、削除・置換が G で最小・高レバレッジ。

(ステップ2G) 削除・統合候補 3 つ（各1行でデフォルト挙動/アウトカム差）
1) Compare テンプレ冒頭の “ANALYSIS を飛ばすな” 系の禁止文: デフォルトで例外許可（triage で直結論）を無視しがち → After で「NOT_EQUIV 直結論」または「追加探索」の選択が triage 規定どおり安定。
2) Explain テンプレの “FINAL ANSWER 前に…するな” 系の前置き: デフォルトで Core Method の順序制約と二重化しがち → After で「手順の読み替えコスト」だけ減り、UNVERIFIED 明示/結論は不変。
3) Guardrails と Step 4/Step 5 の重複（例: 名前から推測するな、反証を飛ばすな）: デフォルトで同じ禁止が3箇所に散り注意資源を消費 → After で「チェックの重複読み」による停滞が減り、反証やトレースの要件は維持。

(ステップ3G) 今回選ぶ候補
- 候補1（Compare 内の矛盾解消）を選ぶ。
  理由は2点以内:
  (i) compare の実行時分岐（結論に進む/ANALYSIS を続ける）が、同一テンプレ内の衝突で不安定になりうるため。
  (ii) 1行置換で済み、研究コア（前提/仮説/トレース/必須反証）に触れずに認知負荷だけを減らせるため。

(ステップ4G) 削除仮説（1つ）
- 仮説: compare テンプレ内の矛盾する禁止文は、判断に必要な情報を増やさずに「例外規定の見落とし」か「不要な ANALYSIS の強制」を誘発し、過度な保留/誤った自己整合化（推測で埋める）を増やしている。

(ステップ5G) Before/After の挙動差（抽象ケース）
- Before: STRUCTURAL TRIAGE で片側が“関連ファイルを欠く”と見えるのに、「ANALYSIS を完了せよ」に引っ張られ、未検証部分を推測で埋めてしまい偽 EQUIV または長い保留（UNRESOLVED/不明確）になりがち。
- After: TRIAGE が明確なギャップを示すときは、テンプレ内の例外どおり「NOT_EQUIVALENT の結論」へ進むか、ギャップが assertion boundary に結びついていないなら「追加探索」へ戻る、の2択が安定する（推測で ANALYSIS を埋める圧が下がる）。

SKILL.md の該当箇所（短い引用）と変更
- 現行（Compare / Certificate template 冒頭）:
  "Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS."
- これを、既に同テンプレート内に存在する例外（STRUCTURAL TRIAGE で直結論可）と矛盾しない短文に置換する。

Decision-point delta（IF/THEN、2行）
Before: IF STRUCTURAL TRIAGE で結論に足る構造ギャップが見えても THEN ANALYSIS 完遂を優先しがち because テンプレ冒頭の「Do not skip…」が例外より強く読まれうる。
After:  IF STRUCTURAL TRIAGE で結論に足る構造ギャップが見えたら THEN 例外規定どおり FORMAL CONCLUSION（NOT EQUIVALENT）へ進める because 同一テンプレ内の衝突が解消され、triage→結論の分岐が安定する。

変更差分プレビュー（Before/After、Trigger line planned を1行だけ含む）
Before:
  *This template implements Steps 1–6 of the Core Method for `compare` mode.*

  ### Certificate template

  Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS.
After:
  *This template implements Steps 1–6 of the Core Method for `compare` mode.*

  ### Certificate template

  "Note: if STRUCTURAL TRIAGE reveals a clear gap, you may proceed directly to FORMAL CONCLUSION (NOT EQUIVALENT) per the triage rules."

Discriminative probe（抽象ケース、2〜3行）
- ケース: Change A は失敗テストの assertion が依存する設定/変換モジュールを更新するが、Change B はそのファイルを触らない。
- Before は「ANALYSIS を埋める」圧で推測・保留に流れやすいが、After は triage の“欠落”を根拠に NOT_EQUIVALENT へ直結（または boundary が弱ければ追加探索へ）し、偽 EQUIV と停滞を減らす。

failed-approaches.md との照合（整合点 1〜2）
- 証拠種別の事前固定や読解順序の半固定を増やさず、テンプレ内部の矛盾を減らすだけなので探索自由度を削らない。
- 特定の観測境界に判定条件を還元して狭める変更ではなく、既存の例外規定の“見落とし源”を除去する（過度な具体化/固定化を避ける原則に整合）。

変更規模の宣言
- SKILL.md 変更は 1 行の置換のみ（5行以内、必須ゲートの純増なし）。
