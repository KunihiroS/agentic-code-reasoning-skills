1) Target misclassification: 偽 EQUIV
2) Current failure story (抽象): 「名前参照が見つからない」だけで pass-to-pass テストを“存在しない扱い”にし、間接到達するテストを取りこぼして EQUIV を早期に結論してしまう
3) Mechanism (抽象): pass-to-pass の“到達性”が UNVERIFIED のときに結論を縮小/保留へ分岐させ、陰性探索（見つからない）の過信を減らす
4) Non-goal boundary: 読解順序の半固定・証拠種類の事前固定・必須ゲート増（MUST/required の追加）は行わない

Focus domain: overall
Exploration Frameworkカテゴリ: B. 情報の取得方法を改善する
メカニズム選択理由: compare の誤判定は「何を読むか」ではなく「どの探索で“関連テストが本当に無い”と言えるか」の取得・判定の仕方で起きやすい。D2 の pass-to-pass 同定を“名前参照検索”に寄せすぎず、到達性の未検証（UNVERIFIED）を観測可能な状態として扱うことで、探索の自由度を保ったまま意思決定だけを改善できる。

改善仮説（1つ）
pass-to-pass テストの同定で「負の証拠（見つからない）」を過信しない分岐を入れると、間接到達するテストの取りこぼしによる早期 EQUIV が減り、全体の比較判定が安定する。

現状ボトルネックの診断（SKILL.md 自己引用 + 誘発機構）
SKILL.md の Compare > DEFINITIONS > D2 には次がある:
"To identify them: search for tests referencing the changed function, class, or variable."
この文言は「参照（reference）探索」へ誘導しやすく、参照が見つからない＝到達しない、という短絡を誘発しうる。その結果、pass-to-pass の関連性が未検証のまま“空集合”扱いになり、EQUIV を早期結論しやすい（偽 EQUIV）。

Decision-point delta（IF/THEN の2行、行動差があること）
Before: IF pass-to-pass テストの“参照（reference）”が見つからない THEN pass-to-pass は実質無関係として結論を出す because 負の参照検索を「到達しない」の根拠にしてしまう
After:  IF pass-to-pass の到達性が UNVERIFIED THEN 結論を保留する/条件付きに縮小する/追加で探す because 到達性の証拠（call-path / import 等）が未確定で、負の証拠だけでは空集合と言えない
対応するSKILL.mdの見出し/セクション名: Compare > DEFINITIONS (D2) / Step 5.5: Pre-conclusion self-check (UNVERIFIED を条件付き結論と CONFIDENCE に反映)

変更タイプ: 定義の精緻化
なぜ効くか: “関連テストが無い”という強い主張の入口を、観測可能な状態（reachability=UNVERIFIED）で分岐させる。探索経路を固定せず、結論の出し方だけを変える。

具体的な変更内容（SKILL.md のどこをどう変えるか）
Compare の DEFINITIONS D2 にある pass-to-pass テストの同定方法を、(a) 参照探索だけに還元しない、(b) 到達性が UNVERIFIED の場合に結論を縮小/保留へ分岐、の2点が明示されるように置換する。

支払い（必須ゲート総量不変の証明）
今回の変更は MUST/required の新設や必須ゲートの増設ではなく、既存の D2 の同定手段の定義精緻化（置換）であるため、支払いは不要（必須ゲート総量は不変）。

変更差分の最小プレビュー（3〜10行、同一範囲のBefore/After）
対象範囲: Compare > Certificate template > DEFINITIONS > D2

Before:
```
D2: The relevant tests are:
    (a) Fail-to-pass tests: ...
    (b) Pass-to-pass tests: tests that already pass before the fix — relevant
        only if the changed code lies in their call path.
    To identify them: search for tests referencing the changed function, class,
    or variable.
```

