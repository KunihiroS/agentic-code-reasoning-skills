# Iter-5 Proposal (focus_domain: overall)

## Exploration Framework カテゴリ
- カテゴリ: **F. 原論文の未活用アイデアを導入する**
- メカニズム選択理由: 原論文の動機例・エラー分析が示す「**既知API/組み込みだと決め打ちしてしまう（名前から意味を推測する）**」失敗は、compare の **EQUIV 判定**を直接誤らせるのに対し、SKILL.md の compare 証明書テンプレート内ではそのチェックが“手続きの中心（意思決定点）”に明示的に編み込まれていない。そこで、compare の既存必須セクション（NO COUNTEREXAMPLE EXISTS）の中で、探索対象の型を 1 行だけ精緻化してこの失敗を減らす。

## 改善仮説（1つ）
compare で「反例が見つからない → EQUIV」と結論する直前に、**推論に依存した識別子（関数/変数名）の“実際の束縛先（定義・import・shadowing）”も反例探索の対象に含める**よう明確化すると、名前ベースの誤推論を減らし、EQUIV/NOT_EQUIV の両方向の誤判定を抑えつつ結論の安定性が上がる。

## 現状ボトルネックの診断（SKILL.md 引用 + 誘発する失敗メカニズム 1つ）
該当箇所（Compare > Certificate template > NO COUNTEREXAMPLE EXISTS）:
> `Searched for: [specific pattern — test name, code path, or input type]`

この「pattern」の例示が **テスト名/経路/入力型**に寄り、原論文が強調する失敗（名前からの推測・shadowing・import 解決の取り違え）が **反例探索の射程外**になりやすい。その結果、(a) 既知API前提で「同じはず」と短絡しやすく、(b) 反例が見つからないことを過大評価して **偽 EQUIV** を誘発する。

## 停滞打破: Decision-point delta（IF/THEN 2行）
- Before: IF 反例パターン（テスト名/経路/入力型）で何も見つからない THEN EQUIV を結論しやすい because 「テストに現れる反例が無い」型の根拠に依存する
- After:  IF 反例パターンに加えて“推論で依存した識別子の束縛先”でも矛盾が無い/未解決が無い THEN EQUIV を結論し、未解決が残るなら結論を保留して追加探索する because 「反例不在 + 前提（束縛）健全性」型の根拠に依存する

対応する SKILL.md の見出し/セクション:
- `## Compare` → `### Certificate template` → `NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT)`

## 変更タイプ
- **明確化**
- 理由: compare の最重要な意思決定点（EQUIV の結論直前）にある「Searched for」を 1 行だけ精緻化し、原論文のエラー分析由来の失敗（名前推測・束縛取り違え）を **探索対象の定義**として組み込む。手順の増設ではなく、既存の必須欄の意味を明確にするだけなので、形式的充足の負担増（必須ゲート増）を避けつつ、結論の根拠型が変わる。

## SKILL.md のどこをどう変えるか（具体）
- 変更箇所: `Compare` 証明書テンプレート内 `NO COUNTEREXAMPLE EXISTS` の `Searched for:` の 1 行
- 変更内容: 反例探索の「pattern」に、**推論に依存した識別子の解決（定義・import・shadowing）**を含めることを追記する（1行置換）。

## 変更差分の最小プレビュー（必須: 同じ範囲を 3〜10 行引用して Before/After）

Before (SKILL.md 自己引用):
```
NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT):
  If NOT EQUIVALENT were true, a counterexample would look like:
    [describe concretely: what test, what input, what diverging behavior]
  I searched for exactly that pattern:
    Searched for: [specific pattern — test name, code path, or input type]
    Found: [result — cite file:line, or NONE FOUND with search details]
  Conclusion: no counterexample exists because [brief reason]
```

After (同一範囲; 1行のみ変更):
```
NO COUNTEREXAMPLE EXISTS (required if claiming EQUIVALENT):
  If NOT EQUIVALENT were true, a counterexample would look like:
    [describe concretely: what test, what input, what diverging behavior]
  I searched for exactly that pattern:
    Searched for: [specific pattern — test name, code path, input type, OR resolved definition/binding of any relied-upon identifier (imports/shadowing)]
    Found: [result — cite file:line, or NONE FOUND with search details]
  Conclusion: no counterexample exists because [brief reason]
```

意思決定ポイントの変化（1行）:
- 「反例が無い」だけで結論を出しやすい状態から、「反例が無い」+「前提に使った識別子の束縛が確認済み（または未解決が明示）」という根拠型で EQUIV を結論/保留する状態に変わる。

