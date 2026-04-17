# Iter-2 Discussion

## 総評
提案は、既存の `compare` が「差分を見つけたこと」と「テスト oracle に効く重要差分であること」を混同しやすい、という問題に対して、既存の STRUCTURAL TRIAGE に optional な優先度付けを足すもの。変更規模が小さく、研究コア（前提・トレース・反証・形式的結論）を弱めず、`compare` の証拠駆動性を補強する方向なので、監査 PASS の下限は満たしていると判断する。

## 1. 既存研究との整合性

### Web 調査メモ
1. https://en.wikipedia.org/wiki/Test_Oracle
   - 要点: test oracle は「入力とプログラム状態に対して何が正しい結果か」を与える情報源であり、実際の結果と期待結果を比較するための基準。
   - 含意: 差分の重要性を「asserted output / exception / externally visible state」に結びつける発想自体は、テストの観測可能結果を中心に据えるので妥当。

2. https://arxiv.org/html/2503.18597v1
   - 要点: 回帰検査では「振る舞い差分を全部 regression とみなす」と false positive が増える。重要なのは、見つかった behavioral difference が intended か unintended かの分類。
   - 含意: 提案の「差分は全部同格ではない」「oracle に結びつく差分を優先すべき」という方向性は、一般的な回帰判定の知見と整合する。

3. https://softwarefoundations.cis.upenn.edu/plf-current/Equiv.html
   - 要点: behavioral equivalence は、式なら全 state で同じ結果、コマンドなら同じ初期 state から同じ最終 state（または両方 diverge）を与えること。
   - 含意: 等価性の本質が「観測可能な振る舞いの一致」にある以上、提案が差分を観測可能性で整理するのは一般原則として筋がよい。

### 評価
研究的には、「観測される差分」と「単なる内部差分」を区別する発想は自然。しかも提案は compare の結論条件そのものを変えておらず、既存の per-test tracing / counterexample obligation の上に“探索優先度”を足すだけなので、README と docs/design.md が強調する certificate-based reasoning とも矛盾しない。

## 2. Exploration Framework のカテゴリ選定
提案者の分類 C「比較の枠組みを変える」は適切。

理由:
- これは読み順固定や新しい自己監査ゲート追加ではなく、「発見済み差分をどう分類して比較判断に結びつけるか」の枠組み変更。
- Objective.md の C 例示にある「差異の重要度を段階的に評価する」にかなり直接一致している。
- B「情報の取得方法」よりも、取得済み情報の意味づけ変更が主眼なので C の方が正確。

## 3. EQUIVALENT / NOT_EQUIVALENT の両方向への作用

### 変更前との差分
変更前:
- 差分発見後、どの差分を深掘りすべきかの補助分類がない。
- そのため、表層的・内部的な差分に注意が吸われ、oracle まで届かないまま重要差分扱いしやすい。

変更後:
- 差分を ORACLE-VISIBLE / ORACLE-INVISIBLE に仮ラベルして、前者を先に test oracle へ結線する。
- ただし mandatory obligation は不変で、EQUIVALENT なら「no counterexample exists」、NOT EQUIVALENT なら具体 counterexample が依然必要。

### EQUIVALENT 判定への作用
正方向:
- 偽 NOT_EQUIVALENT を減らしやすい。内部実装差分・補助関数分割・キャッシュ・表現差などに過剰反応せず、実際の assertion 差に届くかで重要度を見直せるため。

逆方向リスク:
- ORACLE-INVISIBLE と早く決めすぎると、本当は観測される差分を見落として偽 EQUIVALENT を増やす危険がある。
- とくに exception type/message、順序、外部状態更新、ログ/メトリクス、タイミング依存のような「一見内部だが test が拾う」差分は危ない。

### NOT_EQUIVALENT 判定への作用
正方向:
- 具体 counterexample に近い差分を優先するため、NOT_EQUIVALENT の根拠が強くなる。
- 「差分があるから違うはず」ではなく、「この差分がこの assertion を割る」という形に寄せられる。

逆方向リスク:
- ORACLE-VISIBLE のみを実質上の主戦場にしすぎると、当初は visibility が低く見える差分から counterexample に至る経路を拾いにくくなる。

### 片方向最適化か
現状の提案文だけでも、片方向専用ではない。
- 主効果は偽 NOT_EQ の抑制。
- ただし、oracle 連結を優先するので偽 EQUIV の抑制にも理屈はある。
- 一方で、偽 EQUIV 側の悪化リスクも明記されており、提案者自身が回避策を示している。

