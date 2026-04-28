# Phase 3: メタエージェントによる自己改善プロセスの進化

**作成日:** 2026-04-16
**ブランチ:** `meta-agent/auto-improve`
**前提:** `auto-improve_update_plan.md` §1〜§14 の知見を踏まえた設計

---

## 1. 背景と動機

### これまでの経緯

agentic-code-reasoning-skills の `auto-improve.sh` は、SKILL.md（コード推論スキル）を
自動的に改善するループである。Phase 1〜2 で以下を実装した:

- **Phase 1**: HyperAgents (arXiv:2603.19461) の score_prop 親選択 + 5行 hard limit
- **Phase 2**: Staged Eval、Re-propose ループ廃止、構造改革エスケープハッチ

118 イテレーションを実行した結果、§10 の収束判定で **統計的に進歩ゼロ** と判定された。
同一 SKILL.md を 3 回評価すると 75%〜90% の幅があり (stdev 7.64%)、
文言微調整 (2〜5行) による改善はノイズを超えられなかった。

### ベンチマーク増強

§11〜§14 でベンチマークを刷新:

| ベンチマーク | 内容 | without_skill | with_skill | Delta |
|---|---|---|---|---|
| **Compare Pro** | SWE-bench Pro 20ペア (Go/JS/TS/Python) | 59.2% | 64.2% | +5.0pp |
| **Audit** | セキュリティバグ特定 28件 (多言語) | 82.1% | 88.4% | +6.3pp |

SKILL.md 自体の効果は確認済み。問題は **改善プロセスの限界**:
- 提案者が見える情報がスコアと原則のみ（Meta-Harness の指摘）
- ���変の幅が SKILL.md の 5行に限定（HyperAgents との差）
- 監査プロンプトが固定で進化しない

### なぜ Phase 3 か

関連研究との比較 (§11) から、最も欠けているのは:

1. **改変の幅** — SKILL.md 文言ではなく、改善プロセス全体を最適化対象にする
2. **ベンチマークの信頼性** — Audit (stdev ~2.5%) は改善検出に十分

Phase 3 は「改善プロセスそのもの（プロンプトテンプレート）を進化させる」
メタエージェントを導入し、探索空間を SKILL.md 文言から改善プロセスに拡張する。

---

## 2. アーキテクチャ

### 全体像

```
┌─────────────────────────────────────────────────┐
│                 auto-improve.sh                  │
│                                                  │
│  ┌───────────┐    停滞検知     ┌──────────────┐ │
│  │ 内部ループ │ ─────────────→ │ メタエージェント│ │
│  │           │                │              │ │
│  │ propose   │ ← テンプレート  │ テンプレート   │ │
│  │ discuss   │    読み込み     │ 編集          │ │
│  │ implement │                │              │ │
│  │ audit     │                └──────────────┘ │
│  │ benchmark │                                  │
│  └───────────┘                                  │
│        │                                        │
│        ↓                                        │
│  archive.jsonl (template_version 付き)           │
└─────────────────────────────────────────────────┘
```

### エージェント構成

