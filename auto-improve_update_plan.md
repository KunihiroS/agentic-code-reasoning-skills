# agentic-code-reasoning-skills / auto-improve.sh 改造計画

**作成日:** 2026-04-06
**対象リポジトリ:** https://github.com/KunihiroS/agentic-code-reasoning-skills
**対象ブランチ:** `script/auto-improve`
**対象スクリプト:** `auto-improve.sh`

---

## 1. 背景

### 現在の構成

| 役割 | ツール | モデル |
|---|---|---|
| 実装者 | Copilot CLI | `claude-sonnet-4.6` |
| 監査役 | Pi (pi-coding-agent) | `github-copilot/gemini-3.1-pro-preview` |
| ベンチマーク | SWE-bench Verified / django / 20ペア | Haiku |
| 検索 | DuckDuckGo MCP (Pi) | — |

### 現状の問題: 85% の壁を越えられない

iter-5（初期ベースライン）から iter-45 までで **最高スコア 85% (17/20)** から改善できない。

**主な失敗ケース:**
| ケース | 性質 | 失敗傾向 |
|---|---|---|
| `django__django-15368` | EQUIVALENT | **全回で失敗（構造的）** |
| `django__django-15382` | EQUIVALENT | 確率的に失敗 |
| `django__django-14787` | NOT_EQUIVALENT | 確率的に失敗 |
| `django__django-13821` | EQUIVALENT | 確率的に失敗 |
| `django__django-11433` | NOT_EQUIVALENT | 確率的に失敗 |

### なぜ詰まっているか

1. **貪欲探索:** 常に直前イテレーションを親にしている。スコア低下時は直前に戻し、直近3回平均が75%以下ならmainにフルロールバック。「直前の良い状態」しか親候補にならない。
2. **アーカイブがない:** iter-5, 21, 31, 35, 41 など過去の 85% 版から「別方向に分岐」する手段がない。
3. **監査プロンプトが固定:** 監査役の思考パターン自体が進化せず、BL（ブラックリスト）が増えるほど新提案の空間が狭まる。
4. **単一スコア集約:** EQUIV 10 + NOT_EQ 10 を1つのスコアに集約しており、どちらに強い親かを区別できない。
5. **全ケース評価:** 改善案が明らかに筋悪でも毎回 20 ケース × 1〜4分 = 30〜60分を消費する。

---

## 2. 参考: HyperAgents (Meta AI Research, 2026)

**論文:** arXiv:2603.19461
**リポジトリ:** https://github.com/facebookresearch/Hyperagents

### HyperAgents の要点

- **自己参照的自己改善エージェント。** Task Agent（タスクを解く）と Meta Agent（自分自身とTask Agentを編集する）を同一の編集可能プログラムに統合。
- メタレベルの改善手順自体が編集可能 → 再帰的改善が可能。
- **DGM-H** (DGM-Hyperagents) はベースラインを上回り、メタレベル改善（永続メモリ、性能トラッキング等）がドメイン間で転移し実行間で蓄積することを示した。

### 主要機構（全リスト、採用判断付き）

| 機構 | 役割 | 本計画での扱い |
|---|---|---|
| `score_prop` 親選択 | 過去全世代からシグモイド分布で確率的に親を選ぶ | **採用（Phase 1）** |
| `score_child_prop` | `score * (1 / num_successful_children)` で重み付け。多く選ばれた親の重みを下げ多様性を保つ | **検討中**（§8.1 の選択肢の一つ） |
| `archive.jsonl` | 全世代のメタデータ・スコア・系統を記録 | **採用（Phase 1）** |
| Staged Evaluation | 小データセットで足切り → 閾値超えたらfull評価 | **採用（Phase 2）** |
| ドメイン分割スコア | 複数ドメインで並列評価し別々の親を選ぶ | **採用（Phase 2）** |
| Compilation check | コード変更後に syntax/型チェック → 失敗世代は即除外 | **検討中**（§8.9 で記録） |
| Persistent memory | meta agents が autonomous に永続 insight storage を進化させる（タイムスタンプ付き JSON、causal hypothesis tracking） | **検討中**（failed-approaches.md がこれに近いが受動的） |
| Cross-domain transfer | メタレベルの改善がドメイン間で転移し実行間で蓄積 | **部分採用**（ドメイン分割スコアで近似） |
| 自己編集可能な Meta Agent | 監査プロンプト自体を進化対象に | **採用（Phase 3）** |
| Docker 隔離 | 各世代をコンテナで実行 | **採用せず**（git checkout で代替、ただし process leak 等の事故あり） |
| Ensemble 評価 | アーカイブ全体を集約予測 | **採用せず** |
| Best/Latest/Random 親選択 | greedy / 最近 / 一様ランダム | **未採用**（score_prop に統一、ただし escape mode で best を使用） |

### score_prop の公式と steepness 調整

HyperAgents の標準実装:

```
mid_point = mean(top 3 scores)
weight_i  = sigmoid(steepness * (score_i - mid_point))
prob_i    = weight_i / sum(weights)
parent    = random.choices(candidates, weights=probs)
```

論文のデフォルトは **steepness=10**、対象スコアは 0-1 範囲。
本プロジェクトのスコアは 0-100 のパーセント、変動幅は 65〜90 と狭い。
そのまま steepness=10 を使うと、85% と 75% で重みがほとんど差がつかない (sigmoid(-1)≈0.27, sigmoid(0)≈0.5)。

そこで **steepness=20** を採用 (実効的に HyperAgents の 2 倍の傾き)。
実測分布 (iter-1〜46 を archive に含めた状態):
- 90% 個別 ~12%
- 85% 個別 ~9.92% (合計 ~40%)
- 80% 個別 ~5.33% (合計 ~21%)
- 75% 個別 ~2.36% (合計 ~26%)
- 70% 以下 < 13%

→ 高スコア親が支配的だが多様性も残る (狙い通り)。
ただし「もっと最高スコアを優先したい」場合のために §8.1 で steepness 調整可能化を検討。

### Persistent memory との関係

