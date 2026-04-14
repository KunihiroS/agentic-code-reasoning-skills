# Iteration 28 — Discussion

## 総評

結論から言うと、この提案は狙い自体は妥当です。Step 5 の反証確認を「推論だけで済ませる」抜け穴を減らしたい、という問題意識は `README.md` と `docs/design.md` が強調する certificate-based reasoning と整合しています。

ただし、今回の文言変更は

1. 既存のテンプレート・チェック項目とかなり重複しており実効差分が小さいこと、
2. 実質的にはカテゴリ E というより D（自己チェック強化）として作用していること、
3. `failed-approaches.md` の「自己監査で特定の検証経路を半必須化するな」という失敗原則にかなり近いこと、
4. `code inspection` という「行為」を `file:line reference` という「成果物」に置き換えるため、かえって形式的準拠を助長するおそれがあること、

から、監査としては非承認寄りです。

---

## 1. 既存研究との整合性

### 参照した外部情報

DuckDuckGo MCP の search は複数回試しましたが結果が返らなかったため、DuckDuckGo MCP の fetch で公開 URL を直接確認しました。少なくとも以下の文献との整合性は確認できます。

1. Agentic Code Reasoning
   - URL: https://arxiv.org/abs/2603.01896
   - 要点:
     - semi-formal reasoning は、明示的な premises、execution-path tracing、formal conclusion を要求することで、unsupported claims を減らす「certificate」として機能する。
     - この提案の「反証確認に実証的痕跡を求める」という方向性は、論文のコア思想とは整合する。
   - 本件への含意:
     - 「推論だけで反証したことにする」状態を避けたい、という問題設定は研究と一致。
     - ただし論文のコアは“証拠付き追跡全体”であり、Step 5.5 の 1 行を artifact 指向に寄せることが最適解かは別問題。

2. Chain-of-Verification Reduces Hallucination in Large Language Models
   - URL: https://arxiv.org/abs/2309.11495
   - 要点:
     - 初稿の回答を独立した verification question で検証することで hallucination を減らす、という趣旨。
     - 重要なのは「別経路の検証」を入れることであり、単なる表現変更より verification process の独立性が効く。
   - 本件への含意:
     - Step 5 の反証を強化する方向自体は妥当。
     - ただし今回の変更は verification の独立性を増やすというより、「記録様式」を狭める変更で、研究上の強い裏付けは弱い。

3. Language Models Don't Always Say What They Think
   - URL: https://arxiv.org/abs/2305.04388
   - 要点:
     - CoT はもっともらしいが不忠実な説明になりうる。
     - したがって「説明を書かせる」だけでは十分でなく、説明と外部証拠の対応づけが必要。
   - 本件への含意:
     - 反証ステップに evidence を要求したいという意図は妥当。
     - ただし `file:line reference` は evidence の見た目であって、実際に counterexample search をした保証にはならない。

4. ReAct: Synergizing Reasoning and Acting in Language Models
   - URL: https://arxiv.org/abs/2210.03629
   - 要点:
     - reasoning と acting を交互に行い、外部情報取得を伴うことで hallucination を抑える。
   - 本件への含意:
     - 「reasoning alone ではなく、少なくとも一度は search / inspection を挟め」という現行文言は ReAct 的な発想と噛み合う。
     - むしろ現行の `actual file search or code inspection` は action を要求しており、提案後の `file:line reference or explicit search` より研究的には自然です。

### 研究整合性の結論

方向性は整合していますが、実装手段はやや弱いです。研究が支持しているのは「反証の実作業」と「別経路の検証」であって、「file:line という書式への置換」そのものではありません。

---

## 2. Exploration Framework のカテゴリ選定は適切か

提案者はカテゴリ E（表現・フォーマット改善）としていますが、私は「表向きは E、実質は D 寄り」と見ます。

理由:

- 変更対象は Step 5.5 の mandatory self-check です（`SKILL.md:141-148`）。
- ここは単なる説明文ではなく、結論直前の通過条件として作用します。
- `code inspection` を `file:line reference` に変えることで、何をもって self-check を満たすかが変わります。
- これは wording polish 以上に、自己監査ゲートの許容証拠を変更する操作です。