よって「片方向にしか作用しない」提案ではない。ただし、効果の重心は EQUIVALENT 側の安定化にやや寄っている。

## 4. failed-approaches.md との照合

### 良い点
- 「新しい必須ゲートを増やさない」点は failed-approaches の方針に合う。
- 既存の反証義務や per-test tracing を置き換えないので、形式だけ増やして結論前チェックを過剰化するタイプではない。

### 懸念点
本提案には、failed-approaches の次の失敗原則に近づく面が少しある。
- 「次の探索で探すべき証拠の種類をテンプレートで事前固定しすぎる変更は避ける」
- 「既存の汎用ガードレールを、特定の追跡方向や観点で具体化しすぎない」

理由:
- S4 は optional ではあるが、実質的には「oracle-visible 差分を優先せよ」という追跡方向を与える。
- これは弱い形ながら探索経路のバイアスになりうる。

ただし、本質的な再演とまでは言いにくい。
- 証拠の種類を新たに固定しているというより、既に見つかった差分の優先順位付けをしているだけ。
- 必須化されておらず、既存の反証義務も残る。
- 読み始めの順序固定ではなく、STRUCTURAL TRIAGE 内の軽い補助線に留まっている。

結論として、failed-approaches の「再演」ではなく「周辺リスクあり」レベル。

## 5. 汎化性チェック

### ルール違反の有無
明確な違反は見当たらない。
- ベンチマークの具体ケース ID: なし
- 特定リポジトリ名: なし
- 特定テスト名: なし
- ベンチマーク実コード断片: なし

### 補足
- `Iter-2 Proposal` や `focus_domain: overall` は実験管理上のメタ情報であり、ベンチマーク対象の固有識別子ではない。
- `~200 lines` や `5行以内` は閾値記述であって、ケース固有 ID ではない。
- 差分例は SKILL.md 自己引用であり、Objective.md の R1 の減点対象外に入る。

### ドメイン暗黙依存の有無
大きなドメイン依存はない。`asserted output / exception / externally visible state` は言語横断的に通る。
ただし、提案文はやや「テストが明示 assertion を持つ典型的単体テスト」を想起させやすい。イベント、並行性、性能、UI、ログ観測などでも成立することを説明に少し足すと、汎化性はさらに明確になる。

## 6. 全体の推論品質への期待効果
期待できる改善は次の通り。

1. salience bias の緩和
   - 差分の“見つけやすさ”ではなく“観測結果への接続性”で優先順位をつけられる。

2. compare の証拠密度の向上
   - NOT_EQUIVALENT の主張が、抽象的な意味差ではなく具体 assertion 差へ寄る。

3. tracing effort の配分改善
   - 大きな差分や内部差分が多いケースで、全部を同格に追う無駄を減らしやすい。

4. 既存研究コアとの両立
   - 前提、トレース、反証、結論の骨格はそのままで、比較判断の焦点だけを調整している。

## PASS に近づけるための具体的修正指示
1. `ORACLE-INVISIBLE` を断定語にしないこと。
   - 修正案: 「currently not connected to an existing test oracle」や「not yet shown oracle-visible」のように、暫定ラベルだと分かる表現へ弱める。
   - 理由: 偽 EQUIVALENT の主因は早すぎる不可視判定なので、ここを“仮分類”にするだけで回帰リスクが下がる。

2. S4 の目的を「探索制約」ではなく「優先度付け」であると明記すること。
   - 修正案: `prioritize first, but do not treat ORACLE-INVISIBLE as irrelevant without test-path tracing when it may affect observable behavior` に近い一文を説明部で補う。
   - 理由: failed-approaches の「追跡方向の半固定」懸念を弱められる。

3. 期待効果の記述を少し弱め、両方向性をより対称に書くこと。
   - 修正案: 「主に偽 NOT_EQ を減らすが、oracle 連結不足に起因する偽 EQUIV の拾い直しにも補助的に効く」と書き換える。
   - 理由: 現状は実際の重心が EQUIV 側安定化なのに、両側へ同程度に効くように見せており、監査上やや強弁に見える。

## 結論
最大の懸念は「oracle-invisible の早期ラベルが偽 EQUIVALENT を誘発しうること」だが、これは optional な優先度付けであり、failed-approaches の本質的再演でも、汎化性違反でも、片方向最適化が明白な案でもない。軽微な表現修正で十分吸収可能。

承認: YES
