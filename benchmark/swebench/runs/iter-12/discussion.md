# Iteration 12 Discussion

## 総評
提案は、compare における「差分発見後の既定動作」を、単なる経路追跡から「最初の behavioral fork の局在化 + assertion までの伝播/吸収の確認」へ置換するものとして、実行時の意思決定差を比較的はっきり定義できています。failed-approaches.md の禁止方向にも概ね触れておらず、監査 PASS の下限を満たしたまま compare の判別力を上げに行く案として妥当です。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

根拠:
- proposal の中核は、README.md / docs/design.md / SKILL.md に既にある paper 由来の failure pattern「symptom vs root cause confusion」「incomplete reasoning chains」「subtle difference dismissal」の compare への翻訳で説明できる。
- 新しい理論用語や外部手法への強い依拠はなく、最小限の自己完結監査で足りる。

## 2. Exploration Framework のカテゴリ選定
判定: F は適切。

理由:
- 提案は論文の error analysis 由来の Guardrail #3「Do not confuse symptom with root cause.」を compare の checklist に移植する案であり、Objective.md の F「原論文の未活用アイデアを導入する」に最も素直に当てはまる。
- B（情報取得方法）や C（比較の枠組み）にも少し跨るが、主眼は「paper の既存知見を compare に再利用すること」なので F 優先で問題ない。

## 3. compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - 差分を見つけた時点で即 SAME/DIFFERENT に寄せず、first behavioral fork の特定と assertion までの survival / neutralization の説明を追加で要求するようになる。
  - 観測可能には、追加探索の要求、結論保留の発生条件、CONFIDENCE の下げ方が変わる。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか？ YES
  - Trigger line（発火する文言の自己引用）が差分プレビューにあるか？ YES
  - 実効差分の評価:
    - Before: semantic difference が relevant path で見えたら、その path を 1 本 trace して plausible assertion outcome が見えた時点で SAME/DIFFERENT に進みやすい。
    - After: assertion parity 未確定なら first fork を局在化し、その fork が assertion まで残るか途中で吸収されるかを示すまで結論に進まない。
    - これは「理由の言い換え」ではなく、追加で探す条件と結論を出す条件の両方を変えている。

- 2) Failure-mode target:
  - 対象: 両方
  - 偽 NOT_EQUIV: 中間差分を見て、その差が下流で neutralize される可能性を詰めずに DIFFERENT とする誤りを減らす。
  - 偽 EQUIV: 最終 assert 付近の見かけの一致だけで、上流 fork が実は別 assertion branch に伝播する可能性を詰めずに SAME とする誤りを減らす。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ NO
  - 提案本文は「STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を観測境界へ狭めない」と明示しており、ここを触っていない。
  - よって impact witness 要件の不備を主ブロッカーにする状況ではない。

- 3) Non-goal:
  - STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件自体は維持する。
  - 新しい mode や新しい抽象ラベルの増設はしない。
  - 既存 checklist の置換として実装し、必須ゲート総量を増やさない。

- Discriminative probe:
  - 抽象ケース: 2 変更が途中で別の値正規化を行うが、一方は後段 guard で同じ assertion input に戻り、他方は戻らず assertion の分岐条件を跨ぐ。
  - 変更前は「中間差分が見えたので NOT_EQUIV」または「assert 付近だけ見て EQUIV」に振れやすい。
  - 変更後は、最初の fork から assertion boundary まで残るか吸収されるかを書かせるため、両方向の誤判定を減らせる。しかも既存の MUST 行の置換であり、新規必須ゲート純増ではない。

- 支払い（必須ゲート総量不変）の明示:
  - A/B の対応付けは proposal に明示されている。YES
  - add MUST と demote/remove MUST の対応が 1 対 1 で書かれているため、compare に効くが過剰に重くなる案ではない。

## 4. EQUIVALENT / NOT_EQUIVALENT の両方向への作用
判定: 片方向最適化ではない。

- EQUIVALENT 側:
  - 中間差分を見ても、それが assertion まで survival しないなら SAME 寄りの証拠として扱いやすくなる。
  - ただし「吸収の説明を先に組み立てる規範」にはしていないため、過去失敗のような過保守な EQUIV バイアスにはなりにくい。

- NOT_EQUIVALENT 側:
  - final assertion 近辺の表層一致ではなく、上流 fork が concrete assertion に届くかを詰めるため、見かけの一致に引っ張られる偽 EQUIV を減らせる。
  - つまり NOT_EQUIVALENT の成立には、単なる「差分あり」ではなく「差分が assertion outcome を分ける」が必要になる。

