# iter-34 discussion

## 総評
提案の狙い自体は妥当です。compare テンプレート内で、冒頭の強い禁止文と STRUCTURAL TRIAGE の早期結論例外が競合しているのは事実で、ここを解消して実行時の分岐を安定させたいという問題設定は、監査説明のための飾りではなく compare の実運用に触れています。

ただし、現状の差分プレビューは「矛盾解消」よりも「NOT_EQUIVALENT 直行の強調」に寄っており、EQUIVALENT 側や通常の ANALYSIS 継続側の規律を同時にどう保つかが弱いです。とくに置換後文言が `Complete every section` を落としているため、片方向最適化に見える余地があります。ここが最大のブロッカーです。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md / docs/design.md が示す研究コアは「番号付き前提・反復的証拠収集・手続き間トレース・必須反証」であり、今回の提案はそのコアを追加も削除もせず、compare テンプレート内部の競合を減らすものです。したがって研究整合性は概ね良好です。

## 2. Exploration Framework のカテゴリ選定
カテゴリ G（認知負荷の削減）は適切です。

理由:
- 提案対象が新しい探索手順の追加ではなく、既存テンプレート内の矛盾/重複の解消だから。
- failed-approaches.md が禁じる「探索経路の固定化」や「証拠種類の固定」ではなく、既存例外規定の読み落とし源を減らす方向だから。
- 目的が compare の実行時分岐の安定化であり、研究コアを維持したまま認知負荷だけを下げようとしているから。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
### 変更前との実効差
現行 SKILL.md にはすでに
- 冒頭: `Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS.`
- 後段: `If S1 or S2 reveals a clear structural gap ... you may proceed directly ... with NOT EQUIVALENT`
が共存しています。

したがって提案の本質は、新ルールの追加ではなく「どちらが優先されるか」を明示して、実行時に
- 不要な ANALYSIS を続ける
- ANALYSIS を推測で埋める
- 逆に通常ケースでも早期結論に流れる
の揺れを減らすことです。

### NOT_EQUIVALENT 側
プラスに働く余地があります。構造ギャップが assertion boundary に結び付くケースで、不要な ANALYSIS 完遂圧を下げ、早めに NOT_EQUIVALENT を出しやすくなります。偽 EQUIV と過度な保留の低減にはつながり得ます。

### EQUIVALENT 側
現案のままだと作用が弱いです。理由は、置換後文言が NOT_EQUIVALENT 直結論だけを前景化し、通常ケースでは従来どおり ANALYSIS を完遂すべきことを同じ強さで保持していないためです。特に `Complete every section` を丸ごと消すと、EQUIVALENT を主張すべきケースでの証拠積み上げ規律が弱まりうります。

### 片方向最適化の有無
懸念あり。現案は「NOT_EQUIVALENT へ進める条件」を明示する一方で、「それ以外は ANALYSIS を続ける」を同じ行で保持していません。compare 改善としては片側だけ強化された形に見え、逆方向悪化の回避策がまだ不足しています。

## 4. failed-approaches.md との照合
本質的再演ではありません。

- 証拠種類の事前固定: NO
  - 新たに「何を探せ」とは指定していません。
- 探索経路の半固定: NO
  - triage 自体は既存で、今回の変更はその例外の優先順位明確化が主眼です。
- 必須ゲート増: NO
  - 1 行置換であり、必須項目の純増はありません。
- 証拠種類の事前固定: NO
  - 特定の証拠ペアや観測境界への還元を追加していません。

ただし注意点として、現案の after 文言が NOT_EQUIVALENT 直結論だけを強調すると、失敗原則そのものではないものの、compare の分岐を片側へ寄せる危険はあります。これは failed-approaches の再演というより、分岐の中立性不足です。

## 5. 汎化性チェック
大きな違反は見当たりません。

- 具体的な数値 ID: なし
- 特定リポジトリ名: なし
- 特定テスト名: なし
- ベンチマーク実コード断片: なし

抽象ケースも「設定/変換モジュール」「assertion boundary」など一般表現に留まっており、特定言語・特定フレームワーク・特定テストパターンへの依存は比較的弱いです。

軽微な注意:
- `~200 lines of diff` は SKILL.md 既存文言の自己引用なので汎化性違反ではありません。
- `NOT EQUIVALENT` の早期結論を前面に出す書き方は、Java/Python/JS など特定言語依存ではない一方、compare タスク全般での分岐バランスには影響します。

## 6. 全体の推論品質への期待効果
期待できる改善はあります。

