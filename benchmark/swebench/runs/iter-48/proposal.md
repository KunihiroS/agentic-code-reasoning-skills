# Iteration 48 — Proposal

## Exploration Framework カテゴリ: A (強制指定)

### 選択したメカニズム: 逆方向推論 (結論から逆算して必要証拠を特定)

カテゴリ A の 3 つのメカニズムのうち「逆方向推論」を選択する。

理由:
- 「ステップの実行順序を入れ替える」は STRUCTURAL TRIAGE が既に実装済み (詳細トレース前に構造比較)
- 「並列/直列の変換」は Step 3/4 の連動設計に関わり、変更規模が 5 行を超えやすい
- 「逆方向推論」は compare モードの STRUCTURAL TRIAGE 内の既存行への文言追加として
  5 行以内で実現でき、かつ最も未活用のメカニズムである

逆方向推論を STRUCTURAL TRIAGE の S2 に組み込む根拠:
S2 は現在「Change B が Change A と同じモジュールをカバーしているか」を順方向に確認するが、
「もし NOT EQUIVALENT が真なら、どのモジュールが欠落しているはずか」を先に問うことで、
カバレッジ漏れの検出漏れを防ぐ。これは前提から結論への順方向確認より、
結論から必要証拠を逆算する逆方向推論であり、カテゴリ A に正確に合致する。


## 改善仮説

compare モードにおいて、構造的等価性の判定に失敗する主因の一つは、
S2 (Completeness チェック) が「Change B は必要なモジュールをカバーしているか」を
順方向に問うだけで、「NOT EQUIVALENT であれば何が欠けているはずか」という
逆方向の問いかけを持たないことである。
逆方向推論を S2 に追加することで、構造的穴の見落としが減り、
EQUIVALENT/NOT EQUIVALENT 両方向での誤判定を抑制できる。


## SKILL.md のどこをどう変えるか

### 変更対象

SKILL.md の compare モード、STRUCTURAL TRIAGE セクション内の S2 行 (現在の line 187-189):

```
  S2: Completeness — does each change cover all the modules that the
      failing tests exercise? If Change B omits a file that Change A
      modifies and a test imports that file, the changes are NOT EQUIVALENT
      regardless of the detailed semantics.
```

### 変更後

```
  S2: Completeness — does each change cover all the modules that the
      failing tests exercise? If Change B omits a file that Change A
      modifies and a test imports that file, the changes are NOT EQUIVALENT
      regardless of the detailed semantics. Before checking forward,
      ask: if NOT EQUIVALENT were true, which file or module would be absent?
```

### 変更の説明

既存の S2 行の末尾に 1 文を追加する。

追加文: "Before checking forward, ask: if NOT EQUIVALENT were true, which file or module would be absent?"

この 1 文が逆方向推論の指示として機能する。順方向の「Change B はカバーしているか」を
実行する前に、「NOT EQUIVALENT が真なら何が欠けているはずか」を問わせることで、
確認バイアスを抑制し、構造的穴を見落とす失敗パターンを減らす。


## 期待効果

### 減少が期待される失敗パターン

1. EQUIVALENT 誤判定 (False Positive):
   Change B が実際には必要なモジュールを欠いているのに、順方向の確認だけでは
   「あるべきものが見当たらない」という視点が働かず、EQUIVALENT と判定してしまう。
   逆方向推論によって「NOT EQUIVALENT なら X が欠けているはず」という検索対象が
   明示されるため、欠落の発見精度が上がる。

2. 構造的等価性の過信:
   S2 を形式的にチェックしても「チェックした結果、問題なし」という通過バイアスが起きやすい。
   逆方向の問いを先に立てることで、S2 を確認する前にすでに「欠落候補」が具体化されており、
   見落としが減る。

### overall フォーカスへの寄与

逆方向推論は EQUIVALENT / NOT EQUIVALENT の両方向に対して機能する:
- EQUIVALENT の過信防止 → NOT EQUIVALENT の検出精度向上
- NOT EQUIVALENT の過剰判定防止 → EQUIVALENT の判定精度向上 (欠落候補が具体化されることで、
  欠落と思われたものが実際には存在すると分かる場合にも有効)


## failed-approaches.md の汎用原則との照合

1. 「探索を特定シグナルの捜索へ寄せすぎると確認バイアスを強める」:
   本提案は「何を探すか」を具体的に固定しているのではなく、「逆方向に問う」という
   思考方向の変更を促す。固定された証拠種類を増やすのではなく、
   探索の方向を反転させる操作であり、この原則に抵触しない。

2. 「探索の自由度を削りすぎない」:
   S2 内に 1 文の問いかけを追加するだけであり、探索経路を半固定化するものではない。
   「どのファイルを読むか」「どの境界を先に確定するか」には関与しない。
   この原則に抵触しない。

3. 「局所的な仮説更新を即座の前提修正義務に直結させすぎない」:
   本提案は前提の再点検を義務化するものではなく、S2 内での問いかけの方向を変えるだけ。
   この原則に抵触しない。

4. 「既存の汎用ガードレールを特定の追跡方向で具体化しすぎない」:
   S2 は既存のガードレールではなく、compare モード専用の STRUCTURAL TRIAGE の一部。
   かつ追加する問いは「特定のトレース方向」ではなく、
   「逆方向に問う思考フレーム」の付与であり、この原則に抵触しない。

5. 「結論直前の自己監査に新しい必須のメタ判断を増やしすぎない」:
   本変更は Step 5.5 (pre-conclusion self-check) ではなく、
   STRUCTURAL TRIAGE (詳細分析前) の S2 への追加であり、この原則に抵触しない。

照合結果: 全 5 原則に抵触なし。


## 変更規模の宣言

- 変更行数: 1 行追加 (既存 S2 の説明文への文言追加)
- hard limit (5 行) に対して: 1 行 / 5 行 (余裕あり)
- 変更種別: 既存行への文言追加のみ (新規ステップ・新規フィールド・新規セクション なし)
