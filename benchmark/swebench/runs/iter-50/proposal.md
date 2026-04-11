# iter-50 改善案

## 親イテレーションの選定理由

親イテレーション **iter-14（80%、16/20）** を選択した理由:

- iter-14 は CONVERGENCE GATE（BL-4）を追加した結果、13821 が修正されたが 14787 が新たに壊れ、スコアは 80% のまま維持された。
- iter-14 の失敗ケース: 15368（EQUIV→NOT_EQ）、15382（EQUIV→UNK）、14787（NOT_EQ→EQU）、12663（NOT_EQ→UNK）
- iter-14 は BL-4（CONVERGENCE GATE）を含んでいるため、そのデメリット（14787 の早期打ち切りによる誤判定）を除去しつつ別のアプローチを加えることで改善の余地がある。
- 直近の 85% 達成イテレーション（iter-21、iter-35、iter-41）の共通パターンを参照し、iter-14 状態からの最小差分でその効果を再現する戦略とした。

---

## 選択した Exploration Framework のカテゴリ

**カテゴリ F: 原論文の未活用アイデアを導入する**

具体的には「論文の他のタスクモード（localize）の手法を compare に応用する」に該当する。

### 選択理由

- localize モードの `PHASE 2: CODE PATH TRACING` では「Build the call sequence: test → method1 → method2 → ...」と明示し、実行経路をテストの発散点（assertionまたは例外）まで追跡することを要求している。
- compare モードの `ANALYSIS OF TEST BEHAVIOR` では現在 `because [trace through code — cite file:line]` という記述があり、「どこまでトレースするか」のエンドポイントが明示されていない。エージェントは変更された関数の定義を読んだ段階で「コードをトレースした」とみなし、テストの assertion や例外発生地点まで到達しないまま Claim を確定することができる。
- これは localize モードが持つ「発散点（assertion/exception）まで因果連鎖を追う」という構造を compare モードに適用することで汎用的に改善できる問題である。

---

## 改善仮説

**仮説（1つ）**: compare モードの Claim 内 `because` 節に明示的なトレースエンドポイント「テストの assertion または exception site まで」を追加し、現在の早期停止を促す CONVERGENCE GATE（BL-4）を除去することで、エージェントが変更関数のコードを読んだ時点で Claim を確定する「浅いトレース」を防ぎ、正確なテスト結果の導出が可能になる。

根拠:
- iter-14 の 14787 失敗の根本原因は「CONVERGENCE GATE が LOW confidence EQUIVALENT で探索を強制停止させた」こと（BL-4 の確認済みデメリット）。
- iter-14 の 12663 失敗は「エージェントが changed function までは読んでいるが assertion site までのパスが不明確」なことによるターン枯渇。
- localize モードは発散点まで追跡することで症状と根本原因を区別する。同じ「assertion まで追う」概念を compare の `because` 節に適用することで、コード差分→NOT_EQ の短絡、および assertion に到達せずに UNKNOWN になる問題を汎用的に抑制できる。
- iter-35（85%、17/20）がほぼ同一の変更（`because` 節へのエンドポイント明記）で成功した実績がある。iter-35 の親は異なるベースライン（75%、CONVERGENCE GATE なし）だったが、変更の核心は `because` 節のエンドポイント明記であり、iter-14 からも同様の効果が期待できる。

---

## SKILL.md のどこをどう変えるか（具体的な変更内容）

### 変更 1: CONVERGENCE GATE を削除（5行削除、制限内カウントなし）

**対象**: Step 3 の HYPOTHESIS UPDATE ブロック末尾（現行 line 75–78）

```diff
-CONVERGENCE GATE (required after each observation set):
-  Working conclusion: [EQUIVALENT / NOT_EQUIVALENT / UNRESOLVED]
-  If EQUIVALENT or NOT_EQUIVALENT at any confidence: stop exploration and proceed to Step 5 now.
-  If UNRESOLVED: state exactly what missing evidence justifies reading another file.
```

**理由**: CONVERGENCE GATE（BL-4）は iter-14 で 14787 を誤判定させた原因であり、失敗アプローチとして記録済み。除去により過剰な早期打ち切りを防ぐ。

---

### 変更 2: Claim の `because` 節にトレースエンドポイントを明記（既存行の精緻化、追加行 0）

**対象**: Compare テンプレートの `ANALYSIS OF TEST BEHAVIOR` 内 Claim 行（現行 line 177, 179）

