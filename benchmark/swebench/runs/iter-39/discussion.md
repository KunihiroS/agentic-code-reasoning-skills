# Iter-39 Discussion

## 総評

提案は、SKILL.md の Step 3 にある CONFIDENCE 行を

- 変更前: `CONFIDENCE: high / medium / low`
- 変更後: `CONFIDENCE: high (grounded in P[N]) / medium / low`

へ精緻化し、high を宣言する場合だけ「どの前提に立脚しているか」を明示させるものです。

結論から言うと、この変更は
- 研究コアと整合的
- failed-approaches.md の禁止方向をほぼ踏まない
- 汎化性も高い
- 回帰リスクも小さい

一方で、改善幅は大きくなく、効き方は「新しい探索能力を足す」というより「根拠のない過剰確信を弱める」タイプです。したがって、効果は plausibly positive だが限定的、という評価です。

## 1. 既存研究との整合性

### 1-1. Agentic Code Reasoning 論文との整合
- URL: https://arxiv.org/abs/2603.01896
- 要点:
  - semi-formal reasoning は、明示的な premises、execution path tracing、formal conclusion を要求することで「certificate」として働き、unsupported claim を減らす。
  - patch equivalence / fault localization / code QA の各タスクで精度改善が報告されている。
- 本提案との関係:
  - 「high confidence は premise 参照付きでのみ許す」という変更は、論文の certificate 的発想と整合する。
  - ただし論文が直接「confidence は premise 番号付きで書け」と主張しているわけではない。したがって、これは論文のコアを拡張する軽微な運用補強であり、論文の未活用アイデア導入というより既存コアの補強に近い。

### 1-2. Confidence calibration 一般研究との整合
- URL: https://aclanthology.org/2024.findings-acl.515/
- 要点:
  - Fact-and-Reflection (FaR) は、まず relevant facts を出させ、その後に reflection させることで calibration を改善し、Expected Calibration Error を 23.5% 下げたと報告している。
  - 「答え」より前に「根拠となる fact」を表に出させることが calibration 改善に効く、という方向性を示している。
- 本提案との関係:
  - 本提案も「高い確信」を出す前に、その拠り所となる前提を外在化させるため、発想としてはかなり近い。
  - ただし FaR は QA 全般の calibration 研究であり、コード推論における compare タスクへ直接の外挿ではない点は留保が必要。

### 1-3. Overconfidence 低減研究との整合
- URL: https://arxiv.org/html/2502.11028
- 要点:
  - LLM の overconfidence は実用上のリスクであり、structured prompting や alternative consideration が miscalibration を減らしうる。
  - 特に「考慮すべき別の可能性を明示する」ことが過剰確信の抑制に寄与しうると整理されている。
- 本提案との関係:
  - 本変更は alternative path を直接増やすものではないが、「high confidence を無根拠に言い切れなくする」ので、少なくとも overconfidence 対策としての方向性は妥当。

### 研究整合性の総括
研究上の裏付けは十分にある。ただし直接的に支持されているのは「confidence を evidence/facts と結びつけると calibration が良くなりうる」という一般原理であり、本提案の 1 行変更がどれほど大きな改善を生むかまでは既存研究から強くは言えない。

## 2. Exploration Framework のカテゴリ選定は適切か

実装者はカテゴリ D（メタ認知・自己チェックを強化する）を選んでいる。これは概ね適切です。

理由:
- 変更対象は探索順序ではなく、探索中の「自分の確信をどう表明するか」というメタ認知レイヤー。
- 新しい比較軸や test-level 手順は追加していないため、A/C ではない。
- 文面の変更ではあるが、単なる wording polish ではなく「high を名乗る条件」を変えるので、E より D と見る方が本質に近い。

補足すると、この提案は D と E の境界上にはあります。表面的には 1 行の wording change ですが、作用点はフォーマットの見た目ではなく「根拠なき high confidence を抑える」という自己監査的メカニズムです。そのため、主カテゴリ D という整理は妥当です。

## 3. EQUIVALENT 判定 / NOT_EQUIVALENT 判定への作用

## 3-1. 作用メカニズム
この変更が直接変えるのは「探索中の hypothesis に対して、high confidence をどれだけ気軽に宣言できるか」です。つまり、結論を直接変えるルールではなく、探索中の確信の出し方を抑制する soft control です。

期待される効果は次の通りです。
- unsupported な high confidence を medium/low に下げやすくなる
- その結果、仮説への早すぎるコミットを弱める
- 代替仮説や追加確認へ戻る心理的余地を残す

## 3-2. EQUIVALENT への作用
EQUIVALENT 誤判定は、典型的には「差分はあるがテスト結果に効かない」と早く確信しすぎるケース、あるいは「反例がなさそう」と premature closure するケースで起きやすいです。

この変更は、そうした premature closure を少し抑える方向に働きます。特に、high confidence の根拠が premise に接続できない場合、探索継続や premise 再点検に戻りやすくなるため、EQUIVALENT 側の誤答抑制には比較的効きやすいです。

## 3-3. NOT_EQUIVALENT への作用
NOT_EQUIVALENT 誤判定にも理屈上は効きます。たとえば、局所的な semantic difference を見つけた瞬間に「これはテスト outcome も違うはずだ」と過剰確信してしまう場合、high confidence に premise linkage を要求することで、test-path まで追えているかを自省しやすくなります。

