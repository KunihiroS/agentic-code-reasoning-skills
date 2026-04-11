# Iteration 40 — 改善案（修正版）

> **前回提案の却下理由**: `EDGE CASES RELEVANT TO EXISTING TESTS` の全面削除は、compare の探索/検証カバレッジを削る変更であり、`failed-approaches.md` 原則 #3「探索量の削減は常に有害」に実質抵触するとして承認されなかった。監査役の代替案：「全面削除ではなく、統合による圧縮」＝ **Claim C[N].1/2 の because 節に edge-case obligation を埋め込んだうえで、別欄を圧縮する（カテゴリ F）**。

---

## 選択した Exploration Framework カテゴリ

**カテゴリ F: 原論文の未活用アイデアを導入する — 「研究コアの anti-skip 機構を落とさず Claim 内に再配置する」**

### 選択理由

前回提案（カテゴリ E: EDGE CASES 全面削除）は、「探索量の削減」と実効的に等価とみなされて却下された。

監査役のフィードバックが示した代替方針:
- `EDGE CASES` が持つ「ACTUAL tests が踏む edge cases を再確認する」という **anti-skip 義務**を、Claim C[N].1 / C[N].2 の `because` 節に **1行で統合**し、別欄としての EDGE CASES は削除する。
- これはカテゴリ F（論文コアの anti-skip 機構を落とさず再配置する）である。

論文 (Ugare & Chandra, arXiv:2603.01896) の設計思想では、certificate の各 Claim は **その証拠を完全に封じ込める**ことで anti-skip を実現する。現在の EDGE CASES セクションは Claim の**外側**にある後処理的な欄であり、Claim を完成させた後にエージェントが「何か edge case はないか」と戻る構造になっている。これは certificate の各フィールドが独立した証拠として機能する本来の設計（Claim 内で完結）から逸脱している。

**根本的な改善メカニズム**:  
edge-case の確認義務を Claim の `because` 節に統合することで、エージェントは「per-test の trace を書く段階」で edge case も自然に確認するよう誘導される。外部の別欄に後回しにするより、**1つの Claim が1つの完全な証拠単位**として機能するようになる。これは論文が重視する「structured certificate = each claim backed by full evidence」の設計にも整合する。

---

## 改善仮説（1つだけ）

**仮説**: `EDGE CASES RELEVANT TO EXISTING TESTS` の義務（ACTUAL tests が踏む edge case を A/B 両変更で比較する）を、Claim C[N].1 / C[N].2 の `because` 節に統合することで、

1. **anti-skip 機能は維持**される（義務は消えず Claim 内で生きる）
2. **別欄としての EDGE CASES を削除**でき、ターン予算を節約できる  
3. **Claim が証拠として完結**するため、エージェントはトレース中に edge case を処理する（後処理に先送りしない）

この統合により、3件の UNKNOWN（15382、14787、12663）のターン枯渇を軽減しつつ、検証密度を落とさない。

---

## SKILL.md のどこをどう変えるか

**変更対象**: Compare 証明書テンプレート（`ANALYSIS OF TEST BEHAVIOR` 内の Claim フォーマットと EDGE CASES ブロック）

### 変更前（現在の SKILL.md）

```
For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line]
  Comparison: SAME / DIFFERENT outcome

...（pass-to-pass ブロック）...

EDGE CASES RELEVANT TO EXISTING TESTS:
(Only analyze edge cases that the ACTUAL tests exercise)
  E[N]: [edge case]
    - Change A behavior: [specific output/behavior]
    - Change B behavior: [specific output/behavior]
    - Test outcome same: YES / NO
```

### 変更後（提案）

```
For each relevant test:
  Test: [name]
  Claim C[N].1: With Change A, this test will [PASS/FAIL]
                because [trace through code — cite file:line;
                cover all branches this test actually exercises, not just the happy path]
  Claim C[N].2: With Change B, this test will [PASS/FAIL]
                because [trace through code — cite file:line;
                cover all branches this test actually exercises, not just the happy path]
  Comparison: SAME / DIFFERENT outcome

...（pass-to-pass ブロック — 同様に Claim を修正）...

（EDGE CASES RELEVANT TO EXISTING TESTS ブロックを削除）
```

### 変更の詳細

| 操作 | 対象 | 内容 |
|------|------|------|
| 修正 | Claim C[N].1 の `because` | `trace through code — cite file:line` → `trace through code — cite file:line; cover all branches this test actually exercises, not just the happy path` |
| 修正 | Claim C[N].2 の `because` | 同上（fail-to-pass ブロックと pass-to-pass ブロックの両方） |
| 削除 | EDGE CASES ブロック（7行） | `EDGE CASES RELEVANT TO EXISTING TESTS:` 以下7行を削除 |

**変更規模**:
- 削除: 7行（EDGE CASES ブロック）
- 修正: 4行（Claim C[N].1/2 の because 節 × fail-to-pass / pass-to-pass 各ブロック）
- 純追加: 約 8 words（`cover all branches this test actually exercises, not just the happy path` × 4箇所）
- 合計純削減: 約 5〜6 行（20 行以内の目安を満たす）

---

## 前回提案との実効的差分

| 観点 | 前回提案（全面削除） | 今回提案（Claim 内統合） |
|------|---------------------|------------------------|
| edge-case 確認義務 | 消滅 | Claim の `because` 節に存続 |
| anti-skip メカニズム | 弱体化 | 維持（Claim 内で封じ込め） |
| ターン節約 | 7行分 | 7行削減 − 4行修正 ≒ 同程度 |
| 証拠の完結性 | 変化なし | 改善（Claim が edge case まで含む） |
| 探索量 | 減少（原則 #3 抵触リスク） | 維持（再配置のみ） |

