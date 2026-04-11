# Iteration 46 — 改善案（再提出）

> **iter-46 初回却下理由（監査役フィードバック要旨）**:
> `Observed` の記述対象を assertion/exception-handler 終端に狭く固定したことで、BL-5/11/13/16 系の **観測フレーム過剰規定** の再発リスクが高い。また、変更前からの実効差分は NOT_EQ の end-to-end 証明コストを増やす方向に偏っており、EQUIV 改善の核心「途中で止まるな」を実現するために終端の型まで固定する必要はない。
>
> **監査役の代替案**:
> - カテゴリ A: `Observed` を広いまま維持し、`Comparison:` 前に「A と B が同じ観察境界で比較されているか」を1文で確認させる
> - カテゴリ B: テンプレート文言ではなく Guardrail に「Observed が中間値なら同じテストパス上の次の consumer を 1 hop だけ読む」という軽量な読解規則を追加する

---

## 選択した Exploration Framework カテゴリ

**カテゴリ B: 探索優先順位・探索行動を変える（Guardrail 追加）**

### 選択理由

`Observed` フィールドへの記述要件変更（カテゴリ F/A テンプレート変更）は、今回を含む過去の反省により「観測フレームの過剰規定」を招くリスクが繰り返し指摘されている（BL-5/11/13/16 および共通原則 #5）。また、iter-45 で `Observed` 自体は既に追加済みであり、その「書き方の文言」を変えるのは既存変更の wording tightening に過ぎない。

カテゴリ B の Guardrail 追加は:
- テンプレートが「何を書くか」を規定するのではなく、エージェントが「何を読むか」を変える探索行動ルールであり、BL-5/11/13/16 の失敗メカニズムを踏まない
- Guardrail に書くことで `Observed` の記述内容の自由度（副作用・例外・状態変化を含む広い observable）を維持しつつ、中間点で止まることを防げる
- 「1 hop」という限定的な読み量により、full downstream trace obligation とならず、NOT_EQ 側の証明コスト増大（BL-2/14）を回避できる

カテゴリ B の既試行サブアプローチとの差分:
| 既試行 | 失敗原因 | 本提案との差分 |
|--------|----------|--------------|
| BL-12 (iter-24): テストソース先読み順序固定 | 探索開始順序の固定 → test-first アンカリング | 本提案は開始順序を固定しない。`Observed` を書いた後の条件付き行動 |
| BL-14 (iter-28): Backward Trace チェックリスト | NOT_EQ 側のみ高度検証を要求 → 判定非対称 | 本提案は EQUIV / NOT_EQ 両方向に適用される |
| BL-9 (iter-21): メタ認知的自己チェック | 自己評価は常に「やった」に倒れる | 本提案は自己評価を求めず、具体的な読解行動（1 hop 先を読む）を指示する |
| BL-10 (iter-22): Reachability ゲート | ゲート条件が relevant test に対して常に YES → 判別力なし | 本提案の条件「Observed が中間値かどうか」は判別力を持つ（変更関数の直接出力で止まっていれば中間値） |

---

## 改善仮説（1つ）

**`compare` モードの Guardrail に「`Observed under Change A/B` に書いた値が変更関数の直接出力（中間値）であれば、その値が渡される次の downstream consumer を 1 hop 読んでから `Comparison:` を書く」という軽量な読解規則を追加することで、推論連鎖が途中で止まるケース（EQUIV 偽陰性）を減らせる。**

### 失敗モードとの対応

EQUIV 偽陰性の典型パターン（15368, 13821, 15382 が該当）:
1. `Observed under Change A`: 変更関数の返り値 X（中間値）
2. `Observed under Change B`: 変更関数の返り値 Y（中間値、X ≠ Y）
3. `Comparison: DIFFERENT` → NOT_EQ と誤判定
4. 実際には X も Y も、downstream の wrapper/handler を通過した後、テストが観測する点では同じ値になる

Guardrail が作用するメカニズム:
1. エージェントは `Observed under Change A: X（変更関数の返り値）` と書く
2. Guardrail 「Observed が中間値なら 1 hop 先を読め」が適用される
3. downstream consumer（例: wrapper 関数）を読む → X が最終的に Z になることを確認
4. `Observed under Change B: Y（変更関数の返り値）→ downstream で同じ Z になる` と訂正または補足
5. `Comparison: SAME` → EQUIV に正しく判定

### EQUIV / NOT_EQ への影響

**EQUIV 正答率（現在 7/10）**: 偽陰性の 1〜2件が改善見込み。1 hop 読むことで「差異が downstream で吸収される」事実に気づける。

**NOT_EQ 正答率（現在 7/10）**: 回帰リスクは低い。真の NOT_EQ では downstream を 1 hop 読んでも差異が維持されるため、`Comparison: DIFFERENT` の判断は変わらない。1 hop という量の限定が full downstream obligation との差分であり、NOT_EQ の証明コストを大幅に増やさない。

---

## SKILL.md のどこをどう変えるか

### 対象箇所

`## Guardrails` → `### From the paper's error analysis` → Guardrail 5 の後に **新規 Guardrail** を追加する。

（Guardrail 5 は「downstream が既に処理しているかを確認せよ」という原則レベルのルールであり、`compare` モード固有の具体的行動指示を別に設けることで相互補完にする。）

### 変更前

```
5. **Do not trust incomplete chains.** After building a reasoning chain, verify that downstream code does not already handle the edge case or condition you identified. Confident-but-wrong answers often come from thorough-but-incomplete analysis.
6. **Handle unavailable source explicitly.** When a function's source is not in the repository (third-party library), mark it UNVERIFIED in trace tables. Search for type signatures, documentation, or test usage as secondary evidence. Do not guess behavior from the function name.
```

