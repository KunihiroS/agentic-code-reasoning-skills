#!/bin/bash
set -euo pipefail

# =============================================================================
# auto-improve.sh — SKILL.md 自動改善ループ
#
# Codex が実装者、Claude が監査役。
# Objective.md に定義されたプロセスに従う。
# =============================================================================

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNS_DIR="$REPO_DIR/benchmark/swebench/runs"
BENCH_DIR="$REPO_DIR/benchmark/swebench"

INITIAL_SCORE=85
MAX_ITER=20
MAX_AUDIT_RETRY=3
ROLLBACK_THRESHOLD=75
GOAL_WINDOW=5
GOAL_PERFECT_COUNT=2
START_ITER=6

export PATH="$HOME/.npm-global/bin:$PATH"

cd "$REPO_DIR"

# =============================================================================
# ユーティリティ
# =============================================================================

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [iter-$current_iter] $1"
}

get_score_from_json() {
  local json_file="$1"
  python3 -c "
import json, sys
with open('$json_file') as f:
    data = json.load(f)
print(data.get('with_skill', {}).get('overall_accuracy_pct', 0))
" 2>/dev/null || echo "0"
}

get_recent_scores() {
  local count="$1"
  local scores=()
  for i in $(seq $((current_iter - 1)) -1 $START_ITER); do
    local sf="$RUNS_DIR/iter-$i/scores.json"
    if [ -f "$sf" ]; then
      scores+=("$(get_score_from_json "$sf")")
    fi
    if [ ${#scores[@]} -ge "$count" ]; then break; fi
  done
  echo "${scores[*]}"
}

get_prev_score() {
  if [ "$current_iter" -eq "$START_ITER" ]; then
    echo "$INITIAL_SCORE"
  else
    local prev_iter=$((current_iter - 1))
    local sf="$RUNS_DIR/iter-$prev_iter/scores.json"
    if [ -f "$sf" ]; then
      get_score_from_json "$sf"
    else
      echo "$INITIAL_SCORE"
    fi
  fi
}

check_full_rollback() {
  local scores_str
  scores_str=$(get_recent_scores 3)
  local scores=($scores_str)
  if [ ${#scores[@]} -lt 3 ]; then return 1; fi

  local sum=0
  for s in "${scores[@]}"; do
    sum=$((sum + ${s%.*}))
  done
  local avg=$((sum / 3))

  if [ "$avg" -le "$ROLLBACK_THRESHOLD" ]; then
    return 0  # ロールバック必要
  fi
  return 1
}

check_goal() {
  local scores_str
  scores_str=$(get_recent_scores "$GOAL_WINDOW")
  local scores=($scores_str)
  if [ ${#scores[@]} -lt "$GOAL_WINDOW" ]; then return 1; fi

  local perfect=0
  for s in "${scores[@]}"; do
    if [ "${s%.*}" -eq 100 ]; then
      perfect=$((perfect + 1))
    fi
  done

  if [ "$perfect" -ge "$GOAL_PERFECT_COUNT" ]; then
    return 0  # ゴール達成
  fi
  return 1
}

# =============================================================================
# メインループ
# =============================================================================

for current_iter in $(seq "$START_ITER" $((START_ITER + MAX_ITER - 1))); do
  log "========== イテレーション開始 =========="

  ITER_DIR="$RUNS_DIR/iter-$current_iter"
  mkdir -p "$ITER_DIR"

  prev_score=$(get_prev_score)
  log "前回スコア: ${prev_score}%"

  # === 1. 分析 + 2. 改善案作成 ===
  log "Codex: 分析・改善案作成中..."

  if [ "$current_iter" -eq "$START_ITER" ]; then
    ANALYSIS_CONTEXT="docs/evaluation/benchmark-progression.md の全履歴を分析してください。初回イテレーションです。前回スコアは ${prev_score}% です。"
  else
    ANALYSIS_CONTEXT="benchmark/swebench/runs/iter-$((current_iter - 1))/scores.json と前回の rationale.md を分析してください。前回スコアは ${prev_score}% です。"
  fi

  codex --dangerously-bypass-approvals-and-sandbox -p "
あなたは SKILL.md の改善担当です。以下の手順で作業してください。

1. Objective.md を読み、ゴールと制約を理解する
2. ${ANALYSIS_CONTEXT}
3. README.md と docs/design.md を参照し、研究のコア構造を確認する
4. 失敗原因を特定し、汎用的な改善仮説を立てる
5. SKILL.md を改善する（直接ファイルを編集）
6. benchmark/swebench/runs/iter-${current_iter}/rationale.md を Objective.md のフォーマットに従い作成する

注意:
- 特定のベンチマークケースを狙い撃ちする変更は禁止
- 研究のコア構造（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）を維持すること
" 2>&1 | tee "$ITER_DIR/codex-implement.log"

  log "Codex: 改善完了"

  # === 3. 監査 ===
  log "Claude: 監査中..."

  audit_passed=false
  for retry in $(seq 1 "$MAX_AUDIT_RETRY"); do
    log "監査 試行 $retry/$MAX_AUDIT_RETRY"

    # diff を生成
    git diff -- SKILL.md > "$ITER_DIR/diff.patch"

    claude --dangerously-skip-permissions -p "
あなたは SKILL.md の変更に対する監査役です。

以下のファイルを参照してください:
- Objective.md の Audit Rubric セクション
- README.md（スキルの概要と研究の要約）
- docs/design.md（論文からスキルへの翻訳設計）
- docs/reference/agentic-code-reasoning.pdf（原論文）

以下の diff を Audit Rubric の 7 項目（R1〜R7）で採点し、
Objective.md に定義された audit.md フォーマットに従って
benchmark/swebench/runs/iter-${current_iter}/audit.md を作成してください。

合格基準: 全項目 2 以上、かつ合計 14/21 以上

diff:
$(cat "$ITER_DIR/diff.patch")

rationale:
$(cat "$ITER_DIR/rationale.md" 2>/dev/null || echo '(未作成)')
" 2>&1 | tee "$ITER_DIR/claude-audit-${retry}.log"

    # 判定を確認
    if grep -q "判定: PASS" "$ITER_DIR/audit.md" 2>/dev/null; then
      audit_passed=true
      log "監査 PASS"
      break
    else
      log "監査 FAIL (試行 $retry)"
      if [ "$retry" -lt "$MAX_AUDIT_RETRY" ]; then
        log "Codex: 監査指摘を反映して再改善..."
        codex --dangerously-bypass-approvals-and-sandbox -p "
audit.md の指摘を読み、SKILL.md を修正してください。
監査結果: $(cat "$ITER_DIR/audit.md" 2>/dev/null)
rationale.md も更新してください。
" 2>&1 | tee "$ITER_DIR/codex-revise-${retry}.log"
      fi
    fi
  done

  if [ "$audit_passed" = false ]; then
    log "監査 ${MAX_AUDIT_RETRY}回 FAIL — SKILL.md をロールバック"
    git checkout -- SKILL.md
    echo "監査を ${MAX_AUDIT_RETRY} 回パスできず、改善を断念" > "$ITER_DIR/rationale.md"
    git add "$ITER_DIR"
    git commit -m "iter-${current_iter}: 監査 FAIL — ロールバック"
    git push
    continue
  fi

  # === 4. ベンチマーク実行 ===
  log "ベンチマーク実行中..."
  cp SKILL.md "$ITER_DIR/SKILL.md.snapshot"

  cd "$BENCH_DIR"
  bash run_benchmark.sh --variant with_skill 2>&1 | tee "$ITER_DIR/benchmark.log"
  python3 grade.py > "$ITER_DIR/scores.json" 2>&1
  cd "$REPO_DIR"

  # === 5. 結果評価 ===
  current_score=$(get_score_from_json "$ITER_DIR/scores.json")
  log "今回スコア: ${current_score}% (前回: ${prev_score}%)"

  if [ "${current_score%.*}" -lt "${prev_score%.*}" ]; then
    log "スコア低下 — SKILL.md を前イテレーションに戻す"
    git checkout -- SKILL.md
  fi

  # === 6. フルロールバック判定 ===
  if check_full_rollback; then
    log "直近3回平均が ${ROLLBACK_THRESHOLD}% 以下 — main の SKILL.md にフルロールバック"
    git checkout main -- SKILL.md
  fi

  # === 7. コミット・プッシュ ===
  log "コミット・プッシュ..."
  git add -A
  git commit -m "iter-${current_iter}: score=${current_score}% (prev=${prev_score}%)" || true
  git push

  # === 8. ゴール判定 ===
  if check_goal; then
    log "🎉 ゴール達成！ 直近${GOAL_WINDOW}回中${GOAL_PERFECT_COUNT}回以上 100%"
    exit 0
  fi

  log "========== イテレーション完了 =========="
done

log "最大イテレーション数 (${MAX_ITER}) に到達。終了。"
exit 1
