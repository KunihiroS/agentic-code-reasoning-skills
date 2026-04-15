# Iteration 59 — 監査コメント

## 総評
提案の着眼点自体は理解できる。`explain` モードの `SEMANTIC PROPERTIES` に相当する「不変な意味的性質」を `compare` に持ち込み、EQUIVALENT 判定の早計さを抑えたい、という発想は研究の周辺概念とも整合する。

ただし、今回の具体案である

- `SHARED INVARIANTS (required if claiming EQUIVALENT)`
- `At least one: [behavior that is identical in both changes — cite file:line from each side]`

の追加は、実効上「EQUIVALENT 側にだけ新しい必須証拠タイプを追加する」変更であり、双方向の判定品質を対称に改善するというより、EQUIVALENT のハードルだけを上げる方向に働く。

そのため、発想レベルでは妥当でも、テンプレート変更としては `failed-approaches.md` の警告にかなり近い。現状の提案のままでは承認しにくい。

---

## 1. 既存研究との整合性
DuckDuckGo MCP の search は今回ほぼ結果を返さなかったため、同じ DuckDuckGo MCP の `fetch_content` で既知 URL を直接確認した。

### 参照 URL と要点
1. https://arxiv.org/abs/2603.01896
   - `Agentic Code Reasoning` の要旨では、explicit premises・execution path tracing・formal conclusions から成る semi-formal reasoning を「certificate」として位置づけている。
   - したがって、compare モードに追加する改善は、既存の certificate 構造を補強するなら研究コアと整合する。
   - 一方で、論文の主要な anti-skip mechanism は per-item tracing と counterexample / alternative-hypothesis の義務化であり、「共有不変条件を別欄として必須化すること」自体が直接の中核ではない。

2. https://en.wikipedia.org/wiki/Observational_equivalence
   - observational equivalence は「観測可能な帰結が区別不能であること」という定義。
   - compare モードの D1「existing tests に対して同一 pass/fail outcome」を見る設計とは相性がよい。
   - ただしこの概念から直ちに「EQUIVALENT 主張時には shared invariants を最低 1 件必須にすべき」とは導かれない。観測同値の本丸は観測結果の一致であり、不変条件の明示は補助手段に留まる。

3. https://en.wikipedia.org/wiki/Invariant_(computer_science)
   - invariant は「変換後も変わらない性質」。
   - 提案の「shared invariants」という語彙自体は一般的で、compare 分析に持ち込むことは概念的に自然。
   - ただし invariant は一般に証明補助・分類補助として有効であって、必須テンプレート項目にした瞬間に探索の焦点を固定しやすい。

4. https://en.wikipedia.org/wiki/Counterexample-guided_abstraction_refinement
   - CEGAR は counterexample を使って抽象化を精密化する枠組み。
   - compare モードにはすでに `COUNTEREXAMPLE` / `NO COUNTEREXAMPLE EXISTS` があり、等価性・非等価性の判断で「反証可能性」を中心に置く現行設計は一般的な検証思想と整合する。
   - この観点では、もし equivalent 側を強化したいなら、shared invariants の新設よりも、既存の `NO COUNTEREXAMPLE EXISTS` の具体化の方が研究的には筋がよい可能性がある。

5. https://arxiv.org/abs/1907.01257
   - observational equivalence の証明に local reasoning と robustness を使うという内容。
   - 「局所的に保たれている性質」を通じて equivalence を支える発想自体は学術的に自然。
   - ただし、ここでの local reasoning はかなり形式的な証明枠組みであり、今回のような軽量な reporting field 追加が同等の効果を持つとまでは言えない。

### 小結
研究との整合性は「概念レベルではある」。
しかし、研究から直接支持されるのは主に
- 明示的 premises
- per-item tracing
- refutation / counterexample
であって、提案の新欄はそれらの直接延長というより「関連概念の導入」に留まる。

---

## 2. Exploration Framework のカテゴリ選定は適切か
カテゴリ F「原論文の未活用アイデアを導入する」の選定自体は妥当。

理由:
- proposal は `explain` 側にある `SEMANTIC PROPERTIES` 的発想を `compare` に移植しようとしている。
- `docs/design.md` でも、各 appendix template から anti-skip mechanism を抽出して skill に翻訳していることが明示されている。
- したがって「他モードの未活用アイデアを compare に応用する」という分類は Exploration Framework の F に合致する。

ただし、カテゴリ選定が正しいことと、その具体的メカニズムが良いことは別。
今回の問題はカテゴリではなく、実装形式が「新しい必須欄の追加」になっている点にある。

---

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定への作用

### 直接効果
この変更は、文言上は明確に `required if claiming EQUIVALENT` なので、直接には EQUIVALENT 側にしか作用しない。

期待できる正の効果:
- EQUIVALENT を主張する前に、少なくとも 1 件は「両者で同じ振る舞い」を file:line 付きで挙げるため、雑な同一視を減らす可能性はある。
- 「差異は見えたが実害なし」と早計するケースでは、同一性の根拠を言語化させることで多少ブレーキがかかる。

### 限界と副作用
しかし、この効き方はかなり片方向。

1. NOT_EQUIVALENT 側にはほぼ直接効かない
   - NOT_EQUIVALENT はすでに `COUNTEREXAMPLE` 欄で決まる。
   - shared invariants は required ではないため、非等価の立証には新情報を足さない。

2. EQUIVALENT の precision を上げても recall を落とす恐れがある
   - 実際には等価でも、モデルが「共有不変条件」をうまく言語化できないと、EQUIVALENT を避けて NOT_EQUIVALENT 側へ逃げる圧力が増える。
   - つまり false positive な EQUIVALENT は減っても、false negative な EQUIVALENT が増えうる。