HyperAgents の論文では、meta agents が **自律的に** 永続メモリを進化させたと記述されている。
本プロジェクトの `failed-approaches.md` は近い役割を果たすが:
- 自律進化ではなく Pi が固定プロンプトで追記する
- 構造が固定 (ブラックリスト + 共通原則)
- 23 個の汎用原則 (サニタイズ後) が蓄積されている

将来的に Phase 3 で Meta Agent 自身が `failed-approaches.md` の構造を進化できるようにする余地あり。

---

## 3. 改造方針

### 3.1 score_prop 親選択（最優先）

**アルゴリズム:**

```
mid_point = mean(top 3 scores)
weight_i = sigmoid(10 * (score_i - mid_point))
probability_i = weight_i / sum(weights)
parent = random.choices(candidates, weights=probabilities)
```

**期待される効果:**

- iter-21, 31, 35, 41（全て 85%）が高確率で親候補となる
- iter-9(80%), iter-34(75%) なども低確率で選ばれる
- 現在は「iter-41 の直系しか見ない」状態 → 「iter-21, 31, 35 からの分岐」も可能になる
- 15368 を解く別方針を探索できる可能性

### 3.2 archive.jsonl

**フォーマット:**

```json
{"genid": 5, "parent_genid": null, "skill_snapshot": "iter-5/SKILL.md.snapshot", "scores": {"overall": 85, "equiv": 80, "not_eq": 90, "unknown": 0}, "valid_parent": true, "timestamp": "2026-04-XX..."}
{"genid": 6, "parent_genid": 5, "patch_file": "iter-6/diff.patch", "skill_snapshot": "iter-6/SKILL.md.snapshot", "scores": {"overall": 75, ...}, "valid_parent": true}
...
```

**保管場所:** `benchmark/swebench/runs/archive.jsonl`

**構築方法:** 既存の `iter-{N}/scores.json` と `iter-{N}/SKILL.md.snapshot` から初期構築する migration スクリプトを作る。

### 3.3 Staged Evaluation

**Phase 1（Fast subset）:** 5ケース（EQUIV 3 + NOT_EQ 2 を選定、失敗頻度の低い安定ケース）
**Phase 2（Full）:** 残り 15 ケース

**ゲート条件:** Phase 1 のスコア閾値 ≥ 3/5 (60%) → Phase 2 実行。未満なら破棄して次の親を選ぶ。

**期待効果:** 筋悪な改善案を早期に弾くことで、1 イテレーションあたり最大 75% のベンチマーク時間削減。

### 3.4 ドメイン分割スコア

既存の `grades.json` は以下を既に出力している:

```
Overall:  17/20 = 85.0%
EQUIV:    7/10 = 70.0%
NOT_EQ:  10/10 = 100.0%
UNKNOWN:  0
```

これを `archive.jsonl` の `scores` フィールドに EQUIV / NOT_EQ 別々に記録。`select_parent.sh` はドメインごとに別の親を選べるオプションを持つ（例: EQUIV 改善フェーズでは EQUIV スコアで親選択）。

### 3.5 監査プロンプトの外部ファイル化（Phase 3）

現状 `auto-improve.sh` に埋め込まれている以下のプロンプトを外部ファイルに分離:

- `prompts/propose.tmpl`
- `prompts/discuss.tmpl`
- `prompts/implement.tmpl`
- `prompts/audit.tmpl`
- `prompts/update-bl.tmpl`

テンプレート変数（`${current_iter}`, `${prev_score}`, `${ANALYSIS_CONTEXT}` 等）は `envsubst` または sed で展開。

Phase 3 ではメタエージェントがこれらのテンプレート自体を編集できるようにする。

---

## 4. 実行結果レビューからの追加ヒント (iter-29〜46)

HyperAgents 由来の構造的改造とは別に、18 イテレーションの実データから導かれる改造ヒントを検討した。以下はその検討結果である。

### 4.1 採用候補（レビュー由来）

#### H1. 変更規模を「5行 hard limit」に **[Phase 1 採用]**

**根拠データ:**
- 85% 到達の iter-31, 35, 41 はすべて **2〜5行の文言精緻化のみ**
- 構造追加・フィールド追加・新規ステップ挿入はすべて失敗（BL-11〜21 の大半）
- 現状の prompt は「20行以内を目安」という緩い指示のみ

**改造内容:**
- `propose.tmpl` に「**5行以内 (hard limit)**。既存行への文言追加・精緻化のみ。新規ステップ・新規フィールド・新規セクションは原則不可」を明示
- 実装フェーズで変更行数を `git diff --stat` でチェックし、5行超ならリジェクト & 再提案

**実装コスト:** 低（プロンプト変更 + 数行のバリデーションのみ）

**リスク:** 構造的な大改修が必要な場合に手詰まりになる可能性。ただし過去18回の実績から構造改修は全て失敗しているので、リスクは低い。

---

#### H2. Re-propose ループの廃止または1回制限 **[Phase 2 候補]**

**根拠データ:**
- 却下率 83%（18回中15回で承認NO）
- **iter-31（一発承認）が 85% 達成**
- iter-38（一発承認）も 75% 維持
- 再提案後に承認されたケースは大半が 65〜75% に終わる
- ディスカッションが「改善の場」ではなく「コーナーに追い詰める場」化している可能性

**改造内容:**
- `承認: NO` 時の再提案ループを削除するか、1回のみに制限
- NO なら skip して次の親（score_prop で再選択）に進む

**実装コスト:** 低

---

#### H3. BL ワーキングセット化 **[Phase 2 候補]**

**根拠データ:**
- 21個のBL + 14個の共通原則 = **35個の制約**
- 後半（iter-42〜46）の連続失敗は、全制約を避ける提案が不可能に近づいた結果
- 新規 BL の多くが「構造追加・フィールド追加・条件分岐ゲート」系で原則 #5, #8 の変種

**改造内容:**
- 直近 N 回（例: 10回）で実際に却下根拠として参照された BL のみを active に
- 残りは `failed-approaches-archive.md` に隔離
- もしくはカテゴリタグ付けし、現在の提案カテゴリに関連する BL のみ表示

**実装コスト:** 中