| 役割 | ツール | モデル | 変更対象 |
|------|--------|--------|----------|
| 提案者/実装者 | Hermes Agent | openai-codex/gpt-5.2 | SKILL.md |
| 監査役 | Hermes Agent | openai-codex/gpt-5.4 | — (読取のみ) |
| ベンチマーク | Pi | github-copilot/claude-haiku-4.5 | — (評価のみ) |
| **メタエージェント** | **Hermes Agent** | **openai-codex/gpt-5.4** | **prompts/*.txt** |

### ループフロー

```
for each iteration:
  1. 停滞検知 → 停滞なら メタエージェント発動
  2. ロールバック判定 → メタ編集後の退行チェック
  3. 親選択 (score_prop)
  4. 親の SKILL.md 復元
  5. render_template("propose") → 提案
  6. render_template("discuss") → ディスカッション
  7. render_template("implement") → 実装
  8. render_template("audit") → 監査
  9. ベンチマーク (Compare Pro + Audit)
  10. archive.jsonl に記録 (template_version 付き)
```

---

## 3. 実装詳細

### 3.1 テンプレート外部化

auto-improve.sh に埋め込まれていた 7 つの heredoc プロンプトを `prompts/` に抽出。

```
prompts/
  manifest.json           # テンプレート名 → ファイル、必須変数、agent role
  propose-normal.txt      # 通常モードの提案プロンプト
  propose-escape.txt      # 構造改革モードの提案プロンプト
  discuss.txt             # ディスカッション（監査役）プロンプト
  implement.txt           # 実装プロンプト
  audit.txt               # 監査プロンプト
  revise.txt              # 監査 FAIL 後の修正プロンプト
  update-bl.txt           # failed-approaches 更新プロンプト
  meta-propose.txt        # メタエージェント用プロンプト
  .version                # テンプレートバージョン番号
```

**変数展開**: `envsubst` を使用。manifest.json から変数リストを取得し、
明示的に展開対象を指定 (`envsubst '${VAR1} ${VAR2}'`) することで、
テンプレート内の意図しない `$` 展開を防止する。

```bash
render_template() {
  local tpl_name="$1"
  local vars=$(python3 -c "..." )  # manifest.json から変数リスト取得
  envsubst "$vars" < "prompts/${tpl_name}.txt"
}
```

### 3.2 テンプレートバージョン追跡

archive.jsonl の各エントリに以下を追加:

```json
{
  "genid": 1,
  "scores": { "compare": 65, "audit": 89 },
  "template_version": 1,
  "template_hash": "a1b2c3d4e5f6g7h8",
  ...
}
```

- `template_version`: `prompts/.version` ファイルの値。メタエージェントがテンプレートを
  更新するたびにインクリメント。
- `template_hash`: 全テンプレートファイルの SHA-256 (先頭16文字)。
  同一バージョンでのテンプレート不整合を検出する。

### 3.3 停滞検知

`benchmark/swebench/detect_stagnation.py`:

- archive.jsonl の直近 N エントリ (デフォルト N=5) を参照
- valid_parent かつ audit > 0 のエントリのみ対象
- 直近ウィンドウ内のベスト audit スコアが歴代ベストを超えていなければ「停滞」
- 終了コード 0 = 停滞、1 = 改善中

`--meta` フラグでメタエージェントを強制トリガーすることも可能。

### 3.4 メタエージェント

`run_meta_agent()` 関数:

1. archive.jsonl の直近 10 エントリからスコアサマリーを生成
2. `render_template("meta-propose")` でメタプロンプトを展開
3. Hermes Agent (proposer) を実行 — テンプレートファイルを読み、編集する
4. テンプレートに変更があれば:
   - 変数プレースホルダーの健全性チェック
   - `prompts/.version` をインクリメント
   - `git tag meta-v{N}` でバックアップ
   - コミット & ��ッシュ

**メタエージェントが見る情報:**
- 全テンプレートファイル (7 + manifest)
- failed-approaches.md
- 現在のベスト SKILL.md
- 直近 10 イテレーションのスコア推移

**メタエージェントの編集スコープ:**

| 対象 | Phase 3a (MVP) | Phase 3b (拡張) |
|------|----------------|-----------------|
| プロンプトテンプレート 7 ファイル | 編集可 | 編集可 |
| failed-approaches.md の構造 | 不可 | 編集�� |
| MAX_ADDED_LINES / escape 閾値 | 不可 | 編集可 |
| auto-improve.sh 制御フロー | 不可 | 不可 |
| ベ��チマーク定義 / モデル | 不可 | 不可 |
| meta-propose.txt 自体 | 不可 | 不可 (Phase 3c) |

### 3.5 ロールバック機構

`check_meta_rollback()` 関数:

- メタ編集後のテンプレートバージョンで 3 イテレーション以上実行された時点で評価
- 直近 3 回の平均 audit スコアが前バージョンのベストより 5pp 以上低下していれば発動
- `git checkout meta-v{N-1} -- prompts/` で前バージョンに復元
- `prompts/.version` もデクリメント

---

## 4. 関連研究との対応

| 概念 | HyperAgents (Meta) | Meta-Harness (Stanford) | 本実装 |
|------|---------------------|-------------------------|--------|
| メタレベル編集 | agent ソースコード全体 | harness コード全体 | プロンプトテンプレート (7 ファイル) |
| 安全機構 | なし (暗黙の tree archive) | なし | git tag + スコア退行ロールバック |
| バージョン追跡 | tree archive (genid) | 不明 | archive.jsonl + template_version |
| 停滞検知 | なし (固定回数) | なし | audit スコアの窓内最高値比較 |
| 再帰的改善 | あり (meta-agent が自身を編集) | なし | Phase 3c で予定 |

---

## 5. 検証計画

### Step 6: 検証ラン

1. `./auto-improve.sh --meta -n 1` でメタエージェント初回動作を確認
2. テンプレート抽出後の状態で 10 イテレーション → ベースライン取得
3. メタエージェントを発動（停滞検知 or `--meta`）
4. さらに 10 イテレーション → 効果測定
5. **主指標: Audit スコア** (stdev ~2.5% で改善検出可能)
6. Compare Pro は参考値 (stdev ~10% で検出困難)

### 成功基準

- メタエージェントがテンプレートを有意に変更し、構文エラーなく適用されること
- メタ編集後の 10 イテレーションで、ベースライン期間より audit スコアが改善 (or 同等以上)
- ロールバック機構が退行時に正しく発動すること

---

## 6. 今後の展望

### Phase 3b: 拡張スコープ
- failed-approaches.md の構造をメタエージェントが再編成
- MAX_ADDED_LINES、escape 閾値をメタエージェントが調整

### Phase 3c: 再帰的メタ
- meta-propose.txt 自体をメタエージェントが編集 (HyperAgents の再帰的改善に相当)
- 安全層として、必須セクションの存在を検証するバリデータを凍結

### ACPX 統合
- セッション永続化でトークン効率改善
- 構造化出力で grep ベースのパース脆弱性を解消
- プロンプトキューで並列テンプレート探索 (A/B テスト)

---

## 7. 参考資料

- [auto-improve_update_plan.md](../auto-improve_update_plan.md) — Phase 1〜2 の全記録、§10 収束判定、§11 関連研究比較
- [HyperAgents (arXiv:2603.19461)](https://arxiv.org/abs/2603.19461) — 自己参照的自己改善エージェント
- [Meta-Harness (arXiv:2603.28052)](https://arxiv.org/abs/2603.28052) — LLM による harness 自動最適化
- [Agentic Code Reasoning (arXiv:2603.01896)](https://arxiv.org/abs/2603.01896) — SKILL.md の元論文
