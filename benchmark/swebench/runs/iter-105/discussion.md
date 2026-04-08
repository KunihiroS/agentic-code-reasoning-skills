# Iter-105 監査ディスカッション

## 総論

結論から言うと、この提案の問題は「観測境界まで追え」という一般原則そのものよりも、
その原則を Guardrail #4 の現在位置に 1 行追加することで、実効的には **EQUIVALENT 側にだけ追加の立証責任を載せる** 点にあります。

提案者は「差異を中間ノードで打ち切る不完全推論を減らす」ことを狙っていますが、
変更前との差分で見ると、これは NOT_EQUIVALENT を出す経路にはほぼ作用せず、
「差異はあるが無害」と結論する経路だけを厳格化します。
`failed-approaches.md` の原則 #1, #4, #6, #12 にかなり近い危険があります。

また、「a test assertion would observe a value」という表現は一見抽象的ですが、
実際にはエージェントに「assertion という物理的ターゲットを特定せよ」と読まれやすく、
原則 #22, #26 が警戒している探索予算消費型の挙動を誘発する可能性があります。

したがって、現状の提案文のままでは承認しません。

---

## 1. 既存研究との整合性

注: DuckDuckGo MCP の search エンドポイントは今回の実行環境では結果を返さなかったため、
同じ DuckDuckGo MCP の fetch_content で公開 URL を直接取得して確認しました。

### 参照URLと要点

1. Agentic Code Reasoning
   - URL: https://arxiv.org/abs/2603.01896
   - 要点:
     - semi-formal reasoning は、明示的 premises、execution path tracing、formal conclusion を要求して、スキップや unsupported claims を防ぐ「certificate」として機能する。
     - つまり、提案の方向性である「差異を見つけた後に下流まで追跡を要求する」は、研究の基本思想とは整合する。
     - 一方で、この論文要約から直接に導けるのは「追跡の必要性」であって、「EQUIV 側だけに終端条件を追加せよ」ではない。

2. Program slicing
   - URL: https://en.wikipedia.org/wiki/Program_slicing
   - 要点:
     - slicing は「point of interest における値へ影響する文」を依存関係に沿って追う考え方であり、
       中間ノードで止めず観測点まで因果連鎖を見る発想そのものは妥当。
     - この観点から見ても、「差異の影響が最終的に観測されるか」を確認する考えは一般原則として筋がよい。
     - ただし、一般に slicing criterion は「観測点」を意味論的に定めるのであって、
       特定のソース上の assertion 記述の発見を必須にすることとは別問題である。

3. Test oracle
   - URL: https://en.wikipedia.org/wiki/Test_oracle
   - 要点:
     - テストは最終的に oracle によって actual と expected を比較する。assertion はその一実装形態にすぎない。
     - したがって、「observable behavior / oracle-relevant outcome」まで追うという抽象化は妥当だが、
       「assertion が値を観察する地点」と言い切ると、テストフレームワーク依存・表現依存になる。
     - 例外期待、終了コード、ログ、状態変化、snapshot、property-based check など、観測は assertion 文一つに還元できない場合がある。

### 研究整合性の評価

- 良い点:
  - docs/design.md が強調する「incomplete reasoning chains」を直接狙っている点は研究コアに沿っています。
  - README/設計文書がいう「analysis process を constrain して reasoning を改善する」という方向にも合っています。

- 問題点:
  - 研究コアとの整合性はあるものの、今回の具体的な差分は「追跡を強化する一般原則」を、
    Guardrail #4 の dismissal 条件にだけ結びつけています。
  - そのため、研究上は筋がよいアイデアでも、SKILL.md への落とし込み方としては非対称に働く懸念が強いです。

---

## 2. Exploration Framework のカテゴリ選定は適切か

### 判定

カテゴリ E を主カテゴリ、F を副カテゴリとする整理自体は形式上は妥当です。

### 理由

- E. 表現・フォーマット改善:
  - 実際にやっていることは Guardrail #4 の 1 行文言修正であり、提案の見た目は明らかに E です。

