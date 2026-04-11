# Iteration 62 — 改善提案

## 親イテレーションの選定理由

**親: iter-21（スコア 85%、フォーカス: overall）**

iter-21 は Guardrail #10「Commit to a conclusion」の追加により 65% → 85% へと最大幅の改善を達成し、現行 SKILL.md の基底として最も高いスコアを持つイテレーションである。後続イテレーション（iter-22〜iter-61）は多数の試行にもかかわらず 85% の壁を突破できなかったため、この基底から探索フレームワークの未試行カテゴリを選択する。

iter-21 の失敗ケース:
- **django__django-15368**: EQUIV → NOT_EQUIVALENT（コード差異からテスト不合格への推論ジャンプ）
- **django__django-15382**: EQUIV → UNKNOWN（Guardrail #10 があっても収束失敗）
- **django__django-14787**: NOT_EQUIVALENT → EQUIVALENT（反例の見つけ損ね）

---

## 選択した Exploration Framework カテゴリと理由

**カテゴリ F: 原論文の未活用アイデアを導入する**

副次的に **カテゴリ E: 表現・フォーマットを改善する**

理由:
- カテゴリ A（推論順序）: BL-6, BL-12, BL-14, BL-24, BL-26 が多数の構造変更を網羅済み。
- カテゴリ B（情報取得）: BL-17, BL-18, D2 関連変更が網羅済み。
- カテゴリ C（比較枠組み）: BL-1, BL-7, BL-32, CONTRACT DELTA（iter-35）が網羅済み。
- カテゴリ D（メタ認知）: BL-9 と Step 5.5 が網羅済み。
- カテゴリ E（表現）: BL-11, BL-16, BL-29, BL-32 が多数の表現変更を網羅済みだが、**compare モードの導入テキスト（テンプレートヘッダー）への一般的なフレーミング指示**は未試行。
- カテゴリ F: 論文の `localize` モードの PHASE 1（TEST/SYMPTOM SEMANTICS）と `explain` モードの DATA FLOW ANALYSIS は、分析をテスト観測点から出発させるアプローチを採用している。compare モードの**テンプレート実行前指示**にこの「テスト観測点起点」の思考フレームを導入することは未試行である。

---

## 改善仮説

**compare モードのテンプレート実行前に「各変更による挙動差異はテストの PASS/FAIL 結果への影響を問う」というフレーミング指示を 1 行追加することで、エージェントがコード差異発見後に「テスト結果に影響するか」を自然に問いかけながら分析を進め、コード差異 → テスト不合格への浅い推論ジャンプ（EQUIV 偽陰性パターン）が抑制される。**

根拠:
1. **論文の設計思想（Category F）**: 論文の localize モード PHASE 1 は分析の起点をテストの期待値（what the test expects）に置く。compare モードには同等の起点フレーミングが欠けており、エージェントは「コード差異が存在する」という事実から推論を開始しがちである。
2. **現行 SKILL.md の構造的空白**: compare モードの Certificate template 導入部（"Complete every section…"）は手続き的指示のみで、**何を目的として分析するか**の認知フレームを与えていない。localize/explain モードは section ヘッダー直前でタスクの核（"Goal: identify the root cause of a bug"）を明示し、これが分析の方向性を定める役割を果たしている。compare モードは "determine whether two changes produce the same relevant behavior" という Goal 記述はあるが、テンプレート実行直前の framing は手続きのみである。
3. **テンプレート位置の違い**: BL-11（ANALYSIS セクションヘッダーへの注釈追加、失敗）は分析ループの**内部**へ観点リストを挿入したため mechanism のアンカリングが発生した。本提案はテンプレート**実行前**（certificate template の最初の instruction 直後）への 1 行であり、機能フレームとして作用するのみで、template フィールドや記録義務を追加しない。

---

## SKILL.md の変更内容

**対象箇所**: `## Compare` セクション → `### Certificate template` の第 1 instruction 行の直後

**変更前**（既存テキスト抜粋）:
```
Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS.

```

