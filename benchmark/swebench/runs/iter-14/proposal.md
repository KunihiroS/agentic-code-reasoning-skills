1) Target misclassification: 偽 NOT_EQUIV を減らす
2) Current failure story (抽象): 構造差（欠落/追加ファイル等）を見つけた時点で「観測可能な差」への写像が弱いまま NOT_EQUIV を早期確定し、後段のテストオラクル照合を省いて誤判定しやすい
3) Mechanism (抽象): 構造差を「オラクル可視/不可視」の重要度に分類し、オラクル可視だと示せない構造差では結論を保留して ANALYSIS 側へ送るため、過剰反応（早期 NOT_EQUIV）を減らす
4) Non-goal boundary: 読解順序の半固定・証拠種類の事前固定・新しい必須ゲート増設（MUST/required の純増）は行わない

Exploration Framework カテゴリ: C（比較の枠組みを変える）
- 選ぶメカニズム: 「差異の重要度を段階的に評価する」（Objective.md: “差異の重要度を段階的に評価する”）
- 理由: compare の誤判定は「差があるか」より「差が D1（テストオラクル）に写像できる重要差か」を取り違えることで起きやすく、重要度の分類が結論トリガ（EQUIV / NOT_EQUIV）に直結するため。

改善仮説（1つ）
- 構造差による早期 NOT_EQUIV のショートカットを「オラクル可視な構造差」に限定すると、観測可能性が薄い差への過剰反応が減り、全体として比較の誤判定（特に偽 NOT_EQUIV）が減る。

現状ボトルネック診断（SKILL.md 短い引用 + 失敗メカニズム）
- 現行の早期結論トリガが、重要度（オラクル可視性）を満たさない構造差でも発火しうる:
  - 引用（SKILL.md / compare / STRUCTURAL TRIAGE）:
    “If S1 or S2 reveals a clear structural gap (missing file, missing module update, missing test data), you may proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT ...”
- 誘発される失敗メカニズム: 「構造差 = 直ちに NOT_EQUIV」という分類が先に立ち、D1（テストオラクル一致/不一致）への写像確認が弱いまま結論が確定する（比較枠組みの粒度/重要度の取り違え）。

Decision-point delta（IF/THEN 2行、観測できる条件で分岐）
- Before: IF S1/S2 で structural gap が見える THEN 追加で探さず NOT_EQUIV を結論してよい because “missing file/module/test data” を構造根拠として扱える
- After:  IF S1/S2 で structural gap が見える AND それが ORACLE-VISIBLE（関連テストの assert/例外/外部状態に写像できる） THEN NOT_EQUIV を結論してよい ELSE 結論を保留して ANALYSIS へ進む because 「テストオラクルに写像できた差」だけを結論根拠として扱う
- 対応する SKILL.md セクション名:
  - “STRUCTURAL TRIAGE (required before detailed tracing)”
  - “### Compare checklist”

Trigger line:
- “only shortcut to NOT EQUIVALENT on gaps that are ORACLE-VISIBLE to a relevant test oracle.”

変更タイプ（1つ）
- 定義の精緻化（比較枠組み: 構造差の「重要度（オラクル可視性）」を、結論トリガに接続して精緻化）

SKILL.md のどこをどう変えるか（具体）
- compare モードの “STRUCTURAL TRIAGE” にある早期 NOT_EQUIV 条件を、S4 の概念（ORACLE-VISIBLE/INVISIBLE）でゲートする。
- compare checklist の先頭項目に、同じ条件（オラクル可視なギャップのみショートカット）を明示して、行動差をチェックリストとして発火させる。

支払い（必須ゲート総量不変の証明）
- 今回は MUST/required の追加・強化を行わず、既存の “may proceed directly” の適用条件を狭めるだけなので、必須ゲート総量は増えない（支払い不要）。

変更差分の最小プレビュー（同一範囲 3〜10行、Before/After）
Before（SKILL.md / compare / STRUCTURAL TRIAGE + checklist 抜粋）:
```text
STRUCTURAL TRIAGE (required before detailed tracing):
...
  OPTIONAL — S4: Difference importance — label each discovered difference as ORACLE-VISIBLE
      (can change an asserted output/exception/externally visible state) vs ORACLE-INVISIBLE,
      and prioritize tracing ORACLE-VISIBLE differences to a concrete test oracle first.

If S1 or S2 reveals a clear structural gap (missing file, missing module
update, missing test data), you may proceed directly to FORMAL CONCLUSION
with NOT EQUIVALENT without completing the full ANALYSIS section.

### Compare checklist
- **Structural triage first**: compare modified file lists, check for missing modules or test data before any detailed tracing
```

