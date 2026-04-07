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

INITIAL_SCORE=85
MAX_ITER=20
MAX_AUDIT_RETRY=1        # Phase 2 H2: 3 → 1 (再試行は 1 回のみ)
GOAL_WINDOW=5
GOAL_PERFECT_COUNT=2
START_ITER=47
MAX_ADDED_LINES=5        # H1: 5行 hard limit (Phase 1)
STAGED_GATE_THRESHOLD=3  # Phase 2: Staged Eval で 5ケース中 3 以上正答なら Full 実行
ESCAPE_MODE=0            # Phase 2: 構造改革エスケープハッチ

COPILOT_MODEL="claude-sonnet-4.6"
PI_PROVIDER="github-copilot"
PI_MODEL="gemini-3.1-pro-preview"

# オプション解析
PARSED_OPTS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -n) MAX_ITER="$2"; shift 2 ;;
    -s) START_ITER="$2"; shift 2 ;;
    --escape) ESCAPE_MODE=1; shift ;;
    *) echo "Usage: $0 [-n max_iterations] [-s start_iter] [--escape]"; exit 1 ;;
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
    --score-key "$key" 2>/dev/null
}

# Phase 2: フォーカスドメインをローテーション
# イテレーション番号に応じて overall / equiv / not_eq を順に切り替える
# EQUIV 側を相対的に多く回す (持続的失敗の傾向に対処するため)
# overall:equiv:not_eq = 2:2:1 のローテーション
get_focus_domain() {
  local iter_n="$1"
  local mod=$((iter_n % 5))
  case $mod in
    0|2) echo "overall" ;;
    1|3) echo "equiv" ;;
    4)   echo "not_eq" ;;
  esac
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
  python3 -c "
import json
for line in open('$ARCHIVE_FILE'):
    e = json.loads(line)
    if e['genid'] == $parent_genid:
        print(e['scores']['overall'])
        break
else:
    print($INITIAL_SCORE)
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
  local scores_json="$3"
  local valid_parent="$4"
  python3 -c "
import json, datetime
scores_data = json.load(open('$scores_json')) if '$scores_json' else []
ws = [x for x in scores_data if x.get('variant') == 'with_skill']
if ws:
    correct = sum(1 for x in ws if x.get('correct'))
    total = len(ws)
    eq_total = sum(1 for x in ws if x.get('ground_truth') == 'EQUIVALENT')
    neq_total = sum(1 for x in ws if x.get('ground_truth') == 'NOT_EQUIVALENT')
    eq_ok = sum(1 for x in ws if x.get('ground_truth') == 'EQUIVALENT' and x.get('correct'))
    neq_ok = sum(1 for x in ws if x.get('ground_truth') == 'NOT_EQUIVALENT' and x.get('correct'))
    unk = sum(1 for x in ws if x.get('predicted') in (None, 'UNKNOWN'))
    scores = {
        'overall': int(100 * correct / total) if total else 0,
        'equiv_ok': eq_ok, 'equiv_total': eq_total,
        'not_eq_ok': neq_ok, 'not_eq_total': neq_total,
        'unknown': unk, 'correct': correct, 'total': total,
    }
else:
    scores = {'overall': 0, 'correct': 0, 'total': 0}

import os.path
snap_path = 'benchmark/swebench/runs/iter-$genid/SKILL.md.snapshot'
snap_exists = os.path.isfile(snap_path)

entry = {
    'genid': int('$genid'),
    'parent_genid': int('$parent_genid') if '$parent_genid' else None,
    'skill_snapshot': snap_path if snap_exists else None,
    'scores': scores,
    'valid_parent': bool('$valid_parent' == 'true') and snap_exists,
    'timestamp': datetime.datetime.now().isoformat(),
}
with open('$ARCHIVE_FILE', 'a') as f:
    f.write(json.dumps(entry, ensure_ascii=False) + '\n')
"
}