3. 実効差分は「推論の質向上」より「判定閾値の非対称化」に近い
   - 既存テンプレートは equivalent 側にも `NO COUNTEREXAMPLE EXISTS` を要求している。
   - そこにさらに shared invariants を追加すると、equivalent 側だけ二重の説明義務を負う。
   - これは両方向の reasoning を均衡させる変更ではなく、EQUIVALENT だけを harder にする変更。

### 結論
「片方向にしか作用しないか」という監査観点に対しては、実質的には YES。
副次的な波及はあっても、主効果は EQUIVALENT 側の抑制であり、NOT_EQUIVALENT 側の品質改善は弱い。

---

## 4. failed-approaches.md の汎用原則との照合
proposal 本文では「非抵触」と主張しているが、私はそうは見ない。

### 原則1: 探索すべき証拠の種類をテンプレートで事前固定しすぎない
抵触寄り。

- `shared invariants` は、まさに「示すべき証拠の型」を新設している。
- しかも equivalent 側に限定した必須欄なので、モデルは結論に向けて「共有不変条件らしいもの」を探しにいきやすくなる。
- これは proposal の言う「探索経路は自由」と完全には言えない。

### 原則2: 探索の自由度を削りすぎない
軽度に抵触。

- compare では本来、relevant tests・call path・counterexample の探索が主軸。
- そこへ shared invariants を足すと、「まず違いを見る」以外に「同一性を 1 件は報告する」というサブ目標が生まれる。
- これは探索空間そのものを大きく狭めるほどではないが、reporting obligation によって視線を誘導する。

### 原則4: 既存の汎用ガードレールを、特定の追跡方向や観点で具体化しすぎない
かなり近い。

- proposal は Guardrail #4/#5 の補強を名目にしている。
- しかし補強の仕方が「共通不変な振る舞いを少なくとも 1 件書け」という特定観点の強制になっている。
- これは guardrail を方向非依存のまま保つより、かなり具体的な観点へ寄せている。

### 原則5: 結論直前の自己監査に新しい必須のメタ判断を増やしすぎない
形式上は ANALYSIS フェーズ内だが、実質的には equivalent 側の追加ゲート。

- proposal は「Step 5.5 や FORMAL CONCLUSION の前ではない」と言うが、required if claiming EQUIVALENT である以上、実質的には結論成立条件の一部。
- failed-approaches には「反証が見つからなかった場合の記録様式を細かく規定しすぎると、探索の質の改善よりテンプレート充足が目的化しやすい」とある。
- 今回の追加はこれにかなり近い。

### 小結
過去失敗の完全再演とまでは言わないが、本質的にはかなり近縁。
特に
- 新しい証拠タイプの必須化
- equivalent 側だけの追加報告義務
- no-counterexample 系の記録の細密化
は、failed-approaches.md が明示的に警戒している方向である。

---

## 5. 汎化性チェック

### 明示的なルール違反の有無
提案文には、少なくとも以下の NG は見当たらない。
- 特定ベンチマークケース ID
- 特定リポジトリ名
- 特定テスト名
- ベンチマーク対象実コードの断片

含まれているのは主に
- `SKILL.md` 自身の引用
- `compare` / `explain` / `SEMANTIC PROPERTIES` / `Guardrail #4/#5` のような内部概念名
であり、これは Objective の R1 注記に照らして許容範囲。

したがって、形式的な overfitting ルール違反は確認できない。

### 暗黙のドメイン依存性
大きな問題はない。

- `shared invariants` という表現は言語非依存。
- `file:line from each side` も一般的。
- 特定言語・フレームワーク・テストパターンを露骨には想定していない。

ただし、提案は compare モードの「modulo existing tests」という現在の skill 設計に強く依存しているため、一般の program equivalence というより「テスト証拠ベースの patch comparison」の文脈に最適化されている。これは SKILL.md の守備範囲としては自然だが、効果の一般性を強く主張しすぎるのは難しい。

---

## 6. 全体の推論品質がどう向上すると期待できるか

### 見込める改善
- EQUIVALENT 主張時の雑な楽観を抑える可能性はある。
- 「差異があるのに harmless と流す」誤りに対して、追加の説明責任を与える点は一定の意味がある。
- compare の記述が `explain` の semantic-property 発想と少し接続され、同一性の根拠を明文化しやすくなる。

### 見込まれる限界
- 既存の equivalent 側にはすでに `NO COUNTEREXAMPLE EXISTS` があり、目的がかなり重複している。
- したがって改善の本体が「新しい reasoning capability」ではなく「別表現での再記録」になりやすい。
- モデルが shared invariant の充足に気を取られると、より重要な per-test trace や concrete counterexample search が弱まるおそれがある。
- 全体としては、推論品質の底上げよりもテンプレート充足負荷の増加に寄る可能性が高い。

### 監査上の判断
小幅な改善可能性は認めるが、回帰リスクと failed-approaches との近さを考えると、現時点では「期待利益 > 期待コスト」とは言い切れない。

---

## 最終判断
承認: NO（理由: 研究との概念的整合性はあるが、変更の実効は EQUIVALENT 側に偏った追加報告義務であり、既存の `NO COUNTEREXAMPLE EXISTS` と機能重複しつつ、`failed-approaches.md` が警戒する「証拠タイプの事前固定」「guardrail の特定観点への具体化」「反証不在記録の様式追加」に近い。全体品質の双方向改善より、判定閾値の非対称化とテンプレート充足化を招く懸念が上回る。）