```diff
-                because [trace through code — cite file:line]
+                because [trace through changed code to the assertion or exception — cite file:line]
```

（同じ変更を Claim C[N].1 と C[N].2 の両行に適用）

**理由**: 「trace through code」はエージェントが changed function を読んだ時点でトレース完了とみなすことを許容する。「to the assertion or exception」を加えることで、テストが実際に結果を観測する地点まで因果連鎖を追う義務を明示する。localize モードの `CODE PATH TRACING` が assert まで追跡させる構造を compare に移植する。

---

### 変更 3: COUNTEREXAMPLE の `because` 節も同様に精緻化（既存行の精緻化、追加行 0）

**対象**: Compare テンプレートの `COUNTEREXAMPLE` ブロック（現行 line 196, 197）

```diff
-  Test [name] will [PASS/FAIL] with Change A because [reason]
-  Test [name] will [FAIL/PASS] with Change B because [reason]
+  Test [name] will [PASS/FAIL] with Change A because [trace from changed code to the assertion or exception — cite file:line]
+  Test [name] will [FAIL/PASS] with Change B because [trace from changed code to the assertion or exception — cite file:line]
```

**理由**: COUNTEREXAMPLE を記述する際も「コード差分があるから DIFFERENT」ではなく「assertion または exception で観測される結果が異なるから DIFFERENT」であることを証拠付きで示す義務を課す。

---

### 変更 4: Compare checklist に 1 行追加（追加行 +1）

**対象**: `### Compare checklist` の既存 bullet の後

```diff
 - Trace each test through both changes separately before comparing
+- Do not conclude NOT EQUIVALENT from a code difference alone — verify the difference reaches the test's assertion or exception by tracing the full call path
```

**理由**: 変更 2・3 の `because` 節への明記を補強するチェックリスト項目。エージェントが「コード差分 → NOT_EQUIVALENT」という短絡をとることを防ぎ、テストの観測地点までの完全なトレースを義務付ける。アドバイザリな禁止ではなく「差分を assertion まで追え」という正方向の指示として機能させる。

---

## 変更規模の宣言

| 種別 | 行数 |
|------|------|
| 追加行数 | **1行**（checklist bullet 1行） |
| 削除行数 | 5行（CONVERGENCE GATE ブロック） |
| 既存行精緻化 | 4行（`because` 節 4カ所の wording 変更） |

追加行数 1 は hard limit（5行）の範囲内。

---

## EQUIV と NOT_EQ の両方の正答率への影響予測

### EQUIV（現状 8/10 = 80%）

| ケース | 現状 | 予測 | 理由 |
|--------|------|------|------|
| 15368 | NOT_EQ（誤） | NOT_EQ（誤）継続の可能性 | 削除テスト誤判定パターンは assertion エンドポイント変更だけでは解消が難しい。ただし checklist「コード差分のみで NOT_EQ にするな」が抑制に作用する可能性あり。 |
| 15382 | UNKNOWN（誤） | EQUIV（正）を期待 | CONVERGENCE GATE 除去により探索継続が可能。`because` 節のエンドポイント明記で assertion まで追跡し、両変更で同一結果を確認できる。 |
| 他 6件 | 正解 | 正解維持 | 既に assertion まで追跡して正解しているケースには実効的な変化なし。 |

予測 EQUIV 正答率: **80〜90%（8〜9/10）**

### NOT_EQ（現状 8/10 = 80%）

| ケース | 現状 | 予測 | 理由 |
|--------|------|------|------|
| 14787 | EQUIV（誤） | NOT_EQ（正）を期待 | CONVERGENCE GATE 除去により LOW confidence EQUIVALENT での早期停止が解消。`because` 節で assertion まで追跡すれば真の差分が観測される。 |
| 12663 | UNKNOWN（誤） | NOT_EQ（正）を期待 | `because` 節のエンドポイント明記により「何を確認すれば結論できるか」が明確になり、ターン枯渇前に assertion での差分を発見できる。 |
| 他 8件 | 正解 | 正解維持 | 既に差分発見から NOT_EQ を正しく判定しているケース。assertion エンドポイント明記は判定を強化しても反転させない。 |

予測 NOT_EQ 正答率: **80〜100%（8〜10/10）**

### 13821 の回帰リスク（EQUIV）