check_goal() {
  python3 -c "
import json
entries = [json.loads(l) for l in open('$ARCHIVE_FILE')]
recent = entries[-$GOAL_WINDOW:]
if len(recent) < $GOAL_WINDOW:
    exit(1)
perfect = sum(1 for e in recent if e['scores']['overall'] == 100)
exit(0 if perfect >= $GOAL_PERFECT_COUNT else 1)
" 2>/dev/null
}

run_copilot() {
  local prompt_file="$1"
  local log_file="$2"
  copilot -p "$(cat "$prompt_file")" --yolo --model "$COPILOT_MODEL" -s 2>&1 | tee "$log_file"
}

run_pi() {
  local prompt_file="$1"
  local log_file="$2"
  # < /dev/null で stdin を切り、pi が親の stdin を食わないようにする
  pi -p --no-session --provider "$PI_PROVIDER" --model "$PI_MODEL" "$(cat "$prompt_file")" < /dev/null 2>&1 | tee "$log_file"
}

# =============================================================================
# メインループ
# =============================================================================

echo "=== auto-improve.sh (Phase 2) ==="
echo "  実装者: Copilot CLI ($COPILOT_MODEL)"
echo "  監査役: Pi ($PI_PROVIDER/$PI_MODEL)"
if [ "$ESCAPE_MODE" -eq 1 ]; then
  echo "  モード: 構造改革エスケープハッチ (5行制限解除、親=best)"
else
  echo "  親選択: score_prop (HyperAgents) + ドメインローテーション"
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

for current_iter in $(seq "$START_ITER" $((START_ITER + MAX_ITER - 1))); do
  log "========== イテレーション開始 =========="

  ITER_DIR="$RUNS_DIR/iter-$current_iter"
  mkdir -p "$ITER_DIR"
  PROMPT_DIR="$ITER_DIR/.prompts"
  mkdir -p "$PROMPT_DIR"

  # === 0. 親選択 (Phase 2: ドメインローテーション + escape モード対応) ===
  if [ "$ESCAPE_MODE" -eq 1 ]; then
    focus_domain="overall"
    parent_genid=$(select_parent_genid overall best)
    log "Escape モード: 親=iter-${parent_genid} (best)"
  else
    focus_domain=$(get_focus_domain "$current_iter")
    parent_genid=$(select_parent_genid "$focus_domain" score_prop)
    log "フォーカスドメイン: $focus_domain, 親: iter-${parent_genid}"
  fi
  if [ -z "$parent_genid" ]; then
    log "ERROR: 親選択に失敗"
    exit 1
  fi
  prev_score=$(get_parent_score "$parent_genid")
  log "親: iter-${parent_genid} (score: ${prev_score}%)"

  # 親の SKILL.md.snapshot を復元
  restore_parent_skill "$parent_genid"
  # 既存の変更をクリーンアップ（親からの diff を正しく測るため）
  git add SKILL.md 2>/dev/null || true

  # ANALYSIS_CONTEXT は変数として残すが、ケース情報を含む過去の rationale/scores 参照を促さない
  ANALYSIS_CONTEXT="現在の SKILL.md は過去の高スコア時点 (集約スコア ${prev_score}%、フォーカスドメイン: ${focus_domain}) から復元されています。SKILL.md 自体を読み、汎用的な改良点を検討してください。"

  # === 1. 改善案提案 ===
  log "Copilot ($COPILOT_MODEL): 分析・改善案作成中..."

  # 出力先ファイル (Copilot がここに書く)
  PROPOSAL_PATH="benchmark/swebench/runs/iter-${current_iter}/proposal.md"

  if [ "$ESCAPE_MODE" -eq 1 ]; then
    cat > "$PROMPT_DIR/propose.txt" << PROMPT
あなたは SKILL.md という汎用コード推論フレームワークの改善担当です。

【参照してよいファイルの完全なリスト】
- SKILL.md
- Objective.md
- README.md
- failed-approaches.md
- docs/design.md
- docs/reference/agentic-code-reasoning.pdf

この 6 ファイル以外を read / search / list してはいけません。
現在のディレクトリ構造を ls / find / grep で探索する必要もありません。