したがって、カテゴリ E だと言い切るのはやや楽観的です。分類上は「E の衣を着た D」であり、`Objective.md` の Exploration Framework の意味でいうと、カテゴリ D の副作用評価を避けてはいけません。

---

## 3. EQUIVALENT 判定と NOT_EQUIVALENT 判定の両方への作用

## 3.1 変更前の既存ガードレール

現行 `SKILL.md` には既に以下があります。

- Step 5.5 の 1 項目目:
  - `Every PASS/FAIL or EQUIVALENT/NOT_EQUIVALENT claim traces to a specific file:line` (`SKILL.md:145`)
- compare テンプレートの NO COUNTEREXAMPLE EXISTS:
  - `Searched for:` と `Found:` を書くこと、`Found` では file:line か search details を記録することがすでに要求されている (`SKILL.md:234-240`)
- compare テンプレートの COUNTEREXAMPLE:
  - NOT_EQUIVALENT では diverging assertion の `test_file:line` まで要求している (`SKILL.md:228-232`)

つまり、今回の変更はゼロから新しい証拠主義を導入するのではなく、既存要求の一部を Step 5.5 で言い換えて再強調する性格が強いです。

## 3.2 EQUIVALENT への作用

ここには一定の改善余地があります。

- EQUIVALENT 側では「反例がない」と言うため、形式的・空疎な refutation になりやすい。
- 提案はその穴を狙っており、狙い自体は正しいです。
- ただし compare テンプレートの `NO COUNTEREXAMPLE EXISTS` は現状でもかなり具体的で、`Searched for:` と `Found:` を要求済みです。

したがって、改善が出るとしても「既存要求の再想起による軽微な改善」に留まる可能性が高いです。

さらに懸念として、`file:line reference` は「Step 5 で実際に反証探索した」ことを保証しません。既に前段で読んだ箇所を引用して終えるだけでも、形式上は満たせます。これは proposal が狙う failure mode を完全には塞ぎません。

## 3.3 NOT_EQUIVALENT への作用

こちらへの改善はかなり限定的です。

- NOT_EQUIVALENT はもともと counterexample と diverging assertion を示す必要があり、証拠密度が高い (`SKILL.md:228-232`)。
- そのため Step 5.5 の 3 項目目を `file:line reference` 化しても追加利益は小さいです。
- 実効的には EQUIVALENT 側の形式主義を少し締める一方、NOT_EQUIVALENT 側にはほぼ既存要求の重複としてしか働きません。

## 3.4 片方向性の評価

結論として、この変更はかなり片方向です。

- 主作用: EQUIVALENT 側の「反例なし」宣言をやや厳しくする
- 副作用/ほぼ無効: NOT_EQUIVALENT 側には実質的差分がほとんどない

監査観点 3 に照らすと、「両方向にバランスよく効く改善」というより、「EQUIVALENT 側の形式不備を狙った局所調整」です。これは悪いことではありませんが、proposal が主張するほど汎用的な推論品質改善かは慎重に見るべきです。

---

## 4. failed-approaches.md の汎用原則との照合

提案文は非抵触だと主張していますが、私は完全には同意しません。

### 4.1 原則 1: 探索で探すべき証拠の種類をテンプレートで事前固定しすぎるな

`failed-approaches.md:8-10` は、探索を特定シグナルの捜索に寄せすぎるなと警告しています。

今回の変更は exploration 本体ではなく self-check ですが、`file:line reference or explicit search` と書くことで、受理される反証の形をかなり特定の artifact に寄せます。探索そのものを直接拘束しないとしても、「結論前に満たすべき証跡の種類」を狭めている点で、本質的には近いです。

### 4.2 原則 4: 結論直前の自己監査に新しい必須のメタ判断を増やしすぎるな

`failed-approaches.md:18-20` の後半は特に重要です。

- 「既存チェック項目への補足に見える形でも、結論前に特定の検証経路を半必須化すると、実質的に新しい判定ゲートとして働きやすい」

今回まさに起きているのはこれです。