### 変更後

```
5. **Do not trust incomplete chains.** After building a reasoning chain, verify that downstream code does not already handle the edge case or condition you identified. Confident-but-wrong answers often come from thorough-but-incomplete analysis.
5a. **In `compare` mode: if `Observed` is an intermediate value, read one downstream consumer before comparing.** If the value written in `Observed under Change A` or `Observed under Change B` is taken directly from the changed function's output and has not yet reached the code the test observes, read the next function or caller that receives that value before writing `Comparison:`. One hop is sufficient — do not require full end-to-end tracing. This prevents stopping at intermediate differences that cancel out downstream.
6. **Handle unavailable source explicitly.** When a function's source is not in the repository (third-party library), mark it UNVERIFIED in trace tables. Search for type signatures, documentation, or test usage as secondary evidence. Do not guess behavior from the function name.
```

### 変更の意図

- `Observed` フィールドの記述要件は iter-45 のまま変更しない（BL-5/11/13/16/BL-2 回避）
- `compare` モードに限定することで、他のモードへの副作用を排除する
- 「1 hop」という量の限定により、full downstream trace 義務とならない（BL-2/14 回避）
- 自己評価ではなく「次の関数を読む」という外部的に検証可能な行動指示（BL-9 回避）
- 「Observed が中間値かどうか」という条件は、変更関数の直接出力で止まっているケース（失敗モードの本質）を弁別する（BL-10 回避）
- EQUIV / NOT_EQ どちらの判定経路でも同じ行動が適用される（共通原則 #1 回避）

### 変更規模

**3行追加（新規 Guardrail 5a）**。既存 Guardrail の削除・変更なし。テンプレートブロック（ANALYSIS OF TEST BEHAVIOR 等）への変更なし。

---

## failed-approaches.md ブラックリストおよび共通原則との照合

| 原則/BL | 照合結果 | 理由 |
|---------|---------|------|
| BL-2（NOT_EQ 立証責任の引き上げ） | ✅ 非該当 | 変更は A/B 対称。「1 hop」制限により証明コストの大幅増大を避ける |
| BL-5（テスト終端への観測フレーム固定） | ✅ 非該当 | `Observed` フィールドへの変更なし。Guardrail は「何を読むか」の行動指示 |
| BL-6（対称化の実効差分） | ✅ 非該当 | 変更前には存在しないルールの追加。A/B 両方に同一適用 |
| BL-8（受動的記録フィールド） | ✅ 非該当 | 記録フィールドの追加ではなく、読解行動（1 hop 先を読む）の指示 |
| BL-9（メタ認知的自己チェックの精度限界） | ✅ 非該当 | 自己評価ではなく、「次の関数を読む」という外部的・能動的な行動指示 |
| BL-10（ゲート条件が常に YES） | ✅ 非該当 | 条件「Observed が中間値か」は、変更関数の出力で止まっているケースとそうでないケースを弁別する。常に YES ではない |
| BL-11（outcome mechanism 注釈） | ✅ 非該当 | テスト側のラベル付けではなく、変更コード側の downstream を 1 hop 読むという探索行動 |
| BL-13（key value at assertion 固定） | ✅ 非該当 | 特定フォーマットへの記録規定ではなく探索行動ルール |
| BL-14（Backward Trace チェックリスト） | ✅ 非該当 | DIFFERENT/NOT_EQ 時のみ適用するのではなく、EQUIV/NOT_EQ 両方向に同一適用 |
| BL-16（Comparison 直前の観測フレーム） | ✅ 非該当 | `Comparison:` 行への新しい注釈追加ではなく、Guardrail での行動指示 |
| 共通原則 #1（判定の非対称操作） | ✅ 非該当 | EQUIV / NOT_EQ どちらを判定する場合も同一のルールが適用される |
| 共通原則 #2（出力側の制約） | ✅ 非該当 | Guardrail は出力形式の規定ではなく、探索行動の規定 |
| 共通原則 #5（入力テンプレートの過剰規定） | ✅ 非該当 | テンプレートへの変更なし。Guardrail は「どこまで書くか」ではなく「何を読むか」 |
| 共通原則 #14（特例探索が主比較ループを強化しない） | △ 要注意 | 条件付き行動であるが、条件（中間値で止まっている）は主比較ループの失敗モードそのものと対応している。特例サイドクエストではなく、主ループ内の次のステップを 1 hop 読むだけ |

---

## 全体の推論品質への影響予測

本 Guardrail が想定通りに機能した場合:
- `Observed` に中間値が書かれたとき、エージェントはそのまま `Comparison:` を書かず、1 hop 先（downstream consumer）を読む
- 差異が downstream で収束する EQUIV ケース: 訂正後の `Observed` が A = B となり、`Comparison: SAME` → EQUIV 判定が改善
- 差異が downstream でも維持される NOT_EQ ケース: 1 hop 読んでも A ≠ B のままであり、`Comparison: DIFFERENT` の根拠がより具体的になる

懸念点と緩和策:
- 「Observed が中間値かどうか」の判断をエージェントが誤る可能性: `changed function's output and has not yet reached the code the test observes` という記述により、テストが直接観察するコードに届いているかという基準を示している
- 1 hop では不十分な場合: 1 hop で「さらに先がある」と分かれば Guardrail 5（"verify downstream code"）が補完する。完全な fix ではないが、短絡判定の一段階目を防ぐことが目的