ただし NOT_EQUIVALENT 側は、もともと SKILL.md に
- per-test tracing
- counterexample obligation
- diverging assertion の特定

がすでに入っており、証拠要求が強いです。そのため今回の 1 行変更の追加効果は、EQUIVALENT 側より小さい可能性が高いです。

## 3-4. 片方向にしか作用しないか
「完全に片方向」ではありません。仕組み自体は、unsupported な high confidence 全般を抑えるため、理論上は両方向に作用します。

ただし実効的には非対称です。
- EQUIVALENT 側: 「反例なし」を早く信じすぎる誤りを抑えるので効きやすい
- NOT_EQUIVALENT 側: 既存の counterexample 要件が強いため、追加効果は相対的に小さい

したがって、「両方向に作用するが、強さは対称ではない」というのが妥当な評価です。

## 4. failed-approaches.md の汎用原則との照合

### 4-1. 「特定シグナルの捜索」への寄りすぎ
今回の変更は「次に何を探せ」とは指定していません。要求しているのは high confidence の場合に premise 番号を明記することだけです。したがって、探索対象を特定シグナルに固定する変更ではありません。

この点で failed-approaches.md の最初の禁止原則には基本的に抵触しません。

### 4-2. 探索の自由度を削りすぎない
読み始める順番や、どの境界を先に見るかを固定していないため、探索経路の自由度はほぼ維持されています。この点でも大きな抵触はありません。

### 4-3. 局所的な仮説更新を前提修正義務へ直結させすぎない
今回の変更は、仮説が崩れた瞬間に premise の修正を義務化するものではありません。high confidence を名乗る条件を厳しくするだけで、局所更新と global premise 管理を強く結びつけてはいません。

この意味で、failed-approaches にある「探索中の局所的な仮説更新を、即座の前提修正義務に直結させすぎない」にも大筋では抵触しません。

### 4-4. 結論直前の新しい必須メタ判断の追加
変更箇所は Step 3 であり、Step 5.5 の pre-conclusion self-check ではありません。したがって blacklist の中でも最も危険な「結論直前の新しい判定ゲート追加」には当たりません。

### 4-5. ただし残る懸念
懸念がゼロではありません。現行 SKILL.md にはすでに
- `EVIDENCE: [what supports this hypothesis — cite premises or prior observations]`
- `Do not treat guesses as premises. Every later claim must reference a premise by number.`

があり、すでに evidence-premise linkage はかなり要求されています。そのため今回の変更は、新原則の導入というより既存要求の再ラベル化に近い面があります。

つまり、「本質的に同じ失敗の再演」ではないが、「既存ガードレールの重複強調」に留まって効果が薄い」リスクはあります。

## 5. 汎化性チェック

## 5-1. 明示的な固有識別子の有無
提案文には、ベンチマーク対象リポジトリ名、テスト名、関数名、クラス名、ファイルパス、ケース ID、対象コード断片の引用は含まれていません。

含まれている具体表現は主に
- `Step 3`
- `CONFIDENCE`
- `P[N]`
- `Guardrail #1/#2/#4`
- `iter-39`
- 変更行数

のような、SKILL 自身またはイテレーション運用上のメタ情報です。これは benchmark target を狙い撃ちする固有識別子とは性質が違います。

厳密に言えば `iter-39` のような数値付き運用メタ情報は proposal 文中に存在します。ただし、これは過剰適合を示す benchmark case ID ではなく、単なる反復管理ラベルです。したがって、汎化性違反として強く問題視する必要はありません。

## 5-2. ドメイン・言語・テストパターン依存性
提案は
- 特定言語の構文
- 特定フレームワーク
- 特定のテストスタイル
- 特定のリポジトリ構造

を前提としていません。premise 番号への grounding は、任意の言語・任意の静的コード推論タスクで成立します。

このため、汎化性は高いと判断できます。

## 6. 全体の推論品質への期待改善

期待できる改善は次の 3 点です。

1. 高確信のハードルが少し上がる
- 「なんとなく high」と書きにくくなり、根拠の外在化が促される。

2. unsupported certainty の早期露見
- 仮説自体は立ててもよいが、high confidence を付けるには premise linkage が必要なため、思い込み混入が可視化されやすくなる。

3. 既存コアを壊さず calibration を補強できる
- premises / tracing / refutation / conclusion という研究コアを変えずに、確信表明だけを狭く補強している。

一方で、限界も明確です。
- 新しい証拠収集行動を増やす変更ではない
- refutation の粒度を直接強化する変更でもない
- agent が単に `medium` を多用するだけなら、推論そのものは改善しない

したがって、期待値としては「大幅な能力向上」ではなく、「過剰確信による取りこぼし・見落としをわずかに減らす軽量な calibration 改善」です。

## 最終判断

私はこの提案を、
- 汎用的で
- 研究コアに整合し
- blacklist を実質回避しており
- 回帰リスクが低い

という理由で前向きに評価します。

ただし、追加効果は限定的であり、既存の EVIDENCE / premise discipline とかなり近いため、「効くとしても小さく効く」タイプの変更です。大きな改善を約束する提案としては弱いですが、1 行変更としては合理的です。

承認: YES