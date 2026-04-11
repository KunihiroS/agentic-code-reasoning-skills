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
MAX_ADDED_LINES=5        # H1: 5行 hard limit (Phase 1)
STAGED_GATE_THRESHOLD=3  # Phase 2: Staged Eval で 5ケース中 3 以上正答なら Full 実行
ESCAPE_MODE=0            # Phase 2: 構造改革エスケープハッチ
STEEPNESS=20             # 8.1.A: score_prop sigmoid steepness (高いほど高スコア親優先)

PI_PROVIDER="github-copilot"
PI_MODEL="gemini-3.1-pro-preview"

# 8.8: 監査役を Hermes Agent に置換 (旧 Pi)
HERMES_PROVIDER="openai-codex"
HERMES_MODEL="gpt-5.4"

# 8.8.2 (2026-04-09): 提案者/実装者も Hermes に統一。Copilot CLI の /critique が
# 機能ゼロ (実測 70k〜120k tokens/call、品質改善ゼロ) かつプロセス制御が弱いため撤廃。
# propose/implement は Hermes 経由 copilot provider + claude-sonnet-4.6 を使う
# (認証は gh auth token 経由で自動解決)。
HERMES_PROPOSER_PROVIDER="copilot"
HERMES_PROPOSER_MODEL="claude-sonnet-4.6"

# オプション解析
PARSED_OPTS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -n) MAX_ITER="$2"; shift 2 ;;
    -s) START_ITER="$2"; shift 2 ;;
    --escape) ESCAPE_MODE=1; shift ;;
    --steepness) STEEPNESS="$2"; shift 2 ;;
    *) echo "Usage: $0 [-n max_iterations] [-s start_iter] [--escape] [--steepness N]"; exit 1 ;;
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
# メインループ
# =============================================================================

