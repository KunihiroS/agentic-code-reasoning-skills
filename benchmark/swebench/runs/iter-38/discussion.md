# Iteration 38 — 監査コメント

## 総評
結論から言うと、**提案の方向性自体は妥当で、実装に進んでよい**と考えます。特に、`compare` の Claim を既存 PREMISE（P3/P4）へ接続させる発想は、README / docs/design.md / 原論文が強調する **certificate-based reasoning** と整合しています。

ただし、proposal の説明には重要な補足が必要です。**カテゴリ F 自体も、localize の claim→premise 接続の compare への移植も、完全な新規ではありません。** iter-9 と iter-28 で近い方向は既に試されています。今回の新規性は「premise 参照を COUNTEREXAMPLE の最終出力ではなく、per-test の ANALYSIS Claim に前倒しする点」にあります。ここを明確に言い換えるべきです。

---

## 1. 既存研究・コード推論知見にもとづく評価（MCP 利用）

### MCP での確認結果
DuckDuckGo MCP の `ddg_search_search` は今回も `No results were found` となったため、同じ MCP サーバーの `ddg_search_fetch_content` で既知の公開 URL を確認しました。よって以下は **MCP を使った Web 確認結果**です。

### 参照 URL と要点
1. **Agentic Code Reasoning**  
   URL: https://arxiv.org/abs/2603.01896  
   要点:
   - semi-formal reasoning は **explicit premises / execution path tracing / formal conclusions** を要求する。
   - 構造化テンプレートは *certificate* として働き、ケース飛ばしや unsupported claims を防ぐ。
   評価:
   - 今回の提案はまさに「Claim を PREMISE に結び直す」変更であり、**研究コアの強化**として学術的にかなり自然。

2. **Chain-of-Thought Prompting Elicits Reasoning in Large Language Models**  
   URL: https://arxiv.org/abs/2201.11903  
   要点:
   - 中間推論ステップの明示は複雑推論の性能を改善しうる。
   - ただし「中間ステップなら何でもよい」わけではなく、粒度と形式が重要。
   評価:
   - `because` 節を「trace + P[N] との関係」まで明示させるのは、**妥当な中間推論の具体化**。
   - 一方で、過度に観測点を固定する wording は逆効果になりうるため、その点の監視は必要。

3. **ReAct: Synergizing Reasoning and Acting in Language Models**  
   URL: https://arxiv.org/abs/2210.03629  
   要点:
   - reasoning trace と情報取得行動を往復させると、hallucination と error propagation を抑えられる。
   - 効果が出やすいのは、単なる出力整形よりも、探索時の認知ループが変わるとき。
   評価:
   - 今回の変更は wording 変更ではあるが、**COUNTEREXAMPLE ではなく ANALYSIS Claim に作用する**ため、出力末尾の整形よりは探索中の思考に入り込みやすい。
   - この点で BL-15 型の「最終文言だけ変える」案よりは実務的に期待できる。

4. **LLMDFA: Analyzing Dataflow in Code with Large Language Models**  
   URL: https://arxiv.org/abs/2402.10754  
   要点:
   - reliable なコード解析には hallucination 抑制のための **subtask decomposition** と、小さな意味単位への整合が重要。
   - データ依存や意味追跡を局所的・明示的に扱うことが有効。
   評価:
   - 「コード差異がある」から直ちに FAIL に飛ばず、**その差異が P3/P4 の記述するテスト動作にどう接続するか**を小さな単位で示させる今回の案は、実務的にも理にかなう。

### 学術的・実務的な総合評価
- **学術的には妥当**です。premise→claim の接続を強める方向は原論文と整合します。
- **実務的にも一定の妥当性があります。** 既存の失敗は「コード差異の発見」で止まり、「テストが見ている動作」との接続が抜けることでした。今回の変更はそこを直接突いています。
- ただし、提案の価値は「新規カテゴリ」ではなく、**既に有効だった premise 参照を、より上流の ANALYSIS 段階に移すこと**にあります。

---

## 2. Exploration Framework のカテゴリ選択は適切か？同一カテゴリ既試行との関係

### 判定
**カテゴリ F を選ぶこと自体は妥当**です。README / docs/design.md が示す研究コアに沿った「原論文の未活用アイデアの再導入」と言えます。

ただし、proposal の「未試行」主張は正確ではありません。

### 既試行との関係
- **iter-9**: localize の divergence claim を compare に持ち込もうとした F 系試行。
- **iter-28**: `COUNTEREXAMPLE` に `By P[N]` を追加し、claim→premise 接続を compare に移植しようとした F 系試行。
- **iter-29 / BL-15**: `By P[N]` を削除するリバートは失敗。これは逆に、**premise 参照自体には価値があった**ことを示唆する。

したがって今回の正確な位置づけは、
- **カテゴリ F の再試行** であり、
- **未試行なのは「COUNTEREXAMPLE ではなく ANALYSIS Claim に premise 接続を入れる」点**
です。

この意味でカテゴリ選択は適切ですが、discussion と rationale では **iter-28 / BL-15 との差分**を明記すべきです。

---

## 3. EQUIV / NOT_EQ への影響と、変更前からの実効差分分析

### 変更前との差分
変更前:
```text
Claim C[N].1: ... because [trace through code — cite file:line]
```

変更後:
```text
Claim C[N].1: ... because [trace through code and show whether the behavior in P[N]
is satisfied or violated — cite file:line]
```

