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
# EQUIV 側の持続的失敗 (15368, 15382, 13821) を重点的に探索するため
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

  ANALYSIS_CONTEXT="今回の親イテレーションは iter-${parent_genid} (スコア ${prev_score}%, フォーカスドメイン: ${focus_domain}) です。benchmark/swebench/runs/iter-${parent_genid}/scores.json と benchmark/swebench/runs/iter-${parent_genid}/rationale.md (存在する場合) を分析し、この親からどう改善するかを検討してください。"

  # === 1. 改善案提案 ===
  log "Copilot ($COPILOT_MODEL): 分析・改善案作成中..."

  if [ "$ESCAPE_MODE" -eq 1 ]; then
    # エスケープモード: 構造改革を許可する proposal prompt
    cat > "$PROMPT_DIR/propose.txt" << PROMPT
あなたは SKILL.md の改善担当です。まだ SKILL.md を編集しないでください。まず改善案を提案してください。

【重要: 今回は構造改革エスケープモード】
Phase 1 の通常イテレーションは 5 行 hard limit の下で行われ、文言精緻化レベルの
改善に限定されていた。しかし iter-47〜60 を通じて 85% の壁を越えられなかったため、
今回は構造改革を 1 回だけ試行する特別なイテレーションです。

現在の SKILL.md は親イテレーション iter-${parent_genid} (スコア ${prev_score}%) から
復元されています。この親は best (最高スコア) から選ばれています。

1. Objective.md を読み、ゴール・制約を理解する
2. README.md と docs/design.md と docs/reference/agentic-code-reasoning.pdf を参照し、
   研究のコア構造を把握する
3. ${ANALYSIS_CONTEXT}
4. 改善案を benchmark/swebench/runs/iter-${current_iter}/proposal.md に書く

【制約の緩和】
- 追加行数の 5 行制限を解除 (構造改革を許可)
- failed-approaches.md の BL 参照は任意 (照合を義務としない)
- 新規ステップ・新規セクション・新規テンプレート要素の追加を許可

【維持される制約】
- 特定のベンチマークケースを狙い撃ちする変更は禁止
- 研究のコア構造（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）を維持
- 汎用的なコード推論フレームワークの改良であること (ドメイン・言語非依存)
- Objective.md の Audit Rubric R1 (汎化性) と R7 (ケース非依存性) に準拠

【構造改革のヒント】
- 持続的失敗ケース: 15368, 15382, 13821 (すべて EQUIVALENT、コード差異を発見すると
  NOT_EQUIVALENT に飛びつくパターン)
- これまでの文言精緻化アプローチでは解決できなかった
- SKILL.md の推論プロセスそのものを再設計する余地がある
PROMPT
  else
    # 通常モード
    cat > "$PROMPT_DIR/propose.txt" << PROMPT
あなたは SKILL.md の改善担当です。まだ SKILL.md を編集しないでください。まず改善案を提案してください。

現在の SKILL.md は親イテレーション iter-${parent_genid} (スコア ${prev_score}%) から復元されています。
今回のフォーカスドメインは ${focus_domain} です:
- overall: 全体スコアの改善
- equiv: EQUIVALENT 判定の正答率改善 (持続的失敗ケース 15368, 15382, 13821 が EQUIV)
- not_eq: NOT_EQUIVALENT 判定の正答率改善

1. Objective.md を読み、ゴール・制約・Exploration Framework を理解する
2. failed-approaches.md を読み、過去に失敗した改善方向と共通原則を確認する
3. ${ANALYSIS_CONTEXT}
4. README.md と docs/design.md と docs/reference/agentic-code-reasoning.pdf を参照し、研究のコア構造と未活用のアイデアを確認する
5. Exploration Framework の6カテゴリ（A〜F）から、この親イテレーションでは試されていないカテゴリのアプローチを選択する
6. 改善案を benchmark/swebench/runs/iter-${current_iter}/proposal.md に書く。以下を含むこと:
   - 親イテレーション (iter-${parent_genid}, フォーカス: ${focus_domain}) の選定理由への言及
   - 選択した Exploration Framework のカテゴリ（A〜F）とその理由
   - 改善仮説（1つだけ）
   - SKILL.md のどこをどう変えるか（具体的な変更内容）
   - EQUIV と NOT_EQ の両方の正答率にどう影響するかの予測
   - failed-approaches.md のブラックリストおよび共通原則との照合結果
   - 変更規模の宣言

【変更規模の制約（重要）】
- 追加行数は ${MAX_ADDED_LINES} 行以内（hard limit、超過時は自動リジェクト）
- 既存行への文言追加・精緻化のみ可
- 新規ステップ・新規フィールド・新規セクション・新規テンプレート要素の追加は原則不可
- 削除行はこの制限に含めない