- 実効的差分:
  - 変更前は relevant path trace 自体が十分条件っぽく働きやすい。
  - 変更後は fork-to-assertion の伝播/吸収が確認できない限り verdict を早く出しにくくなる。
  - これは EQUIVALENT / NOT_EQUIVALENT の両方に同じく効く分岐条件の変更であり、片側専用の最適化ではない。

## 5. failed-approaches.md との照合
本質的再演か: NO

理由:
- 原則1「再収束を比較規則として前景化しすぎない」
  - 提案は neutralization を compare の既定ゴールにはしていない。差分検出後に、その差が assertion まで残るかどうかを説明させるだけで、吸収説明を優先する規範にはしていない。
  - したがって「再収束を先に組み立てる読み方」を直接促す案とは異なる。
- 原則2「未確定なら常に保留へ倒す既定動作にしすぎない」
  - 提案は未確定性一般を verdict stopper にしていない。対象は semantic difference 発見後のローカル追跡であり、広い fallback 追加ではない。
- 原則3「差分の昇格条件を新しい抽象ラベルで強くゲートしすぎない」
  - `behavioral fork` は新しい分類ラベルというより、差分の起点を説明する tracing 単位として使われている。compare 証拠への昇格前に別抽象フィルタを噛ませる構造ではない。

補足懸念:
- 実装がまずいと、「neutralized before assertion」を探すことが半ば既定化し、原則1に近づくリスクはある。したがって trigger line は「show whether it propagates ... or is neutralized ...」の対称性を保ったまま、どちらも同格の分岐として書くべき。

## 6. 汎化性チェック
判定: 概ね問題なし。

- proposal 内に、特定ベンチマークのケース ID、リポジトリ名、テスト名、コード断片の引用はない。
- 数値は `~200 lines` や `6-9 行` のような運用上の一般的閾値・変更規模であり、「具体的な数値 ID」には当たらない。
- ドメイン前提も弱く、言語固有の構文や特定フレームワークのテスト様式を前提にしていない。
- `assertion` 中心の書きぶりはテスト駆動比較タスクに整合しており、README.md / SKILL.md の compare 定義とも一致する。

軽微な注意:
- 「first behavioral fork」が実装者の頭の中で branch 文だけを指す狭い意味に落ちると、例外・データ正規化・mapping table 差分などを取りこぼすおそれがある。文言上は control-flow 分岐に限定しないことを保つとよい。

## 7. 全体の推論品質への期待効果
- compare の誤りは「差分を見つけたが、その差が outcome を変えるかを詰めない」か、「下流一致を見たが、上流差分が別 branch を作るかを詰めない」かに集約されやすい。この提案はその空白部分を直接埋める。
- 既存の研究コア（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）を壊さず、Guardrail と compare checklist の接続だけを強化している点もよい。
- 置換ベースなので認知負荷の純増が限定的で、R5/R6 的にも許容範囲。

## 停滞診断
- 懸念点（1 点のみ）:
  - 「first behavioral fork」を説明する文章量だけが増えて、実際には追加探索条件や verdict 条件が変わらない実装になると、“監査 rubic に刺さる説明強化”で止まり compare の意思決定が動かない恐れがある。

- 「探索経路の半固定」該当: NO
- 「必須ゲート増」該当: NO
- 「証拠種類の事前固定」該当: NO

理由:
- 探索順序を固定していない。
- Payment が明示されており、既存 MUST の置換として設計されている。
- compare でもともと必要な assertion-level evidence を、差分起点まで遡って結び直すだけで、新しい証拠型を別建てで固定していない。

## 修正指示（最小限）
1. `first behavioral fork` が「if/else だけ」を意味しないことを 1 フレーズで補足する。
   - 追加ではなく、Trigger line の `behavioral fork` の直後に `(control, data normalization, exception, mapping choice)` のような抽象例を括弧で短く入れる程度でよい。
2. `propagates to, or is neutralized before, the concrete assertion` の対称性を崩さないことを明記する。
   - neutralization 側だけを厚く書かず、NOT_EQUIVALENT 側でも assertion outcome を分ける survival witness を同等に要求する表現にする。
3. 実装時は compare checklist と Guardrail の二重化を避ける。
   - proposal の Payment 通り、旧 MUST を optional 化/削除して trigger line に置換する形を守ること。

## 結論
承認: YES