- F. 原論文の未活用アイデア導入:
  - docs/design.md が列挙する failure pattern に「Incomplete reasoning chains」があり、
    proposal もそこを根拠にしています。
  - よって、「論文の失敗分析の知見を既存 guardrail に反映する」という意味では F 的でもあります。

### ただし重要な留保

カテゴリ選定が正しいことと、提案メカニズムが妥当であることは別です。
今回の問題はカテゴリではなく、
「終端条件の追加先が dismissal path に限定されている」ことです。

つまり、カテゴリ E/F の選定自体は大きな問題ではないが、
そこから導いた具体差分は failed-approaches の危険地帯に入っています。

---

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定への作用

## 変更前後の実効差分

変更前の Guardrail #4:
- semantic difference を見つけたら、relevant test を differing code path に trace してから、
  「impact がない」と結論せよ

変更後の Guardrail #4:
- semantic difference を見つけたら、relevant test を differing code path に trace し、
  さらに「test assertion would observe a value」に到達してから、
  「impact がない」と結論せよ

この差分で追加される義務は、文法上も意味上も
「before concluding the difference has no impact」にのみ係っています。

### EQUIVALENT への作用

強く作用します。

- EQUIVALENT を出すには、差異があってもそれが test outcome を変えないと示す必要があります。
- 今回の変更は、その「無害性」の立証コストを上げます。
- したがって、差異が見つかったケースでは EQUIVALENT を出しにくくなります。
- 方向としては、proposal の狙い通り、根拠の弱い誤 EQUIV は減る可能性があります。

### NOT_EQUIVALENT への作用

ほぼ直接作用しません。

- NOT_EQUIVALENT は compare template 上、counterexample が確定した時点で停止できます。
- SKILL.md には既に「COUNTEREXAMPLE (required if claiming NOT EQUIVALENT)」「confirmed via traced code paths, proceed directly to FORMAL CONCLUSION」があります。
- 今回の 1 行追加は、この経路を強化していません。
- よって proposal が述べる「EQUIV / NOT_EQ ともに改善方向」は過大評価です。

### 監査上の判断

これは実効的に **片方向の変更** です。

- 誤 EQUIV を減らす方向には作用しうる
- しかし誤 NOT_EQ を減らす仕組みは新たに入っていない
- しかも EQUIV 側だけ立証責任を上げるので、全体精度ではなく判定バランスを歪めるリスクがある

従って、failed-approaches.md 原則 #6 が言う
「対称的な文言に見えても、変更前との差分が非対称なら効果も非対称」に該当します。

---

## 4. failed-approaches.md の汎用原則との照合

提案文の自己評価では「非抵触」とされていますが、私はそうは見ません。

### 強く抵触する原則

1. 原則 #1 判定の非対称操作は必ず失敗する
   - 今回の追加義務は、差異を dismiss して EQUIV 側へ倒すときにだけ発火します。
   - これは実質的に EQUIV 側の立証責任引き上げです。

2. 原則 #4 同じ方向の変更は表現を変えても同じ結果になる
   - proposal は「明確化」であって閾値移動ではないと見せていますが、
     実効としては「EQUIV を出すための要件を厳しくする」方向です。
   - 方向が同じなら、過去失敗の言い換えである可能性が高いです。

3. 原則 #6 対称化は既存制約との差分で評価せよ
   - 提案者は両方向に効くと主張しますが、変更前との差分で見ると dismissal path にしか新効果がありません。
   - まさに #6 が警戒するパターンです。

4. 原則 #12 アドバイザリな非対称指示も実質的な立証責任の引き上げになる
   - Guardrail はテンプレート本体より弱い形でも、モデルには十分強く効きます。
   - 特に「before concluding X」という形は、その結論を出すための前提条件として解釈されやすいです。

### 中程度に抵触する原則

5. 原則 #22 抽象原則での具体物の例示は物理的探索目標として過剰適応される
   - proposal は「assertion は状態・性質の記述だ」と弁護していますが、文面には実際に assertion という具体物が出ています。
   - エージェントが「どの assertion か」を探し始める危険があります。
   - とくに大規模テストコードや間接的 oracle を使うテストでは、探索コストを増やします。