- 項目数は増えていないが、
- `code inspection` という広い行為を、`file:line reference or explicit search` という限定された検証痕跡に置き換え、
- self-check 通過条件を狭めている。

よって、「表現を変えただけなので非抵触」という主張は弱いです。失敗原則の“文面”ではなく“本質”に照らすと、かなり近縁です。

### 4.3 さらに本質的な懸念

現行文言は曖昧ではありますが、少なくとも「actual file search or code inspection」という action を要求しています。提案後は `file:line reference` という output artifact が許容されるため、

- 実際に Step 5 で counterexample probing をしたか
- それとも前段で得た file:line を貼って済ませたか

の区別が弱くなります。

つまり、proposal は「推論だけの反証」を減らしたい一方で、「artifact を貼るだけの反証」を新たに許しうる。この意味でも、過去失敗の“形式化は進むが本質検証は増えない”型に近いです。

---

## 5. 汎化性チェック

## 5.1 明示的なルール違反の有無

提案文 (`proposal.md`) には、禁止対象である

- 特定ベンチマークケース ID
- 特定対象リポジトリ名
- 特定テスト名
- ベンチマーク対象コード断片

は見当たりません。

この点は問題ありません。

## 5.2 暗黙のドメイン依存の有無

大きなドメイン依存も見当たりません。

- `file:line` は言語非依存の証拠単位として既に `SKILL.md` 全体で使われています。
- `explicit search` も、任意のテキストベースのコードベースに適用可能です。

ただし弱い前提として、

- 行番号を安定的に参照できるソースコード資産があること
- 検索や参照がしやすい静的コード分析環境であること

は必要です。もっとも、これは現行 SKILL の前提でもあるため、新規の overfitting とは言えません。

## 5.3 汎化性の総合判断

R1 観点の露骨な overfitting はありません。ここは提案の長所です。

ただし「汎用的である」ことと「有効である」ことは別で、汎用性は保っていても、改善量が小さく、かつ失敗原則に近いという問題は残ります。

---

## 6. 全体の推論品質がどう向上すると期待できるか

期待できる改善は限定的です。

### 期待できる点

- EQUIVALENT 側で、空疎な「反例なしでした」を多少言いにくくする。
- Step 5 の要求を再想起させる効果はある。
- SKILL 内の evidence 単位を `file:line` に揃える、という統一感はある。

### 期待しにくい点

- compare テンプレート側で既に `Searched for:` / `Found:` が要求されているため、新規性が低い。
- Step 5.5 の 1 項目目でもすでに file:line tracing を要求しているため、差分が重複気味。
- NOT_EQUIVALENT 側にはほぼ効かない。
- `code inspection` を `file:line reference` に変えることで、実作業より報告形式の最適化に寄るおそれがある。

### 実効差分のまとめ

この変更で上がるとしても、「本当に必要な反証探索が増える」より「反証欄の記入が少し具体化する」程度だと思われます。推論品質そのものを押し上げる強い改善というより、フォーマット準拠性を少し上げるタイプの変更です。

---

## 最終判断

私の判断では、この proposal は

- 問題意識: 良い
- 汎化性: 問題なし
- 研究との方向整合: ある
- しかし実装手段: 冗長かつ効果が片方向で、failed-approaches の警告に近い

です。

とくに決定的なのは次の 2 点です。

1. 既存 `SKILL.md` がすでに Step 5 本体と compare template で `Searched for` / `Found` / `file:line` をかなり要求しており、今回の変更の増分が小さいこと。
2. `actual code inspection` という行為要件を `file:line reference` という成果物要件に置き換えるため、狙いとは逆に、形式的準拠を助ける可能性があること。

以上より、監査としては現案のままの採用には反対です。

承認: NO（理由: 実効差分が小さく、EQUIVALENT 側に偏った効果しか見込みにくいうえ、結論前 self-check に特定の検証痕跡を半必須化する点で `failed-approaches.md` の失敗原則に近い。さらに `code inspection` という実作業要件を `file:line reference` という成果物要件へ置き換えてしまい、形式的遵守を助長する逆効果の懸念がある）