**変更後**:
```
Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS.
Throughout the analysis, ask: does the changed behavior cause each relevant test to produce a different PASS/FAIL result?

```

**追加行数: 1 行**（変更行数: 0）

---

## EQUIV / NOT_EQ の両正答率への予測影響

### EQUIV 正答率（現状 7/10 → 予測 8〜9/10）

- **15368 / 15382 に対する期待効果**: テンプレート実行前フレームが「PASS/FAIL の差異があるか？」という問いを最初に植え付ける。コード差異を発見したエージェントが自然に「この差異はどのテストの PASS/FAIL を変えるか？」と問い、変えないと判断したケースでは EQUIVALENT に収束しやすくなる。
- **15382 の UNKNOWN**: 根本は情報不足ではなく推論収束の問題であるが、テスト結果への焦点付けがあることで、情報が限られた中でも「差異が PASS/FAIL に届かない」という判断に傾きやすくなる可能性がある。

### NOT_EQ 正答率（現状 10/10 → 予測 9〜10/10）

- **現正答 NOT_EQ ケース**: 本フレーミングは「PASS/FAIL の差異があるか？」という問いを立てる。真の NOT_EQ ケースでは差異が PASS/FAIL に届くため、エージェントは反例を見つけやすくなる（中立〜プラス）。
- **14787 への影響**: 14787 は NOT_EQ → EQUIV の誤答であり、フレーミングが「PASS/FAIL 差異を探せ」と促すことで反例発見に若干寄与する可能性がある。
- **リグレッションリスク**: 10/10 正答の NOT_EQ ケースに対して 1 行の soft framing がリグレッションを引き起こす可能性は極めて低い（実行義務を課さず、探索コストを増加させず、テンプレートフィールドを追加しない）。

---

## failed-approaches.md との照合

### ブラックリスト非該当の確認

| BL 項目 | 本提案との関係 |
|---------|---------------|
| BL-6: Guardrail 4 対称化 | 本提案は Guardrail に触れない |
| BL-7: 変更性質の事前ラベル付け | 本提案はコード変更の分類を求めない。テスト結果への問いを立てるのみ |
| BL-11: ANALYSIS ヘッダーへの mechanism 注釈 | 本提案は ANALYSIS セクション内ではなく Certificate template の実行前指示（ANALYSIS の外側） |
| BL-14: チェックリストへの逆方向推論追加 | 本提案はチェックリスト変更ではなく framing 指示 |
| BL-29: evidence 基準の言い換え | 本提案は証拠要件を変更しない。問いの方向性を与えるのみ |
| BL-32: D1 定義への対偶補足 | 本提案は D1 定義に触れない |

### 共通原則との照合

| 原則 | 評価 |
|------|------|
| #1: 判定の非対称操作は失敗する | 「PASS/FAIL の差異があるか？」は EQUIV/NOT_EQ 両方向に同様に働く中立な問い → 非対称でない |
| #2: 出力側の制約は効果がない | 本変更は出力を制約せず、推論プロセスのフレームを提供する（入力・処理側） |
| #3: 探索量の削減は有害 | 探索量を削減しない（手続きを追加せず） |
| #5: テンプレートの過剰規定は探索視野を狭める | 1 行の汎用 framing であり「何を記録するか」を規定しない |
| #7: 事前ラベル生成はアンカリングを導入する | コード変更の性質ラベルではなく、分析の「問いの方向」を定めるのみ |
| #8: 受動的な記録フィールドは検証を誘発しない | 記録フィールドを追加しない |
| #9: メタ認知的自己チェックは機能しない | 自己評価チェックではなく framing 指示 |

---

## 変更規模の宣言

- **追加行数**: 1 行（hard limit 5 行以内）
- **変更行数**: 0 行
- **削除行数**: 0 行
- **変更箇所**: `## Compare` → `### Certificate template` の第 1 instruction 行の直後のみ
- **他セクションへの影響**: なし（localize, explain, audit-improve, Core Method, Guardrails は無変更）
