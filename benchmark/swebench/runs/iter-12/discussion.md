# Iter-12 Discussion

## 総評

提案の狙い自体は妥当です。既存の `compare` モードは、`SKILL.md` 上でもすでに
- 構造比較
- per-test tracing
- counterexample obligation
- no-counterexample obligation

を中核にしており、提案はその新設ではなく、「反証的な問いを前倒しする」調整です。このため研究コア（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）を壊してはいません。

ただし、今回の具体文言

`Before detailed tracing, state: "If NOT EQUIVALENT, which test and which assertion would diverge, and why?" — then trace that path first.`

のうち、特に `trace that path first` は、探索の初動を一つの想定 counterexample に強く固定します。これは「反証を前倒しする」という良い発想と、「探索を特定シグナル探索へ寄せすぎない」という失敗原則の境界にあります。したがって、コンセプトは支持する一方、現提案のままの文言には慎重です。

## 1. 既存研究との整合性

### 研究的に整合する点

1. `README.md` と `docs/design.md` が示す本スキルのコアは、semi-formal reasoning により
   - 明示的 premises
   - concrete tracing
   - mandatory refutation
   を強制することです。今回の提案はこのうち refutation を早めるもので、コア構造とは整合します。

2. `README.md` では、このリポジトリ自身の既存知見として「counterfactual reasoning を final gate から continuous obligation に拡張したことが有効だった」と説明されています。今回の案は、その方向性をさらに `compare` の初動に寄せるもので、方向としては一貫しています。

### DuckDuckGo MCP で確認した関連研究・資料

1. https://link.springer.com/chapter/10.1007/978-3-032-15981-6_1
   - タイトル: Interpretable Configuration Optimization for Static Program Verification via Rule-Based and Counterfactual Reasoning
   - 要点: 静的検証で counterfactual reasoning を使い、「望ましくない結果を避ける設定」を系統的に探索して探索空間を狭める、という発想を採っています。
   - 本提案との関係: 「うまく行かなかった場合に存在するはずの反例側条件を先に言語化して探索を導く」という意味で整合的です。

2. https://arxiv.org/html/2604.07679v1
   - タイトル: Towards Counterfactual Explanation and Assertion Inference for CPS Debugging
   - 要点: failing test input から、passing に変わる最小 counterfactual change を作り、失敗条件を解釈可能な形で説明する枠組みです。
   - 本提案との関係: 失敗/非等価の説明を「どの条件が変われば結果が分かれるか」という形で先に捉える考え方は、提案の backward reasoning と相性が良いです。

3. https://cadp.inrialpes.fr/ftp/publications/others/Barbon-Leroy-Salaun-17.pdf
   - タイトル: Debugging of Concurrent Systems using Counterexample Analysis
   - DuckDuckGo 検索要約: 性質違反時に返る counterexample を debugging に使うが、その理解自体が難しいため、counterexample analysis が重要であると位置付けています。
   - 本提案との関係: counterexample を中心に据えたデバッグは既存研究と整合的です。
   - 備考: 本 URL は本文 fetch 時に SSL 証明書エラーが出たため、ここでは DuckDuckGo 検索要約ベースで扱っています。

### 研究整合性の結論

「反証・counterexample を使って探索を導く」こと自体は研究的に十分妥当です。ただし、研究整合性があることと、テンプレート文言として最適であることは別です。今回の懸念は後者です。

## 2. Exploration Framework のカテゴリ選定は適切か

結論: カテゴリ A は適切です。

理由:
- 提案の本質は「何を探すか」よりも「どの順序で問うか」の変更です。
- 既存 Step 5 の counterexample/no-counterexample obligation を、新規ステップとして増やすのでなく、`STRUCTURAL TRIAGE` 後に前置する発想だからです。
- したがって、B（取得方法）や D（自己チェック追加）より、A（推論の順序・構造を変える）が主分類として自然です。

補足:
- 二次的には F（原論文・既存知見の未活用アイデア活用）にも接しています。`README.md` 上の「counterfactual reasoning の継続的義務化」と親和的だからです。
- ただし主作用は順序変更なので、A の選定で問題ありません。

## 3. EQUIVALENT 判定 / NOT_EQUIVALENT 判定への作用

### 変更前との実効的差分

変更前:
- まず structural triage
- その後、test ごとの tracing
- 最後に counterexample/no-counterexample check

変更後案:
- structural triage の直後に
  「もし NOT EQUIVALENT なら、どの test / assertion が分岐するか」を先に言語化
- その候補 path を先に追う
- その後に通常 tracing と formal conclusion

つまり本質的差分は、「反証の問いを結論直前から探索初動へ移す」ことです。

### EQUIVALENT への作用

正の効果:
- premature EQUIVALENT を抑える方向に強く働きます。
- 特に `proposal.md` が狙っている「順方向に追って差が見えないので EQUIVALENT としてしまう」バイアスには効きます。
- 真に EQUIVALENT なケースでも、「想定される counterexample 候補が立たず、立っても検証で崩れる」ことを先に確認するため、EQUIVALENT の根拠を厚くできます。

負の効果 / リスク:
- 実際には差がないケースで、無理に divergence 候補を先に作らせることで、存在しない差分へのアンカリングが起こりえます。
- その結果、探索が「その仮説を崩す/守る」方向に偏り、通常の per-test coverage が弱くなる可能性があります。

### NOT_EQUIVALENT への作用

正の効果:
- 真に NOT_EQUIVALENT なケースでは、早い段階で「どの assertion が割れるか」を具体化できれば、証拠の取り方が明確になります。
- semantic difference を見つけた後に「でも影響ないかも」と流す Guardrail #4 型のミスには一定の抑止力があります。

