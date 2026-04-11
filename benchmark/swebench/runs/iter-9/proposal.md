# Iteration 9 — 改善案（Proposal）

## 前イテレーション（iter-8）の分析

### スコアサマリー
- iter-8 スコア: 70%（14/20）
- EQUIV 正答率: 8/10（80%） — 15368, 15382 が誤（NOT_EQUIVALENT と誤判定）
- NOT_EQ 正答率: 6/10（60%） — 14787, 11433, 14122, 12663 が UNKNOWN（31 ターン枯渇）

### 失敗パターン分析

**パターン A（EQUIV 偽陽性）**: 15368（19ターン）・15382（12ターン）はターン枯渇ではなく、
コードパス上に変更点を発見した時点で NOT_EQUIVALENT と結論付けている。
iter-8 で導入した Divergence-First（値レベルの乖離点明示）により2重独立トレース廃止が
行われたが、「乖離点を発見 → そのままテスト結果が変わると判断」するジャンプは改善されていない。
具体的には：Change A と Change B のコードが中間的な値で分岐しているが、
その分岐がテストのアサーション境界に到達する前に収束しているケース（EQUIV の本質）で、
エージェントが乖離点の「発見」→「テスト結果の差異」を証拠なしに結論付けている。

**パターン B（NOT_EQ UNKNOWN）**: 14787, 11433, 14122, 12663 は 4 件とも 31 ターン上限に
到達。iter-8 は Divergence-First で 1 テストあたりのターンを削減する狙いだったが、
UNKNOWN は改善どころか iter-7 の 3 件から 4 件に増加した（14122 が新規追加）。
Divergence-First の「A/B 両方を VERIFIED で記述」要求がコードパスの深い読み込みを
誘発し、複雑なケースでのターン消費を増やした可能性がある。

---

## 選択した Exploration Framework カテゴリ

**カテゴリ F: 原論文の未活用アイデアを導入する**

理由:
- iter-8 もカテゴリ F（localize の DIVERGENCE ANALYSIS を compare に応用）を使い、
  Divergence 乖離点の特定まで実装した。しかし localize の PHASE 3 が完全に実装されていない。
  localize では「CLAIM D[N]: At [file:line], [code] produces [behavior] **which contradicts
  PREMISE T[N]** because [reason]」と明記され、乖離主張がテスト前提（PREMISE T[N]）と
  直接接続されることを要求する。
- compare モードの Divergence ブロックにはこの「乖離 → テストアサーションへの伝播確認」
  ステップが欠けており、中間的な値の乖離を発見した段階でテスト結果の差異と結論付ける
  ショートカットが起きやすい。
- この未実装部分を埋めることは、原論文の「localize テンプレートに見る divergence-claim-premise
  接続」の apply であり、カテゴリ F に明確に該当する。

---

## 改善仮説（1つ）

**compare モードの Divergence ブロックに「乖離の伝播確認（Propagation check）」サブステップを
追加することで、コードレベルの乖離がテストのアサーション境界まで到達するかどうかを
VERIFIED 証拠として明示させ、伝播しない場合は Comparison を SAME と記録させる。
これにより EQUIV 偽陽性（コード差異 → テスト結果差異 の証拠なしジャンプ）を防ぎ、
NOT_EQ ケースではアサーション到達経路が明確化されることで UNKNOWN の一因である
「何を確認すれば結論できるか不明な状態」を解消する。**

根拠:
- localize の PHASE 3 は「CLAIM D[N]: ... which contradicts PREMISE T[N] because [reason]」
  という形式で、乖離が前提（アサーション条件）に対して矛盾することを明示させる。
  compare の Divergence ブロックには同等の「前提への接続」がなく、乖離発見で分析が止まる。
- 原則 #3（探索量の削減は常に有害）には抵触しない：Propagation check は追加の証拠収集であり、
  探索量を増やす方向（有益な方向）。