---

#### H4. `--focus equivalent` モード **[Phase 2 候補]**

**根拠データ:**
- 失敗の構造的源泉は **`15368`, `15382`, `13821` の EQUIVALENT 3ケース**（94%, 94%, 88% 失敗率）
- NOT_EQUIVALENT はほぼ解けている

**改造内容:**
- フラグで EQUIVALENT 側の改善に探索を集中
- prompt に「現在の持続的失敗は EQUIVALENT ケース。NOT_EQ 側を弱めずに EQUIVALENT を強化せよ」を明示

**実装コスト:** 低

**補足:** HyperAgents のドメイン分割スコアと併用で、EQUIV スコアの高い親を EQUIV フェーズで選択する等の拡張が可能。

---

#### H5. カテゴリ成功率を prompt に反映 **[Phase 3 候補]**

**根拠データ:**
| カテゴリ | 使用回数 | 85%到達 |
|---|---|---|
| F (論文の未活用) | 6 | **0** |
| B (情報取得) | 5 | 1 |
| C (比較枠組み) | 3 | 1 |
| E (表現・フォーマット) | 2 | 1 |
| A (推論順序) | 2 | 0 |
| D (メタ認知) | 0 | — |

**改造内容:**
- カテゴリ別の過去成功率を propose prompt に埋め込み、B/C/E を優先
- F は優先度低に降格
- D（メタ認知）は BL-9 以降完全回避されているが、これは「自己チェック自体の問題」であって D 全体ではない可能性がある。未試行サブメカニズムを明示して再開検討

**実装コスト:** 低

---

### 4.2 棄却した候補（オーバーフィット懸念）

#### R1. 成功例（iter-31/35/41 の diff）を propose prompt に埋め込む **[棄却]**

**当初の着想:** 18回中3回 85% に到達した diff は、すべて「`because [trace]` 指示の文言精緻化」という類似パターン。これをポジティブ例として見せれば、実装者が成功パターンを踏襲しやすくなる。

**棄却理由:**

1. **iter-31/35/41 はベースライン (iter-5: 85%) を超えていない。** 本質的な「成功」ではなく「他より壊さなかった変更」に過ぎない。これを good pattern として提示すると **「現状維持バイアス」を強化するだけ**になり、真の天井突破には寄与しない。

2. **この 20 ケース特有のパターンに依存している。** `trace to assertion/exception` の文言精緻化が効いたのは、django ベンチマークの失敗分布（EQUIVALENT 偽陽性が多い）に依存する可能性が高い。他ドメインでは効果がない or 逆効果の可能性。

3. **Objective.md の制約（特定ベンチマークへの overfitting 禁止）に反する。** 成功例の埋め込みは実装者を過去の微修正パターンに縛り、SKILL.md の汎用的改善という本来の目的と逆行する。

4. **真の天井突破には構造的変化が必要。** `15368` のような持続的失敗を解くには、むしろ過去試されていない方向の探索が必要。成功例の埋め込みはそれを妨げる。

**結論:** この項目は採用せず。HyperAgents の archive + score_prop によって「過去の高スコア版からの分岐探索」を実現する方向で代替する。

---

### 4.3 レビュー由来の追加発見（実装には直結しないが重要）

- **スコアの確率的変動:** 同じ SKILL.md でも 65〜85% の幅がある（ベンチマーク評価に確率的揺らぎがある）。単一ロールバック判定は過剰反応のリスクがある。
- **UNKNOWN 率の上昇 = 提案が複雑化している兆候:** iter-42 の UNK=5 は複雑な提案が推論ターンを食い潰した症状。H1（5行制限）で副次的に抑制されるはず。
- **Pi (gemini-3.1-pro) の監査は厳格:** 却下率 83% で BL 類似性を厳密にチェック。H2（ループ廃止）と組み合わせると、監査の厳格性を保ちつつ無駄な再提案ループを避けられる。

---

## 5. 実装フェーズ

### Phase 1: MVP（最優先）

**目的:** score_prop 親選択を導入し、85% の壁を打ち破れるか検証する。あわせて H1（5行 hard limit）を先行導入する。

**作業項目:**

1. `benchmark/swebench/archive_migrate.py` を作成
   - 既存の `iter-{5..46}/scores.json` + `iter-{N}/SKILL.md.snapshot` + `iter-{N}/diff.patch` から `archive.jsonl` を構築
2. `benchmark/swebench/select_parent.py` を作成
   - `archive.jsonl` を読み、`score_prop` アルゴリズムで親の genid を出力
   - CLI: `python select_parent.py --archive archive.jsonl --method score_prop`
3. `auto-improve.sh` メインループ改造
   - 直前イテレーションを親にする代わりに `select_parent.py` で親を選ぶ
   - 親の `SKILL.md.snapshot` を現在の `SKILL.md` に復元してから改善開始
   - スコア計算・ロールバック判定を archive.jsonl 参照に変更
   - 改善案の proposal.md には「今回の親 = iter-N (score S%)」を明示
4. **[H1] propose プロンプトの変更規模制約を「5行 hard limit」に変更**
   - 「既存行への文言追加・精緻化のみ。新規ステップ・新規フィールド・新規セクションは原則不可」を明示
   - 実装後の diff を `git diff --stat` でチェックし、追加行数が 5 を超えたらリジェクト
5. `failed-approaches.md` 参照ロジックは維持（BL は引き続き蓄積）
6. 動作確認: 2 イテレーション実行

**完了条件:**

- `archive.jsonl` が iter-5〜45 の全エントリで初期化されている
- `select_parent.py` が iter-21/31/35/41 を高確率で返す
- `auto-improve.sh` が選ばれた親を正しく復元してから改善を開始する
- 2 イテレーション完走

### Phase 2: 効率化、ドメイン分割、構造改革エスケープハッチ

**目的:**

1. 1 イテレーションあたりの計算コスト削減（Staged Eval、Re-propose 廃止）
2. EQUIV/NOT_EQ を別ドメインとして扱い、片側集中の親選択を可能にする
3. **5行 hard limit を一時解除しての構造改革を試行**し、85% の壁を直接打ち破る試みを行う