## 期待される“挙動差”（compare に効く形）
- 変更前に起きがちな誤り（一般形・1つ）:
  - 既知の関数名/型名/変数名を「言語組み込み/標準API」と思い込み、その前提で「両者は同じ計算をしている」と判断して **偽 EQUIV** になる（実際には shadowing や別定義で例外/分岐が異なる）。
- 変更後にその誤りが減るメカニズム（1つ）:
  - EQUIV 主張に必須の `NO COUNTEREXAMPLE EXISTS` で、反例探索の対象に「識別子の束縛先の解決」を含めるため、名前推測のまま結論しにくくなり、誤った前提（束縛取り違え）を反例として拾いやすくなる。
- どちらの誤判定が減る見込みか（片方向最適化にならない形で）:
  - 主に **偽 EQUIV** が減る見込み。ただし束縛未解決を理由に即 NOT_EQUIV へ倒す設計ではなく「保留→追加探索」の分岐なので、**偽 NOT_EQUIV の増加**を避ける（結論を急がず、既存の反証枠内で確度を上げる）。

## 最小インパクト検証（思考実験で可）
- ミニケース A（変更前は揺れる/誤るが、変更後は安定）:
  - 2つの実装が同名の呼び出し（例: `format` や `parse` のような一般名）に依存し、表面上は同じ入出力変換に見える。だが実際には片方の環境では同名が別定義に束縛され、例外/型制約が異なる。変更後は「束縛先の定義/import/影響範囲」を反例探索に含めるため、名前推測での EQUIV 結論が減り、判断が安定する。
- ミニケース B（逆方向の誤判定を誘発しうる状況 + 悪化しない理由/回避策）:
  - 束縛先が外部（第三者ライブラリ等）でソースが見えず、定義解決が完全にはできない状況。ここで「未解決＝NOT_EQUIV」と短絡すると偽 NOT_EQUIV が増える恐れがある。
  - 悪化しない理由/回避策: この提案は NOT_EQUIV を促進せず、未解決なら **結論を保留して追加探索**に誘導するだけ（しかも新しい必須手順は増やさない）。また SKILL.md には既に「Unavailable source を UNVERIFIED として明示し、仮定が結論を変えない範囲に制限する」原則（Core Method Step 4/Guardrails）があり、そこで安全に扱える。

## focus_domain が equiv/not_eq の場合のトレードオフ（今回: overall）
- overall でも悪化しうる経路を 1つ想定:
  - 「束縛先の解決」を過剰に広く解釈し、EQUIV のたびに無限に探索して結論が出にくくなる（萎縮）。
- 新しい必須手順を増やさずに避ける工夫:
  - 文言を **“relied-upon identifier” に限定**しているため、推論の根拠に使っていない識別子まで追わない。加えて、これは既存の `Searched for` の明確化であり、探索の自由度（どこから読む/何を優先する）は固定しない。

## failed-approaches.md との照合（1〜2点だけ具体）
- 「証拠の種類をテンプレートで事前固定しすぎる変更は避ける」（箇条書き1）との整合:
  - 今回は“特定シグナル”の固定ではなく、原論文由来の一般失敗モード（名前推測/束縛取り違え）を **反例探索の射程に追加**するだけで、探索対象の自由度を狭めない。
- 「結論直前の自己監査に新しい必須のメタ判断を増やしすぎない」（箇条書き5）との整合:
  - 新しい必須ゲートを増やさず、既存の必須欄（NO COUNTEREXAMPLE EXISTS）の 1 行を置換して明確化するだけ。追加の“判定手順”を増設しない。

## 変更規模の宣言
- 追加/変更: **1行（置換 1 行）**
- hard limit（5行以内）を満たす。

## 停滞対策の自己チェック（proposal 内で明記）
- 監査で褒められやすいが compare には効きにくい整形/美文化に留まっていないか？
  - 留まっていない。EQUIV 結論直前の探索対象定義を変え、誤判定（偽 EQUIV）を直接減らす狙い。
- compare の誤判定（偽 EQUIV / 偽 NOT_EQUIV）を減らす“意思決定ポイント”が実際に変わるか？
  - 変わる。EQUIV の根拠が「反例が見つからない」単独から「反例不在 + 束縛前提の健全性確認（未解決なら保留）」へ変わる。
- 必須ゲートに手を入れる場合、置換/統合/削除で総量を増やしていないか？
  - 総量は増やしていない（必須セクション増設なし、チェック項目増設なし、1行置換のみ）。