【出力先】
${PROPOSAL_PATH}

【今回のモード】
構造改革エスケープモード。通常の 5 行 hard limit を解除し、新規セクション
追加も許可します。ただし以下の制約は維持されます。

【提案ルール】
- SKILL.md は特定の言語・フレームワーク・テストデータに依存しない汎用フレームワークである。
  改善案も同様に汎用原則として正当化できなければならない。
- 提案には具体的な数値 ID, リポジトリ名, テスト名, コード断片を一切含めないこと。
- failed-approaches.md の汎用原則のいずれかに抵触する変更は提案しない。
- 研究のコア構造（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）を維持する。
- 改善仮説は 1 つだけ。

現在の SKILL.md の集約スコアは過去最高水準にある。汎用的な観点から、
推論プロセスのどこに改良余地があるかを検討してください。
PROMPT
  else
    cat > "$PROMPT_DIR/propose.txt" << PROMPT
あなたは SKILL.md という汎用コード推論フレームワークの改善担当です。

【参照してよいファイルの完全なリスト】
- SKILL.md
- Objective.md
- README.md
- failed-approaches.md
- docs/design.md
- docs/reference/agentic-code-reasoning.pdf

この 6 ファイル以外を read / search / list してはいけません。
現在のディレクトリ構造を ls / find / grep で探索する必要もありません。

【出力先】
${PROPOSAL_PATH}

【今回のフォーカスドメイン】
${focus_domain}
これは compare モードの判定方向を意味します:
- overall: 全体的な推論品質の向上
- equiv: 2 つの実装が同じ振る舞いを持つと判定する精度の向上
- not_eq: 2 つの実装が異なる振る舞いを持つと判定する精度の向上

【提案ルール】
- SKILL.md は特定の言語・フレームワーク・テストデータに依存しない汎用フレームワークである。
  改善案も同様に汎用原則として正当化できなければならない。
- 提案には具体的な数値 ID, リポジトリ名, テスト名, コード断片を一切含めないこと。
- failed-approaches.md の汎用原則のいずれかに抵触する変更は提案しない。
- 研究のコア構造（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）を維持する。
- 改善仮説は 1 つだけ。
- 変更規模は ${MAX_ADDED_LINES} 行以内 (hard limit、超過時は自動リジェクト)。
  既存行への文言追加・精緻化のみ可。新規ステップ・新規フィールド・新規セクション
  の追加は原則不可。削除行はこの制限に含めない。

【proposal.md に含めるべき内容】
- Exploration Framework のカテゴリ (Objective.md 参照) と選定理由
- 改善仮説 (1 つだけ、抽象的・汎用的な記述)
- SKILL.md のどこをどう変えるか (具体的な変更内容)
- 一般的な推論品質への期待効果 (どのカテゴリ的失敗パターンが減るか)
- failed-approaches.md の汎用原則との照合結果
- 変更規模の宣言
PROMPT
  fi

  run_copilot "$PROMPT_DIR/propose.txt" "$ITER_DIR/copilot-propose.log"
  log "Copilot: 改善案提案完了"

  # === 2. ディスカッション ===
  log "Pi: ディスカッション..."
  DISCUSSION_PATH="benchmark/swebench/runs/iter-${current_iter}/discussion.md"
  cat > "$PROMPT_DIR/discuss.txt" << PROMPT
あなたは SKILL.md という汎用コード推論フレームワークの改善に対する監査役です。
実装者から改善案が提案されました。

【参照してよいファイルの完全なリスト】
- ${PROPOSAL_PATH}
- SKILL.md
- failed-approaches.md
- Objective.md
- README.md
- docs/design.md

この 6 ファイル以外を read / search / list してはいけません。
DuckDuckGo MCP による Web 検索は許可します (改善案の汎用的妥当性の調査用)。

【出力先】
${DISCUSSION_PATH}