iter-12 では CONVERGENCE GATE なしで 13821 が EQUIV→NOT_EQ に失敗していた。CONVERGENCE GATE を除去すると 13821 が再び失敗するリスクがある。ただし:
- iter-35（CONVERGENCE GATE なし、85%）では 13821 が **失敗**（EQUIV→NOT_EQ）
- iter-41（CONVERGENCE GATE なし、85%）では 13821 が **失敗**（EQUIV→NOT_EQ）
- つまり 85% 達成は「13821 失敗、他を修正」というトレードオフで成立している

**全体予測**: 16/20（80%）→ **17/20（85%）**（13821 が回帰 -1、14787 修正 +1、12663 修正 +1 の場合）

---

## failed-approaches.md のブラックリストおよび共通原則との照合

### ブラックリスト照合

| BL番号 | 内容 | 本提案との関係 |
|--------|------|---------------|
| BL-1 | テスト削除を ABSENT 定義 | 無関係。定義追加なし。 |
| BL-2 | NOT_EQ 証拠閾値強化 | 無関係。閾値設定なし。 |
| BL-3 | UNKNOWN 禁止 | 無関係。UNKNOWN を禁止する文言を追加しない。 |
| BL-4 | CONVERGENCE GATE | **本提案は BL-4 を除去する方向**。BL-4 は「探索量を削減する」ことが問題。本提案はその削減を除去し、探索量を回復させる。 |
| BL-5〜24 | 各種 | 本提案の変更（`because` 節エンドポイント明記）は BL-5〜24 のいずれにも記載されていない。 |

### 共通原則照合

| 原則 | 内容 | 照合結果 |
|------|------|----------|
| #1 判定の非対称操作 | EQUIV/NOT_EQ いずれかに有利な変更は失敗 | `because` 節の変更は EQUIV・NOT_EQ 両方の Claim に同様に適用。チェックリスト項目は NOT_EQ 方向に追加制約を課すが、本質は「assertion まで追えという品質要求」であり、判定閾値の変更ではない。 |
| #2 出力側の制約は効果なし | 「こう答えろ」は無効 | `because` 節はテンプレートの入力側（トレース方法の指示）を改善するもの。出力を直接指定しない。 |
| #3 探索量の削減は有害 | 探索を減らす変更は悪化 | CONVERGENCE GATE の削除により探索量が**増加**する。本提案は探索削減に逆行しない。 |
| #4 同じ方向の変更は同じ結果 | 表現を変えても効果は同じ | `because` 節エンドポイント明記は既存のどの BL エントリとも異なるメカニズム（assertion site まで追跡する義務）。BL-20（関数ごとの verified effect 義務）とは対象が異なる。 |
| #5 入力テンプレート過剰規定 | 見るべき情報の限定は視野を狭める | エンドポイント明記は「何を記録するか」を限定しない。「どこまで追うか」の終端を明示するだけで、途中で見るものを制限しない。 |
| #14 条件付き特例探索は主ループ強化にならない | サイドクエストの追加は無効 | 本変更は主比較ループ（ANALYSIS OF TEST BEHAVIOR の Claim）そのものに適用される。特例条件ではない。 |
| #15 固定長局所追跡ルールによる近似 | hop 数指定は無効 | 「assertion or exception site」はセマンティックな終端点（テストの観測境界）であり、固定hop数ではない。 |
| #16 ネガティブプロンプト | 禁止指示は過剰適応 | チェックリスト項目は「コード差分のみで NOT_EQ にするな」という禁止を含むが、その目的は「assertion site まで追え」という正方向の要求。iter-35 で同一の表現（「Do not conclude NOT EQUIVALENT from a code difference alone」）が 85% を達成した実績あり。 |
| #17 中間ノード局所分析義務化 | nearest consumer へのフォーカスはエンドツーエンド追跡を阻害 | 本提案は「assertion または exception site」（最終観測点）まで追跡する義務であり、中間ノード（nearest consumer）への局所フォーカスではない。 |

---

## まとめ

| 項目 | 内容 |
|------|------|
| 親イテレーション | iter-14（80%） |
| カテゴリ | F（localize モードの assertion-site 追跡を compare に適用）+ E（既存 wording の精緻化） |
| 仮説 | `because` 節に assertion/exception エンドポイントを明記し、BL-4（CONVERGENCE GATE）を除去することでトレースが浅いまま結論を出す問題を汎用的に防止できる |
| 追加行数 | 1行（hard limit 5行以内） |
| 削除行数 | 5行（CONVERGENCE GATE） |
| 修正行数 | 4行（既存 `because` 節の wording） |
| 期待スコア | 85%（17/20） |