After（同じ範囲；変更は5行以内）:
```text
STRUCTURAL TRIAGE (required before detailed tracing):
...
  OPTIONAL — S4: Difference importance — label each discovered difference as ORACLE-VISIBLE
      (can change an asserted output/exception/externally visible state) vs ORACLE-INVISIBLE,
      and prioritize tracing ORACLE-VISIBLE differences to a concrete test oracle first.

If S1 or S2 reveals a clear structural gap that is ORACLE-VISIBLE to a relevant test oracle,
you may proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT without completing the full ANALYSIS section.

### Compare checklist
- **Structural triage first**: compare modified file lists, check for missing modules or test data before any detailed tracing; only shortcut to NOT EQUIVALENT on gaps that are ORACLE-VISIBLE to a relevant test oracle
```

意思決定ポイントがどう変わるか（1行）
- 早期 NOT_EQUIV の結論は「構造差がある」だけでは発火せず、「テストオラクルに写像できる（ORACLE-VISIBLE）構造差がある」場合に限定され、そうでなければ結論を保留して ANALYSIS 側で比較を続ける。

期待される“挙動差”（compare に効く形）
- 変更前に起きがちな誤り（一般形）: 片側にだけ存在する差分（ファイル/モジュール/データ等）を見つけると、その差が実際にテストの assert/例外/外部状態へ影響するか未確定でも NOT_EQUIV を確定してしまう（偽 NOT_EQUIV）。
- 変更後に減るメカニズム: 「ORACLE-VISIBLE へ写像できるか」をショートカットの条件にすることで、観測可能性が薄い構造差では ANALYSIS に送られ、テストオラクル基準（D1）に沿った比較へ戻る。
- 誤判定方向: 主に偽 NOT_EQUIV を減らす。偽 EQUIV を増やしにくい理由は、ORACLE-VISIBLE だと示せる差（＝D1 に影響する差）では従来通り NOT_EQUIV を早期確定でき、また ORACLE-VISIBLE でない場合も「EQUIV を早期確定」するのではなく「保留して分析継続」へ倒すため。

最小インパクト検証（思考実験）
- ミニケースA（改善が効く状況）:
  - 観測: S1/S2 で片側にだけ存在する artifact が見えるが、それが関連テストの assert/例外/外部状態と結びつく証拠が薄い（ORACLE-VISIBLE と言えない）。
  - Before: structural gap だけで NOT_EQUIV を早期結論しがち。
  - After: ORACLE-VISIBLE でないため結論を保留し、ANALYSIS（テスト単位のオラクル照合）へ進む。
- ミニケースB（逆方向の誤判定を誘発しうる状況）:
  - 観測: structural gap が実は決定的で、短い照合で ORACLE-VISIBLE と示せるが、分析者が「ORACLE-VISIBLE の主張」を書き落とす。
  - 悪化しない理由/回避策（新しい必須手順を増やさずに）: チェックリストの trigger line が “only shortcut ... ORACLE-VISIBLE ...” を明示するため、「ショートカットを使うなら ORACLE-VISIBLE を書く」方向に自然に誘導される。一方で書き落とした場合はショートカット不能となり、誤った EQUIV ではなく「保留→ANALYSIS 継続」に倒れる（逆方向の誤判定より、追加探索に寄るだけ）。

failed-approaches.md との照合（1〜2点、具体）
- “証拠の種類をテンプレートで事前固定しすぎる変更は避ける” に整合: 本提案は「どの証拠を探すか」を固定せず、結論ショートカットの根拠型を「テストオラクルへ写像できる差」に揃えるだけで、探索の入口や証拠種類を強制しない。
- “探索の自由度を削りすぎない / 読解順序の半固定は避ける” に整合: S1/S2 の実施順序や探索経路はそのまま維持し、ショートカット条件だけを精緻化する（早期確定の過剰適応を抑えるが、探索経路の固定はしない）。

未参照（理由）
- README.md / docs/design.md / docs/reference/agentic-code-reasoning.pdf は今回は未参照（理由: 本提案は compare テンプレート内の結論トリガ条件の精緻化で完結し、根拠となる失敗原則（failed-approaches）とカテゴリ定義（Objective）の参照で十分なため）。

変更規模の宣言
- 変更規模: 2行変更（いずれも既存 compare セクション内の置換/追記で、MUST/required の純増なし）。5行以内を満たす。

停滞対策の自己チェック
- 監査で褒められやすいだけの美文化に留まっていないか？: 留まっていない。早期結論の発火条件（行動）が変わり、保留→ANALYSIS へ送る分岐が増える。
- compare の誤判定を減らす意思決定ポイントが実際に変わるか？: 変わる（structural gap のみでは NOT_EQUIV を確定できず、ORACLE-VISIBLE の観測条件が必要になる）。
- Decision-point delta が理由の言い換えだけになっていないか？: なっていない（IF 条件が “structural gap” → “structural gap AND ORACLE-VISIBLE” に変わり、行動も “結論” vs “保留して分析継続” に分岐）。
- 必須ゲート総量を増やしていないか？: MUST/required の追加なし。既存の “may proceed directly” をより限定するだけで、必須ゲートは増やしていない。
