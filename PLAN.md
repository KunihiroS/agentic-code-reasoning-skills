# Development Plan

## Current Status

**SKILL.md: v2 (93/100)** — 実テスト前の構造的完成段階

### Completed

- [x] 論文の全セクション読み込み・核心哲学の抽出
- [x] 評価ルーブリック作成（5カテゴリ・20基準、`docs/evaluation/rubric-v1.md`）
- [x] v1 作成・評価（62/100、`docs/evaluation/skill-v1-evaluation.md`）
- [x] v2 作成・自己評価（93/100、`docs/evaluation/skill-v2-evaluation.md`）

### v1 → v2 の主な改善

| 改善 | 概要 |
|------|------|
| Certificate ゲート機構 | セクション順序依存の明示化 |
| Per-item ループ構造 | 「各テストについて」「各メソッドについて」の反復テンプレート |
| Interprocedural tracing | Core Method Step 4 として独立化、VERIFIED/UNVERIFIED 列 |
| サードパーティライブラリ対策 | UNVERIFIED マーキング + 代替エビデンス探索 |
| Guardrails 拡充 | 6 → 9項目、論文の全失敗モードをカバー |
| 番号付き相互参照 | P[N], H[N], O[N], C[N], D[N], T[N], F[N], R[N], E[N] |

### 残り 7点の内訳（ドキュメントレベルの限界）

| 基準 | 現スコア | 要因 |
|------|---------|------|
| A1: Certificate ゲート | 4/5 | 完全な強制はツールレベルの実装が必要 |
| B4: Per-item 網羅性 | 4/5 | 「全項目必須」の明示的ゲート文言 |
| C3: 不完全チェーン | 4/5 | メタ認知的指示の構造的限界 |
| C4: サードパーティ | 4/5 | UNVERIFIED の具体サンプル |
| C5: 微妙な差異 | 4/5 | テンプレート内への組み込み |
| E1: トリガー精度 | 4/5 | Description Optimization 未実施 |

## Next Steps

### Phase 1: 実テスト（優先）

2〜3件の realistic なテストケースで動作確認する。

候補タスク:
1. **compare** — 実際の OSS パッチペアで等価性を判定
2. **localize** — 既知のバグ（failing test あり）で root cause を特定
3. **explain** — 複数ファイルにまたがるコードの挙動を説明

Skill Creator のテスト・評価インフラ（subagent 実行、baseline 比較、eval viewer）は活用可能。

### Phase 2: Description Optimization

Skill Creator の `run_loop.py` による trigger eval で description の精度を最適化する。
SKILL.md 本体には影響しないため安全に実行可能。

### Phase 3: 微調整

実テスト結果に基づき、**論文ルーブリック**を基準にして改善を判断する。
Skill Creator の反復改善ループに全面委任すると、論文由来の構造的保証が簡略化されるリスクがあるため、改善の意思決定は手動で行う。

## Design Decisions

### 統合スキル（1 skill + 4 modes）
論文の3タスク（compare, localize, explain）+ 論文 future work の実践的拡張（audit-improve）を1つのスキルに統合。Core Method を共有し、モード固有の certificate テンプレートを持つ。

### audit-improve の根拠
論文の §5 Future Work に「security vulnerability detection, code smell identification, and API misuse detection」が明示されている。refactoring は同じ推論プロセスの実践的拡張として追加。

### Skill Creator との関係
Skill Creator の哲学（「柔軟で説明的」「rigid structures は yellow flag」）と、本スキルの哲学（「論文由来の構造的強制」）は方向が異なる。テスト・評価インフラは活用するが、SKILL.md 本体の改善判断は論文ルーブリックに基づいて行う。
