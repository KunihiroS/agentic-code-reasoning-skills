# Iteration 38 — 改善案

## 1. Exploration Framework カテゴリ選択

**選択カテゴリ: F — 原論文の未活用アイデアを導入する**

具体的サブ方針: 「論文の他のタスクモード（localize、explain）の手法を compare に応用する」

### 選択理由

localize モードの Phase 3（Divergence Analysis）では、各 CLAIM が必ずPREMISEへの参照を含む:

```
CLAIM D1: At [file:line], [code] produces [behavior]
          which [satisfies / contradicts] PREMISE T[N] because [reason]
```

この「クレーム → プレミス クロスリファレンス」が localize モードの中心的な anti-skip 機構である。compare モードの Claim テンプレートにはこの機構が存在しない。現状の Claim は:

```
Claim C[N].1: With Change A, this test will [PASS/FAIL]
              because [trace through code — cite file:line]
```

コードトレースとテスト結果の Claim が存在するが、「このトレース結果が P3/P4（テストが何を検証するかを記述するプレミス）に対してどう接続するか」を明示的に要求しない。

**他カテゴリを選ばない理由**:
- **A（推論の順序）**: BL-12（探索順序の固定）が失敗済み。逆方向推論（BL-14）も非対称適用で失敗済み。
- **B（情報取得方法）**: iter-37 のチェックリスト追加（アドバイザリ形式）で部分改善（65%→75%）を達成したが、構造変化なしでは EQUIV 偽陰性3件が残存。
- **C（比較の枠組み）**: BL-7（変更分類）、BL-16（観測点フレーミング）が失敗済み。BL-13（Key value データフロー）が失敗済み。
- **D（メタ認知）**: BL-9（自己チェック）が失敗済み。自己評価精度の限界が根本原因。
- **E（表現・フォーマット）**: 冗長削減は有益かもしれないが、残存失敗原因（プレミスとクレームの非接続）への直接対処にならない。

---

## 2. 改善仮説

**仮説**: compare モードの Claim テンプレートに、localize モードの「クレームはプレミスを参照する」という構造を導入することで、エージェントが「コード差異を発見 → 即 FAIL」というショートカットを踏む前に、「この差異は P3/P4 が記述するテスト期待動作に対して接続するか」を明示的にトレースする義務が生じる。

現在の失敗パターン（EQUIV 偽陰性 3 件）: エージェントはコード差異（例: 関数 X が返す値が変わる）を発見し、「その差異がテストのアサーション到達に影響するか」を確認せずに Claim FAIL と書く。テストのアサーションが実際に比較しているのは別の値（P3 が記述する動作）であることを確認するプロセスがない。

Claim テンプレートが「このトレースが P[N] の期待動作をどう満たす・違反するか」を明示するよう要求すれば、「コード差異 ≠ テスト動作差異」という推論が自然に発生する。

---

## 3. SKILL.md の変更内容

**対象**: `## Compare` セクション内の `ANALYSIS OF TEST BEHAVIOR` の Claim テンプレート（2行）

**変更前**（現行 iter-37 スナップショット状態）:
```
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
```

**変更後**:
```
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code and show whether the behavior in P[N]
                is satisfied or violated — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code and show whether the behavior in P[N]
                is satisfied or violated — cite file:line]
```

（P[N] = fail-to-pass テストに対しては P3、pass-to-pass テストに対しては P4）

**変更規模**: 2行修正（各 Claim の `because` 節に 7語追加）。新規セクション・フィールド追加なし。

### なぜ新規フィールド追加ではないか

BL-8（受動的記録フィールド）の失敗との差異:
- BL-8 は "何を記録するか" の欄を追加した（Relevant to 列、Key value 欄など）
- 本変更は既存の "because [trace]" 節のトレース先を「P[N] の期待動作」として明示する。P[N] はすでに PREMISES に存在するため、参照コストはゼロ。エージェントは「P3 が記述する動作に対して、このトレースがどう接続するか」を考えるが、これは新しい「埋めるべき欄」ではなく、既存トレース義務の終端の明確化である。

### localize モードの既存機構との整合性

localize の `CLAIM D1: which contradicts PREMISE T[N] because [reason]` と同様に、compare の Claim もプレミスへの接続を要求する。これは論文のコア機構（numbered premises → claims reference premises）の compare モードへの適用であり、研究のコア構造を強化する。

---

## 4. EQUIV / NOT_EQ 両正答率への影響予測

### EQUIV 正答率（現在 7/10 = 70%）
- **改善見込み**: 1〜2 件（推定 8〜9/10）
- 根拠: 15368、13821、15382 では、エージェントはコード差異を発見しているが P3 が記述する動作（テストのアサーションが観測する値）に影響するかを追跡していない。`show whether the behavior in P3 is satisfied or violated` を要求することで、「コード差異はあるが P3 の動作は変わらない → satisfied with both → PASS/PASS → SAME」という推論経路が明示的になる。

### NOT_EQ 正答率（現在 8/10 = 80%）
- **影響**: 維持 or 軽微な改善
- 根拠: 真の NOT_EQ ケースでは、変更は P3 の動作を実際に違反する。`show whether P3 is violated` を要求しても、証拠がある場合には違反を示せばよく、NOT_EQ の立証責任を一方的に上げるものではない。14787（EQUIV 誤答）については、P3 への明示的接続要求が「P3 の期待動作が Change B で実際に異なるか」を追跡させ、改善の可能性がある。
- **リスク**: P3 の記述が曖昧な場合、エージェントが「P3 を満たしているか不明」として UNKNOWN に倒れる可能性がある。ただし P3 は PREMISES テンプレートの既存フィールドであり、具体的行動記述が既に要求されている。