6. 原則 #26 中間ステップでの過剰な物理的検証要求は探索予算を枯渇させる
   - 変更文自体は file:line 義務までは入れていませんが、
     実運用では assertion 特定の再探索を誘発しやすいです。
   - proposal が想定するより重くなる可能性があります。

### 提案者の「非抵触」主張への反論

- 「EQUIV/NOT_EQ の両方に同等に作用する」: いいえ。差分は dismissal 側だけに載っています。
- 「assertion は意味論的境界であり具体物ではない」: 文言上は具体物です。より安全なのは observable outcome / oracle-visible effect のような状態記述です。
- 「完全立証義務ではない」: その点自体は正しいが、だからといって非対称性が消えるわけではありません。

---

## 5. 汎化性チェック

### 明示的なルール違反の有無

- ベンチマークケース ID: なし
- 特定リポジトリ名: なし
- 特定テスト名: なし
- ベンチマーク実コード断片: なし

この点では大きな違反は見当たりません。

### ただし注意点

proposal には変更前/変更後の Guardrail 文が code block で引用されています。
これはベンチマーク対象コードではなく SKILL.md 自身の文言引用なので、
Objective.md の R1 の減点対象外規定に照らせば違反とは言えません。

### 暗黙の過剰適合リスク

ただし、文言の中身には汎化性の弱さがあります。

1. 「test assertion would observe a value」はテストスタイル依存
   - xUnit 的な assert 文を持つ世界観には合うが、
     例外期待、プロパティテスト、snapshot、golden file、exit code、HTTP status、mutation of state などでは表現がずれる

2. 「value」を観測する、という表現も狭い
   - 実際に観測されるのは値だけでなく、例外、副作用、状態遷移、呼び出し回数、出力フォーマットなどもある

3. 言語・フレームワーク横断性が弱い
   - UI テスト、統合テスト、非同期処理、イベント駆動、DB state verification などでは assertion location が分散・間接化しやすい

つまり、提案はベンチマーク固有の ID を含んでいないという意味では sanitized ですが、
「assertion/value」という語の選び方が特定の典型的ユニットテスト様式を暗黙に仮定しています。
これは汎化性の軽微ではない懸念です。

---

## 6. 全体の推論品質はどう向上すると期待できるか

### 期待できる改善

限定的には改善余地があります。

- semantic difference を見つけたのに、その下流の吸収・伝播・無害化を十分追わずに
  「影響なし」と言ってしまうミスは確かに減る可能性があります。
- その意味では、不完全推論チェーン対策としての発想自体は悪くありません。

### しかし、期待できる改善より副作用の方が大きい

1. EQUIVALENT 側の過剰慎重化
   - 差異を見つけた後、「assertion 地点」を特定しきれないと安全側に倒れやすい
   - 結果として EQUIVALENT 正解を NOT_EQUIVALENT または低確信に崩すリスクがあります

2. 探索予算の追加消費
   - 中間差異から十分に判断できる場面でも、assertion という追加ターゲット探索が入りやすい
   - docs/design.md が重視する中心因果連鎖の強化ではあるが、実装先が悪く、主比較ループにコストを増やします

3. 観測点の定義が狭い
   - 良い一般原則は「oracle-visible outcome」や「test-observable effect」ですが、
     提案文はそれを「assertion/value」に狭めています
   - この狭さが不要な再探索と過剰適応を招きます

### 監査上の総合評価

- 改善仮説の核: 妥当
- 具体差分: 非対称で危険
- 汎化表現: やや狭い
- failed-approaches 再演リスク: 高い

したがって、推論品質の純改善は見込みにくいです。
「狙っている失敗モード」には刺さる可能性がある一方、
同時に判定バランスと探索効率を悪化させる公算が大きいです。

---

## 最終判定

承認: NO（理由: 変更前との差分で見ると EQUIVALENT 側にのみ追加の立証責任を課す非対称変更であり、failed-approaches.md の原則 #1, #4, #6, #12 に抵触する可能性が高い。加えて「test assertion would observe a value」という表現は汎化性が弱く、原則 #22, #26 が警戒する物理探索ターゲット化を誘発しうるため。）