After:
```
D2: The relevant tests are:
    (a) Fail-to-pass tests: ...
    (b) Pass-to-pass tests: tests that already pass before the fix — relevant
        only if the changed code lies in their call path.
    To identify them: search for tests that reach the changed code (e.g., reference, import, or traced call path).
    If reachability is UNVERIFIED, do not treat pass-to-pass as empty; keep exploring or narrow the conclusion and set CONFIDENCE=LOW.
```

変更による意思決定ポイントの変化（1行）
pass-to-pass の到達性が UNVERIFIED という観測状態が、EQUIV を即断するのではなく「保留/条件付き/追加探索」に分岐するトリガになる。

Trigger line:
If reachability is UNVERIFIED, do not treat pass-to-pass as empty; keep exploring or narrow the conclusion and set CONFIDENCE=LOW.

期待される挙動差（compare に効く形）
- 変更前に起きがちな誤り（一般形）: 参照検索の陰性（見つからない）を根拠に pass-to-pass の影響を否定し、間接経路で到達するテスト差分を見落として偽 EQUIV。
- 変更後に減るメカニズム（1つ）: 到達性が UNVERIFIED なら“空集合扱い”せず結論を縮小/保留/追加探索へ分岐するため、陰性探索の過信が減る。
- どちらの誤判定が減る見込みか（片方向最適化を避けて）: 主に偽 EQUIV を減らす。偽 NOT_EQUIV を増やしにくい理由は「UNVERIFIED のときに直ちに NOT_EQUIVALENT を推す」のではなく、(a) 追加探索、または (b) 条件付き結論＋低確信度へ縮小するだけで、否定方向へ強制しないため。

最小インパクト検証（思考実験で可）
- ミニケースA（変更後に安定する）: 変更点が“呼び出し元の間接層”にあり、テストは変更シンボル名を直接参照しないが import/実行経路で到達する。変更前は「参照が無い→無関係」で EQUIV に寄るが、変更後は reachability=UNVERIFIED をトリガに追加探索/条件付きへ分岐し、取りこぼしを減らす。
- ミニケースB（逆方向悪化の可能性と回避）: 参照も import も到達も薄く、探索を続けるほど不確実性が残る状況で、過度に保留し続けて決められない（萎縮）リスク。回避策: 本変更は「必ず追加探索せよ」ではなく、既存の枠組みに沿って“条件付き結論＋CONFIDENCE=LOW”へ縮小できる選択肢も明示するため、新しい必須手順を増やさず停滞を回避できる。

failed-approaches.md との照合（1〜2点、具体）
- 「証拠の種類をテンプレで事前固定しすぎる変更は避ける」に整合: 本変更は特定の証拠タイプを必須化せず、reach の例示（reference/import/call-path）を挙げるだけで、探索の自由度を残す。
- 「読解順序の半固定は避ける」に整合: “どこから読むか”の順序指定ではなく、観測状態（reachability=UNVERIFIED）に応じた意思決定の分岐だけを追加している。

未参照の資料
- README.md: 未参照（今回の変更は Compare>D2 の局所的な取得・分岐定義の精緻化で完結し、研究概要の追加参照が不要）
- docs/design.md / docs/reference/agentic-code-reasoning.pdf: 未参照（同上。新規メカニズム導入ではなく、既存概念 UNVERIFIED/CONFIDENCE の適用範囲の明確化のため）

変更規模の宣言
- 変更は D2 の2行置換（追加2行相当だが既存2行を置換するため、差分は5行以内）。新しい MUST/required の増設なし。

停滞対策の自己チェック
- “監査 rubic に刺さる説明強化”だけで終わっていない: pass-to-pass 同定の分岐（保留/条件付き/追加探索）が明示され、compare の結論行動が変わる。
- Decision-point delta は理由だけの言い換えでない: IF 条件（reachability=UNVERIFIED）と行動（保留/条件付き/追加探索）が変わる。
- 必須ゲート総量を増やしていない: MUST/required を増やしていない（既存 D2 文言の置換のみ）。
