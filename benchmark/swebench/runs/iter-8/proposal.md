1) Target misclassification: 偽 NOT_EQUIV
2) Current failure story (抽象): compare で「構造差（片側だけが触るファイル）= 即 NOT_EQUIV」と過剰反応し、テスト境界で観測されない差でも早期に不一致判定してしまう
3) Mechanism (抽象): 差異を「テストのパス/フェイルを左右する観測可能な差」へ優先的に写像し、import/ファイル非対称だけで結論を確定しにくくする
4) Non-goal boundary: 読解順序の半固定・証拠種類の事前固定・必須ゲート総量の増加はしない（既存の S2 の判定基準だけを精緻化する）

Exploration Framework のカテゴリ: C（比較の枠組みを変える）
- メカニズム選択理由: 現状の compare は D1（テスト結果の同一性）で等価性を定義している一方、STRUCTURAL TRIAGE の S2 が「import されたファイルの非対称」だけで NOT EQUIVALENT を結論できる書き方になっており、比較粒度（ファイル構造）と比較基準（テスト境界の観測結果）がズレている。このズレを、差異重要度（観測可能性）で再接続するのがカテゴリCに合致する。

改善仮説（1つ）
- 「構造差」は NOT_EQUIV の十分条件ではなく“反例候補”であり、NOT_EQUIV の早期結論はテスト境界（PASS/FAIL を決める assertion/例外/戻り値）に結び付いたときだけ許す、という比較枠組みにすると、偽 NOT_EQUIV が減りつつ偽 EQUIV も増やしにくい。

現状ボトルネックの診断（SKILL.md から短く引用 + 誘発する失敗メカニズム）
- 引用（Compare > STRUCTURAL TRIAGE S2）:
  “modifies and a test imports that file, the changes are NOT EQUIVALENT regardless of the detailed semantics.”
- 誘発する失敗メカニズム: 「import = 影響あり」と短絡し、D1（テスト結果）に到達する前に NOT_EQUIV を確定しやすい。結果として、観測不能/無関係な差（リファクタ、到達不能分岐、冗長ガード等）でも不一致判定が出る。

Decision-point delta（IF/THEN の2行、行動が変わる条件を明示）
- Before: IF 片側だけが触るファイルがあり、関連テストがそれを import している THEN 「NOT EQUIVALENT」を結論する because 構造差（import）を十分条件として扱う
- After:  IF 片側だけが触るファイルがある THEN 「追加で探す（テスト境界に結び付く反例の有無を確認）」 because 観測可能な差（PASS/FAIL を左右する根拠）に写像できるまで結論を保留する
- 対応する SKILL.md の文言（見出し名）: Compare > STRUCTURAL TRIAGE (S2) / Compare > Compare checklist（Structural triage first）

変更タイプ（1つ）
- 定義の精緻化: 「構造差→不一致」の判定を、“テスト境界で観測される差→不一致”へ置き換え、比較基準（D1）と整合させる。

SKILL.md のどこをどう変えるか（具体）
- Compare > STRUCTURAL TRIAGE の S2 の「import されたら即 NOT EQUIVALENT」を、
  「関連テストの PASS/FAIL がそのファイルの挙動に依存すると言えるなら NOT EQUIVALENT」に置換する。
- Compare > Compare checklist の先頭 bullet も同趣旨に合わせて 1 行だけ更新し、構造差を“リスク旗（反例探索の優先対象）”として扱う。
- （追加の必須ゲートは増やさない。既存の COUNTEREXAMPLE/NO COUNTEREXAMPLE の枠組み内で、S2 の十分条件を絞るだけ。）

変更差分の最小プレビュー（Before/After、同じ範囲を自己引用）

[Excerpt A: Compare > STRUCTURAL TRIAGE (S2) — 4 lines]
Before:
```
  S2: Completeness — does each change cover all the modules that the
      failing tests exercise? If Change B omits a file that Change A
      modifies and a test imports that file, the changes are NOT EQUIVALENT
      regardless of the detailed semantics.
```
After:
```
  S2: Completeness — does each change cover all the modules that the
      failing tests exercise? If Change B omits a file that Change A
      modifies and a relevant test's PASS/FAIL depends on that file's behavior,
      the changes are NOT EQUIVALENT (tie it to a concrete assertion boundary).
```
- 意思決定ポイントの変化（1行）: 「import を見た時点で NOT_EQUIV」→「PASS/FAIL 依存（反例）に結び付くまで追加探索し、結論を保留しやすい」

[Excerpt B: Compare > Compare checklist — 3 lines]
Before:
```
### Compare checklist
- **Structural triage first**: compare modified file lists, check for missing modules or test data before any detailed tracing
- For large patches (>200 lines), rely on structural comparison and high-level semantic analysis rather than exhaustive line-by-line tracing
```
After:
```
### Compare checklist
- **Structural triage first**: compare modified file lists; treat asymmetry as a counterexample lead unless tied to a PASS/FAIL boundary
- For large patches (>200 lines), rely on structural comparison and high-level semantic analysis rather than exhaustive line-by-line tracing
```