【監査観点】
1. 既存研究との整合性 (mcp ツール DuckDuckGo MCP で Web 検索し URL と要点を記載)
2. Exploration Framework のカテゴリ選定は適切か。汎用原則として理にかなっているか。
3. この変更は EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方に対してどう作用するか。
   変更前との実効的差分を分析し、片方向にしか作用しないか確認する。
4. failed-approaches.md の汎用原則との照合。表現を変えても本質が同じ過去失敗の
   再演になっていないか。
5. **汎化性チェック**: 提案文中に具体的な数値 ID, リポジトリ名, テスト名, コード断片
   が含まれていないか。含まれていれば実装者のルール違反であり指摘すること。
   提案が特定のドメイン・言語・テストパターンを暗黙に想定していないか。
6. 全体の推論品質がどう向上すると期待できるか。

最後に「承認: YES」または「承認: NO（理由）」を明記してください。
PROMPT

  run_pi "$PROMPT_DIR/discuss.txt" "$ITER_DIR/pi-discuss.log"

  # Phase 2 H2: Re-propose ループ廃止
  # NO 却下時は即座に skip して次のイテレーションへ
  if grep -q "承認: NO" "$ITER_DIR/discussion.md" 2>/dev/null; then
    log "ディスカッション: 改善案が却下されました。skip → 次のイテレーション (H2)"
    git checkout -- SKILL.md 2>/dev/null || true
    echo "ディスカッションで却下された提案のため skip" > "$ITER_DIR/rationale.md"
    append_archive "$current_iter" "$parent_genid" "" "false"
    git add "$ITER_DIR" || true
    git commit -m "iter-${current_iter}: discussion NO → skip (H2)" 2>/dev/null || true
    git push 2>/dev/null || true
    continue
  fi

  # === 3. 実装 ===
  log "Copilot: 実装中..."
  RATIONALE_PATH="benchmark/swebench/runs/iter-${current_iter}/rationale.md"
  cat > "$PROMPT_DIR/implement.txt" << PROMPT
${PROPOSAL_PATH} の改善案に従い、以下を実行してください:

1. SKILL.md を編集する (proposal.md に記載した変更のみ)
2. ${RATIONALE_PATH} を Objective.md の rationale.md フォーマットに従い作成する

【参照してよいファイルの完全なリスト】
- ${PROPOSAL_PATH}
- SKILL.md
- Objective.md (rationale フォーマットのため)

この 3 ファイル以外を read / search / list する必要はありません。

【制約】
- 変更規模は ${MAX_ADDED_LINES} 行以内 (hard limit、escape モード時は解除)
- proposal.md に記載のない変更は行わない
- rationale.md にも具体的な数値 ID, リポジトリ名, テスト名は書かない
PROMPT

  run_copilot "$PROMPT_DIR/implement.txt" "$ITER_DIR/copilot-implement.log"
  log "Copilot: 実装完了"

  # === 3.5 H1: 5行 hard limit チェック (escape モードでは skip) ===
  added_lines=$(count_added_lines)
  log "追加行数チェック: ${added_lines} 行"
  if [ "$ESCAPE_MODE" -eq 0 ] && [ "$added_lines" -gt "$MAX_ADDED_LINES" ]; then
    log "H1 制約違反: ${added_lines} 行 > ${MAX_ADDED_LINES} 行 — このイテレーションを破棄"
    git checkout -- SKILL.md
    echo "変更行数 ${added_lines} 行が制限 ${MAX_ADDED_LINES} 行を超過。破棄。" > "$ITER_DIR/rationale.md"
    append_archive "$current_iter" "$parent_genid" "" "false"
    git add "$ITER_DIR" || true
    git commit -m "iter-${current_iter}: H1 制約違反 (${added_lines} 行) — 破棄" || true
    git push || true
    continue
  fi

  # === 4. 監査 ===
  log "Pi: 監査中..."
  audit_passed=false

  for retry in $(seq 1 "$MAX_AUDIT_RETRY"); do
    log "監査 試行 $retry/$MAX_AUDIT_RETRY"
    git diff -- SKILL.md > "$ITER_DIR/diff.patch"

    AUDIT_PATH="benchmark/swebench/runs/iter-${current_iter}/audit.md"
    cat > "$PROMPT_DIR/audit.txt" << PROMPT