限定的な点:
- 既に `STRUCTURAL TRIAGE` には S1/S2 による early NOT EQUIVALENT ルートがあります。したがって構造差分で決まる NOT_EQ には追加効果はほぼありません。
- この提案の主な改善対象は、構造差分ではなく「微妙な semantic difference を見逃して EQUIVALENT に倒れる」領域です。

### 片方向にしか作用しないか

厳密には「片方向だけ」ではありません。しかし実効的には EQUIVALENT 側への作用が強いです。

- 強く効く方向: false-positive EQUIVALENT の削減
- 中程度に効く方向: semantic NOT_EQ の根拠明確化
- ほぼ効かない方向: structural-gap 型 NOT_EQ

したがって、「両方向に作用はするが、主作用は EQUIVALENT 側のバイアス補正」と評価するのが妥当です。

## 4. failed-approaches.md の汎用原則との照合

### 原則1: 探索すべき証拠の種類をテンプレートで事前固定しすぎない

ここが最大の懸念点です。

提案者は「証拠の種類ではなく問いの方向を変えるだけ」と述べていますが、文言は実際にはかなり具体的です。

- `which test`
- `which assertion`
- `trace that path first`

まで指定しているため、探索の出発点を「想定される発散 assertion」の探索へ強く寄せます。`compare` モードでは test/assertion が重要なのはその通りですが、「最初にそれを一つ仮定してその path を先に追う」という運用は、証拠タイプの半固定に近いです。

評価:
- 本質的に同じ失敗の再演とまでは言えない
- ただし、失敗原則1にはかなり接近している
- 特に `trace that path first` が危ない

### 原則2: 探索の自由度を削りすぎない

これにも軽度に抵触リスクがあります。

- 良い面: 追加は 2 行で、テンプレート全体を大きく変えない
- 悪い面: 初動の優先順序を一つの仮説 path に固定するため、自由探索の幅を狭める

`trace that path first` がなければ「初手で counterexample 候補を一度明示する」程度で済みますが、現案は「まずそこを追え」としているので、自由度の削減が実際に発生します。

### 原則3: 結論直前の自己監査に新しい必須メタ判断を増やしすぎない

これは抵触しません。

- 追加位置は結論直前ではなく structural triage の直後です。
- Step 5.5 の自己監査を増やす案ではありません。

### failed-approaches との総合評価

「完全に同一の失敗方向」ではないが、原則1・2に対する near miss です。コンセプト単位では許容できても、現行の具体文言は一歩強すぎます。

## 5. 汎化性チェック

### 明示的なルール違反の有無

提案文を確認した限り、以下は見当たりません。
- ベンチマーク対象リポジトリ名
- 特定テスト名
- 特定ケース ID
- ベンチマーク対象コード断片

したがって、この意味での明白な overfitting ルール違反はありません。

### 含まれている具体表現の扱い

提案文には以下の具体表現があります。
- `SKILL.md line 190-196`
- `Guardrail #4`
- `変更前 / 変更後` の `SKILL.md` 自己引用

これらは benchmark 固有識別子ではなく、`Objective.md` の R1 にある減点対象外の
- `SKILL.md` 自身の文言引用
- 一般概念名

に該当するため、違反とは見なしません。

### 暗黙のドメイン依存性

大きな問題はありません。理由は:
- compare モード自体が「tests の pass/fail outcome」を定義の中心にしており、提案の test/assertion 言及はその範囲内だからです。
- 特定言語、特定フレームワーク、特定テストランナーに依存した用語は入っていません。

ただし弱い懸念として、assertion-centric すぎる書き方は、差異の現れ方が
- exception type
- fixture/setup path
- import/dispatch reachability
- generated data / config / metadata

のように assertion 手前の層で決まるケースに対して、初動をやや狭める可能性があります。compare モードの定義上は最終的に test outcome に還元されるとしても、探索初手の wording としては少し狭いです。

## 6. 全体の推論品質への期待効果

期待できる改善:
- false-positive EQUIVALENT の削減
- semantic difference 発見後の「影響なし」短絡の抑制
- EQUIVALENT 結論時の no-counterexample justification の質向上

期待しにくい改善:
- structural gap 型 NOT_EQ の改善（既存 S1/S2 でほぼ足りているため）
- 非比較モード全般への波及（今回の提案は compare に局所的）

主要リスク:
- 想定 counterexample へのアンカリング
- 初手の探索が 1 本の仮説 path に寄りすぎることによる coverage 低下
- failed-approaches が警戒する「特定シグナル探索」への傾斜

総合すると、推論品質を上げるポテンシャルはありますが、現案の wording だと「バイアス是正」と「探索拘束」の両方を同時に起こしうるため、純粋改善とは言い切れません。

## 結論

監査判断としては、アイデアの方向性自体は支持します。しかし、現提案の具体文言はやや強すぎます。

より安全な方向は、例えば
- counterexample 候補を 1 つ以上先に言語化する
- ただしそれを exploration seed として使い、唯一の優先 path に固定しない
- assertion だけでなく import path / exception / output shape などの発散形も許す

という形です。要するに、「反証を前倒しする」は良いが、「その想定 path を first priority で固定する」は強すぎます。

承認: NO（理由: backward reasoning の方向性は妥当だが、提案文の `trace that path first` が探索を単一の想定 counterexample に過度に固定し、failed-approaches.md の「証拠種類の事前固定」「探索自由度の削りすぎ」に近づくため。現状のままでは回帰リスクを十分に抑えた提案とは言いにくい。）
