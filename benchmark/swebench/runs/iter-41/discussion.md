# Iteration 41 — Discussion

## 1. 既存研究との整合性

### 調査結果

1. https://arxiv.org/abs/2603.01896
   - 要点: Agentic Code Reasoning 論文は、semi-formal reasoning により「明示的前提」「実行経路トレース」「形式的結論」を強制すると、patch equivalence / fault localization / code QA の精度が改善すると述べている。
   - 本提案との関係: compare モードへ追加の追跡粒度を入れる方向性自体は、論文の「structured certificate によって推論の飛躍を防ぐ」という思想と整合する。

2. https://arxiv.org/html/2603.01896v2
   - 要点: 論文本文では、explain 系テンプレートに data flow analysis があり、key variable について「Created / Modified / Used」を追跡させている。これは code QA 側での未活用アイデアとして実在する。
   - 本提案との関係: explain の data-flow 観点を compare に移植する、という提案の出典根拠はある。

3. https://www.sciencedirect.com/topics/computer-science/data-flow-analysis
   - 要点: Data-flow analysis は、プログラム中で値がどのように流れるか、どこで定義されどこで使われるかを静的に把握する古典的手法と説明されている。
   - 本提案との関係: 「変更された値の伝播を追う」という発想そのものは一般的・妥当な静的解析観点であり、場当たり的ではない。

4. https://ui.adsabs.harvard.edu/abs/2026arXiv260301896U/abstract
   - 要点: 論文要約の再掲。semi-formal reasoning は execution-free なコード意味解析を改善し、patch equivalence にも有効だとされる。
   - 本提案との関係: compare の証拠収集をもう少し厳密化する、という方向の妥当性は補強される。

### 評価

研究整合性は「方向としてはある」。特に、explain モードの data-flow 観点を compare に持ち込む、という F カテゴリの主張には根拠がある。

ただし、外部根拠が支持しているのは「data flow は有用な観点である」という一般論であり、「compare の Claim 行で variable / return の流れを必須化することが最適」というところまでは支持していない。つまり、研究整合性はあるが、提案文の具体的 wording まで強く正当化しているわけではない。

## 2. Exploration Framework のカテゴリ選定は適切か

結論: カテゴリ F の選定は概ね妥当。

理由:
- Objective.md の F には「論文の他のタスクモード（localize, explain）の手法を compare に応用する」が明記されている。
- 本提案はまさに explain の DATA FLOW ANALYSIS を compare の Claim 記述に移植しようとしている。
- したがって、カテゴリ F の中でも mechanism 2 の選択は素直。

留保:
- 実際の変更は「新規手法の導入」というより「既存 compare 文言の精緻化」なので、見かけ上は E（表現改善）にも近い。
- ただし、発想の根拠が論文の別モード由来である以上、主カテゴリを F とする判断は許容範囲。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方への作用

### 実効的差分

提案の実効差分は compare テンプレートの Claim C[N].1 / C[N].2 の説明文に、

- changed code から assertion outcome まで trace せよ

に加えて、

- changed value が途中で流れ込む variable / return を追え

を足す、というもの。

つまり、変更対象は:
- STRUCTURAL TRIAGE ではない
- COUNTEREXAMPLE / NO COUNTEREXAMPLE セクションではない
- pass-to-pass 用の behavior 記述行でもない
- compare の主要 per-test trace 行だけ

である。

### EQUIVALENT 判定への作用

こちらには比較的効きやすい。

期待できる改善:
- 変更箇所から assertion までを飛ばして「たぶん届かない」と雑に結論する誤りを減らせる。
- README.md でも persistent failure は EQUIVALENT 側に寄っており、提案仮説の狙いは現状課題と整合する。
- docs/design.md の「incomplete reasoning chains」対策としても筋が良い。

### NOT_EQUIVALENT 判定への作用

こちらへの寄与は限定的。

理由:
- compare にはもともと COUNTEREXAMPLE と diverging assertion の義務があるため、NOT_EQUIVALENT 側は既に比較的強い。
- 差分が assertion に届くことを示すには value flow が有効な場合もあるが、既存テンプレートでも十分に示せるケースが多い。

### 非対称性の懸念

本提案は「両方向に同程度効く変更」ではなく、実質的には EQUIVALENT 側を主に狙った変更に見える。

さらに、差分が assertion に影響する経路は variable / return の流れだけではない。
たとえば:
- 例外の発生有無
- control flow の分岐差
- 共有状態やミュータブルオブジェクトの更新
- alias を介した変更
- call の有無や順序差
- side effect

のような差分は、value flow の phrasing だけでは捉えきれない。

そのため、この wording は
- EQUIVALENT 側にはプラスになりうる一方、
- NOT_EQUIVALENT 側や非 value-centric なケースでは、モデルを不必要に value-tracking へ寄せる

