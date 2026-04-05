#!/bin/bash
set -euo pipefail

# =============================================================================
# auto-improve.sh — SKILL.md 自動改善ループ
#
# 実装者: GitHub Copilot CLI (gpt-5.2)
# 監査役: Claude Code
#
# Usage:
#   ./auto-improve.sh              # デフォルト: 最大20イテレーション
#   ./auto-improve.sh -n 1         # 1イテレーションだけ実行
#   ./auto-improve.sh -n 5         # 5イテレーションまで実行
#   ./auto-improve.sh -s 8         # iter-8 から開始
#   ./auto-improve.sh -n 1 -s 8    # iter-8 を1回だけ実行
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

COPILOT_MODEL="claude-sonnet-4.6"

# オプション解析
while getopts "n:s:" opt; do
  case $opt in
    n) MAX_ITER="$OPTARG" ;;
    s) START_ITER="$OPTARG" ;;
    *) echo "Usage: $0 [-n max_iterations] [-s start_iter]"; exit 1 ;;
  esac
done

export PATH="$HOME/.npm-global/bin:$PATH"

cd "$REPO_DIR"

# =============================================================================
# ユーティリティ
# =============================================================================

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [iter-$current_iter] $1"
}

get_score_from_json() {
  python3 -c "
import json, sys
with open('$1') as f:
    data = json.load(f)
# grades.json format: list of dicts with 'correct' field
if isinstance(data, list):
    total = len([r for r in data if r.get('variant') == 'with_skill'])
    correct = len([r for r in data if r.get('variant') == 'with_skill' and r.get('correct')])
    print(int(100 * correct / total) if total > 0 else 0)
elif isinstance(data, dict):
    print(int(data.get('with_skill', {}).get('overall_accuracy_pct', 0)))
else:
    print(0)
" 2>/dev/null || echo "0"
}

get_prev_score() {
  if [ "$current_iter" -eq "$START_ITER" ]; then
    echo "$INITIAL_SCORE"
  else
    local sf="$RUNS_DIR/iter-$((current_iter - 1))/scores.json"
    [ -f "$sf" ] && get_score_from_json "$sf" || echo "$INITIAL_SCORE"
  fi
}

