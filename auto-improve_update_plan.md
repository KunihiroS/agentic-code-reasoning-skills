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

### 方針

- **試行錯誤を重ねることでスコアが上がる** ことを目指す。特定の通っていないテストを追い込まない (オーバーフィッティング懸念)。
- 確率的揺らぎは仕方がないこととして許容する。
- 当面の運用負荷 (中断率等) は許容範囲。
- ベンチマーク実行系 (Pi → claude-haiku-4.5) は変更しない (実験変数の固定)。

### 現在の役割構成と次の予定

**現在 (Phase 2 完了時点):**
| 役割 | 担当 | モデル |
|---|---|---|
| 実装者 | Copilot CLI | `claude-sonnet-4.6` |
| 監査役 (discuss/audit/update-bl) | Pi | `github-copilot/gemini-3.1-pro-preview` |
| ベンチマーク | Pi | `github-copilot/claude-haiku-4.5` |

**次の予定 (8.8 で実施):**
| 役割 | 担当 | モデル |
|---|---|---|
| 実装者 | Copilot CLI **+ Rubber Duck** | `claude-sonnet-4.6` + `gpt-5.4` (`/critique`) |
| 監査役 | **Hermes Agent** | `gpt-5.4` (openai-codex provider) |
| ベンチマーク | Pi | `github-copilot/claude-haiku-4.5` (変更なし) |

### 項目ステータス一覧

| # | 項目 | 効果 | 手間 | ステータス |
|---|---|---|---|---|
| 8.1.A | steepness の CLI 化 | — | — | **✅ 実施済 (2026-04-08)** |
| 8.1.B-E | 親選択高度化 (ドメイン別/適応的/ε-greedy/top-K) | 中 | 中 | 候補 |
| 8.2 | ホールドアウトセット導入 | 高 | 中 | 候補 |
| 8.3 | 異種ベンチマークでの汎化検証 | 高 | 高 | 候補 |
| 8.4 | ACPX 統合 | 中 | 高 | 保留 (Hermes 統合で類似機能を一部代替) |
| 8.5 | 汚染 archive 削除 | — | — | **✅ 実施済** |
| 8.6 | Compilation check | 低-中 | 中 | 候補 |
| 8.7 | 運用マニュアル整備 | (別軸) | 中 | 将来課題 |
| **8.8** | **Hermes Agent 統合 + Rubber Duck 採用** | **高** | **中** | **✅ 完了 → 収束判定 (§10)、ベンチマーク増強へ移行 (§11.4)** |
| 8.9 | Hermes を Phase 3 Meta Agent として採用 (旧 X-2) | 高 | 高 | 候補 (Phase 3 本体検討時) |
| 8.10 | Hermes worktree モード並列探索 (旧 Z) | 高 | 高 | 候補 (Phase 3 以降) |
| §5 Phase 3 | プロンプト外部化 + Meta Agent 自己編集 | 高 | 高 | ロングターム (8.9 と統合検討) |

本セクションは選択肢のカタログ + 実施履歴。
現在の作業は **8.8** (Hermes 統合 + Rubber Duck 採用)。
8.9 / 8.10 は 8.8 の運用が安定してから検討する Hermes 関連の発展候補。

### 8.1 親選択戦略 (score_prop) の調整可能化

#### 8.1.A steepness の CLI 化 — **実施済 (2026-04-08)**

`auto-improve.sh` に `--steepness N` フラグを追加。デフォルトは 20 (従来通り)。
バナーにも現在の値を表示する。

```bash
./auto-improve.sh --steepness 50  # 高 exploitation (90% 親を強く優先)
./auto-improve.sh --steepness 10  # 高 exploration (HyperAgents デフォルト)
./auto-improve.sh                 # デフォルト 20 (Phase 1〜2 で使用)
```

実測効果 (archive 56 エントリ、90% × 2 / 85% × 8 / 80% × 6 / 他):

| steepness | 90% 個別 | 90% 合計 | 85% 合計 | 80% 合計 |
|---|---|---|---|---|
| 10 (HyperAgents 標準) | (拡散) | (拡散) | — | — |
| **20 (現行)** | **9.46%** | **18.92%** | 44% | 15% |
| 50 (高 exploitation) | 25.10% | 50% | 46% | 3% |
| 100 (ほぼ greedy) | (大半) | (ほぼ独占) | わずか | ほぼ 0 |

#### 8.1.B-E その他の親選択高度化候補 (未実施)

- **B. ドメイン別 steepness**: EQUIV と NOT_EQ で別の steepness を持つ。一方が天井に近く、他方が遠い場合に有効。
- **C. 適応的 steepness (時間軸減衰)**: 序盤は exploration 重視 (低 steepness)、後半は exploitation 重視 (高 steepness)。シミュレーテッドアニーリング型。
- **D. ε-greedy ハイブリッド**: 1−ε の確率で best、ε の確率で score_prop。ε を徐々に下げる強化学習パターン。
- **E. top-K 制限**: 最高スコア top-K (例: top-5) のみから確率選択。effective sample size を保つ。

判断材料: A の `--steepness` 値を変えて回した結果から、B-E のどれが必要か判断する。

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

iter-47〜65 はサニタイズ前の contaminated 環境下 (Phase 2 開発時に propose プロンプトに具体的失敗ケース ID を埋め込んでいた状態) で生成された。

**処置済み (Phase 2 完了時点):**
- iter-65 (汚染下の 90%) を archive から削除
- iter-47〜64 を archive から削除 (13 エントリ)
- iter-1〜46 は残す (Phase 2 以前の状態で、BL に case ID は含まれていたが prompt 経由のヒント漏洩はなかった)
- iter-66〜81 (サニタイズ後) はそのまま親候補として有効

archive 現状: 56 エントリ (iter-1 + iter-6〜46 + iter-66〜81)。

### 8.6 Compilation check (HyperAgents 由来)

HyperAgents は各世代の生成後にコードのコンパイル/構文チェックを行い、失敗した世代を archive に excluded として記録する。これにより明らかに壊れた世代がベンチマーク評価まで進むのを防ぐ。

本プロジェクトでは SKILL.md は Markdown なので「コンパイル」ではなく:
- **構造妥当性チェック**: SKILL.md がパース可能か (compare/localize/explain/audit-improve のセクションが揃っているか)
- **長さチェック**: 異常に短い/長い変更でないか
- **プレースホルダー残存チェック**: `[TODO]` や `XXX` 等が紛れ込んでいないか

候補: implement ステップ後、ベンチマーク前に簡易 lint を実行。失敗時はそのイテレーションを破棄。

### 8.7 運用マニュアルの整備 (将来課題)

**問題:** Phase 1〜2 を経てパイプラインの構成要素・CLI フラグ・前提条件が増え、plan doc 単体では「実行方法」を網羅できなくなっている。現状は設計判断と歴史が主体で、運用情報は各セクションに散在。

**対応方針:** マニュアルは plan doc とは別ファイルとして整備する。**今は plan doc を肥大化させない**。整備時期は「Phase 3 着手前」または「他者に共有が必要になった時点」。

**マニュアルに含めるべき内容 (予定):**

1. **実行コマンドリファレンス**
   - `auto-improve.sh` の全フラグ (`-n`, `-s`, `--escape`, `--steepness`)
   - 各フラグの効果と組み合わせ
   - 起動例 (デフォルト / 開始 iter 指定 / 構造改革モード / steepness 調整)
2. **環境前提条件**
   - Fedora VM の必要パッケージ (bash, python3, git, uvx)
   - AI CLI ツール (`copilot`, `pi`) のバージョン要件と認証
   - 必須モデル (`claude-sonnet-4.6`, `gemini-3.1-pro-preview`, `claude-haiku-4.5`)
   - MCP セットアップ (pi-mcp-adapter, duckduckgo-mcp-server)
3. **主要ファイル一覧**
   - 編集対象 (`SKILL.md`)
   - ナレッジ蓄積 (`failed-approaches.md`, `failed-approaches-historical.md`)
   - 系統管理 (`benchmark/swebench/runs/archive.jsonl`)
   - 各イテレーションの成果物 (`benchmark/swebench/runs/iter-N/`)
   - 補助スクリプト (`select_parent.py`, `archive_migrate.py`, `run_benchmark.sh`, `grade.py`)
4. **ログの場所**
   - スクリプト全体ログ (`/tmp/auto-improve.log`)
   - per-step ログ (`copilot-*.log`, `pi-*.log`)
   - ベンチマーク結果 (`grades.json`, `scores.json`)
5. **トラブルシューティング**
   - 9 章の実装史 (silent stop, stdin 食い等) を運用視点で再構成
   - プロセス停止と再開手順
   - 中断時のクリーンアップ (iter-N 削除、SKILL.md リセット)
6. **モデル/プロバイダー切替**
   - GitHub Copilot 認証 vs Anthropic 直接認証の使い分け
   - レートリミット時の代替プロバイダー
7. **Phase 1〜2 で追加された主要機構の運用上の意味**
   - score_prop / ドメインローテーション / Staged Eval / hard limit / escape mode
   - 何が起きているか、いつ介入すべきか

**形式案:** `docs/MANUAL.md` または `docs/operations.md` として別ファイルで作成。

### 8.8 Hermes Agent 統合 + Rubber Duck 採用 [完了 → 収束判定、ベンチマーク増強へ移行]

Phase 3 の準備として、監査役を Pi → Hermes Agent に置き換え、同時に実装者の Copilot CLI で Rubber Duck (`/critique`) を有効化する。ベンチマーク実行系 (Pi → claude-haiku-4.5) は変更しない。

#### 採用する変更内容

**(1) 実装者: Copilot CLI で Rubber Duck を有効化 (採用 = 旧候補 C)**

`auto-improve.sh` の implement プロンプトに `/critique` 指示を追加し、Copilot CLI が自身の実装を GPT-5.4 で self-critique させる。
- v1.0.18+ で導入された Critic Agent (内部 ID `rubber-duck`, モデル `gpt-5.4`) を使う
- `--experimental` フラグは config で永続化済み
- 動作確認済: `subagent.completed` イベントで JSONL から検出可能
- 効果: 実装の質を内部で 1 段引き上げる。プロセス追加なし。