注意:
- 特定のベンチマークケースを狙い撃ちする変更は禁止
- 研究のコア構造（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）を維持すること
- 失敗ケースの修正に固執しない。SKILL.md の推論フレームワークとしての質の向上を目指すこと
- failed-approaches.md の共通原則に抵触する変更は提案しないこと
PROMPT
  fi

  run_copilot "$PROMPT_DIR/propose.txt" "$ITER_DIR/copilot-propose.log"
  log "Copilot: 改善案提案完了"

  # === 2. ディスカッション ===
  log "Pi: ディスカッション..."
  cat > "$PROMPT_DIR/discuss.txt" << PROMPT
あなたは SKILL.md の改善に対する監査役です。実装者から改善案が提案されました。

以下を参照して改善案を評価してください:
- benchmark/swebench/runs/iter-${current_iter}/proposal.md（実装者の改善案）
- failed-approaches.md（過去の失敗履歴）
- Objective.md（ゴール・制約・ルーブリック）
- README.md、docs/design.md

以下の観点で意見を述べ、benchmark/swebench/runs/iter-${current_iter}/discussion.md に書いてください:
1. この改善案に関連する既存研究やコード推論の知見を mcp ツール（DuckDuckGo MCP サーバー）を使って Web 検索し、改善案の妥当性を学術的・実務的観点から評価せよ（検索結果のURLと要点を記載すること）
2. Exploration Framework のカテゴリ選択は適切か？親 iter-${parent_genid} から見て未試行のアプローチか？
3. この変更は EQUIV と NOT_EQ の両方の正答率に対してどう影響するか？変更の実効的差分（変更前との差分）を分析し、その差分が一方向にしか作用しないか確認せよ。
4. failed-approaches.md のブラックリストおよび共通原則との照合:
   - 表現や用語が違っていても、実質的な効果が同じではないか？
   - 共通原則（判定の非対称操作、出力側の制約、探索量の削減、同方向の変形、入力テンプレートの過剰規定、対称化の実効差分）のいずれかに抵触しないか？
5. 全体の推論品質がどう向上すると期待できるか？
6. 承認するか、修正を求めるか

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
  cat > "$PROMPT_DIR/implement.txt" << PROMPT
benchmark/swebench/runs/iter-${current_iter}/proposal.md の改善案に従い、以下を実行してください:

1. SKILL.md を編集する（proposal.md に記載した変更のみ）
2. benchmark/swebench/runs/iter-${current_iter}/rationale.md を Objective.md のフォーマットに従い作成する

【重要】変更規模は ${MAX_ADDED_LINES} 行以内（hard limit）。既存行への文言追加・精緻化のみ。
proposal.md に書いた内容以外の変更は行わないでください。
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

【重要: 出力フォーマット】
audit.md の冒頭で、必ず以下のいずれかの形式で判定を明示してください:
- 合格時: \`## 判定: PASS\` または \`## 監査結果: PASS\`
- 不合格時: \`## 判定: FAIL\` または \`## 監査結果: FAIL\`
スクリプトはこのパターンで判定を検出するため、形式を変えないでください。

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
audit.md の指摘を読み、SKILL.md を修正してください。
監査結果: $(cat "$ITER_DIR/audit.md" 2>/dev/null)
rationale.md も更新してください。

【重要】変更規模は ${MAX_ADDED_LINES} 行以内を維持すること。
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

  # スコア低下時は BL 更新（SKILL.md は次イテレーションで親選択により上書きされるので git checkout しない）
  if [ "$current_score" -lt "$prev_score" ]; then
    log "スコア低下 — ブラックリスト更新中..."
    cat > "$PROMPT_DIR/update-bl.txt" << BLPROMPT
今回のイテレーション(iter-${current_iter})で親 iter-${parent_genid} (${prev_score}%) から SKILL.md を改善したが、スコアが ${current_score}% に低下した。

以下のファイルを参照し、failed-approaches.md に新しいエントリを追記してください:
- benchmark/swebench/runs/iter-${current_iter}/proposal.md（改善案）
- benchmark/swebench/runs/iter-${current_iter}/rationale.md（変更理由）
- benchmark/swebench/runs/iter-${current_iter}/diff.patch（実際の変更差分）

追記フォーマット（既存エントリに倣うこと）:
### BL-{次の番号}: {変更の要約}
- 試行: iter-${current_iter} (親: iter-${parent_genid})
- 内容: {何を変えたか}
- 結果: スコア ${prev_score}% → ${current_score}%
- 原因: {なぜスコアが下がったか}
- Fail Core: {この失敗の本質は何か}

また、共通の失敗パターンに新たな原則を追加すべきか検討し、必要なら追記せよ。
BLPROMPT
    run_pi "$PROMPT_DIR/update-bl.txt" "$ITER_DIR/pi-bl-update.log" || log "BL更新失敗（続行）"
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