**背景:**

Phase 1 (iter-47〜60) の結果から、5行 hard limit + 32 個の BL によって提案空間が極度に縮小しており、score_prop で過去の高スコア親から分岐しても 85% を超えない。文言精緻化レベルの改善では本質的な限界に達しつつある。

実験の本来の趣旨（低能力モデル + SKILL の組み合わせで底上げ可能性を探る）は維持したまま、SKILL.md 側の構造改革を 1 回だけ試行する余地を残す必要がある。

**作業項目:**

6. **Staged Evaluation 実装**
   - `benchmark/swebench/run_benchmark.sh` に `--fast-subset` フラグ追加
   - 5 ケース (EQUIV 3 + NOT_EQ 2) で先行評価
   - 閾値 ≥ 60% 超えたら full 20 ケース、未満なら破棄
   - 1 イテレーションあたり最大 75% のベンチマーク時間削減を狙う

7. **Re-propose ループ廃止 (H2)**
   - Phase 1 結果: ディスカッション一発承認率 100%（5行制限の効果）。再提案ループは実質無駄。
   - 監査3回FAIL も発生 (iter-52, 53)。これも `承認: NO` での再提案ではなく、即座に skip → 次の親選択に切り替える。
   - `承認: NO` 時の再提案を削除、または 1 回のみに制限
   - 監査 FAIL も同様に retry を 1 回までに制限

8. **ドメイン分割スコアを `archive.jsonl` に反映**
   - 既存の `equiv_ok / equiv_total / not_eq_ok / not_eq_total` フィールドはすでに記録されている
   - `select_parent.py` に `--score-key equiv` `--score-key not_eq` を追加

9. **イテレーションごとに「フォーカスドメイン」を決めるロジック追加**
   - イテレーション番号に応じて EQUIV/NOT_EQ/overall をローテーション
   - フォーカスドメインのスコアで親選択 → そのドメインの改善に集中する提案を促す
   - 持続的失敗ケース (15368, 15382, 13821 はすべて EQUIV) の対策

