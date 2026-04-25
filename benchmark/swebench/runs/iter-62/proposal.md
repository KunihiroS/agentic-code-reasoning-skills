過去提案との差異: 直近却下のように早期 NOT_EQUIV の条件を観測境界へ写像せず、STRUCTURAL TRIAGE 自体は残したまま Compare checklist の重複強調だけを削る。
Target: 両方
Mechanism (抽象): 同じ義務をテンプレート本体と末尾チェックリストで二重に読ませる箇所を削り、判定時に最終チェックリストの反復語へ過剰アンカーしないようにする。
Non-goal: 証拠十分性チェック、反証、番号付き前提、手続き間トレース、早期 NOT_EQUIV の成立条件は変更しない。

カテゴリ G 内での具体的メカニズム選択理由:
- failed-approaches.md と直近却下履歴からの禁止方向: 再収束を既定化する、未検証 relevance を広く保留へ倒す、差分昇格に新ラベル/観測境界を置く、証拠十分性を CONFIDENCE へ吸収する、最初の差分から単一路径へ固定する、探索理由と情報利得を一欄へ潰す、早期 NOT_EQUIV を特定の観測境界へ狭める、Diverging assertion / impact witness を弱める、の各方向は採らない。
- 2G 候補:
  1. Compare checklist の「Structural triage first」と「large patches」: STRUCTURAL TRIAGE 本体 S1-S3 と重複。現在は証拠不足時でも末尾の反復により構造差ショートカットを再優先しがち。削除後は本体条件だけが残り、アウトカムは過剰な早期 NOT_EQUIV から通常 ANALYSIS 継続へ変わりうる。
  2. Core Method Step 3 の OPTIONAL — INFO GAIN: NEXT ACTION RATIONALE と近接。ただし failed-approaches 原則 6 がこの統合方向を明示的に危険視しているため捨てる。
  3. Minimal Response Contract: Core Method と Compare template の required sections と重複。現在は形式充足へ寄りうるが、削ると出力契約全体を弱める恐れがあるため今回は選ばない。
- 選定理由: 候補 1 は Compare の最後にある短いチェックリストなのでベンチモデルが結論直前に参照しやすく、重複した structural/large-patch 語が ANSWER 直前の探索優先度を歪めうる。削っても S1-S3 と早期結論条件は本体に残るため、研究コアや反証義務は維持される。

改善仮説:
Compare checklist から STRUCTURAL TRIAGE 本体と重複する2項目だけを削ると、必須構造比較は維持したまま、結論直前のチェックリストが「構造差・大規模差を再度優先せよ」という過剰な二重シグナルにならず、EQUIV/NOT_EQUIV の両方で証拠に沿った停止位置を選びやすくなる。

SKILL.md の該当箇所と変更:
- 残す本体引用: 「STRUCTURAL TRIAGE (required before detailed tracing):」および S1-S3、さらに「If S1 or S2 reveals a clear structural gap ... you may proceed directly to FORMAL CONCLUSION ...」は変更しない。
- 削る重複引用: Compare checklist 冒頭の「Structural triage first: compare modified file lists...」と「For large patches (>200 lines), rely on structural comparison...」を削除する。
- Payment: add MUST("none") ↔ remove MUST("none; deletion only, no new required gate")

Decision-point delta:
Before: IF final Compare checklist is consulted before ANSWER and structural/large-patch cues are present THEN re-prioritize structural shortcut language even though S1-S3 already ran because the same priority appears twice.
After:  IF final Compare checklist is consulted before ANSWER and structural/large-patch cues are present THEN rely on the single STRUCTURAL TRIAGE block for any shortcut and otherwise continue the remaining checklist items because the duplicate reinforcement was removed.

変更差分プレビュー:
Before:
- **Structural triage first**: compare modified file lists, check for missing modules or test data before any detailed tracing
- For large patches (>200 lines), rely on structural comparison and high-level semantic analysis rather than exhaustive line-by-line tracing
- Identify changed files for both sides
- Identify fail-to-pass AND pass-to-pass tests
After:
- Identify changed files for both sides
- Identify fail-to-pass AND pass-to-pass tests
Trigger line (planned): "- Identify changed files for both sides"

Discriminative probe:
抽象ケース: 両変更は同じ挙動を実装しているが、一方だけ補助ファイル構成や差分量が目立ち、S1-S3 では clear structural gap までは立たない。
変更前は末尾チェックリストの重複した structural/large-patch 強調で偽 NOT_EQUIV または過度な構造優先に寄りがちだが、変更後は本体 S1-S3 で clear gap がない限り per-test / counterexample 項目へ進み、偽 NOT_EQUIV を避ける。
これは新しい必須ゲートではなく、既存文言の削除のみで、必須反証と Diverging assertion は維持される。

failed-approaches.md との照合:
- 原則 3/5 と整合: 新しい抽象ラベルや単一観測アンカーを追加せず、むしろ重複した探索順固定シグナルを減らす。
- 原則 4 と整合: Pre-conclusion self-check、COUNTEREXAMPLE、NO COUNTEREXAMPLE EXISTS、Diverging assertion は削らず、証拠十分性を CONFIDENCE へ吸収しない。

変更規模の宣言:
SKILL.md の変更は Compare checklist から2行削除のみ（2行、15行以内）。新規モードなし、新規 MUST なし、研究コア構造は維持。