# Iteration 31 — 改善案レビュー

## 総評
提案の問題設定自体は妥当です。現行 Guardrail 2 は「relevant code path を trace せよ」までは言っていますが、**どこまで trace すればよいか**が曖昧で、実装者が指摘する「コード差分を見つけた時点で trace 完了とみなす」ショートカットを許している可能性があります。今回の変更は、その終着点を **"assertion または PASS/FAIL を直接決める条件"** と明示するもので、出力書式の変更や片側判定の閾値操作ではなく、**推論プロセスの完了条件の明確化**です。

ただし、提案書のカテゴリ整理には修正が必要です。**F は未試行ではありません**（iter-8, iter-9, iter-25 で F 系の試行あり）。今回の提案は、実装形式としては E（文言明確化）ですが、**実質的には F（論文の error analysis にある incomplete reasoning chains の compare への再適用）**として捉えるのが正確です。

結論としては、**小さく、対称で、過去の失敗と完全同型ではない**ため、私は承認寄りです。

---

## 1. Web 検索に基づく妥当性評価（mcp / DuckDuckGo）

### 検索結果と要点

| URL | 要点 | 本提案への含意 |
|---|---|---|
| https://arxiv.org/abs/2603.01896 | *Agentic Code Reasoning* は、semi-formal reasoning の有効性を explicit premises / execution-path tracing / formal conclusion にあるとし、失敗要因として **incomplete reasoning chains** と **downstream handling の見落とし**を挙げる。 | 今回の「trace の終着点を明示する」方向は、論文の失敗分析と整合する。特に compare で「差分発見で止まる」ショートカット抑制として筋が良い。 |
| https://aclanthology.org/2024.emnlp-main.629/ | *Code Prompting Elicits Conditional Reasoning Abilities in Text+Code LLMs* は、入力表現・構造化が entity/state tracking を改善すると報告。 | 文言の小修正でも、**追うべき対象・終点が明確化されると state tracking が安定する**という一般知見と整合する。今回の変更はまさに「trace の終点」を構造化するもの。 |
| https://research.google/blog/language-models-perform-reasoning-via-chain-of-thought/ | Chain-of-thought は複雑問題を中間ステップへ分解することで性能を改善する、という一般知見。 | 「関連コードを読んだ」だけではなく「観測結果を決める地点まで到達した」というステップ分解の明示は、推論の抜け漏れ防止に資する。 |
| https://link.springer.com/content/pdf/10.1007/s10009-025-00780-7.pdf | *Interleaving static analysis and LLM prompting...* は、LLM の推論を static analysis 的なフロー追跡と組み合わせる方向を示す。 | 実務的にも、**中間差分ではなく最終的な観測点・sink までの到達確認**が重要という発想を補強する。 |

### 学術的・実務的評価

- **学術的には妥当**です。特に ACR 論文の error analysis と強く整合します。今回の変更は、新しいテンプレート欄や判定ルールを増やすのではなく、既存の trace 義務の **終了条件** を明確化するだけなので、研究コアから逸脱しません。
- **実務的にも妥当**です。静的解析やレビューでの誤判定は、「差分がある」ことと「観測可能な結果が違う」ことの混同から生じやすく、assertion / outcome-determining condition まで追うのは標準的な良い習慣です。
- ただし、検索結果が直接支持しているのは「downstream まで追うべき」という一般原理であり、**今回の具体文言そのもの**を実証しているわけではありません。したがって根拠の強さは「中程度〜強いが間接的」です。

---

## 2. Exploration Framework のカテゴリ選択は適切か？同一カテゴリ既試行性は？

### 判定
**半分適切、半分不正確**です。

### 理由
- 実装の形は 1 文の文言修正なので **E（表現・フォーマット改善）** には確かに見えます。
- しかし提案の本質は、論文の error analysis にある **incomplete reasoning chains** を compare の Guardrail に再投影することなので、**主カテゴリは F、E は実装手段**とみる方が自然です。

### 既試行性
- **カテゴリ E は明確に既試行**です（BL-3, BL-11, BL-15, BL-16）。
- 提案書は **F を「未試行」扱い**していますが、これは不正確です。少なくとも以下は F 系です。
  - iter-8: localize の divergence analysis を compare に応用
  - iter-9: propagation check の導入
  - iter-25: assertion 到達時の key value を追う案
- したがって、「未試行カテゴリから選んだ」という主張は成立しません。

### ただし重要な点
**同一カテゴリであること自体は却下理由にはなりません。** Objective.md も「同一カテゴリでも異なるメカニズムなら可」としています。今回のメカニズムは、
- テンプレート欄追加でもなく
- ラベル生成でもなく
- DIFFERENT 側だけの追加証明義務でもなく
- Guardrail の trace 完了条件の明確化
であり、過去の E/F 系失敗とは仕組みが異なります。

---

## 3. EQUIV / NOT_EQ の両方への影響と、変更前との差分分析

## 変更前
現行 Guardrail 2:

> Trace each test through the relevant code path before asserting PASS or FAIL.

これは「trace せよ」とは言うものの、
- どの地点まで到達すれば PASS/FAIL を主張できるのか
- 差分発見時点で止まってよいのか
- 中間関数の違いを outcome の違いと見なしてよいのか

が曖昧です。

## 変更後の実効的差分
提案文:

> Trace each test through the relevant code path, reaching the assertion or condition that directly determines PASS or FAIL, before asserting either outcome.

実効差分は、**trace の終点が明示される**ことです。これは「trace したつもり」の浅い追跡を減らす方向に働きます。