10. **構造改革エスケープハッチ (1.6 案 #2)**
    - `auto-improve.sh` に `--escape` フラグ追加
    - フラグありで起動した場合、当該イテレーションでは:
      - 5 行 hard limit を解除
      - BL 参照を任意化（提案内で BL に触れる必要なし）
      - 「SKILL.md の構造を 1 回だけ大幅に書き直して構わない」プロンプト
      - 親は最新の最高スコアエントリ (best) 固定（score_prop ではなく）
    - **使用条件:**
      - 通常イテレーションを連続 N 回回しても 85% 超えがない場合のみ手動実行
      - 結果が悪化しても archive に通常通り記録（次の score_prop で自然に淘汰される）
      - 1 セッションで最大 2 回まで（過剰使用を防ぐ）
    - **実験意図への影響:** 構造改革は SKILL.md の改良であり、ベンチマークモデル (Haiku) は変更しない。低能力モデルの底上げを試す本来の実験趣旨は維持される。

11. 2〜5 イテレーション実行して効果検証

### Phase 1.5: ACPX 導入 (保留)

**ステータス:** 当面保留。インストール済み (Fedora VM) だが、コードへの統合は見送り。

#### ACPX とは

**Agent Client Protocol eXecutor**: ACP プロトコル経由で AI コーディングエージェントと構造化通信する統一 CLI。
- リポジトリ: https://github.com/openclaw/acpx
- バージョン: v0.5.0 (alpha)
- 動機: 従来の PTY スクレイピング (ANSI 出力をパース) を排除し、型付き JSON メッセージで通信する

#### 対応エージェント (10+)

`claude` / `copilot` / `codex` / `pi` / `openclaw` / `gemini` / `cursor` / `qwen` / `kimi` 等。`--agent` でカスタム ACP server も指定可能。
**現在のパイプラインで使う Copilot / Pi / Codex は全てカバー済み。**

#### 主要機能

| 機能 | 効果 |
|---|---|
| **セッション永続化** (`~/.acpx/sessions/`) | リポジトリ単位の名前付きセッション。複数 invocation 間で文脈保持 |
| **構造化出力** (NDJSON `--format json`) | `thinking`, `tool_call`, `diff` 等の型付きイベント。`grep "承認: NO"` のような脆弱なテキストパースから解放 |
| **プロンプトキュー** | `--no-wait` でセッションに enqueue → fire-and-forget |
| **権限制御** | `--approve-all` / `--approve-reads` / `--deny-all` / `--non-interactive-permissions fail` |
| **クラッシュ復帰** | dead process 検出 → `session/load` 自動再ロード → fallback to fresh session |
| **Flows Runtime** | TypeScript で多段ワークフロー定義 (`acp` / `action` / `compute` / `checkpoint` ステップ) |
| **TTL 管理** | queue owner の idle TTL (デフォルト 300 秒) で資源管理 |

#### インストール状況 (Fedora VM)

- `npm install -g acpx@latest` → `~/.npm-global/bin/acpx`
- バージョン: **v0.5.0** (2026-04-06 時点)
- 動作確認: `acpx --help` で pi/copilot/codex 等のサブコマンド認識を確認
- 実コマンドでの呼び出し検証は未実施

#### 関連: Pi MCP セットアップ (ACPX とは別物だが関連実験インフラ)

ACPX とは独立に、Pi 経由の MCP 検索能力を実装済み。Pi 監査役が Web 検索を必要とするステップで利用可能。

| 構成要素 | 内容 | 状態 |
|---|---|---|
| `pi-mcp-adapter` | npm:pi-mcp-adapter, Pi に MCP server を proxy する adapter (~200 トークンの単一 proxy ツール経由) | インストール済 |
| `uv` / `uvx` | astral.sh の Python パッケージマネージャー (`~/.local/bin/`) | インストール済 |
| `duckduckgo-mcp-server` | uvx 経由で起動する MCP server | 動作確認済 |
| `~/.pi/agent/mcp.json` | DDG MCP server を `lifecycle: lazy` で登録 | 設定済 |

検証結果: `pi -p --no-session --mode json` で MCP 経由 DuckDuckGo 検索が動作することを確認。`bash` ではなく `mcp` ツールが呼ばれている。

ただし `ddg_search_search` は bot detection で不安定。`ddg_search_fetch_content` (URL 直接取得) にフォールバックして動作している。

#### 保留理由

ACPX は基本的に **インフラ改善** (セッション永続化、構造化出力、クラッシュ復帰) であり、85% の壁を破る**直接的な**効果は期待できない。Phase 1〜2 の改造で十分に成果が出ているため、優先度は低い。

ただし以下のメリットは依然として大きい:
1. **トークン効率**: discuss/audit/update-bl で同一セッションを使えれば 30〜50% 削減見込み
2. **構造化出力**: grep ベースの判定パース脆弱性を全廃 (silent stop 撲滅)
3. **クラッシュ復帰**: API 障害等での中断時に自動復帰
4. **並列イテレーション**: プロンプトキューで複数親候補を並列展開可能

#### 再開条件

- Phase 2 を完走後も 85% を超え続けるにはイテレーション数を増やす必要があり、トークン効率が律速になった時
- もしくは Phase 3 (プロンプト外部化、メタエージェントによる自己編集) で構造化出力が必須になった時
- ACPX が beta/stable に上がりインターフェース安定後

### Phase 3: 自己参照的進化

**作業項目:**

11. プロンプトテンプレートを `prompts/` 配下に外部化
12. `auto-improve.sh` を envsubst ベースに改造
13. メタエージェント（Pi）にプロンプトテンプレート自体を編集する権限を付与
14. テンプレート変更履歴も `archive.jsonl` に記録
15. 10 イテレーション実行して自己改善効果を検証

---

## 6. 想定リスクと対策

| リスク | 対策 |
|---|---|
| Phase 1 で親の復元に失敗する（git状態の衝突） | `git stash` + 親の SKILL.md.snapshot を直接 cp する方式にする |
| `score_prop` が結局 iter-21 系に偏り多様性が出ない | `score_child_prop`（既に多く選ばれた親の重みを下げる）を後続実装 |
| Staged Evaluation の小サブセットが偏り真のスコアと乖離 | Phase 1 の 5 ケース選定を慎重に（EQUIV/NOT_EQ バランス、失敗頻度中程度のケース） |
| 構造改革エスケープハッチで SKILL.md を壊し、以降の親選択を汚染 | escape 実行前後で git tag、結果が 50% 以下なら archive エントリを `valid_parent=false` に手動マーク |
| 構造改革で「特定ベンチマークケースへの overfitting」が発生 | escape プロンプトで「特定ケースを狙わず汎用的なフレームワーク改良であること」を明示。Audit Rubric の R1 (汎化性) と R7 (ケース非依存性) は引き続き適用 |
| プロンプト外部化で既存の動作が壊れる | Phase 3 開始前に Phase 1/2 の成果をタグ付けバックアップ |
| メタエージェントがプロンプトを壊す方向に編集する | プロンプト変更にも Audit Rubric を適用、破綻時はロールバック |

---

## 7. 成功指標

| フェーズ | 指標 |
|---|---|
| Phase 1 | 3 イテレーション内で 85% 超え（= 90% 以上）を 1 回以上達成。**結果: 未達 (iter-47〜60 で最高 80%)** |
| Phase 2 | (1) 1 イテレーションあたりの平均実行時間を 30% 削減 (Staged Eval + Re-propose 廃止)。 (2) 構造改革エスケープハッチを 1 回以上試行し、結果を archive に記録。 (3) ドメイン分割親選択で、過去最低スコアからの分岐を最低 1 回試す。 |
| Phase 3 | 10 イテレーションで 85% を安定化（直近 5 回中 3 回以上で 85% 以上） |
| 最終ゴール | Objective.md の定義通り「直近 5 回中 2 回以上で 100%」 |

**実験意図への注記:**

ベンチマークモデルは Haiku (`github-copilot/claude-haiku-4.5`) から変更しない。本実験は「低能力モデルへの SKILL の効果検証」を目的とするため、より強力なモデル（Sonnet 等）に切り替えることは趣旨を毀損する。SKILL.md 側の改良のみで底上げ可能性を探る。

---

## 8. 次の改良への検討事項 (Phase 3 以降)

Phase 2 の運用データ (iter-67〜81, 12 完了) は取得済み。
平均スコア 80.8%、最高 90% (iter-76, iter-80)、85% 以上 6/12 = 50%、90% 以上 2/12 = 17%。
失敗ケースは構造的に 15368/15382 の 2 ケースに収束。

これ以上の改善には以下の項目から採用候補を選び Phase 3 (またはサブフェーズ) に組み込む。
本セクションは「**選択肢のカタログ**」であり、すべてを実施するわけではない。
優先順位は実験の進捗と必要に応じて決める。

### 8.1 親選択戦略 (score_prop) の調整可能化

現状: `select_parent.py` は `--steepness` を持つが、`auto-improve.sh` から固定値 (20) で呼んでいる。タスクの性質によっては「最高スコア親への重み付け」を強めたい場合がある (探索 vs 活用のバランス)。

候補:
- **A. steepness の CLI 化**: `auto-improve.sh --steepness N` で実行時に指定できるようにする (実装コスト極小)
- **B. ドメイン別 steepness**: EQUIV と NOT_EQ で別の steepness を持つ。一方が天井に近く、他方が遠い場合に有効。
- **C. 適応的 steepness (時間軸減衰)**: 序盤は exploration 重視 (低 steepness)、後半は exploitation 重視 (高 steepness)。シミュレーテッドアニーリング型。
- **D. ε-greedy ハイブリッド**: 1−ε の確率で best、ε の確率で score_prop。ε を徐々に下げる強化学習パターン。
- **E. top-K 制限**: 最高スコア top-K (例: top-5) のみから確率選択。effective sample size を保つ。

判断材料 (Phase 2 運用後に取得):
- 現状 steepness=20 で 90% 親が約 12% 確率で選ばれる。これが iter-76 (90%) を更に改良するイテレーションが何回出現したかで「不足」か「適正」か判断
- ドメイン別の親選択がどの程度効いているか
- 探索の偏り (特定の親への集中) の度合い

### 8.2 ホールドアウトセット導入

現状: 全 20 ケースで訓練 → 評価のリーケージあり。

候補:
- pairs.json から 5 ケースをホールドアウトに分離
- 通常イテレーションは 15 ケースで評価
- 改善案候補が出たら 5 ケースでホールドアウト検証

判断材料: Phase 2 運用後に「同一 SKILL.md の再現性」を測定し、確率変動の幅が分かってから決める。

### 8.3 異種ベンチマークでの汎化検証

候補: scikit-learn, sympy, flask 等の別リポジトリで pairs を作って測定。

判断材料: Phase 2 終了時点の SKILL.md が「真に汎用的」か「django 固有の hack」かを確かめる必要が出たとき。

### 8.4 ACPX による Phase 1.5

保留中。Phase 2 で 85% を超える結果が出れば優先度低、出なければトークン効率改善で「より多くのイテレーションを回す」量的アプローチとして再評価。

### 8.5 archive.jsonl 上の汚染データの扱い

iter-47〜65 はサニタイズ前の contaminated 環境下で生成された。
**iter-65 (汚染下の 90%) は archive から削除済み**。残りの汚染データは引き続き親候補として残すか、削除/隔離するかは運用結果を見て判断。

サニタイズ後 (iter-67〜81) のスコア分布を見ると、汚染前の親 (iter-1〜46) からの分岐でも汚染後 (iter-67〜81) からの分岐でも 85% 以上が頻発しており、 contaminated データを完全削除するメリットは限定的かもしれない。

### 8.6 ベンチマーク再現性 (確率変動) の測定

**問題:** 同一 SKILL.md でも実行ごとにスコアが変動する可能性がある。これが分かっていないと:
- 1 回の良いスコアが「真の改善」か「確率的揺らぎ」か区別できない
- score_prop の親選択が ノイズに惑わされる
- ロールバック判定の閾値設定が適当になる

**候補:**
- 同じ SKILL.md (例: iter-76 の snapshot) でベンチマークを 5〜10 回実行
- スコアの平均と標準偏差を計測
- 標準偏差 > 5pt なら、現在の「親より下回ったら破棄」ロジックを再考する必要

**実装コスト:** 低 (run_benchmark.sh をループで呼ぶだけ)

### 8.7 API 障害復帰機構

**問題:** iter-67, 71, 77, 82 等で実行中断が発生 (原因: API レートリミット / プロセスエラー / その他)。
中断したイテレーションは無駄になり、archive にも記録されない。

**候補:**
- ベンチマーク実行を retry でラップ (失敗ケースのみ再試行)
- イテレーション全体を「再開可能」にする (state file から再開)
- API 障害検出時に sleep → リトライ
- 一定時間以上応答がなければ強制終了 → 次イテレーションへ

**判断材料:** 中断率の継続観察。Phase 2 完了時点で完了率 12/16 = 75%。これが許容範囲か判断。

### 8.8 Compilation check (HyperAgents 由来)

HyperAgents は各世代の生成後にコードのコンパイル/構文チェックを行い、失敗した世代を archive に excluded として記録する。これにより明らかに壊れた世代がベンチマーク評価まで進むのを防ぐ。

本プロジェクトでは SKILL.md は Markdown なので「コンパイル」ではなく:
- **構造妥当性チェック**: SKILL.md がパース可能か (compare/localize/explain/audit-improve のセクションが揃っているか)
- **長さチェック**: 異常に短い/長い変更でないか
- **プレースホルダー残存チェック**: `[TODO]` や `XXX` 等が紛れ込んでいないか

候補: implement ステップ後、ベンチマーク前に簡易 lint を実行。失敗時はそのイテレーションを破棄。

### 8.9 失敗ケース 15368/15382 の構造的分析

サニタイズ後の実験で **15368, 15382 が 91〜100% 失敗**することが確定。これはモデル (Haiku) の能力上限を示している可能性が高い。

**問い:** これらは Haiku 単体では原理的に解けないのか、それとも SKILL.md の改良で解けるのか？

**実験案:**
- Sonnet で同じ 2 ケースを評価 → Sonnet なら解けるか確認 (実験意図と矛盾するが診断目的のみ)
- 解ければ「Haiku の能力不足」確定 → SKILL.md の文言精緻化では無理
- 解けなければ「タスク自体が境界例」 → 別アプローチが必要

注意: ベンチマークモデル変更は本実験の趣旨を毀損するため、**診断目的の単発実行のみ**として扱い、メインループには影響させない。

### 8.10 GitHub Copilot CLI の Rubber Duck (Critic Agent) 統合

#### 背景

2026-04-07 に GitHub が Copilot CLI に **Rubber Duck (Critic Agent)** 機能を追加。Claude orchestrator が GPT-5.4 に critique を依頼する組み込みサブエージェント。Copilot CLI v1.0.18+ で `--experimental` フラグ経由で利用可能。

参考: https://github.blog/ai-and-ml/github-copilot/github-copilot-cli-combines-model-families-for-a-second-opinion/

#### `-p` 非対話モードでの動作確認 (2026-04-08 検証済み)

以下のテストで `-p` モードでも Rubber Duck (`agentName: rubber-duck`, model: `gpt-5.4`) が起動することを確認:

| トリガー | 結果 | モデル | 備考 |
|---|---|---|---|
| `-p "/critique"` | rubber-duck 起動 | gpt-5.4 | 引数なしでも動作 |
| `-p "/critique <file>"` | rubber-duck 起動 (2 段) | gpt-5.4 | 対象ファイル指定可能 |
| `-p "Plan and implement ..."` | rubber-duck 自動起動 | gpt-5.4 | プラン作成検出で発動 |
| `-p "review ... get a second opinion"` | rubber-duck 起動 | gpt-5.2 | 自然言語誘導 |
| `-p "..., 実装後 /critique で批評せよ"` | 実装+critique 1 プロセス | gpt-5.4 | **実装→自己批評ループ** |
| `-p "/review"` (混同注意) | code-review エージェント起動 | claude-sonnet-4.5 | 別エージェント |

検証済みのイベント形式 (JSONL):
```
type: subagent.started
data.agentName: "rubber-duck"
data.agentDisplayName: "Rubber Duck Agent"

type: subagent.completed
data.agentName: "rubber-duck"
data.model: "gpt-5.4"
data.totalTokens: <int>
data.durationMs: <int>
```

#### 注意点

- `/review` は **別物** (Claude ベースの code-review エージェント)
- Rubber Duck の正式名称は **Critic Agent**、内部 ID は `rubber-duck`
- 公式ドキュメントには `/critique` の言及がないが実動作することを確認 (公式の slash command 一覧に未掲載)
- モデルが `gpt-5.4` / `gpt-5.2` で揺れる場合がある (理由不明)
- Rubber Duck サブエージェントは独自に view/glob/rg/bash 等のツールを持ち、対象ファイルを自分で読みに行く

#### パイプライン統合候補

##### 候補 A. 現在の Pi 監査役を `/critique` で完全置換

```bash
# 旧
copilot -p "..." → 別プロセス → pi -p "...audit prompt..."

# 新
copilot -p "...; 実装後 /critique で自分の変更を批評せよ"
```

利点:
- プロセス分離不要、ssh 経由の二重呼び出しが消える
- 文脈共有 (orchestrator が critique 結果を受けて再修正できる、Test 6 で実証)
- トークン消費の削減 (実測 ~35K/critique vs Pi の ~50K)
- 別モデルファミリー (Anthropic vs OpenAI) で independent perspective

欠点:
- 我々の Audit Rubric (R1〜R7) を強制できない (自然言語で渡すしかない)
- `failed-approaches.md` 更新等の独自処理を critique 内で行うのは難しい
- experimental 機能なのでインターフェースが変わる可能性

##### 候補 B. Pi と Rubber Duck を併用 (三角レビュー)

```
Copilot (Claude) 実装
  ├─ Rubber Duck (GPT-5.4) → first opinion (高速、品質中心)
  └─ Pi (Gemini 3.1 Pro) → second opinion (Audit Rubric R1〜R7、汎化性チェック、BL 更新)
```

利点:
- 3 モデルファミリー (Anthropic / OpenAI / Google) からの independent review
- Rubber Duck = 品質、Pi = 汎化性 + プロセス品質、で役割分担
- 既存 Pi ロジックを大きく変えずに追加できる

欠点:
- トークン消費が増える (~35K + ~50K = ~85K/iter)
- 2 つのレビューが矛盾した場合の調停ロジックが必要

##### 候補 C. propose プロンプトに `/critique` を埋め込むだけ

```bash
copilot -p "...今回のフォーカス: equiv... proposal を書いた後 /critique で自分の提案を批評せよ"
```

最も簡単。propose ステップ内で Rubber Duck が自動的に起動し、提案前に self-critique が走る形。Pi は audit ステップ専任で残る。

利点:
- 既存パイプラインへの変更が最小 (プロンプト追記のみ)
- Pi の役割を変えなくて済む
- 「propose の段階で Rubber Duck の指摘を反映した品質の高い提案」が出る

欠点:
- 効果の測定が難しい (どの改善が Rubber Duck 由来か追跡困難)

#### 判断材料 (Phase 2 運用後に取得)

- 候補 A: Pi の役割を完全置換できるほど Rubber Duck の指摘精度が高いか
- 候補 B: 三角レビューで監査通過率や品質が変わるか
- 候補 C: propose プロンプトの軽微な追加だけで提案品質が上がるか
- 共通: トークン使用量と所要時間のオーバーヘッド

#### 関連: Pi MCP (DuckDuckGo) との比較

現在 Pi は MCP 経由で Web 検索ができるが、Rubber Duck (gpt-5.4) は内部に検索能力を持たない。学術的 reference 調査が必要なステップでは Pi が依然有用。

---

## 9. 実装史 — 解決済みの事故と修正

Phase 1〜2 の実装過程で発生した非自明な事故と、その原因・修正を記録。
将来同種の問題に当たったときの参考、または別環境への移植時の注意点。

### 9.1 silent stop の連鎖 (count_added_lines pipefail bug)

**症状:** iter-60, iter-63 で、Copilot 実装フェーズ完了後にスクリプトが何のエラーも出さず終了する事象。

**根本原因:** `count_added_lines` 関数内のパイプライン:
```bash
git diff -- SKILL.md | grep -E '^[+]' | grep -v '^[+][+][+]' | wc -l
```
純粋削除 only の diff (追加 0 行) では、第 1 grep が `+++ b/SKILL.md` ヘッダー行のみマッチ → 第 2 grep がそれを除外 → no match → exit 1。
`set -euo pipefail` により、no-match 終了がパイプライン全体を失敗扱いにし、関数の戻り値が非ゼロ → script-killer。

**修正:**
```bash
count_added_lines() {
  git diff --numstat -- SKILL.md 2>/dev/null | awk 'BEGIN{c=0} {c=$1+0} END{print c}'
}
```
`git diff --numstat` は常に「追加行数 削除行数 ファイル名」の数値を出す。`awk` で常に 0 を初期値とすることで no-match を発生させない。

### 9.2 Pi の stdin 食い (Staged Eval が 1 ケースで停止)

**症状:** Staged Eval を有効化したら 5 ケース中 1 ケースしか実行されない。

**根本原因:** `run_benchmark.sh` の `while read line` ループ内で `pi -p` を呼んでいたが、pi がデフォルトで親シェルの stdin を継承する。pi が 1 ケース処理する間に残り 4 ケースの stdin (Python loop の出力) を全部読み込んで捨ててしまう。

**修正:** pi 呼び出しに `< /dev/null` を追加。

```bash
pi -p --no-session --provider "$PROVIDER" --model "$MODEL" \
    --max-turns 30 "@$OUT_DIR/prompt.txt" \
    < /dev/null \
    > "$OUT_DIR/output.md" 2> "$OUT_DIR/stderr.log" || true
```

`run_pi` (auto-improve.sh) にも同様の修正を適用。

### 9.3 監査判定 grep のパターン不一致

**症状:** Pi が監査結果を「## 監査結果: PASS」と書いた場合、スクリプトが「監査 FAIL」と判定する。

**根本原因:** スクリプトは `grep -q "判定: PASS"` のみ検出していた。Pi がフォーマットを微妙に揺らすと検出失敗。

**修正:**
```bash
grep -qE "(判定|監査結果)[：:]\s*PASS"
```
判定/監査結果 両方を許可、全角/半角コロンも許可、空白を許容。

加えて audit プロンプトでも明示的にフォーマット指示を入れた:
```
audit.md の冒頭で、必ず以下のいずれかの形式で判定を明示してください:
- 合格時: ## 判定: PASS または ## 監査結果: PASS
- 不合格時: ## 判定: FAIL または ## 監査結果: FAIL
```

### 9.4 ベンチマークモデル変更 (Anthropic 直接 → github-copilot 経由)

**症状:** iter-50, 51, 54, 55 で全ケース UNKNOWN/0 turns/0 cost で 0% になる事象が連鎖発生。

**根本原因:** ベンチマーク用 `claude --model haiku` は Anthropic 認証 (Claude Code サブスク) を消費する。ユーザーが本来の Claude Code 利用と並行すると、Anthropic 側のレートリミットに引っかかり、Haiku が即座に UNKNOWN を返す。

**修正:** `run_benchmark.sh` の呼び出しを Pi 経由 GitHub Copilot プロバイダーに切り替え:

```bash
# 旧
echo "$FULL_PROMPT" | claude --model haiku --print --output-format json ...

# 新
pi -p --no-session --provider github-copilot --model claude-haiku-4.5 \
    --max-turns 30 "@$OUT_DIR/prompt.txt" < /dev/null \
    > "$OUT_DIR/output.md" 2> "$OUT_DIR/stderr.log"
```

これによりベンチマーク実行は GitHub Copilot サブスクを消費し、ユーザーの Claude Code 利用と完全独立になった。実験意図 (低能力モデル + SKILL の効果検証) は維持される (claude-haiku-4.5 は Anthropic Haiku と同等)。

### 9.5 grep 警告 + set -e による silent kill (iter-60 silent stop の前段)

**症状:** `grep: warning: stray \ before +` という警告が出るとスクリプトが終了する。

**根本原因:** `grep -E '^\+'` の `\+` は ERE で不要なエスケープ。一部の grep バージョンで警告を出し、加えて exit 1 を返す。`set -euo pipefail` 下では fatal。

**修正:** `grep -E '^[+]'` に変更 (文字クラスで literal +)。

### 9.6 iter-65 の削除 (汚染データの破棄)

**経緯:** サニタイズ前の contaminated 環境下で iter-65 が 90% を達成したが、これは propose プロンプトに具体的失敗ケース ID が漏洩していた状態での結果。汎化性能の証拠としては無効。

**処置:**
- archive.jsonl から iter-65 エントリを削除
- `iter-65/` ディレクトリも削除
- iter-21, 31, 35, 41 等の旧高スコア親は残した (差分が「文言精緻化」のみで overfit リスクが相対的に低いため)

### 9.7 ベンチマーク情報の隔離 (実験設計の根本欠陥修正)

**問題:** 過去 60+ イテレーションで、propose プロンプトに具体的失敗ケース ID (`15368, 15382, 13821 が EQUIV`) を埋め込んでいた。`failed-approaches.md` も 33 個の BL がすべてケース ID を含んでいた。これにより SKILL.md の改善が「20 個の特定 django ケースを解くハック」に堕していた。

**修正:**
1. `failed-approaches.md` のサニタイズ
   - 旧版を `failed-approaches-historical.md` に退避 (gitignore)
   - 新版は汎用原則 23 個のみ、ケース ID/iter 番号/リポジトリ名を一切含まない
   - 289 行 → 54 行に縮小
2. プロンプトの「許可リスト方式」化
   - 「読むなリスト」を渡すのは押すなよ押すなよの逆効果 → やめた
   - 「参照してよいファイルの完全なリスト」を明示し、それ以外への read/search/list を禁止
   - 各プロンプト (propose / discuss / implement / revise / audit / update-bl) に独自 allowlist
3. プロンプト内の具体的ケース ID 言及を全削除
4. discuss プロンプトに「汎化性チェック (具体的 ID/リポジトリ/テスト名が含まれていないか)」観点を追加
5. update-bl プロンプトにケース ID 書き込み禁止を明示

**効果:** サニタイズ後 (iter-67〜81) の 12 完了イテレーションで:
- 平均スコア **80.8%** (サニタイズ前 18 完了で 72.2%、+8.6pt)
- 85% 以上達成率 **6/12 = 50%** (前 3/18 = 17%)
- 90% 以上達成率 **2/12 = 17%** (前 0/18 = 0%、初の 90% 突破)

実験設計の根本欠陥を修正したことで、本来の改善効果が初めて見えるようになった。

---

## 10. 参考資料

- **HyperAgents 論文:** https://arxiv.org/abs/2603.19461
- **HyperAgents リポジトリ:** https://github.com/facebookresearch/Hyperagents
- **当該リポジトリ:** https://github.com/KunihiroS/agentic-code-reasoning-skills/tree/script/auto-improve
- **関連スキル（ベース研究）:** Ugare & Chandra, "Agentic Code Reasoning" (arXiv:2603.01896)
- **GitHub Copilot CLI Rubber Duck (Critic Agent) 発表記事:** https://github.blog/ai-and-ml/github-copilot/github-copilot-cli-combines-model-families-for-a-second-opinion/
- **GitHub Copilot CLI `/review` ドキュメント:** https://docs.github.com/ja/copilot/how-tos/copilot-cli/use-copilot-cli-agents/agentic-code-review
- **ACPX:** https://github.com/openclaw/acpx
- **Pi Coding Agent:** https://github.com/badlogic/pi-mono