- テンプレート内の自己矛盾を減らし、指示解釈コストを下げる
- triage で十分な反例が見えているのに不要な ANALYSIS に流れる停滞を減らす
- ANALYSIS 欄を埋めるための推測補完を減らし、偽 EQUIV を抑える
- compare 実行時の「結論に進む / 追加探索に戻る」の分岐を安定させる

ただし、これらが安定して出るには after 文言が両分岐を中立に規定している必要があります。今のプレビューではその保証が弱いです。

## 停滞診断（必須）
- 懸念 1 点: 監査 rubric に刺さる「矛盾解消」「認知負荷削減」の説明は十分だが、compare の意思決定を本当に変える文言が、現状だと `NOT EQUIVALENT に進める` 側に偏っており、`それ以外は ANALYSIS 継続` まで一体で明文化されていない。
- 探索経路の半固定: NO
- 必須ゲート増: NO
- 証拠種類の事前固定: NO

## compare 影響の実効性チェック（必須）
- 0) 実行時アウトカム差:
  - 構造ギャップが明白なケースで、不要な ANALYSIS 完遂ではなく NOT_EQUIVALENT 早期結論に進む率が上がる。
  - ただし現案のままでは、通常ケースで ANALYSIS 継続をどこまで維持できるかが観測上あいまい。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか？ YES
  - Before/After が分岐として変わっているか？ YES
  - Trigger line（発火する文言の自己引用）が差分プレビューに含まれているか？ YES
  - ただし、After が `NOT EQUIVALENT 直行` の分岐しか強く書いておらず、非発火時の通常分岐が明示不足。

- 2) Failure-mode target:
  - 主対象: 偽 EQUIV と過度な保留
  - メカニズム: 冒頭禁止文に引っ張られて推測で ANALYSIS を埋める/不要に引き延ばす挙動を減らす
  - 副作用懸念: 偽 NOT_EQUIV を避けるための通常 ANALYSIS 継続条件が弱い

- 3) Non-goal:
  - 探索経路の半固定はしない
  - 必須ゲートは増やさない
  - 証拠種類や観測境界を新たに固定しない
  - 研究コア（前提・仮説・トレース・反証）は削らない

- Discriminative probe:
  - 抽象ケースとして、片方の変更だけが失敗テストの assertion に到達する設定/変換モジュールを更新し、もう片方はそのモジュールを触らない場合を考える。
  - 変更前は冒頭禁止文のせいで ANALYSIS を埋めに行き、推測補完か保留に流れやすい。
  - 変更後は triage の欠落を根拠に NOT_EQUIVALENT へ進める点はよいが、通常分岐の維持文言が弱いため、提案としてはまだ片側の改善に寄っている。

- 支払い（必須ゲート総量不変）:
  - A/B 対応付けは一応明示されています（既存 1 行を新 1 行へ置換）。
  - ただし支払いの結果として `Complete every section` まで失われており、単なるコスト削減ではなく行動規律の削れ込みが起きています。ここは置換の仕方を再設計すべきです。

## 最大のブロッカー
片方向最適化です。現在の after 文言は「STRUCTURAL TRIAGE が発火したら NOT_EQUIVALENT に進める」を強くしつつ、「それ以外では ANALYSIS を継続する」という compare の通常分岐を同じ強さで保持していません。結果として、NOT_EQUIVALENT 側には効きそうでも、EQUIVALENT 側や通常の精査ケースでの規律低下が見込まれ、逆方向悪化の回避策が不足しています。

## 修正指示（2〜3 点）
1. 置換対象を丸ごと消さず、`Complete every section` を残したまま例外優先順位だけを統合してください。
   - 例: `Complete every section unless STRUCTURAL TRIAGE already establishes a clear NOT EQUIVALENT gap under S1/S2; otherwise continue ANALYSIS before FORMAL CONCLUSION.`
   - これなら追加ではなく統合で済み、支払いも明確です。

2. Trigger line を片側分岐ではなく二分岐で書いてください。
   - `IF triage clear gap -> direct NOT_EQUIVALENT; ELSE -> continue ANALYSIS`
   の両方を 1 文で保持し、compare の通常ケースを削らないこと。

3. EQUIVALENT 側への効き方を 1 行だけ補強してください。
   - 新規ゲート追加ではなく、`推測で ANALYSIS を埋めず、gap が不十分なら追加探索/通常分析へ戻る` と書いて、偽 NOT_EQUIV を避ける境界条件を明文化してください。

## 結論
承認: NO（理由: focus_domain の片方向最適化で逆方向の悪化回避策がまだ不十分）
