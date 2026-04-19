#!/bin/bash
set -euo pipefail

# =============================================================================
# auto-improve.sh — SKILL.md 自動改善ループ
#   Phase 1: score_prop + 5行 hard limit
#   Phase 2: Staged Eval + Re-propose廃止 + ドメイン分割 + Escape hatch
#
# 実装者: GitHub Copilot CLI (claude-sonnet-4.6)
# 監査役: Pi (pi-coding-agent, github-copilot/gemini-3.1-pro-preview)
# ベンチ: Pi (github-copilot/claude-haiku-4.5)
# 親選択: HyperAgents (arXiv:2603.19461) の score_prop アルゴリズム
#
# Usage:
#   ./auto-improve.sh              # デフォルト: 最大20イテレーション
#   ./auto-improve.sh -n 1         # 1イテレーションだけ実行
#   ./auto-improve.sh -n 5         # 5イテレーションまで実行
#   ./auto-improve.sh -s 8         # iter-8 から開始
#   ./auto-improve.sh --escape     # 構造改革モード (5行制限解除、BL参照任意化)
# =============================================================================

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNS_DIR="$REPO_DIR/benchmark/swebench/runs"
BENCH_DIR="$REPO_DIR/benchmark/swebench"
ARCHIVE_FILE="$RUNS_DIR/archive.jsonl"

INITIAL_SCORE=0
MAX_ITER=20
MAX_AUDIT_RETRY=1        # Phase 2 H2: 3 → 1 (再試行は 1 回のみ)
GOAL_WINDOW=5
GOAL_PERFECT_COUNT=2
START_ITER=1
export MAX_ADDED_LINES=5        # H1: 5行 hard limit (Phase 1)
STAGED_GATE_THRESHOLD=3  # Phase 2: Staged Eval で 5ケース中 3 以上正答なら Full 実行
ESCAPE_MODE=0            # Phase 2: 構造改革エスケープハッチ
META_MODE=0              # Phase 3: メタエージェント強制トリガー
META_STAGNATION_WINDOW=5 # Phase 3: 停滞判定ウィンドウ
STEEPNESS=20             # 8.1.A: score_prop sigmoid steepness (高いほど高スコア親優先)

PI_PROVIDER="github-copilot"
PI_MODEL="gemini-3.1-pro-preview"

# 8.8: 監査役を Hermes Agent に置換 (旧 Pi)
HERMES_PROVIDER="openai-codex"
HERMES_MODEL="gpt-5.4"

# Phase 3 (2026-04-16): copilot → openai-codex に移行 (copilot 使用上限対策)。
# propose/implement は Hermes 経由 openai-codex/gpt-5.2 を使う。
# 監査役/メタエージェントは openai-codex/gpt-5.4。
HERMES_PROPOSER_PROVIDER="openai-codex"
HERMES_PROPOSER_MODEL="gpt-5.2"

# オプション解析
PARSED_OPTS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -n) MAX_ITER="$2"; shift 2 ;;
    -s) START_ITER="$2"; shift 2 ;;
    --escape) ESCAPE_MODE=1; shift ;;
    --steepness) STEEPNESS="$2"; shift 2 ;;
    --meta) META_MODE=1; shift ;;
    *) echo "Usage: $0 [-n max_iterations] [-s start_iter] [--escape] [--steepness N] [--meta]"; exit 1 ;;
  esac
done

export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

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

# score_prop による親選択 (Phase 2: フォーカスドメインをサポート)
# $1: score_key (overall / equiv / not_eq)
# $2: method   (score_prop / best / latest) — escape モード時は best を使う
select_parent_genid() {
  local key="${1:-overall}"
  local method="${2:-score_prop}"
  python3 "$BENCH_DIR/select_parent.py" \
    --archive "$ARCHIVE_FILE" \
    --method "$method" \
    --score-key "$key" \
    --steepness "$STEEPNESS" 2>/dev/null
}

