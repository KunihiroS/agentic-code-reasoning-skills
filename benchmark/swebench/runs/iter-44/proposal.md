# Iteration 44 — 改善提案（再提出）

## iter-43 の分析

- **スコア**: 65%（13/20）
- **失敗ケース**:
  - EQUIV 偽陰性（NOT_EQ と誤判定）: `15368`（17 turns）, `11179`（11 turns）, `13821`（15 turns）, `15382`（20 turns）
  - NOT_EQ 偽陽性（EQUIV と誤判定）: `14787`（26 turns）
  - NOT_EQ UNKNOWN（31 turns ターン枯渇）: `11433`, `14122`

- **iter-43 変更の副作用分析**:
  - iter-43 が修正したケース: `11603`, `12663`（NOT_EQ UNKNOWN → 正答）
  - iter-43 が新規破損させたケース: `13821`, `11179`（EQUIV → NOT_EQ 誤判定に転落）
  - 根本原因: iter-43 の「nearest downstream consumer」指示がエージェントを最初の消費者で止まらせた。`13821`/`11179` では、downstream consumer 自体がコードレベルで A/B 異なる挙動を示すが、その差異はテストが直接アサートする観測対象（return value / assert 引数）にまで伝播しない。エージェントはコードレベルの中間差異を見つけた時点で DIFFERENT と判断し、テストのアサーション境界でその差異が吸収されるかを確認しなかった。

---

## 監査フィードバックの整理

初回 iter-44 提案（「nearest を chain に置き換える」）は以下の理由で却下された：

1. **カテゴリ誤分類**: 表現改善（E）と説明したが、実効差分は downstream trace の深度変更（B）であり、iter-41/43 と同系統。
2. **共通原則 #4 抵触**: iter-41/43 と同じ「downstream を深く辿る」方向の再調整に留まっている。
3. **NOT_EQ 側への追加コスト**: EQUIV 改善はあり得るが、NOT_EQ 側に追加確認負担が発生しうる。

監査からの代替提案：**カテゴリ C（比較の枠組みを変える）**：
> 各 relevant test について、まず「このテストで A/B を比較する唯一の観測対象は何か」を 1 つ定め、その観測対象に対してのみ A/B の因果連鎖を比較する。実装するなら、新たな記録欄追加ではなく、既存 Claim 記述の前提として比較対象を 1 つに揃える程度の最小変更が望ましい。

---

## 選択した Exploration Framework カテゴリ

**カテゴリ C: 比較の枠組みを変える**

具体的には：**「A/B 比較の単位を『コードレベルの中間差異の有無』から『テストのアサーションが検査する観測対象での差異の有無』へ移行する」**

### 選択理由

iter-41/43 はいずれも「どこまで downstream を辿るか（B 方向: 情報取得方法の変更）」に焦点を当てた。監査の指摘通り、これを繰り返しても改善しない。

問題の本質を別の角度から再定義する：

**現在のエージェントの誤認**: コード差異（関数の返り値・例外が A/B で異なる）= NOT_EQ の証拠  
**正しい比較単位**: テストのアサーションが検査する観測対象（assert で比較している値・捕捉している例外・検証している状態）での A/B 差異 = NOT_EQ の証拠

コード中間差異がどれほど明確でも、それがテストのアサーション境界に到達しなければ EQUIV である。逆に、コード差異がテストの観測対象を変えるなら NOT_EQ である。

現在の Compare checklist "trace at least one relevant test through the differing path" は方向性として正しいが、**何に向かって trace するか（比較単位）** が明示されていない。その結果、エージェントはコード差異を trace の「到達目標」と誤認し、観測対象まで追わずに結論を出す。

→ **比較単位を「テストのアサーションが検査する観測対象」に明示することで、この誤認を構造的に除去する。**

### BL-16 との区別

BL-16 はこれと類似した発想（「コード差分ではなく観測点で比較せよ」）を試みたが、実装が **Compare テンプレートの `Comparison:` 直前への注釈追加（出力側フォーマット変更）** だった。その失敗原因は「出力直前のアンカリング」と「新たな観測フレームへの圧縮」だった。

本提案は **Compare checklist への探索方針変更**として実装する（出力テンプレートを変更しない）。checklist はエージェントが **探索・trace を行う前の行動指針** であり、出力フォーマットの変更ではない。これが BL-16 との本質的な違いである：

| 観点 | BL-16（失敗） | 本提案 |
|---|---|---|
| **変更箇所** | `Comparison:` 直前のテンプレート注釈（出力側） | Compare checklist（探索指針） |
| **作用タイミング** | Claims を書き終えた後の比較記述時 | Claims を書く前の trace 時 |
| **失敗原因** | 出力直前アンカリング・比較フレーム圧縮 | 該当しない（探索行動の変更） |

また BL-7（変更性質の中間ラベル生成）とも異なる。BL-7 は「変更の性質を記述させる」ものだが、本提案は「何を trace のゴールにするか」を指定する探索行動指針であり、ラベル生成を要求しない。