可能性がある。

結論として、「片方向にしか作用しない」とまでは言わないが、実効的には EQUIVALENT 側に強く偏った変更であり、双方向の改善としては弱い。

## 4. failed-approaches.md との照合

提案文は「全原則と非抵触」としているが、そこは楽観的すぎる。

### 原則1: 探索シグナルを事前固定しすぎる変更は避ける

軽度の抵触リスクあり。

今回の変更は読解順序を固定してはいないが、Claim 記述において「何を追うか」を value / variable / return にかなり寄せている。これはまさに evidence type の半固定であり、failed-approaches.md の

- 特定シグナルの捜索へ寄せすぎるな

という警告と無関係ではない。

特に compare では、本来追うべきなのは「変更から test outcome までの concrete causal path」であって、その媒介は value flow に限られない。ここを variable / return に狭めると、確認バイアスの入口になりうる。

### 原則2: 探索の自由度を削りすぎない

軽度の抵触リスクあり。

変更は局所的だが、局所的な wording でもモデルの探索の見方を細らせることはある。差分影響が control-flow・exception・state mutation 由来のケースで、value-flow 探索を優先してしまう懸念がある。

### 原則3: 局所的仮説更新を前提修正義務に直結させない

抵触なし。

この提案は仮説更新プロセスには触れていない。

### 原則4: 結論直前の必須メタ判断を増やしすぎない

抵触なし。

Step 5.5 などの最終ゲート増設ではない。

### 総評

failed-approaches.md のブラックリストと完全同型ではないが、
「探索すべき証拠の種類をテンプレートで少し固定する」方向に踏み込んでおり、無抵触とは言いにくい。

## 5. 汎化性チェック

### 明示的なルール違反の有無

提案文中に以下は見当たらない:
- ベンチマークケース ID
- 特定のリポジトリ名
- 特定のテスト名
- 対象リポジトリのコード断片

含まれているのは:
- SKILL.md 自体の行引用
- 一般的な説明文
- 論文 Appendix / モード名

なので、Objective.md の R1 観点では明示的な overfitting 記述違反はない。

### 暗黙のドメイン仮定

ただし wording には暗黙の偏りがある。

「follow the changed value through each variable or return it flows into」は、
- named variable が明示的に存在する
- return value が主要な伝播媒体である

という、比較的命令型・手続き型なコード像を前提にしている。

この phrasing は次のようなケースで自然さが落ちる:
- 例外主導の差分
- 副作用主導の差分
- callback / event / async 境界
- 参照共有や aliasing が本質の差分
- declarative / DSL / config-heavy なコード
- pattern matching や data constructor を主とする言語

したがって、汎化性は「高いが満点ではない」ではなく、「中程度の懸念あり」が妥当。

## 6. 全体の推論品質がどう向上すると期待できるか

### 良い点

- changed code から assertion までの因果鎖をより具体化させる効果は期待できる。
- docs/design.md の incomplete reasoning chains 対策としては筋が良い。
- 変更規模が非常に小さく、研究コアを壊さない。

### 限界

- value flow だけを明示すると、compare で重要な他の媒介経路を相対的に弱くする。
- 既存 compare の弱点が「assertion までの concrete causal trace 不足」なのか、「value flow の不足」なのかは同一ではない。
- したがって、この変更は問題の一部には効くが、一般原則としては少し狭い。

### より良い方向性

もし同じ狙いを維持するなら、variable / return に限定せず、例えば

- value
- control flow
- exception behavior
- state mutation

を含む「concrete propagation path」を求める wording の方が、compare の一般原則としては適切だった可能性が高い。

## 総合判断

本提案は
- 研究との整合性はある
- カテゴリ F の選定も妥当
- 小さく安全な文言変更である

一方で、監査観点として重要なのは「汎用原則として本当に筋が良いか」であり、その点では現行 wording がやや狭い。

特に問題なのは、
- compare で追うべき因果経路を variable / return flow に寄せすぎていること
- failed-approaches.md の「探索シグナルを事前固定しすぎるな」に部分的に触れていること
- 実効的には EQUIVALENT 側への片寄った最適化に見えること

である。

小変更ではあるが、監査役としては「この wording のまま実装してよい」とまでは言いにくい。

承認: NO（理由: 研究的な方向性は妥当だが、提案文の具体的 wording が compare の因果トレースを value / variable / return に狭めすぎており、failed-approaches.md の『探索シグナルの事前固定を避ける』原則に部分的に抵触する。EQUIVALENT 側には効きうる一方で、NOT_EQUIVALENT や非 value-centric な差分への一般性が弱いため、そのままの採用は推奨しない。）