**(2) 監査役: Pi → Hermes Agent に置換**

| 旧 | 新 |
|---|---|
| `pi -p --no-session --provider github-copilot --model gemini-3.1-pro-preview "$(cat prompt.txt)"` | `hermes chat -Q -q "$(cat prompt.txt)" --provider openai-codex` (model: `gpt-5.4`) |

Hermes Agent (Nous Research, v0.8.0) は MIT ライセンスの自己改善型 CLI エージェント:
- Skills (経験からの永続学習)、FTS5 session search、persistent memory
- Worktree モード (将来の並列探索に活用可能)
- MCP 対応 (DuckDuckGo MCP を Hermes 用に再設定可能)
- プロバイダー: `auto / openrouter / nous / openai-codex / copilot-acp / copilot / anthropic / gemini / huggingface / zai / kimi-coding / minimax / minimax-cn / kilocode`
- 動作確認済 (2026-04-08, Fedora VM): `hermes chat -Q -q "..." --provider copilot` でヘッドレス動作

#### モデル選定: GPT-5.4 (openai-codex provider)

理由:
- 既に Codex/Copilot トークン認証で使えることを確認済 (追加コストなし)
- Phase 2 までの Pi (gemini-3.1-pro-preview) と異なるファミリーで independent perspective
- Rubber Duck も GPT-5.4 だが、これは「実装者の self-critique (実装中)」と「外部監査 (実装後)」で時系列が異なるため独立した観点になる

将来的に別モデルへ切替可能 (Hermes は引数だけで切替可能)。

#### 担当ステップ

| ステップ | 担当 |
|---|---|
| propose | Copilot CLI (claude-sonnet-4.6) |
| **implement (+ self-critique)** | **Copilot CLI + Rubber Duck (gpt-5.4)** ← 新 |
| discuss | **Hermes (gpt-5.4)** ← 新 (旧 Pi) |
| audit | **Hermes (gpt-5.4)** ← 新 (旧 Pi) |
| update-bl (失敗時) | **Hermes (gpt-5.4)** ← 新 (旧 Pi) |
| benchmark | Pi (claude-haiku-4.5) ← 変更なし |

#### 残る検討事項

- **Audit Rubric R1〜R7 強制**: Hermes でも現プロンプトをそのまま使えば強制される (許可リスト方式は維持)
- **Web 検索**: Hermes も MCP 対応のため、DuckDuckGo MCP を Hermes 用に再設定する。`~/.pi/agent/mcp.json` 相当の設定先を Hermes ドキュメントで確認する。
- **トークン消費比較**: Hermes は agent framework として動くため Pi よりオーバーヘッドが大きい可能性。実測で判断。
- **Skills 機能の活用**: Hermes の自己学習機構を将来 Phase 3 で活用するための足がかりとなる。

#### Rubber Duck (Critic Agent) 動作確認データ (参考)

`-p` 非対話モードでも Rubber Duck (`agentName: rubber-duck`, model: `gpt-5.4`) が起動することを確認済 (2026-04-08):

| トリガー | 結果 | モデル |
|---|---|---|
| `-p "/critique"` | rubber-duck 起動 | gpt-5.4 |
| `-p "/critique <file>"` | rubber-duck 起動 (2 段) | gpt-5.4 |
| `-p "Plan and implement ..."` | rubber-duck 自動起動 | gpt-5.4 |
| `-p "..., 実装後 /critique で批評せよ"` | 実装+critique 1 プロセス | gpt-5.4 |
| `-p "/review"` (混同注意) | code-review エージェント (別物) | claude-sonnet-4.5 |

検証済イベント形式:
```
type: subagent.started/completed
data.agentName: "rubber-duck"
data.model: "gpt-5.4"
data.totalTokens: <int>
```

注意:
- `/review` は **別エージェント** (Claude ベースの code-review)
- 公式ドキュメントには `/critique` の言及なし (slash command 一覧に未掲載) だが実動作確認済
- モデルが `gpt-5.4` / `gpt-5.2` で揺れる場合がある (理由不明)

#### 棄却した別案 (履歴)

- **旧候補 A (Pi → Rubber Duck 完全置換)**: Audit Rubric R1〜R7 を強制できない、failed-approaches.md 更新ロジックが書きにくい → 棄却
- **旧候補 B (Pi + Rubber Duck 三角レビュー)**: トークン消費が ~85K/iter に増加、調停ロジック必要 → 棄却。代わりに Hermes が 1 つの監査役として動き、実装者側の Rubber Duck と時系列で分離する方式を採用。

#### 8.8.1 初動運用で判明した問題と Rubric 改訂 (2026-04-09)

**初回動作確認 (iter-82〜86) で 3/3 却下が発生:**
- iter-82: discussion NO → skip (`-n 1` 指定で次がなく終了)
- iter-83: discussion NO → skip
- iter-84: discussion PASS → implement (+ `/critique` 動作確認 OK) → **audit FAIL**
- iter-85, 86: 中断

**iter-84 の audit FAIL の中身:**
- 合計 16/21 (≥14 はクリア)
- R2〜R5 はすべて 3 点 (本論評価:「妥当な推論プロセス改善」と認定)
- **R1 (汎化性) と R7 (ケース非依存性) のみ 1 点** → 「全項目 ≥2」条件を満たせず機械的 FAIL

**根本原因:**
1. 旧 audit プロンプトに「diff/rationale にコード断片が含まれていれば R1 と R7 を 1 点 (FAIL)」という追加チェックがあった
2. この「コード断片」の定義が曖昧で、SKILL.md 自身の before/after 引用 (変更内容を文書化するために必須) も巻き込んで誤発火していた
3. **Pi 時代 (iter-75〜81) はこの追加チェックを事実上スキップしていた** — Pi は毎回 R1=3/R7=3 を機械的に付けて素通りさせていた。Pi 時代の高スコア (iter-76: 21/21, iter-79〜80: 21/21) は、この緩い運用の上で成立していた可能性が高い
4. Hermes は同じ rubric を **literal に適用** するため、この差が顕在化した

**設計上の判断:**
- Audit の目的は「ベンチマーク予算を浪費する前の事前品質検査」であり、Audit の点数自体はベンチマーク結果と相関しない (ユーザー判断)
- したがって「Pi 時代の audit が緩かったから過去の成功は無効」という解釈は採らない
- ただし Hermes 時代に literal 解釈で 100% 却下されると前進ゼロになるため、**rubric の文言を Hermes でも合理的に判定できる形に書き直す** 必要がある