- 原則 #1（判定の非対称操作）に抵触しない：EQUIV・NOT_EQ どちらに対しても同一の Propagation
  チェックを要求する対称な変更。

---

## SKILL.md の変更内容

**変更箇所**: compare モード Certificate template 内の ANALYSIS OF TEST BEHAVIOR →
  fail-to-pass テストブロックおよび pass-to-pass テストブロックの Divergence サブ記述に
  Propagation チェック行を追加。

**変更前（fail-to-pass ブロック Divergence 部分）**:
```
  Divergence: Identify the first point in this test's code path where
              Change A and Change B produce different values or behavior.
    A at [file:line]: [specific value or behavior — VERIFIED by reading source]
    B at [file:line]: [specific value or behavior — VERIFIED by reading source]
    (If values are identical at every traced point through the test assertion:
     Comparison is SAME — omit Claim below)
```

**変更後（fail-to-pass ブロック Divergence 部分）**:
```
  Divergence: Identify the first point in this test's code path where
              Change A and Change B produce different values or behavior.
    A at [file:line]: [specific value or behavior — VERIFIED by reading source]
    B at [file:line]: [specific value or behavior — VERIFIED by reading source]
    Propagation: Does this divergence reach the test assertion?
      Trace from divergence point to the test assertion that would detect this difference.
      If no assertion receives a changed value: Comparison is SAME.
    (If values are identical at every traced point through the test assertion:
     Comparison is SAME — omit Claim below)
```

**同様の変更**: pass-to-pass ブロックの Divergence 部分にも同一のフォーマットを適用。

**変更規模**: 4 行追加（fail-to-pass）+ 4 行追加（pass-to-pass）= 最大 8 行の追加。
  20 行以内の制約を満たす。

**変更しない部分**: DEFINITIONS, PREMISES, Step 1–5.5, EDGE CASES, COUNTEREXAMPLE /
  NO COUNTEREXAMPLE, FORMAL CONCLUSION, Guardrails, 他モード（localize, explain,
  audit-improve）はすべて変更なし。

---

## EQUIV・NOT_EQ 正答率への影響予測

### EQUIV（現状 8/10 = 80%）

- **改善予測: 8/10 → 9〜10/10**
- 15368, 15382 はコードパス上に乖離点が存在するが、それがテストアサーション境界まで
  伝播していない（EQUIV の本質）。Propagation check により「アサーションに到達するか」
  を VERIFIED 証拠で記述する義務が生じ、到達しない場合は Comparison を SAME とする
  構造的制約がかかる。乖離点の発見で即 NOT_EQUIVALENT と結論付けるジャンプが防止できる。
- 他の 8 件（正答中）: Propagation check はアサーションへの経路の明示を求めるが、
  これらのケースでは乖離が存在しない（SAME）または既にアサーションまで正しく追跡されており、
  影響は軽微。回帰リスクは低い。

### NOT_EQ（現状 6/10 = 60%）

- **改善予測: 6/10 → 6〜8/10**（不確実性あり）
- 正答 6 件: Propagation check は小規模なオーバーヘッド（1〜2 ターン/テスト）を追加するが、
  これらのケースでは乖離がアサーションに到達しているため Propagation trace が短く完結する。
  回帰リスクは低い。
- UNKNOWN 4 件（14787, 11433, 14122, 12663）: 2 つの効果が拮抗する可能性がある。
  - **好影響**: Propagation check が「乖離 → アサーション到達確認」という具体的なゴールを
    エージェントに与え、探索の目的が明確化する。ゴール明確化により収束が早まる可能性。
  - **悪影響**: 複雑なコードパスで Propagation 経路が長い場合、ターン追加消費が起きる。
    すでに 31 ターン枯渇中のケースがさらに悪化するリスクがある。
  - 総合: UNKNOWN 問題の根本原因（複雑なコードパスにおけるターン枯渇）は本変更では
    完全に解決しない。NOT_EQ の回帰は起こさないが大幅改善も保証しない。