期待される "挙動差"（compare に効く形）
- 変更前に起きがちな誤り（一般形）: 片側だけのファイル変更があると、それが実際には観測不能でも「構造差があるから NOT_EQUIV」と早期確定してしまう（偽 NOT_EQUIV）。
- 変更後に減るメカニズム: S2 が「テスト境界で観測される差」に結び付いた場合のみ NOT_EQUIV を許すため、構造差は“反例探索の手掛かり”として扱われ、根拠が PASS/FAIL に到達しない限り結論を出しにくくなる。
- どの誤判定が減る見込みか（片方向最適化にしない形で）: 主に偽 NOT_EQUIV を減らす。一方で偽 EQUIV を増やさないため、構造差は「NO COUNTEREXAMPLE EXISTS」の探索対象（反例像）として残り、反例があるならそこで拾いやすい。

最小インパクト検証（思考実験）
- ミニケースA（変更前は揺れる/誤るが変更後は安定）:
  2つの変更の差が“到達しない分岐・無影響な補助コード・内部のリネーム/整理”に留まり、関連テストの assertion までの観測結果が同じ状況。
  変更前: import という構造シグナルだけで NOT_EQUIV に倒れやすい。
  変更後: PASS/FAIL 依存に結び付かない限り保留→反例探索→同一観測結果なら EQUIV（modulo tests）へ収束しやすい。
- ミニケースB（逆方向の誤判定を誘発しうる状況 + 悪化しない理由/回避策）:
  片側だけが触るファイルに“実際にテストの観測結果を変える差”があるが、最初はそれが見えにくい状況。
  悪化しうる経路: 「import だけでは NOT_EQUIV できない」→探索が甘いと偽 EQUIV に落ちる。
  回避策（新しい必須手順を増やさずに）: 構造差を checklist 上で “counterexample lead” として明示し、既存の COUNTEREXAMPLE / NO COUNTEREXAMPLE の枠内で反例像に組み込む（＝追加探索の優先度を上げるが、証拠種類や読解順序は固定しない）。

focus_domain が equiv / not_eq の場合のトレードオフ（今回は overall だが、悪化経路を1つ想定して回避）
- 想定する悪化経路: 構造差の自動 NOT_EQUIV を外すことで、観測可能差の発見が遅れ、偽 EQUIV が増える。
- 回避（必須ゲート増なし）: “構造差=反例のリード” として既存の反例探索欄（NO COUNTEREXAMPLE の「counterexample would look like」）に自然に吸収される表現へ調整する（今回の checklist 1 行の置換）。

failed-approaches.md との整合（1〜2点、具体）
- 「証拠種類の事前固定を避ける」（箇条書き1）: 本変更は「何を探すか」を固定しない。あくまで“結論条件”をテスト境界へ寄せるだけで、探索で使う証拠の種類（テスト/型/ドキュメント等）をテンプレで事前固定しない。
- 「読解順序の半固定を避ける」（箇条書き2）: STRUCTURAL TRIAGE の存在自体は維持するが、S2 を“即結論”ではなく“反例探索のリード”に寄せるため、読み始めや境界確定を早期に狭める方向へは進めない。

変更規模の宣言
- SKILL.md 変更は 4 行以内（hard limit 5 行以内を遵守）。追加の MUST/必須 ゲートは増やさず、既存文言の置換で支払う。

停滞対策の自己チェック（proposal 内で明記）
- 監査で褒められやすい説明強化だけに留まっていないか？: 留まっていない。S2 の「NOT_EQUIV へ倒れるトリガ条件」を変更し、結論/保留/追加探索の分岐が実際に変わる。
- compare の誤判定を減らす意思決定ポイントが実際に変わるか？: 変わる。import だけで NOT_EQUIV を確定する経路を塞ぎ、PASS/FAIL 境界への接続を要求するため、追加探索が起動する。
- Decision-point delta が「条件も行動も同じで理由だけ言い換え」になっていないか？: なっていない。条件（import）→（PASS/FAIL 依存）へ変わり、行動（即結論）→（追加探索/保留）へ変わる。
- 必須ゲート総量を増やしていないか？: 増やしていない。S2 の判定基準の置換と checklist 1 行の置換のみ。

参照状況
- 参照した: SKILL.md（Compare 節中心）, failed-approaches.md, Objective.md（Exploration Framework のカテゴリ定義確認）
- 今回未参照: README.md / docs/design.md / docs/reference/agentic-code-reasoning.pdf（理由: 今回の変更は compare 内の比較基準整合（D1 と S2 の齟齬解消）で正当化でき、研究追加参照なしで提案の根拠が足りるため。トークン節約を優先）