---

## 5. failed-approaches.md ブラックリスト・共通原則との照合

| 原則 / BL | 照合結果 | 根拠 |
|-----------|----------|------|
| BL-1（ABSENT 定義） | ✅ 無関係 | テストの除外ではない |
| BL-2（NOT_EQ 閾値引き上げ） | ✅ 対称 | PASS/FAIL 両方の Claim に同一変更。NOT_EQ 方向のみに追加負担なし |
| BL-3（UNKNOWN 禁止） | ✅ 無関係 | 出力強制ではない |
| BL-4（早期打ち切り） | ✅ 無関係 | 探索を打ち切らない |
| BL-5（P3/P4 フォーマット変更） | ✅ 異なる機構 | PREMISES のフォーマットは変えない。CLAIMS 側でプレミスを参照する |
| BL-6（対称化の実効差分） | ✅ 対称 | C[N].1 と C[N].2 の両方に同一変更 |
| BL-7（分析前の中間ラベル生成） | ✅ 分析中 | Claim は ANALYSIS の中（分析中）の記述であり、分析前の分類・ラベルではない |
| BL-8（受動的記録フィールド） | ✅ 異なる | 新フィールド追加なし。既存 `because` 節のトレース対象を明示化 |
| BL-9（メタ認知自己チェック） | ✅ 異なる | 自己評価ではなく P[N] との接続要求 |
| BL-10（判別力のないゲート） | ✅ 異なる | YES/NO 分岐ゲートではない。トレースの終端を P[N] の動作と定義する |
| BL-11（outcome mechanism 注釈） | ✅ 異なる | 観測型の列挙ではなく、既存プレミスへの参照 |
| BL-12（探索順序の固定） | ✅ 異なる | 探索の開始側を固定しない。Claim のトレース終端を明示するのみ |
| BL-13（Key value データフロー欄） | ✅ 異なる | 新欄追加なし。`because` 節内のトレース終端の記述変更のみ |
| BL-14（逆方向推論、NOT_EQ 方向のみ） | ✅ 対称 | 逆方向推論を片方向にのみ課すのではない。PASS/FAIL 両 Claim に対称適用 |
| BL-15（COUNTEREXAMPLE 文言変更） | ✅ 異なる | COUNTEREXAMPLE は変更しない。ANALYSIS Claim のみ |
| BL-16（Comparison 直前のフレーミング） | ✅ 異なる | `Comparison:` 行は変更しない。Claim の `because` 節を変更 |
| BL-17（relevant test 検索拡張） | ✅ 無関係 | テスト集合の変更なし |
| BL-18（条件付き特例探索） | ✅ 無関係 | 特定症状向けの条件分岐なし |
| **共通原則 #1**（判定の非対称操作） | ✅ 対称 | C[N].1 と C[N].2 に同一変更。PASS/FAIL 両方向に同一義務 |
| **共通原則 #2**（出力側の制約） | ✅ 入力側 | 「こう答えよ」ではなく「トレース時に P[N] との接続を示せ」という処理側の改善 |
| **共通原則 #3**（探索量削減） | ✅ 削減なし | 探索量を減らさない。トレース先を具体化するのみ |
| **共通原則 #4**（同方向の変形） | ✅ 異なる機構 | 過去の失敗（アサーション行の特定、逆方向trace等）とは機構が異なる |
| **共通原則 #5**（入力テンプレートの過剰規定） | △ 注意必要 | P[N] への参照は視野を狭める可能性があるが、P[N] は既存プレミスの参照であり、新しい観測対象の列挙ではない。リスク低 |
| **共通原則 #6**（対称化の実効差分） | ✅ 対称 | 差分は両 Claim に同等に作用 |
| **共通原則 #7**（分析前ラベル生成） | ✅ 分析中 | ANALYSIS 内部の Claim 記述の変更。分析開始前の分類ではない |
| **共通原則 #8**（受動的記録） | ✅ 能動的 | P[N] の内容を確認して接続を示す行動を要求する |

**共通原則 #5 の軽微リスクについて**: 「show whether the behavior in P[N] is satisfied or violated」は、P[N] が記述する動作を参照点として使うが、「その動作のみを見よ」ではない。トレースの経路は自由であり、P[N] への到達（または非到達）を確認することが義務。探索視野を P[N] 記述に閉じ込めるのではなく、トレース経路の終端として P[N] を指定する。

---

## 6. 変更規模

- **修正行数**: 2行（Claim C[N].1 の because 節 + Claim C[N].2 の because 節）
- **追加行数**: 各 Claim が複数行にわたる場合、継続行が 1行ずつ増加（合計 2行追加）
- **合計**: 約 4行の変更（修正 2 + 追加 2）、20行以内 ✅
- **新規セクション**: なし
- **既存セクション変更**: `ANALYSIS OF TEST BEHAVIOR` の Claim テンプレートのみ

---

## 補足: iter-37 との継続性

iter-37 のチェックリスト追加（アドバイザリ: 「テストの data value を特定し trace back して Claim を書く前に確認せよ」）は 65%→75% の改善をもたらしたが、チェックリストはアドバイザリであり、Claim を書く際に P3/P4 との接続を証明させる**構造的義務**ではない。本提案はその論理的な次のステップとして、Claim テンプレート自体に P[N] への接続義務を組み込む。
