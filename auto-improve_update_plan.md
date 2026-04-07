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

### 主要機構

| 機構 | 役割 | 本計画で採用するか |
|---|---|---|
| `score_prop` 親選択 | 過去全世代からシグモイド分布で確率的に親を選ぶ | **採用（最優先）** |
| `archive.jsonl` | 全世代のメタデータ・スコア・系統を記録 | **採用** |
| Staged Evaluation | 小データセットで足切り → 閾値超えたらfull評価 | **採用** |
| ドメイン分割スコア | 複数ドメインで並列評価 | **採用** |
| 自己編集可能な Meta Agent | 監査プロンプト自体を進化対象に | **採用（Phase 3）** |
| Docker 隔離 | 各世代をコンテナで実行 | 採用せず（git checkout で代替） |
| Ensemble 評価 | アーカイブ全体を集約予測 | 採用せず |

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

**保留理由:**

ACPX は基本的に「インフラ改善」（セッション永続化、構造化出力、クラッシュ復帰）であり、85% の壁を破る直接的な効果は期待できない。Phase 1 の壁突破には:
- Phase 2 のドメイン分割 + 構造改革エスケープハッチ
- もしくは別軸の根本的改善

の方が優先度が高い。

**再開条件:**

- Phase 2 を実施しても 85% を超えない場合、ACPX 導入によるトークン効率改善で「より多くのイテレーションを回す」量的アプローチを試す価値が出てくる
- もしくは Phase 3 (プロンプト外部化、メタエージェントによる自己編集) で構造化出力が必要になった時点で導入

**保留中の準備:**

- VM 上に `acpx@0.5.0` インストール済み
- `acpx --help` で pi/copilot/codex 等のサブコマンド認識を確認済み
- Phase 2 実装中に余裕があれば、`acpx pi` の単発呼び出しを試して動作確認のみ実施

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

## 8. 参考資料

- **HyperAgents 論文:** https://arxiv.org/abs/2603.19461
- **HyperAgents リポジトリ:** https://github.com/facebookresearch/Hyperagents
- **当該リポジトリ:** https://github.com/KunihiroS/agentic-code-reasoning-skills/tree/script/auto-improve
- **関連スキル（ベース研究）:** Ugare & Chandra, "Agentic Code Reasoning" (arXiv:2603.01896)
- **現行の failed-approaches.md:** 18 個の BL、14 個の共通原則を蓄積済み（Phase 1 以降も引き続き活用）