**改訂内容 (案 1 採用):**
- **R7「ケース非依存性」を R1「汎化性」に統合** (機能重複を解消、6 項目化)
- **R1 採点基準を厳密化:**
  - 1 点 (NG): diff/rationale に **ベンチマーク対象リポジトリの固有識別子** (リポジトリ名、ファイルパス、関数名、クラス名、テスト名、テスト ID、実装コードの引用) が含まれる場合
  - 減点対象**外**: SKILL.md 自身の文言引用 (変更前/後対比)、一般概念名 (「Guardrail #4」「observational equivalence」等)、抽象的な説明文、SKILL.md の自己引用を含む \`\`\` ブロック
- **合格基準: 全項目 ≥2 かつ合計 12/18 以上** (旧: 14/21 以上)
- **propose プロンプトの「コード断片禁止」も同じ定義に揃える** — Copilot 側が誤って自滅しないようガイド
- **audit プロンプトの旧「追加チェック」セクションを削除** — R1 の採点基準に内在化したため不要

**棄却した別案:**
- 案 2 (コア/周辺で重み分け、R2〜R4 must / R1/R5/R6/R7 advisory): 「優先順位ベース」の合格判定が複雑化、Hermes が解釈ぶれする懸念
- 案 3 (3 項目に大幅統合): rubric の細やかな診断機能を失う、過去 audit との比較性も損なう

**コミット:** `718f459` (auto-improve.sh + Objective.md)

**残課題:**
- ~~改訂後 rubric で実際に PASS が出るか → iter-87〜 で観測~~ → iter-87 で PASS 確認済 (80%)
- ~~もし Hermes が引き続き厳しすぎる場合: discussion 圧縮を追加適用~~ → discussion 却下率 100% が継続、§10 の収束判定で根本原因判明
- ~~却下率が改善した後、discussion の Web 検索コスト (~25 分/iter) も別途検討~~ → Hermes proposer 移行後 ~5 分/iter に短縮

#### 8.8.2 提案者/実装者の Hermes 統一、Rubber Duck 撤廃 (2026-04-09)

**背景:** Copilot CLI の `/critique` (Rubber Duck) が品質改善ゼロと判明。

**実測データ:**
- iter-87 implement: rubber-duck subagent (gpt-5.4) が 7 tool calls、**70,878 tokens**、60 秒で実行
- iter-84 implement: 3 回呼び出し、計 **~309,000 tokens**
- **品質改善件数: 0 件** (iter-84: Blocking 指摘なし。iter-87: Blocking 1 件だが「前回スコアの具体的証拠を示せ」→ 我々の制約で提供不可能なため無視)
- iter-84 の audit FAIL 原因 (rationale にコード断片含有) を critic は検出できなかった

**根本原因:**
- `critic.agent.yaml` の system prompt がハードコードの devil's advocate (コードレビュー特化)
- `promptParts.includeCustomAgentInstructions: false` で AGENTS.md 等のプロジェクト固有指示を継承しない
- 我々のフォーマットガードレール検査 (汎化性・コード断片禁止) には構造的に使えない

**対策:**
- Copilot CLI を全廃、提案者/実装者を `hermes chat --provider copilot -m claude-sonnet-4.6` に統一
- Copilot の認証は `gh auth token` 経由で Hermes が自動解決 (`copilot_auth.py` の `resolve_copilot_token()`)
- implement プロンプトから `/critique` 指示を全削除
- `run_hermes_proposer()` 関数追加、ログファイルを `hermes-*.log` に統一

**効果:**
- /critique の無駄トークン (70k〜120k/call) がゼロ
- 1 イテレーション所要時間: ~12 分 → ~5 分 (propose が Copilot CLI の 3〜6 分 → Hermes 1〜2 分に短縮)
- ただし提案内容は同じモデル (claude-sonnet-4.6) のため変化なし (予想通り)

**コミット:** `b9839ea`

#### 8.8.3 強制カテゴリローテーション (2026-04-09)

iter-87〜106 の観察で Exploration Framework カテゴリの偏り確定:
- B (情報取得): 6 回、E (表現): 9 回 → 合計 15/20 = 75% がこの 2 カテゴリに集中
- D (メタ認知): 0 回、F (論文未活用): 0 回

`current_iter % 6` で A→B→C→D→E→F を強制ローテーション。

**結果 (iter-107〜112, iter-113〜118 の 2 サイクル):**
- 12/12 全 discussion 却下
- カテゴリは分散されたが、**実際に触る領域は全件 compare モード** に偏集
- Hermes が「共有 Step 3 に compare 特有の意味論を混入」と看破する例もあり
- **カテゴリ強制は「書き方」しか変えられず「対象」は変えられない** と結論

**コミット:** `813e7ac`

#### 8.8.4 総括: compare 自己改善ループの収束 (2026-04-09)

§10 の再現性測定 (stdev 7.64%, range 15pp) により、**iter-1〜118 の自己改善は統計的に進歩ゼロ** と判定。
§11 の Meta-Harness / HyperAgents 比較分析から、ベンチマーク増強が最優先と方針決定。

→ §8.8 は「完了 (収束判定)」として閉じ、ベンチマーク増強 (§11.4) に移行。

#### 8.8.5 localize benchmark 追加 (2026-04-10)

compare 1 モードだけの評価系ではドメイン多様性が欠如し、改善検出も統計的に不可能なため、SKILL.md の localize モード用ベンチマークを新設。

**実装内容:**
- `scripts/generate_localize_tasks.py`: pairs.json の gold_patch から ground truth (files/functions) を自動抽出
- `benchmark/swebench/data/localize_tasks.json`: 20 ケースの localize タスク (既存 SWE-bench インスタンスを転用)
- `benchmark/swebench/data/prompt_template_localize.md`: localize 用プロンプト (SKILL.md の localize モード指示付き)
- `benchmark/swebench/run_benchmark_localize.sh`: localize benchmark 実行スクリプト
- `benchmark/swebench/grade_localize.py`: file-level 正解判定 (primary) + function-level (secondary)

**採点基準:**
- `correct = file_match` (予測ファイルが ground truth ファイルに一致)
- `function_match` はサブ指標 (クラス名 vs メソッド名のギャップがあるため厳密一致は難しい)
- partial path matching 対応 (末尾一致)

**動作確認:** django-14089 で file-level 100% を確認。
**baseline 測定:** main SKILL.md での localize 20 ケース × with_skill を実行中 (結果待ち)。

**コミット:** `20e2cfb`

**次のステップ:**
- localize baseline スコア + variance 測定
- auto-improve.sh に localize 評価を統合 (combined score = compare + localize)
- paired comparison + statistical significance gate の導入

### 8.9 Hermes を Phase 3 Meta Agent として採用 (旧 X-2)

#### 概要

8.8 で Hermes を「監査役」として採用することと別軸の **Phase 3 本体** に向けた候補。
Hermes Agent の自己改善機構を、SKILL.md 自体やプロンプトテンプレートを進化させる Meta Agent として活用する。

#### 対応する Hermes 機能

Hermes には以下の自己改善機構がビルトインされている:
- **Skills (`~/.hermes/skills/`)**: 経験から自律的にスキルを生成・改善し永続化
- **agentskills.io 標準準拠**: 我々の SKILL.md と同種の概念
- **FTS5 session search**: 過去会話の全文検索 + LLM サマリー
- **Persistent memory**: agent-curated insight storage、cross-session 記憶
- **Honcho dialectic user modeling**: 利用者の振る舞いモデリング

#### 対応する HyperAgents 機構

HyperAgents の以下の機構を、自前で実装する代わりに Hermes でカバーできる:
- **Persistent memory** (我々の `failed-approaches.md` 相当を agent-curated に)
- **Cross-domain transfer** (Skills 機構経由で)
- **Self-editing meta agent** (Skills の自己改善ループ)

#### 採用判断

「**自前で Phase 3 を書くか、Hermes に任せるか**」の選択。8.8 で Hermes が監査役として動いた経験を踏まえて判断する。

利点:
- 自前実装よりはるかに少ないコードで HyperAgents 級の自己進化が実現できる可能性
- Nous Research のエコシステム成熟度に乗れる
- Hermes 側のアップデートで自動的に機能向上する

欠点:
- Hermes の Skills/Memory メカニズムが我々の SKILL.md 文化と完全に一致しない可能性
- 制御の細かさが下がる (内部 logic が Hermes 側でブラックボックス化)
- Hermes のバージョン依存性

#### 関連: §5 Phase 3 との位置づけ

§5 Phase 3 (プロンプト外部化 + Meta Agent 自己編集) は Phase 3 本体の概念設計。
8.9 はその「自前実装 vs Hermes 採用」の選択肢の一つ。
8.8 の運用結果次第で、Phase 3 着手時に判断する。

### 8.10 Hermes worktree モード並列探索 (旧 Z)

#### 概要

`hermes -w` (`--worktree`) を使って、複数の親候補から並列に改善案を生成・検証する仕組み。
現在の sequential iteration を根本から変える野心的な変更。

#### 対応する Hermes 機能

`hermes chat -w -q "..."` で各セッションが独自の git worktree + 独自ブランチを持つ:
- 複数のエージェントが同じリポジトリを並行編集しても干渉しない
- 各 worktree で commit / push / PR 作成が独立
- 親プロセスは worktree 終了後にマージ判断する

#### 採用シナリオ

```
通常の score_prop:
  iter-N: 親選択 → 1 つの子イテレーション

並列 worktree:
  iter-N (parent X) → 子 A (worktree A)
  iter-N (parent Y) → 子 B (worktree B)
  iter-N (parent Z) → 子 C (worktree C)
  ↓ 並列実行
  最良の子を採用、他は破棄
```

これにより 1 サイクルあたりの探索幅が ~3 倍に増える。

#### 利点

- **探索効率の劇的向上** (sequential 1 本 → 並列 3〜5 本)
- 異なる親 + 異なる focus domain の組み合わせを 1 回で試せる
- 確率的揺らぎに強くなる (複数試行から最良を選ぶ)

#### 欠点

- VM のリソース (CPU / メモリ / API レートリミット) が並列度を制限する
- ベンチマーク実行も並列化する必要があり、現在の Pi 直列呼び出しを大改造する必要
- 結果統合のロジックが複雑化 (どの worktree を採用するか)
- score_prop の archive.jsonl への並行書き込みでロック必要

#### 採用判断

8.8 (Hermes 単独監査役) の運用が安定し、かつ Phase 3 で更なる探索効率向上が必要になった時点で検討。
VM の並列度限界 (現状 4 CPU / 8 GB) 次第で、worktree 並列度は 2〜3 が現実的か。

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

## 10. 再現性測定結果と収束判定 (2026-04-09)

### 10.1 再現性測定 (§8.2 前提検証)

同一 SKILL.md (iter-80 snapshot = 過去最高 90%) を 3 回繰り返し実行。

| run | スコア |
|---|---|
| run 1 | 15/20 = 75.0% |
| run 2 | 18/20 = 90.0% |
| run 3 | 17/20 = 85.0% |

- **平均: 83.33%、stdev: 7.64%、range: 15pp**
- 不安定 (flipping) ケース 3/20: django-12663, django-14787, django-15368
- 安定ケース: 17/20 = 85% (= main ブランチの原型スコアと完全一致)

### 10.2 main ブランチとの差分

main (85%) と iter-80 (90%) の差分は **2 箇所 4 行のみ** (compare checklist + Guardrail #4 の文言精緻化)。
iter-80 の 90% はノイズ上限を叩いた lucky run であり、真の期待値 83.33% は main 以下。

### 10.3 収束判定

- **iter-1〜iter-118 の自己改善ループは統計的に進歩ゼロ。** 5〜10pp の揺らぎは 3 ケースの flip ノイズで完全に説明可能。
- **failed-approaches.md に蓄積された原則 (#1〜#27+) の大半は、ノイズから学習された疑似パターン。** 本物の BL と noise-BL の区別が不可能。
- **§8.2 ホールドアウト (15/5 split) は破綻。** 20 ケースで stdev 7.64% なら 5 ケースでは stdev > 15%。
- **compare ベンチマーク駆動の SKILL.md 文言微調整は、この測定解像度では原理的に機能しない。**

結果ファイル: `benchmark/swebench/runs/variance-summary.json`, `variance-{1,2,3}/`

---

## 11. 関連研究の比較分析 (2026-04-10)

### 11.1 Meta-Harness (Stanford IRIS Lab, arXiv:2603.28052)

**概要:** Yoonho Lee, Chelsea Finn ら (Stanford)。LLM で「model harness」(プロンプト + ツール定義 + retrieval ロジック + context 管理のコード全体) を自動最適化する。

**核心アイデア:** 従来手法 (OPRO, AlphaEvolve, Self-Refine 等) は proposer にスコアか短いサマリーしか渡さない (1K〜26K tokens/iter)。Meta-Harness は **全候補の execution traces + ソースコード + スコアをファイルシステムとして** proposer (Claude Code) に提供し、`grep` / `cat` で必要な部分を選択的に読ませる (最大 10M tokens/iter)。

**ループ構造:** propose → evaluate → store (全ログ + コード + スコアをファイルに保存) → repeat

**ノイズ対策:**
- TerminalBench-2: 89 タスク × **5 回試行** = 445 評価点で分散抑制
- train/test 分離 (text classification, math reasoning)
- **unseen model への transfer 検証** (math: search model と別の 5 モデルで評価)

**主要成果:**
- TerminalBench-2: Opus 4.6 で 76.4% (2 位)、Haiku 4.5 で 37.6% (全 agent 1 位)
- Text classification: +7.7pp で SOTA
- **既存手法の 1/10 の評価回数** で同等性能に到達

**リポジトリ:** https://github.com/stanford-iris-lab/meta-harness-tbench2-artifact

### 11.2 HyperAgents との比較

| 観点 | HyperAgents (Meta/FAIR) | Meta-Harness (Stanford) | 我々 (auto-improve) |
|---|---|---|---|
| 最適化対象 | agent ソースコード全体 | harness コード全体 | SKILL.md 文言のみ (2〜5 行) |
| proposer が見る情報 | eval report + コード。DGM baseline は失敗 chat log (250K chars) | 全候補の traces + code (10M tok) | SKILL.md + failed-approaches.md (数千 tok) |
| ノイズ対策 | **なし** (single run、statistical test なし)。tree archive で暗黙ヘッジ | 5 回試行、train/test 分離、transfer 検証 | **なし** (single run、stdev 7.64%、118 回がノイズ) |
| アーカイブ構造 | tree (任意ノード分岐) | 不明 (flat?) | archive.jsonl (linear + score_prop 親選択) |
| domain 多様性 | 6〜8 ドメイン同時で汎化強制 | benchmark ごと (事後 transfer 検証) | compare 1 ドメインのみ |
| 改変の幅 | コード改変 (ツール追加、制御フロー変更、パーサー書き換え) | harness コード改変 | **プロンプト文言のみ** |
| statistical gate | なし | 暗黙 (5 回平均による安定化) | なし |

### 11.3 我々への示唆の統合

**HyperAgents と Meta-Harness は補完的:**
- **HyperAgents** = 「何を」変えるかの幅を広げる (コードレベル改変、multi-domain)
- **Meta-Harness** = 「なぜ」変えるかの診断精度を上げる (execution traces、情報密度)

**我々に最も欠けているもの (優先順):**

1. **ベンチマークの統計的信頼性** — 20 ケース × 1 回では改善検出不可能。
   - 対策: ケース数拡大 (§8.3)、複数回試行、paired comparison

2. **proposer への診断情報** — スコアと理論的原則のみでは targeted fix が不可能。
   - 対策: execution traces (output.md) を proposer に渡す (Meta-Harness 方式)

3. **改変の幅** — SKILL.md 2〜5 行の文言ではノイズを超える改善 delta が生まれない。
   - 対策: harness 全体 (prompt_template, run_benchmark.sh, ツール構成) を最適化対象に (HyperAgents 方式)

4. **statistical significance gate** — 両研究にも明示的には無いが必要。
   - 対策: paired t-test (p < 0.05) を採用判定条件に追加

5. **domain 多様性** — compare 1 ドメインでは過学習も検出不能。
   - 対策: localize/explain モードのベンチマーク追加、または別リポからケース追加

### 11.4 次のアクション: ベンチマーク増強が最優先

上記 5 項目のうち、**(1) ベンチマークの統計的信頼性** が他全ての前提条件となる。
信頼できる測定系がない限り、proposer の改善 (2)、改変幅の拡大 (3)、statistical gate (4)、domain 多様性 (5) のいずれも効果検証が不可能。

**ベンチマーク増強の方向性 (§8.3 を具体化):**
- pairs.json を 20 → 50〜100 ケースに拡大
- django 以外のリポジトリ (scikit-learn, sympy, flask 等) から pairs を追加
- ケース数 n が増えれば stdev は 1/√n で下がる (50 ケースで stdev ~3.4%、100 ケースで ~2.4%)
- train/test 分離が統計的に成立する (50 ケースなら 35/15 split で holdout stdev ~5%)
- paired comparison + 3 回平均を組み合わせれば、1〜2% の改善でも検出可能

---

## 12. ベンチマーク増強: 実施結果と次期方針 (2026-04-10)

### 12.1 localize benchmark の導入と評価

SKILL.md の localize モード評価基盤を新設し、ablation (SKILL あり/なし) を含む系統的な測定を実施。

#### 実施内容

| 条件 | データ | テンプレート | without_skill | with_skill | SKILL delta |
|---|---|---|---|---|---|
| Easy (テスト名あり) | django 20 件 | prompt_template_localize.md | 90% | 95% | +5pp |
| Medium (テスト名なし) | django 20 件 | prompt_template_localize_medium.md | 90% | 90% | 0 |
| Medium (multi-project) | sympy/matplotlib/sphinx/sklearn/xarray 各 2 件 = 10 件 | 同上 | 100% | 100% | 0 |

#### 考察

- **haiku-4.5 は localize タスクが素で得意すぎる。** django でも multi-project でも、SKILL.md なしで 90〜100%。
- **SKILL.md の寄与は compare >> localize。** compare では +25〜35pp の効果があるが、localize では 0〜5pp。
- SKILL.md が compare モード特化で発展してきた結果として当然。
- **localize (file-level) は現モデル能力で天井に達しており、改善検出ベンチマークとして単独では機能しない。**

#### 対応方針

localize を有効なベンチマーク軸にするには:
1. **難度を上げる** — より難しいケース、multi-file バグ、馴染みの薄いリポ
2. **function-level を primary にする** — file match は天井だが function match は with/without で 70%/80% と差がある (multi-project)
3. **SWE-bench Pro** (後述) の採用 — 平均 4.1 ファイル変更のケースなら file-level でも天井が下がる

### 12.2 SWE-bench Pro の評価

**SWE-bench Pro** (Scale AI, 2026) — SWE-bench Verified の上位互換。

| 観点 | SWE-bench Verified (現在使用中) | SWE-bench Pro |
|---|---|---|
| ケース数 | 500 | **1,865** (public 731 + private 276 + held-out 858) |
| 言語 | Python のみ | **Python, Go, JS, TypeScript** |
| リポ数 | ~12 (django 中心) | **41 リポ** (consumer app, B2B, dev tools) |
| 変更規模 | 161/500 が 1〜2 行 | **全タスク 10 行以上、100+ 件が 100 行以上** |
| ファイル数 | ほぼ単一 | **平均 4.1 ファイル** |
| 汚染対策 | なし | GPL ライセンスリポ + private コード |
| top モデルスコア | 70〜81% | **23〜59%** |
| データセット | `princeton-nlp/SWE-bench_Verified` | `ScaleAI/SWE-bench_Pro` (HuggingFace) |
| issue カテゴリ | なし | `security_bug`, `major_bug`, `api_feat` 等 |
| スキーマ | 基本フィールド | Verified の superset (requirements, interface, issue_categories 等) |

**同一モデルで ~35pp 低下** (Claude Opus 4.5: Verified 80.9% → Pro 45.9%) — 本気で難しい。

### 12.3 SKILL.md 4 モード × SWE-bench Pro の適合性評価

| モード | Pro で実現可能か | 採点の信頼性 | 方針 |
|---|---|---|---|
| **compare** | △ (agent_patch 取得が別途必要) | ○ (binary) | 現状維持 (Verified 20 件) |
| **localize** | **◎** (そのまま使える) | ○ (file/func match) | **Pro に移行** |
| explain | △ (LLM-as-judge 依存) | △ (ノイズ大) | 後回し |
| **audit-improve** | **○** (security_bug フィルタ) | ○ (localize 同等) | **Pro で新設** |

#### compare (現状維持)

SWE-bench Verified の 20 件 pairs.json をそのまま使用。compare は SKILL.md の効果が最も大きいモード (+25〜35pp) であり、既にノイズ特性が把握済み (stdev 7.64%, flipping 3 ケース)。Pro に移行するには agent_patch の取得が必要で追加工数が大きい。

#### localize (Pro に移行)

- Pro の 731 件 (public) から localize 用タスクを生成
- **multi-file (平均 4.1 ファイル)** なので file-level でも天井が下がる
- **multi-language** (Python, Go, JS, TS) で SKILL.md の汎用性を本格的に試す
- prompt_template_localize_medium.md (テスト名なし) を使用
- 件数が多いので train/test 分離も統計的に成立

#### audit-improve (Pro で新設)

- Pro の `issue_categories` フィールドで `security_bug` をフィルタ
- タスク: 「このコードをレビューしてセキュリティ上の問題を特定せよ」(問題の存在を事前に教えない)
- 正解: gold_patch が修正した箇所 (localize 同等の採点)
- localize との違い: **問題の存在自体を検出する能力** が問われる

#### explain (後回し)

自由記述の「説明の正しさ」を binary 判定できない。LLM-as-judge を使えば半自動採点可能だが、judge 自体のノイズが大きく、ベンチマークの信頼性が下がる。localize + audit-improve が安定してから検討。

### 12.4 次期実装計画

**Phase A: localize benchmark を Pro に移行**
1. `ScaleAI/SWE-bench_Pro` から localize 用タスクを生成 (multi-language 対応)
2. run_benchmark_localize_multiproject.sh を Pro 対応に拡張 (Go/JS/TS リポのクローン + 適切な worktree)
3. main SKILL.md で baseline 測定 (with/without skill)
4. ケース数とスコア分布から train/test split 比率を決定

**Phase B: audit-improve benchmark の新設**
1. Pro の security_bug インスタンスを抽出、件数を確認
2. audit-improve 用 prompt_template と grade スクリプト作成
3. baseline 測定 (with/without skill)

**Phase C: 統合スコアの定義と auto-improve.sh への組み込み**
1. combined_score = f(compare, localize, audit-improve) の定義
2. auto-improve.sh のベンチマークステップに localize + audit-improve を追加
3. 親選択と BL 更新を combined_score で駆動
4. paired comparison + statistical significance gate の導入

**依存関係:** A → C (localize baseline が必要)、B → C (audit baseline が必要)、A と B は並行可能

---

## 13. 参考資料

- **HyperAgents 論文:** https://arxiv.org/abs/2603.19461
- **HyperAgents リポジトリ:** https://github.com/facebookresearch/Hyperagents
- **Meta-Harness 論文:** https://arxiv.org/abs/2603.28052
- **Meta-Harness プロジェクトページ:** https://yoonholee.com/meta-harness/
- **Meta-Harness リポジトリ:** https://github.com/stanford-iris-lab/meta-harness-tbench2-artifact
- **SWE-bench Pro (Scale AI):** https://labs.scale.com/leaderboard/swe_bench_pro_public
- **SWE-bench Pro データセット:** https://huggingface.co/datasets/ScaleAI/SWE-bench_Pro
- **SWE-bench Pro 評価ハーネス:** https://github.com/scaleapi/SWE-bench_Pro-os
- **当該リポジトリ:** https://github.com/KunihiroS/agentic-code-reasoning-skills/tree/script/auto-improve
- **関連スキル（ベース研究）:** Ugare & Chandra, "Agentic Code Reasoning" (arXiv:2603.01896)
- **GitHub Copilot CLI Rubber Duck (Critic Agent) 発表記事:** https://github.blog/ai-and-ml/github-copilot/github-copilot-cli-combines-model-families-for-a-second-opinion/
- **GitHub Copilot CLI `/review` ドキュメント:** https://docs.github.com/ja/copilot/how-tos/copilot-cli/use-copilot-cli-agents/agentic-code-review
- **ACPX:** https://github.com/openclaw/acpx

- **HyperAgents 論文:** https://arxiv.org/abs/2603.19461
- **HyperAgents リポジトリ:** https://github.com/facebookresearch/Hyperagents
- **Meta-Harness 論文:** https://arxiv.org/abs/2603.28052
- **Meta-Harness プロジェクトページ:** https://yoonholee.com/meta-harness/
- **Meta-Harness リポジトリ:** https://github.com/stanford-iris-lab/meta-harness-tbench2-artifact
- **当該リポジトリ:** https://github.com/KunihiroS/agentic-code-reasoning-skills/tree/script/auto-improve
- **関連スキル（ベース研究）:** Ugare & Chandra, "Agentic Code Reasoning" (arXiv:2603.01896)
- **GitHub Copilot CLI Rubber Duck (Critic Agent) 発表記事:** https://github.blog/ai-and-ml/github-copilot/github-copilot-cli-combines-model-families-for-a-second-opinion/
- **GitHub Copilot CLI `/review` ドキュメント:** https://docs.github.com/ja/copilot/how-tos/copilot-cli/use-copilot-cli-agents/agentic-code-review
- **ACPX:** https://github.com/openclaw/acpx
- **Pi Coding Agent:** https://github.com/badlogic/pi-mono

---

## 14. ベンチマーク再整備と SKILL.md 改訂 (2026-04-11)

### 14.1 localize → diagnose 改名と Activation gates 追加

- **経緯**: SWE-bench Pro の localize タスク（gt ファイル数 17〜106 の hard ケース 10件）で with_skill 80% vs without_skill 100% と、SKILL.md が逆効果になることを確認
- **原因分析**: SKILL.md の構造化分析（Phase 4 Ranked Predictions、Step 5.5 の証拠なき主張の禁止）が出力ファイル数を過度に絞り込み、recall 寄りの採点基準とミスマッチ
- **対策**:
  - `localize` → `diagnose` に名称変更（モードの適用範囲を名前で明示）
  - Activation gates を追加（広範囲列挙タスク、大規模構造変更、フラットなファイルリスト要求時は不発動）
  - diagnose セクションに Scope constraint 追記（1〜5ファイルの単一バグ向け）
- **README.md**: main から持ってきて feature ブランチに配置、"Changes from the Original Paper" セクションで変更経緯を記載
- **commit**: `04d49bf`

### 14.2 論文の再確認

- 元論文 (Ugare & Chandra, arXiv:2603.01896) を再確認した結果、論文は SWE-bench と一体設計ではなく **汎用的な手法論**
  - Patch Equivalence (compare) → SWE-bench Verified で評価
  - Fault Localization (localize) → **Defects4J** (Java) で評価
  - Code QA (explain) → **RubberDuckBench** (Python/Java/C++) で評価
- 3つの異なるベンチマークで評価しており、SWE-bench は compare でしか使われていない
- audit-improve は論文が将来方向として言及した security/API misuse を追加したも���

### 14.3 audit-improve ベンチマーク新設

- **データ**: SWE-bench Pro の `issue_specificity` = `security_bug` から 28件を抽出
- **リポ**: ansible, flipt-io, gravitational/teleport, navidrome, NodeBB, protonmail, tutao, future-architect/vuls
- **言語**: Go, Python, JS, TS
- **実行ツール**: Pi (github-copilot/claude-haiku-4.5)、各インスタンスで git worktree checkout して実行
- **採点**: grade_localize.py を流用（file_match + function_match）

#### Run 1 結果

| | without_skill | with_skill | Delta |
|---|---|---|---|
| File match (correct) | 23/28 (82.1%) | 24/28 (85.7%) | **+3.6pp** |
| Function match | 19/28 (67.9%) | 21/28 (75.0%) | **+7.1pp** |
| No prediction | 3 | 2 | -1 |
| Avg duration | 245s | 221s | -24s |

- with_skill が精度・速度の両方で優勢
- Run 2 実行中（variance 確認用）

### 14.4 compare ベンチマークの Pro 移行

- **データ**: SWE-bench Pro のエージェントパッチ（S3 バケット `s3://scaleapi-results/swe-bench-pro/`）から取得
  - 15エージェント分の `_patch.diff` が公開（Wave 1: 2025-10-13, Wave 2: 2025-10-22, Wave 3: 2025-11-17）
  - GitHub リポ (`scaleapi/SWE-bench_Pro-os/traj/`) に pass/fail 結果あり
- **ペア構成**: 20ペア (10 EQUIVALENT + 10 NOT_EQUIVALENT)
  - EQUIVALENT: 9エージェント中1つだけが解けたインスタンス（最難関）
  - NOT_EQUIVALENT: 全9エージェントが全員失敗したインスタンス
- **言語**: Go 13, JS 4, TS 1, Python 1（旧 django 20件 = Python のみから大幅拡張）
- **パッチサイズ**: gold 58〜1530行、agent 273〜9076行
- **汚染リスク**: 2025年10-11月公開のため現行モデルの学習データに含まれる可能性あり。ただし with/without の相対比較なら汚染は両方に等しく影響するため、スキルの効果測定としては有効
- Run 1 実行中

### 14.5 diagnose の除外

- 適切なベンチマークが用意できないため、自動改善の評価対象から除外
- SKILL.md 上のモード定義と Activation gates は維持（実用時に利用可能）

### 14.6 自動改善パイプライン再設計方針

- **評価**: compare Pro と audit-improve を**独立に評価**（combined_score は不採用）
- **採用判定**: 両ベンチでデグレしないことが条件
- **ドメインローテーション廃止**: 提案者には「両ベンチでデグレしないこと」のみ伝え、フォーカス方向は提案者に委ねる
- **archive.jsonl**: compare_score と audit_score を別カラムで記録
- **改修対象箇所**:
  1. ステップ 5a/5b のベンチ差し替え (django compare → compare Pro + audit)
  2. ステップ 0 のドメインローテーション廃止
  3. ステップ 6 の scores.json 構造変更
  4. 採用判定ロジック変更
  5. Staged Eval の再設計
  6. archive.jsonl のスコア体系リセット

### 14.7 次のステップ

- [x] Compare Pro Run 1〜3 完了 → 結果確認 (2026-04-16)
- [x] Audit Run 1〜2 完了 → variance 確認 (2026-04-16)
- [ ] auto-improve.sh 改修（上記 14.6 の方針に従い）
- [ ] archive.jsonl リセット、新ベースラインで iter-0 記録
- [ ] パイプライン再開

### 14.8 Compare テンプレート改修: STRUCTURAL TRIAGE 追加 (2026-04-11)

- **問題**: Pro compare ベンチ (多言語・大規模パッチ) で with_skill が without_skill より -7.4pp 悪化
  - 原因1: grading スクリプトが `ANSWER: **NO**` や `## ANSWER\n**NO**` を拾えない → UNKNOWN 判定 (バグ修正済み)
  - 原因2: SKILL.md の compare テンプレートが大規模パッチ (数百〜数千行) で全行トレースを試み、トレースできた範囲で EQUIVALENT と誤判定。without_skill は構造的差異 (ファイル欠落等) を即座に検出できていた
  - HURTS 8件中6件が flipt-io/flipt (Go) の NOT_EQUIVALENT — agent patch が必要なモジュールを未更新
- **改修内容**: Compare Certificate template に `STRUCTURAL TRIAGE` セクションを追加
  - S1: 変更ファイルリストの比較 (片方にしかないファイルをフラグ)
  - S2: 網羅性チェック (テストが import するファイルが両方で変更されているか)
  - S3: 規模評価 (~200行超のパッチでは構造比較を優先、全行トレースは非推奨)
  - 構造的ギャップが明確な場合、ANALYSIS をスキップして即 NOT EQUIVALENT 判定を許可
  - Compare checklist の先頭にも反映
- **影響範囲**: Compare の Certificate template とチェックリストのみ。Core Method、他モードへの波及なし
- **Grading バグ修正**: `grade_compare_pro.py` の `extract_answer()` を拡張 — マークダウン太字、改行後の回答を対応

#### 結果比較

| | 改修前 avg (4 runs) | 改修後 avg (3 runs) | Delta |
|---|---|---|---|
| without_skill | 61.2% (stdev 4.8%) | 55.0% (stdev 5.0%) | -6.2pp |
| with_skill | 53.8% (stdev 13.8%) | 58.3% (stdev 12.6%) | +4.5pp |
| **with - without** | **-7.4pp** | **+3.3pp** | **+10.7pp 改善、逆転** |

改修前は with_skill が without_skill より 7.4pp 劣っていたが、改修後は +3.3pp と逆転。STRUCTURAL TRIAGE により大規模パッチでの NOT_EQUIVALENT 誤判定が改善。ただし stdev 12.6% と揺れは大きい。

### 14.9 現時点のベンチマーク総括 (2026-04-11 → 2026-04-16 更新)

#### Audit-Improve (security_bug 28件)

**初回測定 (2026-04-11, §14.3 のデータ):**

| | Run 1 | Run 2 | 平均 | stdev |
|---|---|---|---|---|
| without_skill | 82.1% | 82.1% | 82.1% | 0% |
| with_skill | 85.7% | 85.7% | 85.7% | 0% |
| **Delta** | **+3.6pp** | **+3.6pp** | **+3.6pp** | — |

**検証測定 (2026-04-16, iter-39 ベスト版 SKILL.md で再測定):**

| | Run 1 | Run 2 | 平均 | stdev |
|---|---|---|---|---|
| without_skill (file+func) | 82.1% (23/28) | 82.1% (23/28) | 82.1% | 0% |
| with_skill (file+func) | 89.3% (25/28) | 92.9% (26/28) | 91.1% | 2.5% |
| **Delta** | **+7.2pp** | **+10.8pp** | **+9.0pp** | — |

without_skill は4回とも完全に同じ値 (82.1%) で極めて安定。with_skill は初回測定 (85.7%) より検証測定 (91.1%) で大幅に改善。iter-39 ベスト版 SKILL.md の audit-improve 効果は **+9.0pp** と安定して有効。

なお function match は with_skill/without_skill で差が小さい (67.9%〜75.0%) — file-level の特定には効くが function-level の精度向上は限定的。

#### Compare Pro (20ペア、多言語・高難度)

**初回測定 (2026-04-11, §14.8 改修後):**

| | 改修後 avg (3 runs) | stdev |
|---|---|---|
| without_skill | 55.0% | 5.0% |
| with_skill | 58.3% | 12.6% |
| **Delta** | **+3.3pp** | — |

**検証測定 (2026-04-16, iter-39 ベスト版 SKILL.md で再測定):**

| | Run 1 | Run 2 | Run 3 | 平均 | stdev |
|---|---|---|---|---|---|
| without_skill | 65% (13/20) | 50% (10/20) | 75% (15/20) | 63.3% | 10.3% |
| with_skill | 75% (15/20) | 70% (14/20) | 65% (13/20) | 70.0% | 4.1% |
| **Delta** | **+10pp** | **+20pp** | **-10pp** | **+6.7pp** | — |

平均 +6.7pp で改善方向。初回測定 (+3.3pp) より delta が拡大。ただし Run 3 で逆転 (-10pp) が発生しており、without_skill の stdev (10.3%) が大きい。with_skill の方が stdev が小さい (4.1%) 点は、SKILL.md が推論を安定化させている可能性を示唆。

#### 総合評価

| ベンチマーク | without_skill 平均 | with_skill 平均 | Delta | 安定性 |
|---|---|---|---|---|
| **Audit** (28件, 4回) | 82.1% | 88.4% | **+6.3pp** | 高 (without stdev=0%, with stdev=3.5%) |
| **Compare Pro** (20件, 6回) | 59.2% | 64.2% | **+5.0pp** | 中 (without stdev=8.6%, with stdev=10.5%) |

SKILL.md は両ベンチマークで一貫してプラス効果。特に Audit での安定した改善が顕著。

#### 現在の SKILL.md

- `localize` → `diagnose` に改名、Activation gates 追加
- Compare テンプレートに STRUCTURAL TRIAGE 追加
- iter-39 ベスト版で検証完了
- この版を auto-improve.sh 再開時のベースライン (iter-0) とする
---

## 15. Phase 3: メタエージェント導入 (2026-04-16)

Phase 3 の設計・実装の詳細は **[docs/meta-agent_plan.md](docs/meta-agent_plan.md)** を参照。

**実装サマリー:**
- ブランチ: `meta-agent/auto-improve`
- プロンプトテンプレートを `prompts/` に外部化 (7 ファイル + manifest.json)
- archive.jsonl に `template_version` / `template_hash` を追加
- 停滞検知 (`detect_stagnation.py`) + メタエージェント (`meta-propose.txt`) 実装
- スコア退行時の自動ロールバック機構
- `--meta` フラグで強制トリガー可能

**ステータス:** 実装完了、検証ラン (Step 6) 未実施

---

## 16. Phase 3 検証ラン後の修正 (2026-04-18)

### 16.1 検出された問題

Phase 3 の検証ラン (iter-1〜14, 新ベンチマーク体制) で以下の問題が判明した。

#### A. メタエージェントのパス解決バグ

`append_archive_entry.py` が `prompts/.version` のパスを `archive_file` からの相対パスで解決していたため、`benchmark/prompts/.version`（存在しない）を参照していた。結果として **全エントリの `template_version` が 0 に固定**され、テンプレート変更の効果測定とロールバック判定が完全に機能していなかった。

**修正:** `os.path.dirname(archive_file)` → `os.path.dirname(os.path.abspath(__file__))` に変更。

#### B. 停滞検知の常時発火

`detect_stagnation.py` が旧フォーマット（`template_version` フィールドなし）のアーカイブエントリを含めて判定していたため、旧ベンチの高スコア (audit 85-92%) が `best_audit_ever` に含まれ、**常に `stagnant=True`** となっていた。全 10 iter でメタエージェントが発火し、v1→v11 まで 11 回テンプレート更新が実行されたが、効果測定なしに空転していた。

**修正:**
- `template_version` フィールドを持つ新フォーマットエントリのみでフィルタ
- compare と audit の**両方**が過去ベストを下回った場合のみ stagnant 判定
- 現テンプレートバージョンでの scored iter が `META_STAGNATION_WINDOW`(5) 回溜まるまでメタ発火を抑制

#### C. Worktree レジストリの残留

`auto-improve.sh` のクリーンアップで `rm -rf` によるファイル削除は行っていたが、`git worktree prune` を実行していなかったため、git のワークツリーレジストリに stale な登録が残存。次のベンチマーク実行時に `git worktree add` が「already registered」エラーで失敗し、iter-11 では 20 ペア中 1 ペア、28 件中 0 件しか実行されなかった (Compare 100%/Audit 0% という異常値の原因)。

**修正:** クリーンアップに全 repo への `git worktree prune` を追加。

#### D. 提案の発想が同一パターンに固着

iter-3, 7, 10, 12, 13, 14 の 6 回の却下理由が全て「構造差による早期 NOT_EQUIV の条件を特定の観測境界に狭める」方向の提案で、failed-approaches.md の再演として却下されていた。カテゴリを A〜F でローテーションしても、提案者 (gpt-5.2) が毎回同じボトルネック（STRUCTURAL TRIAGE の S2）に辿り着き、同じ解決策を出し続けていた。

**根本原因:** propose テンプレートが「ボトルネック診断→改善仮説」の流れを強制しており、SKILL.md を読むと最も目立つ改善点（S2 の曖昧さ）に吸い寄せられる構造だった。

**修正:** propose-normal.txt を全面改修 (148行→87行):
- 直近の却下理由を `RECENT_REJECTIONS` 変数として渡し、同じ方向を明示的に禁止
- 思考の流れを「ボトルネック→仮説」から「未探索の方向を列挙→そこから仮説」に反転
- 冒頭 4 行の 1 番目を「過去提案との差異」に変更し、差分思考を強制
- compare の STRUCTURAL TRIAGE 以外の改善方向（他モード、共通フロー、前提の立て方、反証対象の選び方等）を候補として明示

### 16.2 修正コミット

1. `fix: add worktree cleanup after each iteration to prevent disk bloat` — イテレーション完了後の worktree ファイル削除
2. `fix: meta-agent path bug, stagnation detection, and firing frequency` — パス解決、停滞検知、発火頻度の 3 点修正
3. `fix: add git worktree prune to cleanup to prevent stale registration errors` — レジストリ掃除
4. `feat: redesign propose template to break repetitive rejection loop` — テンプレート全面改修

### 16.3 ステータス

修正適用後の検証ラン (iter-15〜) を実行中。

---

## 17. カテゴリ G（アブレーション / 引き算）の導入 (2026-04-19)

### 17.1 前提

Phase 3 の検証ラン (iter-1〜29) で以下の構造的問題が判明した:

1. **SKILL.md が 482 行まで肥大化**: 29 iter の漸進改善で追加を重ねた結果、ベンチモデル (haiku) にとって認知負荷が過大になっている可能性がある。
2. **足し算のみのバイアス**: Exploration Framework の 6 カテゴリ (A〜F) が全て「何を追加・変更するか」の方向で設計されており、「何を削除すべきか」を探索する仕組みが存在しなかった。
3. **局所最適からの脱出困難**: iter-1 (compare 75%, audit 92%) を超える変更が 29 iter で見つからず、5 行制限内の追加では探索空間が枯渇している。
4. **HyperAgents フレームワークの汎用化目的**: 本実験は Meta-agent/Hyper-agent を汎用的なエンジニアリング手段にすることも目的としており、「引き算による改善」は自己改善ループの重要な機能として組み込むべき。

### 17.2 仮説

- SKILL.md の一部セクション（optional ガイド、冗長な例示、重複するチェック項目）は、判定品質に寄与せず認知負荷を増やしているだけの可能性がある。
- これらを削除すれば、(a) 性能維持で認知負荷だけ減る、または (b) 不要な指示に惑わされなくなり性能が改善する、のいずれかが起きうる。
- 自己改善ループに「引き算」の探索方向を組み込むことで、追加と削除の両方向で最適点を探索できるようになり、局所最適からの脱出可能性が高まる。

### 17.3 実装内容

1. **Objective.md**: Exploration Framework にカテゴリ G を追加
   ```
   G. 認知負荷の削減（簡素化・削除・統合）
   - スコアに寄与していないセクション・チェック項目・例示を特定して削除する
   - 重複する指示や冗長な説明を統合・圧縮する
   - optional ガイドが実際に使われているか疑い、不要なら削る
   - 仮説: 削除しても性能が維持または改善されるなら、そのセクションは認知負荷を増やしていただけ
   - 注意: 研究のコア構造は削除しない
   ```

2. **auto-improve.sh**: カテゴリローテーションを 6 → 7 に拡張 (`current_iter % 7`)

3. **prompts/propose-normal.txt**: カテゴリ G 専用の思考フローを追加
   - 通常の「ボトルネック→改善仮説」ではなく「削除候補を列挙→削除仮説→Before/After で推論フローの変化を説明」

### 17.4 期待すること

- **最低限**: 削除しても性能が維持される箇所が見つかれば、SKILL.md をスリム化できる（認知負荷低減）
- **理想**: 削除によって性能が改善するケースが見つかれば、過剰な指示が haiku を萎縮させていたという仮説が検証される
- **メタ的な成果**: 「引き算」が自己改善ループの有効な探索方向であることが実証されれば、HyperAgents フレームワークの汎用化に向けた知見となる

### 17.5 ステータス

iter-34〜40 の検証ラン実行中（iter-34 = カテゴリ G が初回）。

---

## 18. meta-agent/auto-improve ブランチ総括 (2026-04-20)

### ブランチ概要

- **期間**: 2026-03-27 〜 2026-04-20 (24 日間)
- **コミット数**: 306
- **総イテレーション数**: 旧ベンチ 118 iter + 新ベンチ 40 iter = 158 iter
- **ブランチ**: `meta-agent/auto-improve`

### 実装した仕組み

#### Phase 1-2: HyperAgents ベースの自己改善ループ
- **score_prop 親選択**: 過去全世代からシグモイド分布で確率的に親を選ぶ (HyperAgents, arXiv:2603.19461)
- **archive.jsonl**: 全世代のスコア・系統・テンプレートバージョンを記録
- **Staged Evaluation**: 少数ケースで足切り → 閾値超えで full 評価
- **ドメインローテーション**: 探索カテゴリ A〜G を強制ローテーション
- **5 行 hard limit**: 1 イテレーション 5 行以内の変更に制約
- **failed-approaches.md**: 失敗原則の蓄積による同一方向の再演防止

#### Phase 3: メタエージェント
- **テンプレート外部化**: 提案・ディスカッション・監査等のプロンプトを prompts/ に分離
- **停滞検知 → メタ自動発火**: detect_stagnation.py で停滞を検知し、メタエージェントがテンプレート自体を編集
- **テンプレートバージョニング**: archive.jsonl に template_version / template_hash を記録
- **ロールバック判定**: スコア退行時のテンプレート自動ロールバック

#### セッション中の改善 (2026-04-18〜20)
- **バグ修正 3 件**: パス解決、停滞検知、worktree レジストリ
- **propose テンプレート全面改修**: 却下ループ脱出（思考フローの反転、却下履歴の注入）
- **カテゴリ G 導入**: 認知負荷の削減（簡素化・削除・統合）を探索方向に追加

### ベンチマーク結果

#### 旧ベンチ (Django 20ペア, Phase 1-2)
- 初期スコア: 85% (iter-5)
- 最高スコア: 85% (複数 iter で到達、118 iter で突破できず)
- 収束判定: iter-118 で統計的収束

#### 新ベンチ (Compare Pro 20ペア + Audit 28件, Phase 3)

**ベスト (iter-1): Compare 75% / Audit 92%**

| 順位 | iter | Compare | Audit | 合計 |
|------|------|---------|-------|------|
| 1 | iter-1 | 75% | 92% | 167% |
| 2 | iter-9 | 65% | 92% | 157% |
| 3 | iter-6, 36 | 70% | 85% | 155% |
| - | iter-17 | 55% | 96% | 151% |

README 記載の公式評価結果:
- Compare Pro: without 59.2% → with **64.2%** (+5.0pp)
- Audit: without 82.1% → with **88.4%** (+6.3pp)

### 効果があったこと

1. **SKILL.md 自体の改善**: 原論文の semi-formal reasoning を実用スキルに翻訳し、Compare +5.0pp / Audit +6.3pp の安定改善を実証
2. **score_prop + archive**: 系統の多様性を確保し、過去の良い世代から分岐する探索を可能にした
3. **テンプレート外部化**: メタエージェントや人間による改修を容易にした基盤
4. **failed-approaches.md**: 同じ失敗の繰り返しを防ぐ仕組みとして機能（ただし探索空間の縮小という副作用も）
5. **propose テンプレート改修 (人間介入)**: 却下ループからの脱出に最も効果的だった

### 効果が限定的/なかったこと

1. **メタエージェントの自律的テンプレート進化**: 15 回のテンプレート更新のうち、明確にスコア改善に寄与したのは v14/v15 (impact witness) のみ。大半は形式的な追加に留まった
2. **5 行制限の漸進改善**: iter-1 以降 40 iter で超えられず、局所最適に収束
3. **カテゴリ G (引き算)**: 導入したが 1 回の試行で却下。有効性は未検証

### 学んだこと（HyperAgents フレームワーク汎用化への知見）

1. **引き算の探索が必要**: 足し算のみの自己改善は肥大化と局所最適を招く。カテゴリ G のような削除方向の探索は不可欠
2. **メタエージェントより人間の介入が効果的**: テンプレートの構造的な問題（思考フローの方向、禁止パターンの明示）は、メタエージェントの漸進的な追加では解決できなかった
3. **提案者の発想の固着**: モデルを変えなくても、テンプレートの思考フローを変えるだけで提案の多様性は改善できる。ただし発想の質（スコアを上げる変更を見つける能力）はテンプレートだけでは改善困難
4. **ベンチマークのノイズ**: 20 ペアでは ±1 問で 5% 動くため、真の改善と偶然の区別が困難。統計的信頼性にはサンプル数の拡充が必要
5. **バグの影響の大きさ**: パス解決やスタグネーション検知のバグで、メタエージェントが全期間空転していた。自己改善ループのインフラ品質は成果に直結する
6. **Compare と Audit のトレードオフ**: 2 つの異なるタスクの同時最適化は、単一の SKILL.md では構造的に困難。モード別の最適化が必要な段階に来ている可能性

### SKILL.md の最終状態

- **確定版**: iter-1 の snapshot (482 行)
- **配布先**: ローカル (~/.claude/skills/)、GitHub (claude-config)、README に同期済み
- **主な変更点 (iter-0 → iter-1)**: Step 3 に INFO GAIN (optional) + 探索優先度の 1 行追加（わずか 2 行の変更が最も効果的だった）

---

## 19. meta-agent-2/auto-improve ブランチ開始 (2026-04-20)

### 19.1 ブランチの目的

`meta-agent/auto-improve` から派生。前ブランチの仕組み（score_prop、archive、メタエージェント、カテゴリ G）を引き継ぎつつ、ベンチマークモデルを変更して SKILL.md の効果検証を深める。

### 19.2 変更: ベンチマークモデルの変更

| 項目 | Before (meta-agent/auto-improve) | After (meta-agent-2/auto-improve) |
|------|----------------------------------|-----------------------------------|
| ベンチモデル | claude-haiku-4.5 | gpt-5.4-mini |
| プロバイダ | github-copilot | openai-codex |

**変更理由:**
- より弱いモデルを使うことで、SKILL.md の効果（with/without の差分）をより顕著に観測できると期待
- haiku は十分に能力が高く、SKILL.md なしでも 59-65% 程度を出すため、スキルの寄与分が小さくノイズに埋もれやすかった
- 弱いモデルほど構造化された推論ガイドの恩恵が大きい（原論文の知見とも整合）
- github-copilot 依存を減らし、openai-codex に統一することでプロバイダの一貫性も向上

**注意:**
- ベースラインが変わるため、archive.jsonl をリセットし iter-0 からやり直す必要がある
- 前ブランチの iter-1 (compare 75%, audit 92%) とは直接比較不可

### 19.3 計画: explain モードのベンチマーク設計

#### 背景

SKILL.md の 4 モードのうち、ベンチマークが整備されているのは compare と audit-improve のみ。
- compare: Compare Pro (20ペア) — gpt-5.4-mini で +16.7pp の効果を確認
- audit-improve: Audit (28件) — gpt-5.4-mini では性能飽和で with/without 差なし
- diagnose: 広範タスクで逆効果 (-20pp) が判明し評価停止。スコープ縮小後の再評価は未実施
- explain: ベンチマーク自体が未設計

explain は「正解」が一意に決まらないため、LLM-as-Judge によるルーブリック評価が必要。

#### テストケースの構造

```json
{
  "repo": "flipt-io/flipt",
  "commit": "abc123",
  "question": "What happens when a flag evaluation request has no matching rules?",
  "context_files": ["internal/server/evaluation.go"],
  "reference_answer": "..." 
}
```

- 出典: SWE-bench Pro リポ（既にクローン済み）のバグ修正コミットを利用
- 「この変更は何をしているか」「なぜこのバグが起きたか」等を質問
- ground truth はコミットメッセージ + diff から作成可能

#### ルーブリック (5 軸 × 3 段階、合計 15 点)

| 軸 | 測りたいこと | SKILL.md が効くはずの部分 |
|---|---|---|
| R1: 正確性 | 説明が事実として正しいか | 手続き間トレースで誤推論を防ぐ |
| R2: 証拠の具体性 | file:line の引用があるか | 番号付き前提 + VERIFIED/UNVERIFIED |
| R3: 推論の追跡可能性 | 結論に至る過程を読者が再現できるか | certificate 構造 |
| R4: 不支持主張の不在 | 根拠なく推測で済ませていないか | 必須反証 + 名前推測禁止 |
| R5: 簡潔性 | 無関係な情報を詰め込んでいないか | 認知負荷（逆効果も測れる） |

#### Judge の構成

- **ブラインド評価**: Judge は with/without を知らない。回答を A/B として渡す
- **順序ランダム化**: A/B の割り当てをケースごとにランダム化（位置バイアス防止）
- **Judge モデル**: 被評価モデル (gpt-5.4-mini) より強いモデル (gpt-5.4 or Claude)
- **安定性検証**: 同じ回答を 3 回採点させて Judge の一致率を測る

#### 実行計画

**Phase 1: Pilot (5 ケース)**
1. SWE-bench Pro リポから 5 件の質問を手動作成
2. gpt-5.4-mini で with/without の回答を生成
3. Judge で採点し、以下を検証:
   - Judge の採点安定性（3 回採点の一致率）
   - with/without でスコア差が出るか
   - ルーブリックの各軸が discriminative か（差がつかない軸は不要）

**Phase 2: 本格評価 (15-20 ケース)**
- Pilot の結果を踏まえてルーブリックを調整
- ケース数を 15〜20 に拡大
- 複数ラン実行して統計的信頼性を確保

#### Compare/Audit との違いと対策

- Compare は二値判定 → 機械採点可能。explain は自由文 → Judge 依存
- Judge 自体の信頼性が結果の信頼性の上限になる
- reference answer がある場合は Judge なしの自動指標（事実一致率等）も併用検討

### 19.4 ベースライン測定結果: gpt-5.4-mini (2026-04-20)

SKILL.md を iter-1 ベスト版に固定し、ベンチマークモデルを gpt-5.4-mini (openai-codex) に変更して 5 ラン実行した。

#### Compare Pro (20 ペア, 5 ラン)

| | without skill | with skill | Delta |
|---|---|---|---|
| **Overall (avg)** | 52.0% | **69.0%** | **+17.0pp** |
| stdev | 8.4% | 6.5% | — |

| Run | without | with | Delta |
|-----|---------|------|-------|
| 1 | 60% | 75% | +15pp |
| 2 | 40% | 65% | +25pp |
| 3 | 60% | 70% | +10pp |
| 4 | 45% | 75% | +30pp |
| 5 | 55% | 60% | +5pp |

#### Audit (28 件, 5 ラン)

| | without skill | with skill | Delta |
|---|---|---|---|
| **File+func match (avg)** | 94.3% | 95.0% | **+0.7pp** |

| Run | without | with | Delta |
|-----|---------|------|-------|
| 1 | 92.9% | 92.9% | 0 |
| 2 | 96.4% | 92.9% | -3.5pp |
| 3 | 96.4% | 96.4% | 0 |
| 4 | 92.9% | 96.4% | +3.5pp |
| 5 | 92.9% | 96.4% | +3.5pp |

#### haiku (前ブランチ) との比較

| ベンチ | haiku Delta | gpt-5.4-mini Delta | 変化 |
|--------|-----------|-------------------|------|
| Compare Pro | +5.0pp | **+17.0pp** | 3.4 倍 |
| Audit | +6.3pp | +0.7pp | 効果消失 |

#### 所見

1. **Compare: 弱いモデルほどスキルの効果が大きい** — gpt-5.4-mini では +17.0pp と haiku の 3 倍以上。原論文の知見（structured reasoning は能力の低いモデルほど恩恵が大きい）と整合
2. **Compare: スキルが判定を安定化** — with_skill の stdev (6.5%) は without (8.4%) より小さい
3. **Compare: EQUIV 判定が主な改善点** — gpt-5.4-mini は without で EQUIV を 10-30% しか正解できないが、with で 40-60% に改善
4. **Audit: 性能飽和** — gpt-5.4-mini は without でも 93-96% と高く、スキルの付加価値がない。audit-improve モードの SKILL.md からの削除を検討すべき
5. **このベースラインを meta-agent-2/auto-improve の iter-0 として使用する**

### 19.5 Explain ベースライン結果と原論文との照合 (2026-04-20)

#### 結果

20 タスク × with/without を gpt-5.4-mini で実行、gpt-5.4 で Judge 評価（ルーブリック 5 軸 × 3 段階、計 15 点）。

| | without skill | with skill | Delta |
|---|---|---|---|
| **平均スコア (19 ペア)** | 12.0/15 | 10.8/15 | **-1.2** |

軸別では R4（不支持主張の不在: -1.00）と R5（簡潔性: -1.06）で大きく悪化。

with_skill の出力は certificate テンプレート（FUNCTION TRACE TABLE, PREMISES 等）を埋めようとして、検証できない構造体やファイルを捏造する傾向が観察された。

#### 原論文との照合

原論文 (Ugare & Chandra, 2603.01896) の Code Question Answering 評価:
- Opus-4.5: Standard 78.3% → Semi-formal **87.0% (+8.7pp)**
- Sonnet-4.5: Standard 84.2% → Semi-formal **84.8% (+0.6pp)**

論文の指摘:
> "the benefit of structured reasoning varies by model capability and may plateau when the base model is already strong."
> "semi-formal reasoning can fail when agents construct elaborate but incomplete reasoning chains"

#### 構造化の効果モデル（タスク出力形式 × モデル能力）

| | 二値判定 (compare) | 自由記述 (explain) |
|---|---|---|
| **強いモデル** | 小改善 (+5pp haiku) | 改善 (+8.7pp 論文 Opus) |
| **弱いモデル** | 大改善 (+17pp mini) | 悪化 (-1.2pt mini) |

- 二値判定: テンプレートは「証拠収集の過程」を構造化するだけで、埋められない欄があっても判断は出せる
- 自由記述: テンプレートの全セクションが出力の一部になるため、埋められない = 捏造になる
- 弱いモデルはテンプレートを埋める能力が不足し、ハルシネーションで補填する

#### 対応: Guardrail #10 の追加

SKILL.md に以下のガードレールを追加:
> 10. **Do not fabricate to fill template sections.** If you cannot verify a claim, write "NOT VERIFIED" or "N/A" rather than inventing plausible-sounding content. An incomplete but honest certificate is more valuable than a complete but fabricated one.

#### 今後の検討事項

- explain モードのテンプレートを軽量化する（全セクション必須→結論+根拠のみ）可能性
- activation gates でモデル能力に応じた適用制御
- audit-improve モードの SKILL.md からの削除検討（飽和のため）

### 19.6 gpt-5.4 Compare ベースライン確定 + meta-agent-2 実装方針 (2026-04-21)

#### Compare ベースライン (gpt-5.4, iter-1 SKILL.md)

9 ラン実行、Run 6-8 は API エラー（全件 9 秒で完了、出力が不正）のため除外。

| Run | without | with | Delta |
|-----|---------|------|-------|
| 1 | 60% | 65% | +5pp |
| 2 | 65% | 70% | +5pp |
| 3 | 65% | 65% | 0 |
| 4 | 60% | 60% | 0 |
| 5 | 60% | 70% | +10pp |
| 9 | 55% | 70% | +15pp |
| **平均 (正常 6 ラン)** | **60.8%** | **66.7%** | **+5.8pp** |

haiku での +5.0pp と近い値。gpt-5.4 は without でも 55-65% 程度で安定しており、with で 60-70% に改善。

#### ベンチマーク全体像の確定

| ベンチ | モデル | without | with | Delta | 方針 |
|--------|--------|---------|------|-------|------|
| Compare Pro | gpt-5.4 | 60.8% | 66.7% | **+5.8pp** | **auto-improve 対象** |
| Compare Pro | gpt-5.4-mini | 52.0% | 69.0% | +17.0pp | 参考（弱モデル） |
| Audit | gpt-5.4-mini | 94.3% | 95.0% | +0.7pp | 除外（飽和） |
| Explain | gpt-5.4-mini | 12.0/15 | 10.8/15 | -1.2pt | 除外（逆効果） |

#### meta-agent-2 の実装方針

**1. SKILL.md を Compare 特化版に絞る**
- audit-improve / diagnose セクションを除外し、認知負荷を低減
- Compare と共通基盤（Step 1-6, Guardrails）のみ残す
- 改善結果は最終的に本体 SKILL.md にマージする

**2. failed-approaches.md をリセット**
- 旧ベンチ (haiku) 時代の原則を白紙に戻す
- gpt-5.4 での実際の失敗から新たに原則を構築

**3. archive.jsonl をリセット**
- gpt-5.4 ベースラインを iter-0 として仕切り直す

**4. auto-improve.sh の変更**
- proposer: gpt-5.2 → gpt-5.4 に変更
- ベンチマーク: Compare Pro のみ（Audit 除外）
- 行数制限: 5 行 → 10-15 行に緩和
- API エラー検知: 異常に短い実行時間（全件 < 15秒）を自動リトライ

**5. 維持する仕組み**
- propose テンプレート（却下履歴注入 + 未探索方向からの逆算）
- カテゴリ A-G ローテーション（G = 削除）
- score_prop 親選択
- メタエージェント（テンプレート自己編集）
- Guardrail #10（テンプレート捏造禁止）

### 19.7 次のプラン: Hermes のメモリ機能活用 (2026-04-22)

#### 現状

auto-improve.sh では hermes を `hermes chat -Q -q "..." < /dev/null` でワンショット呼び出ししており、Hermes の特徴であるメモリ機能が活用されていない。

- **520 セッション、10,941 メッセージ**が state.db に蓄積されているが、各呼び出しが独立セッションのため相互参照されていない
- `MEMORY.md` / `USER.md` は未作成
- auto-improve 固有のスキルは自動生成されていない
- 現状の「学習の蓄積」は `RECENT_REJECTIONS` 変数（直近却下理由のテキスト注入）と `failed-approaches.md`（手動蓄積の失敗原則）のみ

#### Hermes のメモリ機能の概要（活用可能な機能）

1. **永続メモリ（MEMORY.md）**: セッション横断で常時注入される「常駐知識」。環境・嗜好・過去の学びを保存
2. **セッション継続**: `/resume` で過去セッションを再開し、文脈を引き継いで対話を継続
3. **FTS5 全文検索**: state.db 内の過去会話を検索して再利用
4. **スキル自動生成**: 成功タスクの実行プロセスを抽出し「スキル」として蓄積、同種タスクの再実行時に呼び出し

#### 活用案

**案 A: MEMORY.md への学習結果の書き込み**
- auto-improve のイテレーション完了後、「何を変えたら何点だった」をHermes の MEMORY.md に追記
- 提案者が次の呼び出しで自動的にこの情報を参照し、過去の成功/失敗パターンから提案を立てられる
- 現在の `RECENT_REJECTIONS` 変数より自然で、hermes のネイティブ機能として動作する
- 実装: auto-improve.sh のステップ 7（コミット後）に MEMORY.md への追記処理を追加

**案 B: セッション継続による文脈の蓄積**
- proposer の hermes を同一セッションで呼び続け、過去の提案と結果の文脈を維持
- 「前回は X を試して 65% だった、今回は Y を試す」という自然な思考の流れが生まれる
- 実装: セッション ID を管理し、`hermes chat --resume SESSION_ID` で呼び出す

**案 C: 成功パターンのスキル化**
- 75% 以上を出した提案の実行パターンを Hermes のスキルとして蓄積
- 同種の改善提案時にスキルが自動呼び出しされ、成功パターンを再現しやすくなる
- 実装: 高スコア iter 完了時にスキル生成 prompt を hermes に渡す

#### 優先順位

案 A が最も実装が簡単で効果が見込める（MEMORY.md への追記は数行のシェルスクリプト）。
案 B はセッション管理の複雑さがあるが、Hermes の本来の強みを最も活かせる。
案 C は長期的に面白いが、スキル生成の品質が不明。

**推奨**: まず案 A を実装し、効果を確認してから案 B に進む。