# Phase 2: フォーカスドメインをローテーション
# イテレーション番号に応じて overall / equiv / not_eq を順に切り替える
# EQUIV 側を相対的に多く回す (持続的失敗の傾向に対処するため)
# overall:equiv:not_eq = 2:2:1 のローテーション
get_focus_domain() {
  echo "overall"
}

# Phase 2: Staged Eval のスコアを集計 (0-100)
compute_staged_score() {
  local iter_dir="$1"
  python3 -c "
import json, os
from pathlib import Path
pairs = json.load(open('$BENCH_DIR/data/pairs.json'))
gt = {p['instance_id']: p['ground_truth'] for p in pairs}
d = Path('$iter_dir')
import re
correct = 0
total = 0
for inst_dir in d.iterdir():
    if not inst_dir.is_dir() or not inst_dir.name.startswith('django__'):
        continue
    md = inst_dir / 'with_skill' / 'output.md'
    if not md.exists():
        continue
    total += 1
    text = md.read_text()
    m = re.search(r'ANSWER:\s*(YES|NO)', text, re.IGNORECASE)
    answer = m.group(1).upper() if m else None
    if not answer:
        ms = re.findall(r'\b(YES|NO)\b', text, re.IGNORECASE)
        if ms: answer = ms[-1].upper()
    predicted = 'EQUIVALENT' if answer == 'YES' else ('NOT_EQUIVALENT' if answer == 'NO' else 'UNKNOWN')
    if predicted == gt.get(inst_dir.name):
        correct += 1
print(correct)
" 2>/dev/null || echo "0"
}

# 親イテレーションの SKILL.md.snapshot を現在の SKILL.md にコピー
restore_parent_skill() {
  local parent_genid="$1"
  local snap="$RUNS_DIR/iter-${parent_genid}/SKILL.md.snapshot"
  if [ -f "$snap" ]; then
    cp "$snap" "$REPO_DIR/SKILL.md"
    log "親 iter-${parent_genid} の SKILL.md.snapshot を復元"
  else
    log "警告: 親 iter-${parent_genid} の snapshot がない。現状維持"
  fi
}

# 親の overall スコアを archive.jsonl から取得
get_parent_score() {
  local parent_genid="$1"
  local score_key="${2:-overall}"
  python3 -c "
import json
for line in open('$ARCHIVE_FILE'):
    e = json.loads(line)
    if e['genid'] == $parent_genid:
        print(e['scores'].get('$score_key', 0))
        break
else:
    print(0)
"
}

# diff の追加行数をカウント (git diff --numstat を使用)
# 純粋な削除のみの diff でも 0 を返す (grep の no-match による pipefail を避ける)
count_added_lines() {
  git diff --numstat -- SKILL.md 2>/dev/null | awk 'BEGIN{c=0} {c=$1+0} END{print c}'
}

# archive.jsonl に新エントリを追記
append_archive() {
  local genid="$1"
  local parent_genid="$2"
  local compare_json="$3"
  local audit_json="$4"
  local valid_parent="$5"
  python3 "$REPO_DIR/benchmark/swebench/append_archive_entry.py"     "$ARCHIVE_FILE" "$genid" "$parent_genid" "$compare_json" "$audit_json" "$valid_parent"
}

check_goal() {
  python3 -c "
import json
entries = [json.loads(l) for l in open('$ARCHIVE_FILE')]
recent = [e for e in entries[-$GOAL_WINDOW:] if e.get('valid_parent')]
if len(recent) < $GOAL_PERFECT_COUNT:
    exit(1)
good = sum(1 for e in recent if e['scores'].get('compare', 0) >= 70 and e['scores'].get('audit', 0) >= 90)
exit(0 if good >= $GOAL_PERFECT_COUNT else 1)
" 2>/dev/null
}

run_pi() {
  local prompt_file="$1"
  local log_file="$2"
  # < /dev/null で stdin を切り、pi が親の stdin を食わないようにする
  pi -p --no-session --provider "$PI_PROVIDER" --model "$PI_MODEL" "$(cat "$prompt_file")" < /dev/null 2>&1 | tee "$log_file"
}

