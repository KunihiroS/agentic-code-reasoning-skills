# Iteration 31 — Proposal

## Exploration Framework カテゴリ: B（強制指定）

### 選択したカテゴリ内メカニズム

カテゴリ B「情報の取得方法を改善する」の中でも、本提案は
**「どう探すかを改善する / 探索の優先順位付けを変える」** メカニズムを選択する。

具体的には Step 3 の NEXT ACTION RATIONALE フィールドの記述指示を精緻化する。

**このメカニズムを選んだ理由:**

現行の NEXT ACTION RATIONALE は `[why the next file or step is justified]` という
抽象的な括弧説明しか持たない。このため、探索者が「慣習的・直感的な読み順」に
頼ることを許してしまい、未解決の仮説 (UNRESOLVED リスト) が何であるかと
次の探索ステップとの対応関係が曖昧になる。

カテゴリ B の「どう探すか」を改善するとは、次ステップ選択の判断根拠を
動的な探索状態（未解決の問い）に明示的に紐付けることを意味する。
これは静的な読み順の固定ではなく、探索が進むたびに変化する
UNRESOLVED リストを参照して優先度を更新する動的な原則である。

---

## 改善仮説

**仮説 H-31:**
「NEXT ACTION RATIONALE の記述指示を『どの未解決問いに対処するか』へ精緻化することで、
探索の次ステップが仮説上の空白に動的に向かうよう促し、慣習的な読み順に起因する
証拠取得の偏りを減らせる。」

根拠となる設計原則: docs/design.md「Per-item iteration as the anti-skip mechanism」
セクションは、テンプレートが前提なしの飛躍を防ぐのは「具体的な項目への反復」を
強制するからだと述べている。NEXT ACTION RATIONALE を UNRESOLVED に紐付けることは、
この同じ原則を探索ナビゲーション層にも適用する。

---

## 変更内容

### 変更対象

SKILL.md の Step 3「Hypothesis-driven exploration」の NEXT ACTION RATIONALE フィールド。

### 変更前（SKILL.md L92）

```
NEXT ACTION RATIONALE: [why the next file or step is justified]
```

### 変更後

```
NEXT ACTION RATIONALE: [which UNRESOLVED item this addresses, and why this file/step is the most direct source of evidence for it]
```

### 変更の性格

既存行の括弧内説明の **文言精緻化のみ**。新規ステップ・フィールド・セクションの追加なし。

---

## 変更規模の宣言

- 変更行数: **1行**（既存行の文言置換のみ）
- hard limit 5行以内: 満たしている
- 削除行: 0行

---

## 一般的な推論品質への期待効果

### 減少が期待される失敗パターン

1. **探索ドリフト（Drift）によるスコープ外読み込み**
   次ステップが「なぜその未解決問いに答えられるか」を明示する義務を負うため、
   現時点の仮説と無関係なファイルを慣習的に読む行動が抑制される。

2. **UNRESOLVED リストの形骸化**
   現行では UNRESOLVED を書いても NEXT ACTION RATIONALE がそれを参照しないため、
   未解決リストが「書くだけの形式」になりやすい。両フィールドを明示的に接続することで
   UNRESOLVED が実際の探索の舵取りに機能するようになる。

3. **overall（全体的な推論品質）への効果**
   compare / diagnose / explain 全モードで Step 3 を使う。UNRESOLVED を参照した
   NEXT ACTION RATIONALE は、仮説が更新されるたびに探索の焦点が変わるという
   仮説駆動の本来の意図を強化し、ケース全体の証拠収集の均質性を高める。

### NOT_EQUIVALENT 判定精度への効果

構造的差異の確認後に詳細追跡をする compare モードでは、
UNRESOLVED に「変更 A と変更 B の挙動差が未確認」と記録された項目が
NEXT ACTION RATIONALE を通じて次の読み先を決定する。これにより
差異確認の漏れが減り、NOT_EQUIVALENT の見落としが減る。

### EQUIVALENT 判定精度への効果

「counterexample を探したが見つからなかった」という NO COUNTEREXAMPLE EXISTS の
探索も、UNRESOLVED に「counterexample 候補 [X] の反証が未完」と書かれ続ける限り
次の NEXT ACTION RATIONALE で参照される。探索の打ち切りが正当化されるのは
UNRESOLVED が空になるか明示的に閉じた場合のみとなり、
早期打ち切りによる誤 EQUIVALENT 判定が減る。

---

## failed-approaches.md との照合

### 原則 1: 探索を「特定シグナルの捜索」へ寄せすぎない

本変更は「どのシグナルを探すか」を固定しない。UNRESOLVED リストは
探索が進むにつれて動的に変化するため、特定パターンへの確認バイアスを
固定化しない。照合結果: **抵触なし**

### 原則 2 / 3: 読解順序の半固定・探索の自由度を削りすぎない

本変更は「どのファイルを先に読むか」という読み順序を固定しない。
UNRESOLVED への参照は「どのファイルを選んでもよいが、選択理由を
現在未解決の問いに基づいて説明せよ」という要件であり、自由度を
削るのではなく選択の正当化基準を動的な状態に合わせるものである。
照合結果: **抵触なし**

### 原則 4: 局所的な仮説更新を前提修正義務に直結させすぎない

本変更は UNRESOLVED を参照させるだけで、UNRESOLVED の変化が
前提 P[N] の再書き換えを義務付けるものではない。
照合結果: **抵触なし**

### 原則 5: 結論直前の自己監査に必須メタ判断を増やしすぎない

本変更は Step 3 中の探索ナビゲーションに関するものであり、
Step 5.5 の Pre-conclusion self-check には一切触れない。
照合結果: **抵触なし**

---

## 研究コアの維持確認

| コア要素 | 影響 |
|----------|------|
| 番号付き前提 | 変更なし |
| 仮説駆動探索 | 強化（NEXT ACTION が UNRESOLVED に紐付く） |
| 手続き間トレース | 変更なし |
| 必須反証 | 変更なし |