### iter-41/43 との区別

| 観点 | iter-41/43（B方向） | 本提案（C方向） |
|---|---|---|
| **指示の焦点** | 「次にどこを読むか」（nearest consumer / chain） | 「何を trace のゴールにするか」（観測対象） |
| **エージェントへの問い** | 「最初の consumer を読んだか？」 | 「アサーション観測対象への因果を確認したか？」 |
| **比較単位** | コードレベルの関数・挙動差異 | テストのアサーション検査対象 |

---

## 改善仮説

**仮説**: Compare checklist に「各 relevant test について、A と B の両方を、テストのアサーションが実際に検査する観測対象（比較している値・捕捉している例外・検証している状態）まで trace してから比較せよ。中間コードパスの差異だけで判定してはならない」という 1 文を追加することで：

- エージェントがコードレベルの中間差異で判定を短絡させなくなる
- EQUIV ケース（13821, 11179）: 中間差異があっても観測対象で吸収されれば EQUIV と正しく判断できる
- NOT_EQ ケース: 観測対象に到達する差異を確認してから結論を出すため、確認の方向が明確になる
- 探索の「ゴール」が明確になることで UNKNOWN（ターン枯渇）リスクが下がる

---

## SKILL.md のどこをどう変えるか

**変更箇所**: `## Compare` セクション `### Compare checklist` の末尾（6 番目の項目「Provide a counterexample...」の直前）に 1 行追加する。

**追加内容**:

```markdown
- For each relevant test, trace both changes through to the outcome the test's assertion checks (the value compared, the exception caught, or the state verified); compare A and B at that observable — not at intermediate code differences.
```

**変更内容の詳細説明**:

| 要素 | 内容 | 意図 |
|---|---|---|
| `For each relevant test` | 比較対象テストごとに適用 | iter-43 の "When tracing" より適用スコープを前に出す |
| `trace both changes through to` | A と B の両方を trace の対象として等しく扱う | 非対称な立証義務を避ける |
| `the outcome the test's assertion checks` | テストのアサーションが実際に検査するもの | 「コード差異」ではなく「観測対象」を比較単位として定義 |
| `the value compared, the exception caught, or the state verified` | 観測対象の具体例（過剰列挙ではなく自然な例示） | BL-16 のような重枚挙型カテゴリ化を避けるため短く保つ |
| `compare A and B at that observable` | 比較単位を明示 | BL-16 との違い: 出力注釈ではなく探索指針 |
| `not at intermediate code differences` | 中間差異で止まることを禁止 | iter-43 の失敗モード（中間差異→即 NOT_EQ）を直接防止 |

**変更規模**:
- 変更行数: 0 行
- 追加行数: 1 行
- 削除行数: 0 行
- 合計差分: +1 行（20 行以内の目安を大幅に下回る）

---

## EQUIV と NOT_EQ の両方の正答率への影響予測

### EQUIV 正答率（現在 60% = 6/10、偽陰性 4 件）

**予測: 改善（特に 13821, 11179 の回帰修正）**

iter-43 で新規破損した 13821, 11179 の根本原因は「中間コード差異で止まり観測対象まで追わなかった」こと。本変更の指示は「アサーションが検査する観測対象まで trace せよ」であるため：
- エージェントは中間差異を見つけても「これはアサーション観測対象か？」を問うようになる
- 観測対象まで追った結果、差異が吸収される（fallback・デフォルト値・例外キャッチ等）ことを確認できれば EQUIV と正しく判断できる

15368, 15382 についても、「観測対象まで trace する」という明確な行動指針が探索の収束を助ける可能性がある。

### NOT_EQ 正答率（現在 70% = 7/10）

**予測: 中立〜改善**

- iter-43 の収穫（11603, 12663）: 本変更は「do not expand to surrounding callers/wrappers」的な制約を陽に書いていないが、「観測対象に向けて trace する」という指針があれば周辺への拡散は自然に抑制される。
- `11433`, `14122`（UNKNOWN, ターン枯渇）: 「アサーション観測対象」という到達目標が明確なため、無目的な周辺探索が減りターン消費が改善する可能性がある。
- `14787`（NOT_EQ 偽陽性）: 観測対象での A/B 同一性を確認する方向に働くため、改善の可能性はある。

**対称性の確認**: 本変更は「A も B も観測対象まで trace する」を両方向に等しく課す。EQUIV では「観測対象が同じことを確認」、NOT_EQ では「観測対象が異なることを確認」—どちらも trace のゴールを明示するという同一の指針に従う。立証責任が一方向に偏ることはない。

**回帰リスク**: iter-43 の改善（11603, 12663）については、観測対象へのトレースを要求する指針が nearest consumer 的な探索の代替として機能するため、回帰リスクは低いと判断する。

---

## failed-approaches.md ブラックリストおよび共通原則との照合