check_full_rollback() {
  local scores=()
  for i in $(seq $((current_iter - 1)) -1 $START_ITER); do
    local sf="$RUNS_DIR/iter-$i/scores.json"
    [ -f "$sf" ] && scores+=("$(get_score_from_json "$sf")")
    [ ${#scores[@]} -ge 3 ] && break
  done
  [ ${#scores[@]} -lt 3 ] && return 1
  local sum=0
  for s in "${scores[@]}"; do sum=$((sum + s)); done
  [ $((sum / 3)) -le "$ROLLBACK_THRESHOLD" ]
}

check_goal() {
  local scores=()
  for i in $(seq $((current_iter)) -1 $START_ITER); do
    local sf="$RUNS_DIR/iter-$i/scores.json"
    [ -f "$sf" ] && scores+=("$(get_score_from_json "$sf")")
    [ ${#scores[@]} -ge "$GOAL_WINDOW" ] && break
  done
  [ ${#scores[@]} -lt "$GOAL_WINDOW" ] && return 1
  local perfect=0
  for s in "${scores[@]}"; do [ "$s" -eq 100 ] && perfect=$((perfect + 1)); done
  [ "$perfect" -ge "$GOAL_PERFECT_COUNT" ]
}

run_copilot() {
  local prompt_file="$1"
  local log_file="$2"
  copilot -p "$(cat "$prompt_file")" --yolo --model "$COPILOT_MODEL" -s 2>&1 | tee "$log_file"
}

run_claude() {
  local prompt_file="$1"
  local log_file="$2"
  claude --dangerously-skip-permissions -p "$(cat "$prompt_file")" 2>&1 | tee "$log_file"
}

# =============================================================================
# メインループ
# =============================================================================

echo "=== auto-improve.sh ==="
echo "  実装者: Copilot CLI ($COPILOT_MODEL)"
echo "  監査役: Claude Code"
echo "  開始: iter-$START_ITER"
echo "  最大: ${MAX_ITER} イテレーション"
echo "========================"

for current_iter in $(seq "$START_ITER" $((START_ITER + MAX_ITER - 1))); do
  log "========== イテレーション開始 =========="

  ITER_DIR="$RUNS_DIR/iter-$current_iter"
  mkdir -p "$ITER_DIR"
  PROMPT_DIR="$ITER_DIR/.prompts"
  mkdir -p "$PROMPT_DIR"

  prev_score=$(get_prev_score)
  log "前回スコア: ${prev_score}%"

  # === 1. 分析 + 2. 改善案作成 ===
  log "Copilot ($COPILOT_MODEL): 分析・改善案作成中..."

  if [ "$current_iter" -eq "$START_ITER" ]; then
    ANALYSIS_CONTEXT="docs/evaluation/benchmark-progression.md の全履歴を分析してください。初回イテレーションです。前回スコアは ${prev_score}% です。"
  else
    ANALYSIS_CONTEXT="benchmark/swebench/runs/iter-$((current_iter - 1))/scores.json と前回の rationale.md を分析してください。前回スコアは ${prev_score}% です。"
  fi

  # === 2. 失敗履歴確認 + 3. 改善案提案 ===
  cat > "$PROMPT_DIR/propose.txt" << PROMPT
あなたは SKILL.md の改善担当です。まだ SKILL.md を編集しないでください。まず改善案を提案してください。

1. Objective.md を読み、ゴール・制約・Exploration Framework を理解する
2. failed-approaches.md を読み、過去に失敗した改善方向と共通原則を確認する
3. ${ANALYSIS_CONTEXT}
4. README.md と docs/design.md と docs/reference/agentic-code-reasoning.pdf を参照し、研究のコア構造と未活用のアイデアを確認する
5. Exploration Framework の6カテゴリ（A〜F）から、過去に試されていないカテゴリのアプローチを選択する
6. 改善案を benchmark/swebench/runs/iter-${current_iter}/proposal.md に書く。以下を含むこと:
   - 選択した Exploration Framework のカテゴリ（A〜F）とその理由
   - 改善仮説（1つだけ）
   - SKILL.md のどこをどう変えるか（具体的な変更内容）
   - EQUIV と NOT_EQ の両方の正答率にどう影響するかの予測
   - failed-approaches.md のブラックリストおよび共通原則との照合結果
   - 変更規模（20行以内を目安）

注意:
- 特定のベンチマークケースを狙い撃ちする変更は禁止
- 研究のコア構造（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）を維持すること
- 失敗ケースの修正に固執しない。SKILL.md の推論フレームワークとしての質の向上を目指すこと
- failed-approaches.md の共通原則に抵触する変更は提案しないこと
PROMPT

  run_copilot "$PROMPT_DIR/propose.txt" "$ITER_DIR/copilot-propose.log"
  log "Copilot: 改善案提案完了"

  # === 4. ディスカッション ===
  log "Claude: ディスカッション..."
  cat > "$PROMPT_DIR/discuss.txt" << PROMPT
あなたは SKILL.md の改善に対する監査役です。実装者から改善案が提案されました。

以下を参照して改善案を評価してください:
- benchmark/swebench/runs/iter-${current_iter}/proposal.md（実装者の改善案）
- failed-approaches.md（過去の失敗履歴）
- Objective.md（ゴール・制約・ルーブリック）
- README.md、docs/design.md

以下の観点で意見を述べ、benchmark/swebench/runs/iter-${current_iter}/discussion.md に書いてください:
1. この改善案に関連する既存研究やコード推論の知見を Web 検索して調査し、改善案の妥当性を学術的・実務的観点から評価せよ（検索結果のURLと要点を記載すること）
2. Exploration Framework のカテゴリ選択は適切か？過去のイテレーションで同一カテゴリが既に試されていないか？
3. この変更は EQUIV と NOT_EQ の両方の正答率に対してどう影響するか？変更の実効的差分（変更前との差分）を分析し、その差分が一方向にしか作用しないか確認せよ。
4. failed-approaches.md のブラックリストおよび共通原則との照合:
   - 表現や用語が違っていても、実質的な効果が同じではないか？
   - 共通原則（判定の非対称操作、出力側の制約、探索量の削減、同方向の変形、入力テンプレートの過剰規定、対称化の実効差分）のいずれかに抵触しないか？
   - 上記に該当する場合は「承認: NO」とし、未試行のカテゴリから別のアプローチを提案せよ。
5. 全体の推論品質がどう向上すると期待できるか？
6. 承認するか、修正を求めるか

最後に「承認: YES」または「承認: NO（理由）」を明記してください。
PROMPT

  run_claude "$PROMPT_DIR/discuss.txt" "$ITER_DIR/claude-discuss.log"

  if grep -q "承認: NO" "$ITER_DIR/discussion.md" 2>/dev/null; then
    log "ディスカッション: 改善案が却下されました。再提案..."
    cat > "$PROMPT_DIR/repropose.txt" << PROMPT
監査役から改善案が却下されました。フィードバックを読み、新しい改善案を提案してください。

監査役のフィードバック: $(cat "$ITER_DIR/discussion.md" 2>/dev/null)
failed-approaches.md も再度参照してください。

benchmark/swebench/runs/iter-${current_iter}/proposal.md を上書きしてください。
PROMPT
    run_copilot "$PROMPT_DIR/repropose.txt" "$ITER_DIR/copilot-repropose.log"
    log "Copilot: 再提案完了"
  fi

  # === 5. 実装 ===
  log "Copilot: 実装中..."
  cat > "$PROMPT_DIR/implement.txt" << PROMPT
benchmark/swebench/runs/iter-${current_iter}/proposal.md の改善案に従い、以下を実行してください:

1. SKILL.md を編集する（proposal.md に記載した変更のみ）
2. benchmark/swebench/runs/iter-${current_iter}/rationale.md を Objective.md のフォーマットに従い作成する

proposal.md に書いた内容以外の変更は行わないでください。
PROMPT

  run_copilot "$PROMPT_DIR/implement.txt" "$ITER_DIR/copilot-implement.log"
  log "Copilot: 実装完了"

  # === 3. 監査 ===
  log "Claude: 監査中..."
  audit_passed=false

  for retry in $(seq 1 "$MAX_AUDIT_RETRY"); do
    log "監査 試行 $retry/$MAX_AUDIT_RETRY"
    git diff -- SKILL.md > "$ITER_DIR/diff.patch"

    cat > "$PROMPT_DIR/audit.txt" << PROMPT
あなたは SKILL.md の変更に対する監査役です。

以下のファイルを参照してください:
- Objective.md の Audit Rubric セクション
- README.md
- docs/design.md
- docs/reference/agentic-code-reasoning.pdf

以下の diff を Audit Rubric の 7 項目（R1〜R7）で採点し、
Objective.md に定義された audit.md フォーマットに従って
benchmark/swebench/runs/iter-${current_iter}/audit.md を作成してください。

合格基準: 全項目 2 以上、かつ合計 14/21 以上

diff:
$(cat "$ITER_DIR/diff.patch")

rationale:
$(cat "$ITER_DIR/rationale.md" 2>/dev/null || echo '(未作成)')
PROMPT

    run_claude "$PROMPT_DIR/audit.txt" "$ITER_DIR/claude-audit-${retry}.log"

    if grep -q "判定: PASS" "$ITER_DIR/audit.md" 2>/dev/null; then
      audit_passed=true
      log "監査 PASS"
      break
    else
      log "監査 FAIL (試行 $retry)"
      if [ "$retry" -lt "$MAX_AUDIT_RETRY" ]; then
        log "Copilot: 監査指摘を反映して再改善..."
        cat > "$PROMPT_DIR/revise.txt" << PROMPT
audit.md の指摘を読み、SKILL.md を修正してください。
監査結果: $(cat "$ITER_DIR/audit.md" 2>/dev/null)
rationale.md も更新してください。
PROMPT
        run_copilot "$PROMPT_DIR/revise.txt" "$ITER_DIR/copilot-revise-${retry}.log"
      fi
    fi
  done

  if [ "$audit_passed" = false ]; then
    log "監査 ${MAX_AUDIT_RETRY}回 FAIL — SKILL.md をロールバック"
    git checkout -- SKILL.md
    echo "監査を ${MAX_AUDIT_RETRY} 回パスできず、改善を断念" > "$ITER_DIR/rationale.md"
    git add "$ITER_DIR"
    git commit -m "iter-${current_iter}: 監査 FAIL — ロールバック" || true
    git push || true
    continue
  fi

  # === 4. ベンチマーク実行 ===
  log "ベンチマーク実行中..."
  cp SKILL.md "$ITER_DIR/SKILL.md.snapshot"

  cd "$REPO_DIR"
  bash benchmark/swebench/run_benchmark.sh --variant with_skill --runs-dir "$ITER_DIR" 2>&1 | tee "$ITER_DIR/benchmark.log" || true
  python3 benchmark/swebench/grade.py "$ITER_DIR" benchmark/swebench/data/pairs.json 2>&1 | tee "$ITER_DIR/grade.log" || true
  # grades.json を scores.json としてコピー（スクリプト内の参照用）
  cp "$ITER_DIR/grades.json" "$ITER_DIR/scores.json" 2>/dev/null || true

  # === 5. 結果評価 ===
  current_score=$(get_score_from_json "$ITER_DIR/scores.json")
  log "今回スコア: ${current_score}% (前回: ${prev_score}%)"

  if [ "$current_score" -lt "$prev_score" ]; then
    log "スコア低下 — SKILL.md を前イテレーションに戻す"
    git checkout -- SKILL.md

    # failed-approaches.md に失敗を自動追記
    log "Claude: 失敗分析・ブラックリスト更新中..."
    cat > "$PROMPT_DIR/update-bl.txt" << BLPROMPT
今回のイテレーション(iter-${current_iter})で SKILL.md を改善したが、スコアが ${prev_score}% から ${current_score}% に低下した。

以下のファイルを参照し、failed-approaches.md に新しいエントリを追記してください:
- benchmark/swebench/runs/iter-${current_iter}/proposal.md（改善案）
- benchmark/swebench/runs/iter-${current_iter}/rationale.md（変更理由）
- benchmark/swebench/runs/iter-${current_iter}/diff.patch（実際の変更差分）

追記フォーマット（既存エントリに倣うこと）:
### BL-{次の番号}: {変更の要約}
- 試行: iter-${current_iter}
- 内容: {何を変えたか}
- 結果: スコア ${prev_score}% → ${current_score}%
- 原因: {なぜスコアが下がったか}
- Fail Core: {この失敗の本質は何か。表現を変えても同じ失敗になる根本的なメカニズムを記述せよ。既存の共通原則（判定の非対称操作、出力側の制約、探索量の削減、同方向の変形）のいずれかに該当するか、もしくは新たな原則が必要か検討せよ}

また、共通の失敗パターンに新たな原則を追加すべきか検討し、必要なら追記せよ。
BLPROMPT
    run_claude "$PROMPT_DIR/update-bl.txt" "$ITER_DIR/claude-bl-update.log" || log "ブラックリスト更新失敗（続行）"
    log "ブラックリスト更新完了"
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
  git push || true

  # === 8. ゴール判定 ===
  if check_goal; then
    log "ゴール達成！ 直近${GOAL_WINDOW}回中${GOAL_PERFECT_COUNT}回以上 100%"
    exit 0
  fi

  log "========== イテレーション完了 =========="
done

log "最大イテレーション数 (${MAX_ITER}) に到達。終了。"
exit 1
