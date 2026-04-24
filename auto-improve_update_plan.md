# auto-improve 改善計画 — meta-agent-3/auto-improve

**ブランチ**: `meta-agent-3/auto-improve`
**開始日**: 2026-04-24
**前ブランチの成果**: iter-46 SKILL.md (Compare +10.0pp, gpt-5.4)

過去の記録:
- [meta-agent-1 (2026-04-06〜04-20)](docs/history/meta-agent-1.md)
- [meta-agent-2 (2026-04-20〜04-24)](docs/history/meta-agent-2.md)

---

## 現状

- SKILL.md: Compare 特化版 (269 行)
- ベンチモデル: openai-codex/gpt-5.4
- ベースライン: without 59.0% → with 69.0% (+10.0pp, 5 ラン平均)
- Proposer/Auditor: openai-codex/gpt-5.4
- 行数制限: 15 行
- メタ監査: meta-audit 導入済み

## 次の改善方向（検討中）

- Hermes メモリ機能の活用 (MEMORY.md / セッション継続)
- ベンチマーク自動生成 (SGS の Conjecturer 着想)
- EQUIV 判定精度の安定化
- SKILL.md.full への成果マージ
- フレームワーク化 (AutoAgent / smolvm 参考)
