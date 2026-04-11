# Iteration 24 — 改善提案（改訂版）

## 1. 選択した Exploration Framework カテゴリ

**カテゴリ B: 情報の取得方法を改善する — テストソースを先読みして分析をグラウンドする**

### 選択理由

監査役フィードバックを踏まえ、前回の提案（カテゴリ A: 分析前の BEHAVIORAL SCOPE 追加）は以下の理由で取り下げた。

1. 実効差分が「逆方向推論の新規導入」ではなく「分析前の中間表現追加」であり、BL-7 / BL-10 / BL-11 と同系統
2. 既存の `NO COUNTEREXAMPLE EXISTS` ですでに逆方向推論が担保されているため増分価値が小さい
3. `Diverges when:` という中間ラベルが原則 #7 のアンカリングリスクを持つ

今回選択するカテゴリ B は、**何を記録するかではなく、何から読むかの順序を変える**アプローチである。  
具体的には、各 relevant test の分析において「テストソース（entrypoint・引数・セットアップ）を確認してから変更コードをトレースする」という読取り順序を明示的に規定する。

- **新しいラベルや中間表現を追加しない** → BL-7 / 原則 #7 と重ならない
- **受動的な記録フィールドの追加ではなく、能動的な読取り順序の制約** → BL-8 と異なる
- **YES/NO ゲートではない** → BL-10 と異なる
- **テスト側 assertion 形式の過剰規定でない** → BL-5 と異なる

---

## 2. 改善仮説（1つのみ）

**仮説**: EQUIV→NOT_EQUIVALENT の誤判定（15368・13821・15382 等）は、エージェントが変更コードを先に読んで意味的差異を検出し、その差異の印象を持ったまま各テストの分析に入ることで「コード差異 → テスト結果差異」という推論ジャンプが生じる。Compare テンプレートの `ANALYSIS OF TEST BEHAVIOR` において、各 relevant test の分析ブロック先頭に **「テストソースを先に読んで entrypoint・引数・セットアップを確定してから変更コードをトレースせよ」** という順序制約を追加することで、エージェントはテスト側の具体的な入力から出発して変更コードに入るようになり、その入力が変更後の動作を変えるかどうかをトレースする自然な流れが生まれる。真の EQUIV ケースでは、テスト入力が変更の意味的差異を踏まないことが実際のトレースで確認され、NOT_EQ への推論ジャンプが遮断される。

---

## 3. SKILL.md の変更内容

### 変更箇所

Compare certificate template の `ANALYSIS OF TEST BEHAVIOR` セクション内、`For each relevant test:` ブロックのフォーマットを変更する。

### 変更前（該当部分の抜粋）

```
ANALYSIS OF TEST BEHAVIOR:

For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

### 変更後

```
ANALYSIS OF TEST BEHAVIOR:

For each relevant test, read the test source first to establish the
entry point, arguments, and setup before tracing the changed code.

For each relevant test:
  Test: [name]
  Entry: [test entry point, arguments, and setup — cite file:line from test source]
  Claim C[N].1: With Change A, starting from Entry, this test will [PASS/FAIL]
                because [trace from Entry through changed code — cite file:line]
  Claim C[N].2: With Change B, starting from Entry, this test will [PASS/FAIL]
                because [trace from Entry through changed code — cite file:line]
  Comparison: SAME / DIFFERENT outcome