あなたは SKILL.md の変更に対する監査役です。

【参照してよいファイルの完全なリスト】
- Objective.md (Audit Rubric セクション)
- README.md
- docs/design.md
- docs/reference/agentic-code-reasoning.pdf
- failed-approaches.md
- SKILL.md (変更前後の確認用)

この 6 ファイル以外を read / search / list してはいけません。

【出力先】
${AUDIT_PATH}

【タスク】
プロンプトに添付された diff と rationale を Audit Rubric の 7 項目 (R1〜R7) で採点し、
Objective.md の audit.md フォーマットに従って結果を出力してください。

合格基準: 全項目 2 以上、かつ合計 14/21 以上

【出力フォーマット】
audit.md の冒頭で、必ず以下のいずれかの形式で判定を明示してください:
- 合格時: \`## 判定: PASS\` または \`## 監査結果: PASS\`
- 不合格時: \`## 判定: FAIL\` または \`## 監査結果: FAIL\`

【追加チェック (R1, R7 の補強)】
diff や rationale に具体的な数値 ID, リポジトリ名, テスト名, コード断片が
含まれていないか確認してください。含まれていれば R1 と R7 を 1 点 (FAIL) にしてください。

diff:
$(cat "$ITER_DIR/diff.patch")

rationale:
$(cat "$ITER_DIR/rationale.md" 2>/dev/null || echo '(未作成)')
PROMPT

    run_pi "$PROMPT_DIR/audit.txt" "$ITER_DIR/pi-audit-${retry}.log"

    # 判定の解釈を緩和: "判定: PASS" / "監査結果: PASS" / "PASS" のいずれかを許可
    if grep -qE "(判定|監査結果)[：:]\s*PASS" "$ITER_DIR/audit.md" 2>/dev/null; then
      audit_passed=true
      log "監査 PASS"
      break
    else
      log "監査 FAIL (試行 $retry)"
      if [ "$retry" -lt "$MAX_AUDIT_RETRY" ]; then
        log "Copilot: 監査指摘を反映して再改善..."
        cat > "$PROMPT_DIR/revise.txt" << PROMPT
監査役が改善案を不合格と判断しました。指摘内容を読み、SKILL.md と rationale.md を修正してください。

【参照してよいファイルの完全なリスト】
- ${AUDIT_PATH} (監査結果)
- ${PROPOSAL_PATH}
- ${RATIONALE_PATH}
- SKILL.md
- failed-approaches.md
- Objective.md

この 6 ファイル以外を read / search / list してはいけません。

【制約】
- 変更規模は ${MAX_ADDED_LINES} 行以内を維持
- 具体的な数値 ID, リポジトリ名, テスト名は書かない

監査結果:
$(cat "$ITER_DIR/audit.md" 2>/dev/null)
PROMPT
        run_copilot "$PROMPT_DIR/revise.txt" "$ITER_DIR/copilot-revise-${retry}.log"
      fi
    fi
  done

  if [ "$audit_passed" = false ]; then
    log "監査 ${MAX_AUDIT_RETRY}回 FAIL — 破棄"
    git checkout -- SKILL.md
    echo "監査を ${MAX_AUDIT_RETRY} 回パスできず、改善を断念" > "$ITER_DIR/rationale.md"
    append_archive "$current_iter" "$parent_genid" "" "false"
    git add "$ITER_DIR" || true
    git commit -m "iter-${current_iter}: 監査 FAIL — 破棄" || true
    git push || true
    continue
  fi

  # === 5a. Staged Evaluation (Phase 2): 5ケース先行評価 ===
  log "Staged Eval (5 ケース先行)..."
  cp SKILL.md "$ITER_DIR/SKILL.md.snapshot"

  cd "$REPO_DIR"
  bash benchmark/swebench/run_benchmark.sh --variant with_skill --runs-dir "$ITER_DIR" --fast-subset 2>&1 | tee "$ITER_DIR/benchmark-staged.log" || true

  staged_score=$(compute_staged_score "$ITER_DIR")
  log "Staged Eval 結果: ${staged_score}/5 正答 (ゲート閾値: ${STAGED_GATE_THRESHOLD})"

  if [ "$staged_score" -lt "$STAGED_GATE_THRESHOLD" ]; then
    log "Staged Gate 不通過 → Full Eval スキップ、イテレーション破棄"
    git checkout -- SKILL.md 2>/dev/null || true
    echo "Staged Eval で ${staged_score}/5 のみ正答 (閾値 ${STAGED_GATE_THRESHOLD})。Full Eval 実施せず破棄。" > "$ITER_DIR/rationale-staged.md"
    append_archive "$current_iter" "$parent_genid" "" "false"
    git add "$ITER_DIR" || true
    git commit -m "iter-${current_iter}: Staged Gate 不通過 (${staged_score}/5)" 2>/dev/null || true
    git push 2>/dev/null || true
    continue
  fi

  # === 5b. Full Benchmark 実行 ===
  log "Staged Gate 通過 → Full Eval 実行中..."
  bash benchmark/swebench/run_benchmark.sh --variant with_skill --runs-dir "$ITER_DIR" 2>&1 | tee "$ITER_DIR/benchmark.log" || true
  python3 benchmark/swebench/grade.py "$ITER_DIR" benchmark/swebench/data/pairs.json 2>&1 | tee "$ITER_DIR/grade.log" || true
  cp "$ITER_DIR/grades.json" "$ITER_DIR/scores.json" 2>/dev/null || true

  # === 6. 結果評価 ===
  current_score=$(get_score_from_json "$ITER_DIR/scores.json")
  log "今回スコア: ${current_score}% (親 iter-${parent_genid}: ${prev_score}%)"

  # archive に追加
  append_archive "$current_iter" "$parent_genid" "$ITER_DIR/scores.json" "true"

  # スコア低下時は failed-approaches.md に汎用原則を追記
  if [ "$current_score" -lt "$prev_score" ]; then
    log "スコア低下 — failed-approaches.md 更新中..."
    DIFF_PATH="benchmark/swebench/runs/iter-${current_iter}/diff.patch"
    cat > "$PROMPT_DIR/update-bl.txt" << BLPROMPT
今回試した SKILL.md の変更により、集約スコアが ${prev_score}% から ${current_score}% に低下しました。

failed-approaches.md は **汎用原則集** です。新しいエントリを追加する場合、以下のルールを必ず守ってください。

【参照してよいファイルの完全なリスト】
- ${PROPOSAL_PATH}
- ${RATIONALE_PATH}
- ${DIFF_PATH}
- failed-approaches.md (追記対象)

この 4 ファイル以外を read / search / list してはいけません。

【追加してよい内容】
- 試した変更の **抽象的な性質** (例: 「Guardrail に新しい禁止事項を追加した」)
- 失敗の **汎用的なメカニズム** (例: 「ネガティブプロンプトによる過剰適応を引き起こした」)
- 既存の汎用原則との関連付け
- 新たな汎用原則として一般化できる場合のみ、新しい原則を追記

【書いてはいけない情報】
- 具体的な数値 ID, リポジトリ名, テスト名, コード断片
- iter 番号
- per-case の正解/不正解の詳細

既存の原則の単なる変種なら、既存原則に統合する形でも可。
原則 1 つあたり数行程度の簡潔な記述で十分です。
BLPROMPT
    run_pi "$PROMPT_DIR/update-bl.txt" "$ITER_DIR/pi-bl-update.log" || log "BL 更新失敗（続行）"
    log "BL 更新完了"
  fi

  # === 7. コミット・プッシュ ===
  log "コミット・プッシュ..."
  git add -A
  git commit -m "iter-${current_iter}: score=${current_score}% (parent=iter-${parent_genid}@${prev_score}%)" || true
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