この差分の本質は、単なる wording 追加ではなく、**Claim の終端条件を「P[N] に書かれたテスト動作」へ固定すること**です。

### EQUIV への影響
**改善可能性は高い**です。

現状の EQUIV 誤りは、
1. コード差異を見つける
2. その差異がテスト観測動作に効くか未確認のまま FAIL を書く
というショートカットです。

今回の変更では、FAIL/PASS どちらの Claim でも「そのトレースが P3/P4 の動作を満たすのか壊すのか」を言語化しなければならないため、
- コード差異はあるが P3/P4 の動作は両方で満たされる
- したがって PASS/PASS で SAME
という経路が出やすくなります。

### NOT_EQ への影響
**軽微なリスクはあるが、BL-2 型ほど強くはない**と見ます。

理由:
- 今回は `assertion` や `exception` のような狭い観測点を固定していない。
- 参照先は既存の P3/P4 であり、テンプレート外の新ラベルを増やしていない。
- `violated` だけでなく `satisfied` も同じ Claim 形式で要求されるため、見かけの対称性だけでなく、**実効差分も比較的対称**。

一方で懸念もあります。
- P3/P4 が粗く書かれた場合、その粗い前提に Claim 全体が引っ張られる。
- 真の NOT_EQ でも、P3/P4 記述が弱いと「violated」を書き切れず曖昧化する可能性はある。

ただしこれは新しい問題というより、**既存の PREMISES 品質に依存する既知の問題**です。今回の変更が一方向にだけ強く作用する、とは現時点では言いにくいです。

### 一方向にしか作用しないか？
**今回は「一方向にしか作用しない」とまでは言えません。**

BL-6 / BL-14 型の失敗は、変更前との差分が実質的に NOT_EQ 側の追加立証になっていました。今回の差分は、
- FAIL を書くときは「P[N] を violated」
- PASS を書くときは「P[N] を satisfied」
の双方を要求します。

つまり新しい義務は **DIFFERENT 方向だけでなく SAME 方向にも実効差分を持つ**ため、BL-6 型の再発と断定するのは早いです。

---

## 4. failed-approaches.md のブラックリスト・共通原則との照合

### 抵触しないと見る点
- **BL-2（NOT_EQ 閾値引き上げ）**
  - 今回は NOT_EQ のみ追加証明を要求していない。
  - PASS 側にも「P[N] satisfied」を要求するため、実効差分は両方向にある。

- **BL-11 / BL-16（観測点アンカリング）**
  - `assertion / exception / observation point` の固定ラベルを導入していない。
  - 参照先は既存の P3/P4 であり、観測カテゴリの列挙ではない。

- **BL-8 / BL-13（受動的記録フィールド追加）**
  - 新欄追加ではなく、既存 Claim の `because` 節の意味を変えるだけ。
  - 記録欄の増設ではない点は重要。

- **共通原則 #2（出力側の制約）**
  - COUNTEREXAMPLE や最終結論の wording ではなく、ANALYSIS の per-test Claim を変更している。
  - これは BL-15 より明確に upstream です。

### 注意が必要な点
- **共通原則 #5（入力テンプレートの過剰規定）**
  - P[N] 参照が強すぎると、P3/P4 に書かれていない副作用や例外伝播を見落とす可能性はある。
  - ただし今回は P3/P4 自体を狭めるのではなく、既存の P3/P4 に接続させるだけなので、BL-5 ほど強い制約ではない。

- **カテゴリ新規性の記述不足**
  - これはブラックリスト抵触というより、proposal の整理不足です。
  - iter-28 と BL-15 を踏まえた位置づけ修正は必要です。

### 監査判断
**ブラックリスト実質同型とは判断しません。**

近いのは iter-28 の `By P[N]` ですが、あれは COUNTEREXAMPLE 側、今回は ANALYSIS Claim 側です。これは「同じ premise 参照」でも、**作用するタイミングが output 後段から reasoning 中段へ移る**ので、実効差分があります。

---

## 5. 全体の推論品質がどう向上すると期待できるか

期待できる改善は次の 3 点です。

1. **コード差異からテスト差異への短絡を減らす**  
   ただ差分を見つけるのでなく、「その差分が P3/P4 の動作をどう満たす/壊すか」を必ず一段挟ませることで、浅い FAIL 判定を減らせる。

2. **Claim の証明責任をテスト意味論へ戻す**  
   Claim が単なるコードトレース要約ではなく、「このテストが何を検査するか」という証明書に接続されるため、reasoning certificate としての質が上がる。

3. **counterexample 生成の前段階を強くする**  
   現在の Compare は最終 COUNTEREXAMPLE でのみ差異をまとめがちだが、per-test Claim 段階から P[N] 接続を入れると、最後の結論も自然に安定しやすい。

要するに、今回の変更は「どの観測点を見よ」という新フレームの追加ではなく、**既存の番号付き前提を per-test Claim の推論終端として使い直す**点に価値があります。

---

## 6. 結論

### 推奨
- **実装してよい**です。
- ただし proposal / rationale では次の 2 点を必ず修正してください。
  1. **カテゴリ F は既試行であり、今回の新規性は iter-28 の premise 接続を ANALYSIS Claim へ前倒しする点**だと明記すること。
  2. **BL-15（`By P[N]` 削除の失敗）との連続性**を明記し、「premise 参照そのものは有望だったが、最終出力だけでは弱かった。今回は分析中に移す」という説明に改めること。

### 最終判断
**承認: YES**