```

### 変更規模

**4 行追加、2 行変更**（合計実効差分 6 行、≤ 20 行制約を満たす）。他セクション・他モードへの変更なし。

---

## 4. EQUIV・NOT_EQ 両方の正答率への予測

### EQUIV 側

- **期待効果**: +1〜+3 改善
- **根拠**: 失敗ケース 15368・13821・15382 のパターンは「コード差異を発見 → テスト結果差異を仮定」というジャンプ。今回の変更により、エージェントはまずテストソースを開いて `Entry:` を確定する。真の EQUIV ケースでは、確定した具体的な入力（引数・セットアップ）が変更コードの意味的差異を踏まないことを、コードパスのトレースで直接確認することになる。テスト入力から出発するため、差異が生じない実行経路が自然に選ばれやすくなる。
- **メカニズムの独自性**: これは「差異が生じる条件を先に宣言させる」（前回案・原則 #7 抵触）ではなく、「差異が生じるかどうかをテスト入力から具体的にトレースさせる」ことで、判定前の中間ラベルを生成しない。

### NOT_EQ 側

- **期待効果**: ほぼ維持
- **根拠**: 真の NOT_EQ ケースでは、テスト入力から出発してトレースしても差異は顕在化する。`Entry:` の記録は 1 行追加であり、ターン消費増加は各テストにつき 1〜2 ターン程度。31 ターン上限への影響は軽微（BL-11 ロールバック済みのため、現状の NOT_EQ 正答率は既に回復していると見込む）。
- **回帰リスクが低い理由**: `Entry:` は判定方向と無関係な事実記録（どのテストも entrypoint・引数・セットアップを持つ）であり、NOT_EQ 側の証拠収集を阻害しない。また、「テストが引数Xで呼ばれる」という事実の確認が差異の発見を妨げることはない。

---

## 5. failed-approaches.md ブラックリストおよび共通原則との照合

| チェック項目 | 評価 | 根拠 |
|---|---|---|
| BL-1（ABSENT 定義） | ✓ 非該当 | テストを比較対象から除外しない |
| BL-2（NOT_EQ 証拠閾値の厳格化） | ✓ 非該当 | NOT_EQ を出しにくくする閾値変更ではない。テスト入力から始めるだけで証拠要件は変わらない |
| BL-3（UNKNOWN 禁止） | ✓ 非該当 | 回答形式への制約なし |
| BL-4（早期打ち切り） | ✓ 非該当 | 探索量は維持か増加（テストソースを先に読む分が追加）。削減しない |
| BL-5（P3/P4 形式の過剰規定） | ✓ 非該当 | PREMISES の形式変更ではない。BL-5 は各テストの assertion 条件を厳密書式で PREMISES に記録させたが、今回は ANALYSIS 内の読取り順序変更。記録先・記録形式・記録内容の規定が全て異なる |
| BL-6（対称化） | ✓ 非該当 | 既存制約の拡張でも対称化でもなく、読取り順序という新次元の変更 |
| BL-7（CHANGE CHARACTERIZATION） | ✓ 非該当 | `Entry:` は変更の性質ではなくテスト側の事実（何を呼ぶか・何を渡すか）の記録。判定方向への暗黙的カテゴリラベルを生成しない |
| BL-8（Relevant to 列） | 要注意 / ✓ 非該当 | BL-8 は「この関数がどのテストに関係するか」という関係性の受動記録フィールドだった。`Entry:` はテスト側のコードを実際に読まなければ確定できない事実（file:line 付き）であり、テストファイルへの能動的な読取りを強制する。BL-8 の `Relevant to` 欄は関数を読んだ後に推論で埋められたが、`Entry:` は「テストを読む前に埋めることができない」という能動的探索強制の性質を持つ |
| BL-9（メタ認知的自己チェック） | ✓ 非該当 | 自己評価ではなく、コードの外部的な事実（テストの entrypoint・引数）を確認するステップ |
| BL-10（Reachability ゲート） | ✓ 非該当 | YES/NO の条件分岐ゲートではない。スキップ条件も設けない。BL-10 は「到達するか？」というほぼ常に YES となる問いを先置したが、今回は「何の引数で呼ばれるか」という具体的事実の確定に過ぎず、判別力の問題が生じない |
| BL-11（outcome mechanism 注釈） | ✓ 非該当 | テスト側の失敗メカニズムのラベルを列挙するものではない。失敗の種類（assertion / exception / setup 等）を分類せず、「どこから入るか・何を渡すか」という中立的な事実のみ記録する |
| 原則 #1（判定の非対称操作） | ✓ 非該当 | `Entry:` は EQUIV/NOT_EQ のどちらにも等しく適用される。テスト入力から出発するトレースは両方向の判定に必要 |
| 原則 #2（出力側制約は効果なし） | ✓ 非該当 | 処理側（読取り順序）の変更 |
| 原則 #3（探索量削減は有害） | ✓ 非該当 | テストソースを先読みする分は探索増加 |
| 原則 #5（入力テンプレートの過剰規定） | ✓ 許容範囲 | `Entry: [entrypoint, arguments, setup — cite file:line]` は記録内容の型を大まかに指示するが、どの entrypoint・どの引数かはテストごとに自由。BL-5 のように「asserts [exact condition] at [file:line]」という assert 行への視野固定はなく、テストの入り口全体（引数・セットアップ含む）を対象とするため視野は狭まらない |
| 原則 #6（対称化は差分で評価せよ） | ✓ 非該当 | 既存制約との差分は「per-test 分析の冒頭でテストソースを読む順序拘束」のみ。この差分は EQUIV/NOT_EQ 両方向に等しく作用する |
| 原則 #7（中間ラベル生成のアンカリング） | ✓ 非該当 | `Entry:` はコードの事実を記録する欄であり、判定方向に相関するカテゴリ（production/test/both、diverges/identical 等）を生成させない。テストの entrypoint は常に一意に存在する事実であり、EQUIV/NOT_EQ のどちらにも傾かない |
| 原則 #8（受動的記録は検証を誘発しない） | ✓ 非該当 | `Entry:` はテストソースファイルを実際に読まなければ確定できない（file:line 引用が必須）。これは受動的な「欄を埋める」行為ではなく、テストファイルへの能動的なアクセスを強制する |
| 原則 #9（メタ認知的自己チェック） | ✓ 非該当 | 自己評価の精度問題は関係しない |
| 原則 #10（必要条件ゲートは失敗モードを弁別しない） | ✓ 非該当 | ゲートではないため適用外 |

---

## 6. 変更規模

**4 行追加・2 行変更**（実効差分 6 行、≤ 20 行制約を満たす）。Compare モードの certificate template のみ変更。他モード（localize, explain, audit-improve）・ガードレール・Minimal Response Contract への変更なし。