echo "=== auto-improve.sh (Phase 2) ==="
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
  cat_idx=$(( current_iter % 6 ))
  case "$cat_idx" in
    0) FORCED_CAT="A"; FORCED_CAT_DESC="推論の順序・構造を変える (ステップの順序、並列/直列、逆方向推論)" ;;
    1) FORCED_CAT="B"; FORCED_CAT_DESC="情報の取得方法を改善する (読み方の具体化、探索の優先順位)" ;;
    2) FORCED_CAT="C"; FORCED_CAT_DESC="比較の枠組みを変える (比較粒度、差異重要度、変更分類)" ;;
    3) FORCED_CAT="D"; FORCED_CAT_DESC="メタ認知・自己チェックを強化する (思い込み検査、弱い環特定、確信度)" ;;
    4) FORCED_CAT="E"; FORCED_CAT_DESC="表現・フォーマットを改善する (曖昧文言の具体化、簡潔化、例示)" ;;
    5) FORCED_CAT="F"; FORCED_CAT_DESC="原論文の未活用アイデアを導入する (localize/explain 手法の compare 応用、エラー分析知見)" ;;
  esac
  log "Hermes ($HERMES_PROPOSER_MODEL): 分析・改善案作成中... [強制カテゴリ: $FORCED_CAT]"

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
- 提案には **ベンチマーク対象リポジトリの固有識別子** (リポジトリ名、ファイルパス、
  関数名、クラス名、テスト名、テスト ID、実装コードの引用) を一切含めないこと。
  ただし以下は許可される: SKILL.md 自身の文言引用、一般概念名 (Guardrail #4 等)、
  抽象的な説明文、SKILL.md の自己引用を含む \`\`\` ブロック。
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
- 提案には **ベンチマーク対象リポジトリの固有識別子** (リポジトリ名、ファイルパス、
  関数名、クラス名、テスト名、テスト ID、実装コードの引用) を一切含めないこと。
  ただし以下は許可される: SKILL.md 自身の文言引用、一般概念名 (Guardrail #4 等)、
  抽象的な説明文、SKILL.md の自己引用を含む \`\`\` ブロック。
- failed-approaches.md の汎用原則のいずれかに抵触する変更は提案しない。
- 研究のコア構造（番号付き前提、仮説駆動探索、手続き間トレース、必須反証）を維持する。
- 改善仮説は 1 つだけ。
- 変更規模は ${MAX_ADDED_LINES} 行以内 (hard limit、超過時は自動リジェクト)。
  既存行への文言追加・精緻化のみ可。新規ステップ・新規フィールド・新規セクション
  の追加は原則不可。削除行はこの制限に含めない。

【強制カテゴリ (今回の提案はこのカテゴリに従うこと)】
${FORCED_CAT}. ${FORCED_CAT_DESC}

- このイテレーションではカテゴリ ${FORCED_CAT} のみを使用すること
- 他のカテゴリに該当する変更は提案しないこと
- カテゴリの定義は Objective.md の Exploration Framework セクションを参照
- 強制ローテーションは iter-87〜106 の偏り (B/E に集中、D/F が 0 回) を
  是正するための措置

【proposal.md に含めるべき内容】
- Exploration Framework のカテゴリ: ${FORCED_CAT} (強制指定) と、このカテゴリ内での
  具体的なメカニズム選択理由
- 改善仮説 (1 つだけ、抽象的・汎用的な記述)
- SKILL.md のどこをどう変えるか (具体的な変更内容)
- 一般的な推論品質への期待効果 (どのカテゴリ的失敗パターンが減るか)
- failed-approaches.md の汎用原則との照合結果
- 変更規模の宣言
PROMPT
  fi

  run_hermes_proposer "$PROMPT_DIR/propose.txt" "$ITER_DIR/hermes-propose.log"
  log "Copilot: 改善案提案完了"

  # === 2. ディスカッション ===
  log "Hermes: ディスカッション..."
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
  RATIONALE_PATH="benchmark/swebench/runs/iter-${current_iter}/rationale.md"
  cat > "$PROMPT_DIR/implement.txt" << PROMPT
${PROPOSAL_PATH} の改善案に従い、以下を順番に実行してください:

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
- rationale.md には **ベンチマーク対象リポジトリの固有識別子** (リポジトリ名、
  ファイルパス、関数名、クラス名、テスト名、テスト ID、実装コードの引用) を
  一切含めない。SKILL.md 自身の文言引用や一般概念名は許可される。
PROMPT

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
プロンプトに添付された diff と rationale を Audit Rubric の 6 項目 (R1〜R6) で採点し、
Objective.md の audit.md フォーマットに従って結果を出力してください。
(注: 旧 R7 は R1 に統合されました)

合格基準: 全項目 2 以上、かつ合計 12/18 以上

【出力フォーマット】
audit.md の冒頭で、必ず以下のいずれかの形式で判定を明示してください:
- 合格時: \`## 判定: PASS\` または \`## 監査結果: PASS\`
- 不合格時: \`## 判定: FAIL\` または \`## 監査結果: FAIL\`

【R1 採点の厳密な定義】
R1 (汎化性) は「ベンチマーク対象リポジトリへの過剰適合」を測る項目です。
以下の区別を厳密に守ってください:

- 1 点 (NG): diff や rationale に **ベンチマーク対象リポジトリの固有識別子**
  (リポジトリ名、ファイルパス、関数名、クラス名、テスト名、テスト ID、
   実装コードの引用) が含まれている場合
- 2-3 点 (OK): 以下は減点対象**外**:
  * SKILL.md 自身の文言引用 (変更前/後の対比表示)
  * 一般概念名 ("Guardrail #4", "observational equivalence",
    "test oracle", "call chain" 等)
  * 抽象的な日本語/英語の説明文
  * proposal/rationale 自体の構造を示すマークダウン記号 (\`\`\` ブロック等)
    ※ \`\`\` ブロック内が SKILL.md の自己引用や疑似コード例である場合は OK
    ※ \`\`\` ブロック内がベンチマーク対象リポジトリの実コードである場合のみ NG

diff:
$(cat "$ITER_DIR/diff.patch")

rationale:
$(cat "$ITER_DIR/rationale.md" 2>/dev/null || echo '(未作成)')
PROMPT

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
    DIFF_PATH="benchmark/swebench/runs/iter-${current_iter}/diff.patch"
    cat > "$PROMPT_DIR/update-bl.txt" << BLPROMPT
今回試した SKILL.md の変更により、スコアが低下しました (Compare: ${prev_compare}%→${compare_score}%, Audit: ${prev_audit}%→${audit_score}%)。

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
    run_hermes "$PROMPT_DIR/update-bl.txt" "$ITER_DIR/hermes-bl-update.log" || log "BL 更新失敗（続行）"
    log "BL 更新完了"
  fi

  # === 7. コミット・プッシュ ===
  log "コミット・プッシュ..."
  git add -A
  git commit -m "iter-${current_iter}: compare=${compare_score}% audit=${audit_score}% (parent=iter-${parent_genid})" || true
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