# 8.8: Hermes Agent をヘッドレス呼び出し (監査役: openai-codex/gpt-5.4)
# < /dev/null で stdin を切り、hermes が親の stdin を食わないようにする
run_hermes() {
  local prompt_file="$1"
  local log_file="$2"
  hermes chat -Q -q "$(cat "$prompt_file")" \
    --provider "$HERMES_PROVIDER" \
    -m "$HERMES_MODEL" \
    < /dev/null 2>&1 | tee "$log_file"
}

# 8.8.2: Hermes 経由で提案者/実装者を呼び出す (copilot provider + claude-sonnet-4.6)
run_hermes_proposer() {
  local prompt_file="$1"
  local log_file="$2"
  hermes chat -Q -q "$(cat "$prompt_file")" \
    --provider "$HERMES_PROPOSER_PROVIDER" \
    -m "$HERMES_PROPOSER_MODEL" \
    < /dev/null 2>&1 | tee "$log_file"
}



# =============================================================================
# メタエージェント (Phase 3)
# =============================================================================

run_meta_agent() {
  # カレントディレクトリをリポルートに固定
  cd "$REPO_DIR"

  local meta_dir="$RUNS_DIR/meta-$(get_template_version)"
  mkdir -p "$meta_dir"

  # スコアサマリーを生成
  export SCORE_SUMMARY
  SCORE_SUMMARY=$(python3 -c "
import json
entries = [json.loads(l) for l in open('$ARCHIVE_FILE') if l.strip()]
scored = [e for e in entries if e.get('valid_parent') and e['scores'].get('audit', 0) > 0]
for e in scored[-10:]:
    g = e['genid']
    c = e['scores'].get('compare', 0)
    a = e['scores'].get('audit', 0)
    tv = e.get('template_version', 0)
    print(f'iter-{g}: compare={c}% audit={a}% (template_v{tv})')
" 2>/dev/null)

  export TEMPLATE_VERSION
  TEMPLATE_VERSION=$(get_template_version)

  export META_RATIONALE_PATH="$meta_dir/meta-rationale.md"

  # テンプレートのバックアップ (ロールバック用)
  local tag_name="meta-v${TEMPLATE_VERSION}"
  git tag -f "$tag_name" 2>/dev/null || true

  # .version をメタエージェントに触らせないよう退避
  cp "$TEMPLATE_VERSION_FILE" "$TEMPLATE_VERSION_FILE.bak"

  # メタエージェント実行
  log "メタエージェント起動 (template_v${TEMPLATE_VERSION})"
  render_template "meta-propose" > "$meta_dir/meta-prompt.txt"
  run_hermes_proposer "$meta_dir/meta-prompt.txt" "$meta_dir/hermes-meta.log"

  # .version をメタエージェントが変更していたら復元（スクリプト側で管理する）
  cp "$TEMPLATE_VERSION_FILE.bak" "$TEMPLATE_VERSION_FILE"
  rm -f "$TEMPLATE_VERSION_FILE.bak"

  # テンプレートが変更されたか確認（.version 以外の prompts/ ファイル）
  if git diff --quiet -- prompts/*.txt prompts/*.json; then
    log "メタエージェント: テンプレート変更なし"
    return 1
  fi

  # テンプレート構文検証
  for tpl_file in "$PROMPTS_DIR"/*.txt; do
    local tpl_name
    tpl_name=$(basename "$tpl_file" .txt)
    if python3 -c "import json; m=json.load(open('$PROMPTS_DIR/manifest.json')); exit(0 if '$tpl_name' in m['templates'] else 1)" 2>/dev/null; then
      if ! grep -qP '\$\{[A-Za-z_]+\}' "$tpl_file" 2>/dev/null; then
        log "警告: $tpl_file に変数プレースホルダーがありません"
      fi
    fi
  done

  # バージョンインクリメント（スクリプト側で管理）
  local new_version=$((TEMPLATE_VERSION + 1))
  echo "$new_version" > "$TEMPLATE_VERSION_FILE"
  log "テンプレートバージョン: $TEMPLATE_VERSION → $new_version"

  # コミット & プッシュ
  git add prompts/ "$meta_dir"
  git commit -m "meta-v${new_version}: テンプレート更新 by メタエージェント" 2>&1 || true
  git tag -f "meta-v${new_version}" 2>/dev/null || true
  git push 2>&1 || true
  git push --tags 2>&1 || true

  log "メタエージェント完了: template_v${new_version} をコミット・プッシュ"
  return 0
}

# メタエージェント後のロールバック判定
check_meta_rollback() {
  local current_version
  current_version=$(get_template_version)
  if [ "$current_version" -eq 0 ]; then
    return 1  # ロールバック不要
  fi

  # 現バージョンでの直近 3 エントリを取得
  local should_rollback
  should_rollback=$(python3 -c "
import json
entries = [json.loads(l) for l in open('$ARCHIVE_FILE') if l.strip()]
current_v = $current_version
# このバージョンで実行されたエントリ
ver_entries = [e for e in entries if e.get('template_version') == current_v and e.get('valid_parent')]
if len(ver_entries) < 3:
    print('wait')  # まだ 3 回未満
    exit(0)
# 前バージョンのベストスコア
prev_entries = [e for e in entries if e.get('template_version', 0) == current_v - 1 and e.get('valid_parent')]
if not prev_entries:
    print('wait')
    exit(0)
prev_best_audit = max(e['scores'].get('audit', 0) for e in prev_entries)
# 現バージョンの直近 3 エントリの平均
recent_audits = [e['scores'].get('audit', 0) for e in ver_entries[-3:]]
avg_recent = sum(recent_audits) / len(recent_audits)
if avg_recent < prev_best_audit - 5:  # 5pp 以上の退行
    print('rollback')
else:
    print('ok')
" 2>/dev/null)

  if [ "$should_rollback" = "rollback" ]; then
    local prev_version=$((current_version - 1))
    log "メタロールバック: template_v${current_version} → v${prev_version}"
    git checkout "meta-v${prev_version}" -- prompts/ 2>/dev/null || true
    echo "$prev_version" > "$TEMPLATE_VERSION_FILE"
    git add prompts/
    git commit -m "meta-rollback: template_v${current_version} → v${prev_version} (スコア退行)" || true
    return 0
  fi
  return 1
}

# テンプレート展開 (Phase 3: prompts/ 外部化)
PROMPTS_DIR="$REPO_DIR/prompts"
TEMPLATE_VERSION_FILE="$PROMPTS_DIR/.version"

get_template_version() {
  if [ -f "$TEMPLATE_VERSION_FILE" ]; then
    cat "$TEMPLATE_VERSION_FILE"
  else
    echo "0"
  fi
}

get_template_hash() {
  cat "$PROMPTS_DIR"/*.txt 2>/dev/null | sha256sum | cut -d' ' -f1
}

render_template() {
  local tpl_name="$1"
  local tpl_file="$PROMPTS_DIR/${tpl_name}.txt"
  if [ ! -f "$tpl_file" ]; then
    log "ERROR: テンプレート $tpl_file が見つかりません"
    return 1
  fi
  # manifest.json から変数リストを取得し、明示的に envsubst に渡す
  local vars
  vars=$(python3 -c "
import json
m = json.load(open('$PROMPTS_DIR/manifest.json'))
tpl = m['templates'].get('$tpl_name', {})
print(' '.join('\${' + v + '}' for v in tpl.get('vars', [])))
" 2>/dev/null)
  if [ -z "$vars" ]; then
    # manifest にない場合はそのまま出力 (変数展開なし)
    cat "$tpl_file"
  else
    envsubst "$vars" < "$tpl_file"
  fi
}

# =============================================================================
# メインループ
# =============================================================================

echo "=== auto-improve.sh (Phase 3: Meta-Agent) ==="
echo "  提案/実装: Hermes ($HERMES_PROPOSER_PROVIDER/$HERMES_PROPOSER_MODEL)"
echo "  監査役:    Hermes ($HERMES_PROVIDER/$HERMES_MODEL)"
if [ "$ESCAPE_MODE" -eq 1 ]; then
  echo "  モード: 構造改革エスケープハッチ (5行制限解除、親=best)"
else
  echo "  親選択: score_prop (HyperAgents, steepness=$STEEPNESS) + ドメインローテーション"
  echo "  変更制約: $MAX_ADDED_LINES 行以内 (hard limit)"
fi
echo "  監査 retry: $MAX_AUDIT_RETRY 回 (Phase 2 H2)"
echo "  Staged Eval: 5ケース → ${STAGED_GATE_THRESHOLD}+ 正答で full"
echo "  開始: iter-$START_ITER"
echo "  最大: ${MAX_ITER} イテレーション"
echo "=================================================================="

# archive.jsonl の存在確認
if [ ! -f "$ARCHIVE_FILE" ]; then
  echo "ERROR: archive.jsonl が存在しない。先に archive_migrate.py を実行してください。"
  exit 1
fi

# Phase 3: メタエージェント判定 (ループ開始前)
if [ "$META_MODE" -eq 1 ]; then
  echo "[meta] --meta フラグ検出: メタエージェントを強制実行"
  current_iter=0  # log 用 (実際のイテレーションではない)
  if run_meta_agent; then
    echo "[meta] テンプレート更新完了。通常ループを開始します。"
  else
    echo "[meta] テンプレート変更なし。通常ループを開始します。"
  fi
  META_MODE=0  # 一度だけ実行
fi

for current_iter in $(seq "$START_ITER" $((START_ITER + MAX_ITER - 1))); do
  log "========== イテレーション開始 =========="

  # Phase 3: 停滞検知 → メタエージェント自動トリガー（scored iter が window 以上溜まった場合のみ）
  meta_scored_since_last=$(python3 -c "
import json
entries = [json.loads(l) for l in open('$ARCHIVE_FILE') if l.strip()]
new_entries = [e for e in entries if 'template_version' in e and e.get('valid_parent') and e['scores'].get('audit',0) > 0]
if not new_entries:
    print(0)
else:
    current_tv = max(e.get('template_version',0) for e in new_entries)
    since = [e for e in new_entries if e.get('template_version',0) >= current_tv]
    print(len(since))
" 2>/dev/null || echo 0)
  if [ "$meta_scored_since_last" -ge "$META_STAGNATION_WINDOW" ]; then
    if python3 "$BENCH_DIR/detect_stagnation.py" "$ARCHIVE_FILE" "$META_STAGNATION_WINDOW" 2>/dev/null; then
      log "停滞検知: メタエージェントを起動 (scored=$meta_scored_since_last)"
      if run_meta_agent; then
        log "テンプレート更新完了。イテレーションを続行。"
      fi
    fi
  fi

  # Phase 3: メタロールバック判定
  check_meta_rollback || true

  ITER_DIR="$RUNS_DIR/iter-$current_iter"
  mkdir -p "$ITER_DIR"
  PROMPT_DIR="$ITER_DIR/.prompts"
  mkdir -p "$PROMPT_DIR"

  # === 0. 親選択 (Phase 2: ドメインローテーション + escape モード対応) ===
  if [ "$ESCAPE_MODE" -eq 1 ]; then
    export focus_domain="overall"
    parent_genid=$(select_parent_genid overall best)
    log "Escape モード: 親=iter-${parent_genid} (best)"
  else
    export focus_domain=$(get_focus_domain "$current_iter")
    parent_genid=$(select_parent_genid "$focus_domain" score_prop)
    log "フォーカスドメイン: $focus_domain, 親: iter-${parent_genid}"
  fi
  if [ -z "$parent_genid" ]; then
    log "ERROR: 親選択に失敗"
    exit 1
  fi
  prev_score=$(get_parent_score "$parent_genid" overall)
  log "親: iter-${parent_genid}"

  # 親の SKILL.md.snapshot を復元
  restore_parent_skill "$parent_genid"
  # 既存の変更をクリーンアップ（親からの diff を正しく測るため）
  git add SKILL.md 2>/dev/null || true

  # ANALYSIS_CONTEXT は変数として残すが、ケース情報を含む過去の rationale/scores 参照を促さない
  ANALYSIS_CONTEXT="現在の SKILL.md は過去の高スコア時点から復元されています。SKILL.md 自体を読み、汎用的な改良点を検討してください。"

  # === 1. 改善案提案 ===
  # 強制カテゴリローテーション (iter-87〜106 の観察で B/E に極端偏り、D/F が 0 回だったため)
  # current_iter % 6: 0=A 1=B 2=C 3=D 4=E 5=F
  cat_idx=$(( current_iter % 7 ))
  case "$cat_idx" in
    0) FORCED_CAT="A"; FORCED_CAT_DESC="推論の順序・構造を変える (ステップの順序、並列/直列、逆方向推論)" ;;
    1) FORCED_CAT="B"; FORCED_CAT_DESC="情報の取得方法を改善する (読み方の具体化、探索の優先順位)" ;;
    2) FORCED_CAT="C"; FORCED_CAT_DESC="比較の枠組みを変える (比較粒度、差異重要度、変更分類)" ;;
    3) FORCED_CAT="D"; FORCED_CAT_DESC="メタ認知・自己チェックを強化する (思い込み検査、弱い環特定、確信度)" ;;
    4) FORCED_CAT="E"; FORCED_CAT_DESC="表現・フォーマットを改善する (曖昧文言の具体化、簡潔化、例示)" ;;
    5) FORCED_CAT="F"; FORCED_CAT_DESC="原論文の未活用アイデアを導入する (localize/explain 手法の compare 応用、エラー分析知見)" ;;
    6) FORCED_CAT="G"; FORCED_CAT_DESC="認知負荷の削減 (不要なセクション・チェック項目・例示の削除、重複の統合、冗長の圧縮)" ;;
  esac
  export FORCED_CAT FORCED_CAT_DESC
  log "Hermes ($HERMES_PROPOSER_MODEL): 分析・改善案作成中... [強制カテゴリ: $FORCED_CAT]"

  # 出力先ファイル (Copilot がここに書く)
  export PROPOSAL_PATH="benchmark/swebench/runs/iter-${current_iter}/proposal.md"

  # 直近の却下理由を収集して提案者に渡す
  export RECENT_REJECTIONS
  RECENT_REJECTIONS=$(python3 -c "
import os, re
runs_dir = '$RUNS_DIR'
rejections = []
for i in range(max(1, $current_iter - 6), $current_iter):
    disc = os.path.join(runs_dir, f'iter-{i}', 'discussion.md')
    if os.path.isfile(disc):
        text = open(disc).read()
        m = re.search(r'承認: NO（理由: (.+?)）', text)
        if m:
            rejections.append(f'iter-{i}: {m.group(1)}')
for r in rejections[-5:]:
    print(r)
" 2>/dev/null)

  if [ "$ESCAPE_MODE" -eq 1 ]; then
    render_template "propose-escape" > "$PROMPT_DIR/propose.txt"
  else
    render_template "propose-normal" > "$PROMPT_DIR/propose.txt"
  fi

  run_hermes_proposer "$PROMPT_DIR/propose.txt" "$ITER_DIR/hermes-propose.log"
  log "Copilot: 改善案提案完了"

  # === 2. ディスカッション ===
  log "Hermes: ディスカッション..."
  export DISCUSSION_PATH="benchmark/swebench/runs/iter-${current_iter}/discussion.md"
  render_template "discuss" > "$PROMPT_DIR/discuss.txt"

  run_hermes "$PROMPT_DIR/discuss.txt" "$ITER_DIR/hermes-discuss.log"

  # Phase 2 H2: Re-propose ループ廃止
  # NO 却下時は即座に skip して次のイテレーションへ
  if grep -q "承認: NO" "$ITER_DIR/discussion.md" 2>/dev/null; then
    log "ディスカッション: 改善案が却下されました。skip → 次のイテレーション (H2)"
    git checkout -- SKILL.md 2>/dev/null || true
    echo "ディスカッションで却下された提案のため skip" > "$ITER_DIR/rationale.md"
    append_archive "$current_iter" "$parent_genid" "" "" "false"
    git add "$ITER_DIR" || true
    git commit -m "iter-${current_iter}: discussion NO → skip (H2)" 2>/dev/null || true
    git push 2>/dev/null || true
    continue
  fi

  # === 3. 実装 ===
  # 8.8.2: /critique (Rubber Duck) は撤廃 — 実測で品質改善ゼロ・70k〜120k tokens/call
  log "Hermes ($HERMES_PROPOSER_MODEL): 実装中..."
  export RATIONALE_PATH="benchmark/swebench/runs/iter-${current_iter}/rationale.md"
  render_template "implement" > "$PROMPT_DIR/implement.txt"

  run_hermes_proposer "$PROMPT_DIR/implement.txt" "$ITER_DIR/hermes-implement.log"
  log "Hermes: 実装完了"

  # === 3.5 H1: 5行 hard limit チェック (escape モードでは skip) ===
  added_lines=$(count_added_lines)
  log "追加行数チェック: ${added_lines} 行"
  if [ "$ESCAPE_MODE" -eq 0 ] && [ "$added_lines" -gt "$MAX_ADDED_LINES" ]; then
    log "H1 制約違反: ${added_lines} 行 > ${MAX_ADDED_LINES} 行 — このイテレーションを破棄"
    git checkout -- SKILL.md
    echo "変更行数 ${added_lines} 行が制限 ${MAX_ADDED_LINES} 行を超過。破棄。" > "$ITER_DIR/rationale.md"
    append_archive "$current_iter" "$parent_genid" "" "" "false"
    git add "$ITER_DIR" || true
    git commit -m "iter-${current_iter}: H1 制約違反 (${added_lines} 行) — 破棄" || true
    git push || true
    continue
  fi

  # === 4. 監査 ===
  log "Hermes: 監査中..."
  audit_passed=false

  for retry in $(seq 1 "$MAX_AUDIT_RETRY"); do
    log "監査 試行 $retry/$MAX_AUDIT_RETRY"
    git diff -- SKILL.md > "$ITER_DIR/diff.patch"

    export AUDIT_PATH="benchmark/swebench/runs/iter-${current_iter}/audit.md"
    export DIFF_CONTENT="$(cat "$ITER_DIR/diff.patch")"
    export RATIONALE_CONTENT="$(cat "$ITER_DIR/rationale.md" 2>/dev/null || echo '(未作成)')"
    render_template "audit" > "$PROMPT_DIR/audit.txt"

    run_hermes "$PROMPT_DIR/audit.txt" "$ITER_DIR/hermes-audit-${retry}.log"

    # 判定の解釈を緩和: "判定: PASS" / "監査結果: PASS" / "PASS" のいずれかを許可
    if grep -qE "(判定|監査結果)[：:]\s*PASS" "$ITER_DIR/audit.md" 2>/dev/null; then
      audit_passed=true
      log "監査 PASS"
      break
    else
      log "監査 FAIL (試行 $retry)"
      if [ "$retry" -lt "$MAX_AUDIT_RETRY" ]; then
        log "Copilot: 監査指摘を反映して再改善..."
        export AUDIT_CONTENT="$(cat "$ITER_DIR/audit.md" 2>/dev/null)"
        render_template "revise" > "$PROMPT_DIR/revise.txt"
        run_hermes_proposer "$PROMPT_DIR/revise.txt" "$ITER_DIR/hermes-revise-${retry}.log"
      fi
    fi
  done

  if [ "$audit_passed" = false ]; then
    log "監査 ${MAX_AUDIT_RETRY}回 FAIL — 破棄"
    git checkout -- SKILL.md
    echo "監査を ${MAX_AUDIT_RETRY} 回パスできず、改善を断念" > "$ITER_DIR/rationale.md"
    append_archive "$current_iter" "$parent_genid" "" "" "false"
    git add "$ITER_DIR" || true
    git commit -m "iter-${current_iter}: 監査 FAIL — 破棄" || true
    git push || true
    continue
  fi

  # === 5. Benchmark 実行 (Compare Pro + Audit) ===
  cp SKILL.md "$ITER_DIR/SKILL.md.snapshot"
  cd "$REPO_DIR"

  # 5a. Compare Pro (20ペア)
  log "Compare Pro ベンチ実行中..."
  COMPARE_RUN_DIR="$ITER_DIR/compare"
  bash benchmark/swebench/run_benchmark_compare_pro.sh --runs-dir "$COMPARE_RUN_DIR" 2>&1 | tee "$ITER_DIR/benchmark-compare.log" || true
  python3 benchmark/swebench/grade_compare_pro.py "$COMPARE_RUN_DIR" benchmark/swebench/data/pro_compare/pairs_pro.json 2>&1 | tee "$ITER_DIR/grade-compare.log" || true

  # 5b. Audit (security_bug 28件)
  log "Audit ベンチ実行中..."
  AUDIT_RUN_DIR="$ITER_DIR/audit"
  bash benchmark/swebench/run_benchmark_audit.sh --runs-dir "$AUDIT_RUN_DIR" 2>&1 | tee "$ITER_DIR/benchmark-audit.log" || true
  python3 benchmark/swebench/grade_localize.py "$AUDIT_RUN_DIR" benchmark/swebench/data/audit_tasks_security.json 2>&1 | tee "$ITER_DIR/grade-audit.log" || true

  # === 6. 結果評価 (独立スコア) ===
  compare_score=$(get_score_from_json "$COMPARE_RUN_DIR/grades_compare.json")
  audit_score=$(get_score_from_json "$AUDIT_RUN_DIR/grades_localize.json")
  prev_compare=$(get_parent_score "$parent_genid" compare)
  prev_audit=$(get_parent_score "$parent_genid" audit)
  log "Compare: ${compare_score}% (親: ${prev_compare}%) / Audit: ${audit_score}% (親: ${prev_audit}%)"

  # archive に追加
  append_archive "$current_iter" "$parent_genid" "$COMPARE_RUN_DIR/grades_compare.json" "$AUDIT_RUN_DIR/grades_localize.json" "true"

  # いずれかのスコアが親より低下した場合は failed-approaches.md に追記
  if [ "$compare_score" -lt "$prev_compare" ] || [ "$audit_score" -lt "$prev_audit" ]; then
    log "スコア低下 — failed-approaches.md 更新中..."
    export DIFF_PATH="benchmark/swebench/runs/iter-${current_iter}/diff.patch"
    export prev_compare compare_score prev_audit audit_score
    render_template "update-bl" > "$PROMPT_DIR/update-bl.txt"
    run_hermes "$PROMPT_DIR/update-bl.txt" "$ITER_DIR/hermes-bl-update.log" || log "BL 更新失敗（続行）"
    log "BL 更新完了"
  fi

  # === 7. コミット・プッシュ ===
  log "コミット・プッシュ..."
  git add -A
  git commit -m "iter-${current_iter}: compare=${compare_score}% audit=${audit_score}% (parent=iter-${parent_genid})" || true
  git push || true

  # === 7.5. Worktree クリーンアップ ===
  log "Worktree クリーンアップ..."
  rm -rf "$HOME/bench_workspace/worktrees/"* "$HOME/bench_workspace/worktrees_compare/"* 2>/dev/null || true
  for _repo in "$HOME/bench_workspace/repos/"*/; do
    git -C "$_repo" worktree prune 2>/dev/null || true
  done
  log "Worktree クリーンアップ完了"

  # === 8. ゴール判定 ===
  if check_goal; then
    log "ゴール達成！ 直近${GOAL_WINDOW}回中${GOAL_PERFECT_COUNT}回以上 100%"
    exit 0
  fi

  log "========== イテレーション完了 =========="
done

log "最大イテレーション数 (${MAX_ITER}) に到達。終了。"
exit 1
