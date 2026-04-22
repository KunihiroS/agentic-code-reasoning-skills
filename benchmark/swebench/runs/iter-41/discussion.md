# Iteration 41 Discussion

## 総評
この提案は、既存の compare 要件を増やすのではなく、既にある「semantic difference を見たら relevant test を 1 本は通す」という指示を、実際に差分を見つける地点へ移す局所的な再配置である。研究コア（premises / hypothesis-driven exploration / interprocedural tracing / refutation）を崩さず、カテゴリ G（認知負荷の削減・統合）の範囲として妥当。

## 1) 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md が強調するコアは「証拠収集を judgment より先に置く certificate-based reasoning」であり、この提案は新概念導入ではなく、既存の anti-skip 指示を compare の意思決定点に寄せるもの。したがって研究整合性は高い。

## 2) Exploration Framework のカテゴリ選定
カテゴリ G で適切。

理由:
- 新しい分析モードや分類ラベルを足していない
- 既存の重複指示を「局所トリガ 1 本」に統合している
- Payment が明示されており、必須総量不変を意識している

B（探索優先順位の変更）にも少しまたがるが、主作用は「読み方を増やす」ことではなく「重複指示の圧縮と配置換え」なので、G が最も適切。

## 3) EQUIVALENT / NOT_EQUIVALENT への作用
片方向最適化ではなく、両方向に効く提案として筋が通っている。

- EQUIVALENT 側:
  semantic difference を見ただけで NOT_EQUIV に寄る早合点を抑え、relevant test が実際にその branch を踏まない・assertion 境界へ届かない場合に、証拠付きで EQUIVALENT に戻しやすくなる。
- NOT_EQUIVALENT 側:
  downstream の類似性やテンプレ埋めを優先して差分の追跡が後回しになることを減らし、実際に test outcome を割る分岐なら、その場で diverging assertion へ接続しやすくなる。

実効差分としては「差分を見た後の次行動」が変わるので、片方向にしか作用しない変更ではない。

## 4) failed-approaches.md との照合
本質的再演ではない可能性が高い。

- 原則1（再収束の前景化）: 再収束を既定化していない。むしろ差分を見たら吸収説明より先に test trace を要求するので逆方向。
- 原則2（保留/UNVERIFIED 既定化）: UNVERIFIED fallback や保留既定を増やしていない。
- 原則3（抽象ラベル化・強ゲート化）: 新しい抽象ラベルや証拠昇格ゲートは追加していない。既存の relevant test trace を「いつ発火させるか」だけを変えている。
- 原則4（終盤 self-check の吸収しすぎ）: Step 5.5 を消す提案ではなく、Step 5 の重複 MUST 文言だけを payment として落とす設計なので、最低検証フロアを壊しにくい。

注意点は 1 つだけある。実装時に「semantic difference を見たら必ずこの 1 パターンから始める」と読めるほど強く書きすぎると、原則3 の「探索開始点の半固定」に近づく。だが proposal 文面は「relevant test を 1 本 trace する」であり、証拠種類も既存の compare テンプレ内なので、現状では再演とは言いにくい。

## 5) 汎化性チェック
汎化性違反は見当たらない。

- 具体的な数値 ID: なし
- 特定リポジトリ名: なし
- 特定テスト名: なし
- ベンチマーク実コード断片: なし

暗黙の前提も比較的一般的で、特定言語・特定ドメイン依存は薄い。扱っているのは「semantic difference を見たら relevant test を通す」という compare 一般原則であり、任意言語の static reasoning に適用可能。

## 6) 全体の推論品質への期待効果
期待効果はある。

- 差分発見後の次行動が早く決まり、テンプレ後半まで test probe が遅延するのを減らせる
- 既存の guardrail/checklist の重複を圧縮し、認知負荷を下げつつ反証性は維持できる
- 「差分は見たが outcome につながるか未確認」という compare の中核的な曖昧さに、追加の抽象分類なしで直接対処している

このため、監査受けの説明強化だけでなく、compare 実行時の探索順と verdict タイミングに観測可能な差を生む見込みがある。

## 停滞診断
- 懸念 1 点: もし実装が単なる文言言い換えで、ANALYSIS OF TEST BEHAVIOR 直下への再配置が弱いと、監査 rubic には刺さっても compare の実行行動はあまり変わらない。

- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

理由: 新規ルート・新規ゲート・新規証拠型を足しておらず、既存の relevant test trace をより早く発火させるだけだから。

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  semantic difference を観測した時点で、広いテンプレ継続や終盤 self-check に進む前に、1 本の relevant test trace が先に走る。結果として、追加探索要求のタイミングと ANSWER までの証拠の形が観測可能に変わる。

- 1) Decision-point delta:
  IF/THEN 形式で 2 行（Before/After）になっているか？ YES
  Trigger line（発火する文言の自己引用）が差分プレビューに含まれているか？ YES
  評価: 条件も行動も変わっている。Before は「semantic difference を見ても広く進めがち」、After は「その場で relevant test trace に入る」なので、理由の言い換えではなく分岐変更になっている。

- 2) Failure-mode target:
  対象は両方。偽 NOT_EQUIV は「差分発見だけで impact ありと寄せる」誤り、偽 EQUIV は「差分の test impact 確認を後回しにして downstream 類似で飲み込む」誤り。どちらも『差分発見直後の test trace 欠如』がメカニズム。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ NO
  よって impact witness 要件はこの提案の主ブロッカーではない。

- 3) Non-goal:
  構造差だけで NOT_EQUIV に倒す規則は増やさない。UNVERIFIED / 保留既定も増やさない。新しいラベル分類や必須証拠形式も足さない。

- Discriminative probe:
  抽象ケースとして、2 変更が同じ public API を返すように見えるが、片方だけ内部 branch 条件が違う場合を考える。変更前はその差分を見ても test への接続が後回しになり、早い NOT_EQUIV か安易な EQUIV のどちらにもぶれうる。変更後は既存の relevant-test trace を差分直後へ置き換えるだけで、branch 未到達なら EQUIV、assertion 到達なら NOT_EQUIV へ、より直接に振り分けられる。

- 追加チェック（支払い）:
  A/B の対応付けは明示されている。add MUST と remove MUST が 1 対 1 で書かれており、必須ゲート総量不変の説明として十分。

## 最小修正指示
1. 実装時は「ANALYSIS OF TEST BEHAVIOR 直下」に置くことを明示し、compare checklist 側には同趣旨の文を残さず完全に一本化すること。
2. Trigger line の文面で「before any verdict」を残しつつ、`immediately` が exploration の単一路固定に読めないよう、`immediately` の作用域を「verdict 前の優先行動」として限定すること。
3. Payment で削るのは Step 5 の重複 MUST 文だけに留め、Step 5.5 の検証フロアには触れないこと。

## 結論
提案は、failed-approaches.md の本質的再演を避けつつ、compare の実行時アウトカム差を比較的具体に示せている。とくに Decision-point delta と Trigger line、Payment の対応づけが揃っている点がよい。

承認: YES