---

## EQUIV と NOT_EQ の両方の正答率への影響予測

| ケース | 現状 | 失敗パターン | 本変更の作用 | 予測 |
|--------|------|------------|-------------|------|
| 13821 | EQUIV → NOT_EQ | 9ターン早期誤結論 | Claim に edge-case 義務があるため、DIFFERENT と書く前に「このテストが踏む分岐でも差が出るか」を確認する誘導が生まれる | 改善の可能性あり |
| 15382 | EQUIV → UNKNOWN | 31ターン上限 | EDGE CASES 別欄削除でターン節約。Claim 内への統合は per-test の trace 量を微増させるが、別欄のオーバーヘッド削除が上回る | +1 見込み |
| 14787 | NOT_EQ → UNKNOWN | 31ターン上限 | 同上 | +1 見込み |
| 11433 | NOT_EQ → EQUIV | 26ターン誤結論 | caller 伝播の確認漏れが根本原因。本変更の直接的作用は限定的 | 変化なし〜微改善 |
| 12663 | NOT_EQ → UNKNOWN | 31ターン上限 | 同上（ターン節約） | +1 見込み |

### 総合予測

- **現状**: 15/20（75%）
- **期待**: 17〜18/20（85〜90%）
- **最悪ケース**（Claim の because 節が per-test 記述量を大幅増加させた場合）: 15/20（変化なし）

---

## failed-approaches.md ブラックリストおよび共通原則との照合

### ブラックリスト照合

| ブラックリスト | 本提案との関係 |
|---|---|
| BL-1（ABSENT 定義追加） | 定義の追加なし ✓ |
| BL-2（証拠閾値の引き上げ） | 判定閾値の変更なし ✓ |
| BL-3（UNKNOWN 禁止） | 出力制約なし ✓ |
| BL-4（早期打ち切りゲート） | 探索打ち切りゲートなし ✓ |
| BL-5（前提収集フィールド強化） | 前提収集 P[N] 変更なし ✓ |
| BL-7（中間ラベル生成） | 分析前ラベルを新設しない ✓ |
| BL-8（受動的記録フィールド追加） | フィールド追加ではなく、既存 Claim の because 節の拡張。記録より検証行動を促す ✓ |
| BL-9（メタ認知的自己チェック） | 「やったか？」の自己確認ではなく、because 節の trace 義務の拡張 ✓ |
| BL-10（必要条件ゲート） | YES/NO ゲートの挿入ではない ✓ |
| BL-14（非対称 Backward Trace） | Claim C[N].1 と C[N].2 の両方に対称的に適用 ✓ |
| BL-15（出力文言削減リバート） | COUNTEREXAMPLE / FORMAL CONCLUSION ブロック変更なし ✓ |
| BL-16（Comparison 直前注釈） | Comparison 行変更なし ✓ |
| BL-17（関連テスト探索拡張） | relevant test の探索範囲変更なし ✓ |
| BL-18（条件付き特例探索追加） | サイドクエスト追加なし ✓ |

### 共通原則との照合

| 原則 | 本提案への評価 |
|---|---|
| #1（非対称操作は失敗する） | Claim C[N].1 と C[N].2 に対称的に同じ修正を適用。EQUIV/NOT_EQ どちらの方向にも同等の影響 ✓ |
| #2（出力側の制約は効果がない） | 結論ブロックへの制約ではなく、証拠収集フェーズ（because 節）の修正 ✓ |
| #3（探索量の削減は常に有害） | **探索量の削減ではなく再配置**。edge-case の確認義務は消えず Claim に移るため、検証の総量は維持される ✓ |
| #5（入力テンプレートの過剰規定は視野を狭める） | 新しいフィールドや枠を追加せず、既存の because 節に「branches this test exercises」を加えるのみ。E[N] のような記録様式は廃止 ✓ |
| #6（対称化は差分で見よ） | 実効差分: 「edge-case 確認義務が Claim の because 節に移る + EDGE CASES 別欄が消える」。どちらも EQUIV/NOT_EQ に非対称な影響を持たない ✓ |
| #8（受動的記録は検証を誘発しない） | E[N]（受動的記録欄）を廃止し、代わりに because 節のトレース義務として統合。記録フィールドでなく検証行動の一部として機能させる ✓ |
| #14（特例探索のサイドクエスト） | EDGE CASES という「メインループ後のサイドクエスト」を廃止し、主 Claim に取り込む。原則 #14 の推奨に沿っている ✓ |

---

## 変更規模

- **削除**: 7行（`EDGE CASES RELEVANT TO EXISTING TESTS` セクション）
- **修正**: 4箇所（Claim C[N].1/2 の because 節 × 2ブロック）
- **合計変更量**: 削除 7行 + 修正 4行（20 行以内の目安を満たす）
- **改訂対象ファイル**: `SKILL.md`（Compare 証明書テンプレート内）

---

## 制約・リスクの明示

1. **per-test 記述量の微増リスク**: Claim の because 節が「cover all branches this test actually exercises」を含むことで、1 Claim あたりの書き量が微増する可能性がある。しかし EDGE CASES 別欄（~3〜5 ターン）の削除がこれを上回ると予想する。

2. **11433 への直接効果の限界**: caller 伝播の確認漏れが根本原因のケースには、本変更は直接作用しない。別イテレーションで対処が必要。

3. **13821 への期待効果の不確実性**: 9 ターンという早期結論の原因が「edge case を Claim で確認していないこと」なら改善する可能性があるが、不確実性は残る。