| BL / 原則 | 本提案との関係 | 判定 |
|---|---|---|
| BL-1（ABSENT 定義追加） | 無関係 | ✅ |
| BL-2（NOT_EQ 証拠閾値の引き上げ） | 「観測対象まで trace」は EQUIV/NOT_EQ 双方に等しく適用される。NOT_EQ の証拠閾値を非対称に上げるものではない | ✅ |
| BL-3（UNKNOWN 禁止） | 無関係 | ✅ |
| BL-4（早期打ち切り） | 「観測対象まで trace する」は探索の早期打ち切りを防ぐ方向 | ✅ |
| BL-5（前提収集テンプレートの形式規定） | PREMISES セクションに触れない | ✅ |
| BL-6（対称化の実効差分） | 変更前後の差分: EQUIV/NOT_EQ 双方向に等しく「観測対象まで trace する」義務が追加される。asymmetric ではない | ✅ |
| BL-7（分析前の中間ラベル生成） | ラベルを生成させない。「何を trace のゴールにするか」という行動指針であり、変更性質の記述ではない | ✅ |
| BL-8（受動的記録フィールド追加） | 記録フィールドを追加しない。能動的な trace 行動の指針 | ✅ |
| BL-9（メタ認知的自己チェック） | 自己評価を要求しない | ✅ |
| BL-10（Reachability ゲート） | YES/NO 分岐ゲートではない | ✅ |
| BL-11（outcome mechanism 注釈） | ANALYSIS のフォーマットを変更しない。checklist のみ | ✅ |
| BL-12（探索開始順序の固定） | 探索の開始順序を固定しない | ✅ |
| BL-13（Key value データフロー欄） | 新規フィールドを追加しない | ✅ |
| BL-14（チェックリストへの逆方向推論） | DIFFERENT 方向にのみ非対称な追加検証を課さない。A と B の両方を対称に trace する | ✅ |
| BL-15（COUNTEREXAMPLE 文言調整） | COUNTEREXAMPLE テンプレートを変更しない | ✅ |
| BL-16（Comparison: 直前への注釈） | **重要**: Comparison: テンプレートに触れない。checklist（探索指針）への追加であり、出力フォーマット変更ではない。BL-16 との本質的な違いは上述の通り | ✅ |
| BL-17（caller / wrapper / helper への検索拡張） | relevant test 集合を変更しない | ✅ |
| BL-18（削除テストへの条件付き search 義務） | 条件付き特例処理を追加しない | ✅ |
| BL-19（EDGE CASES の Claim 内統合） | EDGE CASES セクションを変更しない | ✅ |
| BL-20（because 節への per-function 義務） | Claim 行のフォーマットを変更しない | ✅ |
| 共通原則 #1（判定非対称操作） | 「観測対象まで trace する」は EQUIV（観測対象が同じ）と NOT_EQ（観測対象が異なる）の両方向に等しく作用する | ✅ |
| 共通原則 #2（出力側の制約） | 出力テンプレートに触れない | ✅ |
| 共通原則 #3（探索量削減は有害） | 「観測対象まで trace する」は探索を削減しない。到達目標を明確にする | ✅ |
| 共通原則 #4（同方向の変形） | iter-41/43 は「downstream のどこを読むか（B: 情報取得方法）」の変更。本提案は「何を比較単位にするか（C: 比較枠組み）」の変更。方向が異なる | ✅ |
| 共通原則 #5（テンプレート過剰規定） | checklist への 1 行追加のみ。新規フィールド・セクション追加なし | ✅ |
| 共通原則 #6（対称化の実効差分） | 実効差分: EQUIV/NOT_EQ どちらについても「観測対象での確認」を要求する。非対称ではない | ✅ |
| 共通原則 #7（中間ラベルのアンカリング） | ラベルを生成させない。探索行動の指針 | ✅ |
| 共通原則 #10（必要条件ゲートの判別力） | ゲートではない | ✅ |
| 共通原則 #11（探索順序の固定） | 探索の開始順序を固定しない | ✅ |
| 共通原則 #13（relevant test 集合の低精度拡張） | relevant test 集合を変更しない | ✅ |
| 共通原則 #14（条件付きの特例探索） | 条件付き特例なし | ✅ |

---

## 変更規模の確認

- 変更行数: 0 行
- 追加行数: 1 行
- 削除行数: 0 行
- 合計差分: +1 行（20 行以内の目安を大幅に下回る）

## 変更後の Compare checklist（参考）

```markdown
### Compare checklist
- Identify changed files for both sides
- Identify fail-to-pass AND pass-to-pass tests
- For each function called in changed code, read its definition and record in the interprocedural trace table (Step 4)
- Trace each test through both changes separately before comparing
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
- For each relevant test, trace both changes through to the outcome the test's assertion checks (the value compared, the exception caught, or the state verified); compare A and B at that observable — not at intermediate code differences.
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)
```