---

## failed-approaches.md ブラックリストおよび共通原則との照合

| 項目 | 照合結果 |
|------|----------|
| BL-1（ABSENT 定義）| 無関係。テスト除外ルールは導入しない |
| BL-2（NOT_EQ 証拠閾値強化）| 無関係。EQUIV・NOT_EQ の証拠閾値を非対称に変えない |
| BL-3（UNKNOWN 禁止）| 無関係。出力側の制約を追加しない。Propagation は「何を確認するか」の入力側・処理側の変更 |
| BL-4（CONVERGENCE GATE）| 無関係。探索を早期打ち切りする仕組みを追加しない |
| BL-5（P3/P4 過剰規定）| 無関係。PREMISES の形式を変えない |
| BL-6（対称化）| 無関係。既存制約の対称拡張ではなく、新規の確認ステップを追加 |
| BL-7（分析前ラベル生成）| 無関係。分析前の中間ラベルは生成させない |
| BL-8（受動的記録列追加）| **要注意**。Propagation フィールドは追加だが、「アサーションまで経路を読む」という能動的行動（file:line の引用）を要求するため BL-8 の「受動的記録」には該当しない。共通原則 #8「受動的フィールドは能動的検証を誘発しない」を回避するには「cite file:line」の明示が重要 |
| BL-9（メタ認知チェック）| 無関係。自己評価を求めるチェックではない |
| BL-10（必要条件ゲート）| **要注意**。Propagation check は条件分岐を含むが、BL-10 と異なり「乖離がアサーションに到達するか」という条件はまさに EQUIV 偽陽性（到達しない）と正答（到達する）を弁別する。共通原則 #10「ゲートは失敗モードを弁別しなければならない」を満たしている |
| 共通原則 #1（非対称操作）| PASS：EQUIV・NOT_EQ 双方に同一の Propagation 要求を適用 |
| 共通原則 #2（出力側制約）| PASS：処理ステップの追加であり出力フォーマット制約ではない |
| 共通原則 #3（探索量削減）| PASS：探索量を増やす変更（Propagation trace 追加） |
| 共通原則 #4（同方向再試）| PASS：既存変更の焼き直しではなく新規のステップ追加 |
| 共通原則 #5（過剰規定）| **PASS**：当初案の「cite file:line at each step」を軽量化し、「to the test assertion that would detect this difference」に変更。中間経路の全ステップ引用を要求せず、到達するかどうかの結論判断に集中させる |
| 共通原則 #6（対称化差分）| PASS：既存制約の拡張ではなく新規ステップ追加、差分は両方向に同等 |
| 共通原則 #7（中間ラベル）| PASS：アサーション到達の YES/NO を判定させるが、これは最終判断ではなく中間証拠であり、分析前のラベルではない |

---

## 変更規模

- 追加行数: 約 8 行（fail-to-pass ブロック 4 行 + pass-to-pass ブロック 4 行）
- 削除行数: 0 行
- 変更形式: 既存 Divergence サブブロックへのサブステップ追加（構造的変更なし）
- 20 行以内の目安を満たす

### 監査役フィードバック対応（iter-9 再提出）

監査役指摘「`cite file:line at each step` が過剰規定となり NOT_EQ ターン消費を悪化させる」への対応：

- 変更前: `Trace from divergence to assertion — cite file:line at each step.`
- 変更後: `Trace from divergence point to the test assertion that would detect this difference.`

中間経路の全ステップ引用を削除し、「アサーションに到達するか否か」の結論判断に集中させる文言に修正。
「If no assertion receives a changed value: Comparison is SAME.」はアサーションが変化した値を受け取らない場合の SAME 判定条件として明示的に残す。
これにより NOT_EQ ターン消費オーバーヘッドを最小化しつつ、Propagation check の本質的な機能（伝播しない場合の SAME オフランプ）は維持する。
