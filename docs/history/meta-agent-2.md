# meta-agent-2/auto-improve branch record (2026-04-20 to 2026-04-24)

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

### 19.8 メタエージェントのガバナンス不在と v16 崩壊の教訓 (2026-04-22)

#### v16 で何が起きたか

iter-23 で停滞検知→メタエージェント発火→テンプレート v15→v16 に更新。
v16 の主な変更: 参照ファイルを 6→2 に削減（Objective.md, README.md, docs/ を除外）。

結果:
- iter-23: compare 65%（v15 時代の平均 68.6% より低下）
- iter-24, 25: 却下
- iter-26: 監査 FAIL
- iter-27: **compare 15%**（崩壊）
- iter-28: API エラーで停止

**参照ファイルの削減**により、proposer と auditor が判断基準（Exploration Framework, Audit Rubric, 研究コアの設計根拠）を参照できなくなり、提案と監査の品質が崩壊した。

#### 根本原因: メタエージェントにガバナンスがない

SKILL.md の改善パイプライン:
```
propose → discuss → implement → audit → benchmark → (fail → rollback)
```
4 段階のチェック + ベンチマークによる事後検証 + 自動ロールバック。

メタエージェントのテンプレート改善:
```
meta-propose → 即適用 → (次のスコアで事後判定のみ)
```
**レビューなし、事前チェックなし。** 唯一のガードレールはスコア退行時のロールバックだが、複数 iter 経過後にしか発動せず、今回は API エラーで発動前に停止。

#### 構造的な非対称

| | SKILL.md 改善 | テンプレート改善 (現状) |
|---|---|---|
| 提案 | proposer (gpt-5.4) | meta-agent (gpt-5.4) |
| レビュー | discuss + audit (2段階) | **なし** |
| 事前検証 | Audit Rubric (6軸) | **なし** |
| 事後検証 | benchmark (即時) | 次 iter のスコア (遅延) |
| ロールバック | 自動 (親復元) | 自動 (退行検知) だが遅い |
| 変更の粒度制限 | 15 行 hard limit | **なし** |

#### 教訓

1. **自己改善の各レベルにガバナンスが必要**: HyperAgents の論文では「メタレベルの改善自体が編集可能」とあるが、編集可能であることと無審査であることは違う
2. **一見合理的な最適化が破壊的になりうる**: 「トークン節約のためにファイル参照を減らす」は合理的に見えるが、判断基準の喪失→品質崩壊を招いた
3. **事後検証（ロールバック）だけでは不十分**: ロールバック判定は「N iter 経過後の平均退行」で発動するため、急激な崩壊に対応が遅い
4. **メタ改善にも discuss/audit 相当のレビューパイプラインが必要**

#### 次のアクション

メタエージェントのテンプレート改善に監査プロセスを導入する。具体的なパイプライン設計は次節で検討。

### 19.9 参考文献・関連プロジェクト (2026-04-24)

#### AutoAgent (kevinrgu/autoagent)
- URL: https://github.com/kevinrgu/autoagent
- 概要: メタエージェントが agent.py を自動修正→ベンチ→keep/discard を繰り返す自己改善フレームワーク
- 我々との類似: ベンチマーク駆動の自己改善ループ、`program.md` による目標定義（我々の Objective.md に相当）
- 我々の優位: 遺伝的選択 (score_prop)、メタ監査、failed-approaches による失敗知識蓄積、引き算探索 (カテゴリ G)
- AutoAgent の優位: Docker 隔離、シンプルな single-file 設計、agent.py 全体を修正可能

#### SGS - Scaling Self-Play with Self-Guidance (LukeBailey181/sgs)
- URL: https://github.com/LukeBailey181/sgs
- 論文: 非対称 self-play で 7B モデルが 671B モデルの性能を超える
- 核心: 1 つのモデルが Solver / Conjecturer / Guide の 3 役を演じる自己改善ループ
- 我々への示唆:
  - **Conjecturer（ベンチマーク自動生成）の欠如**: 我々のベンチは固定 20 ペア。SGS のように「解ける限界の問題を自動生成」すれば局所最適を避けられる
  - **Guide の重要性**: SGS でも Guide を外すと性能低下。我々の meta-audit 導入（v16 崩壊→回復）と同じ知見
  - **難易度カリキュラム**: without でも解ける簡単なケースではなく、with_skill でも失敗するケースを重点的に増やす方向
- 差分: SGS は形式証明（Lean 4 で自動検証可能）、我々はコード推論（検証に LLM Judge が必要でコストが高い）

#### smolvm (smol-machines/smolvm)
- URL: https://github.com/smol-machines/smolvm
- 概要: 200ms 起動の軽量 VM。ハードウェアレベル隔離、ネットワーク opt-in、`.smolmachine` パッケージング
- フレームワーク化への活用: auto-improve ループを `.smolmachine` にパッケージングして配布可能。Docker daemon 不要、依存ゼロ

---

## 20. meta-agent-2/auto-improve ブランチ最終結果 (2026-04-24)

### iter-46 ベースライン確定 (gpt-5.4, 5 ラン)

| Run | without | with | Delta |
|-----|---------|------|-------|
| 1 | 60% | 75% | +15pp |
| 2 | 60% | 60% | 0 |
| 3 | 60% | 70% | +10pp |
| 4 | 55% | 70% | +15pp |
| 5 | 60% | 70% | +10pp |
| **平均** | **59.0%** | **69.0%** | **+10.0pp** |

### iter-0 → iter-46 の改善

| 指標 | iter-0 (ベースライン) | iter-46 (最終) | 改善 |
|------|---------------------|---------------|------|
| with_skill avg | 66.7% | **69.0%** | +2.3pp |
| Delta (with - without) | +5.8pp | **+10.0pp** | 1.7 倍 |

### iter-46 の変更内容

Compare テンプレートの `NO COUNTEREXAMPLE EXISTS` セクションを改善:
- Before: 汎用的な「反例はこう見えるはず→検索→見つからない」
- After: 「既に見つけた意味差分を名指しし、その差分が具体的テスト/入力で同じ assertion outcome になるか確認する」

この変更により EQUIV 判定の精度が改善。差分を見つけても汎用的な不在証明で EQUIV にしてしまう偽 EQUIV を抑制。

### ブランチ全体の統計

- **総 iter**: 46 (iter-1〜46)
- **Scored**: 31/47 (66%)
- **ベスト**: 90% (iter-46, 単発)、安定ベスト 75% (4 回)
- **平均 (scored)**: 66.0%
- **メタエージェント発火**: 1 回 (v16, 失敗→ロールバック→meta-audit 導入)

### ブランチで得られた知見

1. **Compare 特化が有効**: SKILL.md を 483→269 行に絞り、認知負荷を減らしたことで提案の質が向上
2. **gpt-5.4 proposer が効果的**: gpt-5.2 より多様で質の高い提案が出る。scored 率 37%→66%
3. **15 行制限の緩和が有効**: 5 行では構造的な変更ができなかった
4. **メタ監査 (meta-audit) の必要性**: v16 でテンプレート崩壊→meta-audit 導入で防止
5. **75% の壁**: 20 ペアのベンチマークでは分散が大きく、安定した改善と偶然の区別が困難
6. **EQUIV 判定が主要ボトルネック**: NOT_EQUIV は安定して高いが、EQUIV の精度が揺れる

### 確定版 SKILL.md

iter-46 の SKILL.md を本ブランチの最終成果とする。
- Compare 特化版 (269 行)
- 本体 SKILL.md (SKILL.md.full) へのマージは別途実施