## EQUIV への影響
- **改善可能性は比較的高い**です。
- 現在の持続的失敗パターンが「コード差分発見 → そのまま DIFFERENT」なら、この修正はそこを直接狙っています。
- 特に、`relevant code path` を読んだだけでなく、**その差分が最終的なテスト観測点に届くか**を意識させる点で、EQUIV 偽陽性の抑制に効くはずです。

## NOT_EQ への影響
- **小さな回帰リスクはありますが、BL-2 型ほど強くはない**と見ます。
- 追加されるのは新フィールドでも新ステップでもなく、既存の trace 義務の終点明確化だけです。したがって、NOT_EQ の立証責任を大幅に引き上げるほどではありません。
- 一方で、真の NOT_EQ でも trace を最後までやり切る必要があるため、若干のターン増・慎重化はありえます。

## 一方向にしか作用しないか？
**いいえ、今回の差分は一方向専用ではありません。**

ここが iter-26 / BL-2 / BL-14 と決定的に違います。
- それらは「DIFFERENT を言う前に〜せよ」という形で、**NOT_EQ 側だけ**に追加義務が乗っていました。
- 今回は `before asserting either outcome` と明記しており、**PASS / FAIL のどちらを主張する場合にも同じ終点到達を要求**しています。

したがって、変更前との差分で見ても
- SAME/EQUIV 側にも
- DIFFERENT/NOT_EQ 側にも
同じ種類の浅い trace 禁止が掛かります。ここは提案者の主張を支持できます。

---

## 4. failed-approaches.md のブラックリストおよび共通原則との照合

## BL との関係

### BL-2（NOT_EQ 判定の証拠閾値・厳格化）
- **非該当寄り**です。
- BL-2 は「NOT_EQ と言うための要件を追加する」変更でした。
- 今回は「PASS/FAIL どちらを言うにも終点まで trace せよ」という一般ルールであり、**片側の閾値操作ではない**。

### BL-6（Guardrail 4 の対称化）
- **同型ではありません。**
- BL-6 の失敗は「表面上は対称でも、変更前との差分では NOT_EQ 側だけに新規制約が乗った」ことでした。
- 今回の差分は、現行 Guardrail 2 の曖昧さを埋めるもので、PASS/FAIL 両方に同じく効きます。実効差分が片側だけではありません。

### BL-11 / BL-16（注釈によるアンカリング）
- **注意は必要だが、同一ではない**です。
- 今回も `assertion` という語は入るので、ある種のアンカーになる懸念はあります。
- しかし BL-11/16 と違って、
  - 観測点リストを列挙しない
  - 新しい説明フレームを追加しない
  - `Comparison:` 直前の出力姿勢調整ではない
 ため、アンカリングの強さはかなり弱いです。
- また `assertion or condition that directly determines PASS or FAIL` としている点が重要で、**単一 assert 固定ではなく、テスト結果決定条件一般**を含んでいます。

## 共通原則との照合

- **#1 判定の非対称操作**: 抵触しない
  - 両方向に同じ trace 完了条件を課している。

- **#2 出力側の制約**: 抵触しにくい
  - 出力形式ではなく、trace プロセスの完了条件を明確化している。

- **#3 探索量の削減**: 抵触しない
  - むしろ浅い trace を禁止するので、探索は微増方向。

- **#4 同じ方向の変更は表現を変えても同じ結果**: 直接抵触しない
  - 過去の失敗は多くが NOT_EQ 側の閾値上げや記録欄追加だった。今回はそのどちらでもない。

- **#5 入力テンプレートの過剰規定**: 抵触しにくい
  - 新しいフィールド・書式追加がない。

- **#6 対称化の実効差分**: 抵触しない
  - 今回の差分は genuinely 両方向。

### 小さな懸念
完全に無懸念ではありません。`assertion` という語が入ることで、モデルがテスト outcome を単一 assertion へ還元する方向に少し引かれるリスクはあります。ただし `or condition that directly determines PASS or FAIL` がその狭窄をかなり和らげています。

**総合すると、ブラックリスト再発とまでは判断しません。**

---

## 5. 全体の推論品質がどう向上すると期待できるか

期待できる改善は、主に次の 3 点です。

1. **浅い trace の抑制**
   - 「変更コードに到達した」ことと「テスト outcome が変わる」ことを同一視しにくくなる。

2. **比較の観測点が明確になる**
   - 内部差分ではなく、最終的な PASS/FAIL 決定点まで辿ることが求められるため、compare の判断根拠がより behavior-centric になる。

3. **Guardrail 5 との連携が強まる**
   - Guardrail 5 は downstream handling を見落とすな、という一般則でした。
   - 今回は Guardrail 2 側で「少なくともどこまで辿るか」が明示されるため、Guardrail 5 がより実行可能な形になります。

つまり、今回の変更は新しい能力を足すというより、**既存の semi-formal reasoning を最後まで完遂させるための曖昧さ除去**として価値があります。

---

## 6. 承認するか、修正を求めるか

### 結論
**承認します。**

### ただし修正コメント
提案本文の次の点は直した方がよいです。

1. **カテゴリ記述の修正**
   - 「E 主、F 補」よりも、**F 主、E は実装形式**と書く方が正確です。
2. **F 未試行という記述の削除**
   - iter-8 / iter-9 / iter-25 があるため不正確です。
3. **Guardrail 5 との差分の明示**
   - 「Guardrail 5 は downstream handling の有無、今回の変更は trace の終着点」と整理すると、提案の新規性がより明確になります。

これらは proposal の説明改善であって、**変更案そのものを否定する理由ではありません**。

---

**承認: YES**
