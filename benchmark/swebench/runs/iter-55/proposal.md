過去提案との差異: 構造差から NOT_EQUIV へ進む条件を観測境界へ狭める提案ではなく、既存の STRUCTURAL TRIAGE を Compare checklist で二重ゲート化している重複だけを圧縮する。
Target: 両方
Mechanism (抽象): 同じ構造・規模判断をテンプレート本体とチェックリストで二度読ませる重複を消し、構造差の過剰サリエンスによる偽 NOT_EQUIV と、詳細 trace の早期省略による偽 EQUIV を同時に減らす。
Non-goal: STRUCTURAL TRIAGE の結論条件、assertion boundary、test oracle、VERIFIED 接続条件は変更しない。

カテゴリ G 内での具体的メカニズム選択理由:
- 候補 1: Compare checklist の先頭 2 項目は、STRUCTURAL TRIAGE 本体の S1-S3 と「clear structural gapなら直接結論可」をほぼ再掲している。現在のデフォルト挙動は、証拠が不十分でも checklist 到達時に構造・規模判断をもう一度強調しがちなこと。削除/統合後の観測可能アウトカムは、追加探索/結論保留/CONFIDENCE が structural gap の再確認ではなく未解決の verdict-bearing claim に向きやすくなること。
- 候補 2: Minimal Response Contract は Core Method と Certificate template の必須出力を再掲している。現在のデフォルト挙動は、証拠生成よりテンプレート充足へ寄りやすいこと。削除後のアウトカムは audit/format 負荷の低下だが、出力必須項目の見落としリスクがあり今回は選ばない。
- 候補 3: Guardrails #2/#4 と Compare checklist の trace/counterexample 項目は近接内容を反復している。現在のデフォルト挙動は、semantic difference を見た後の単一 trace へ意識が寄りやすいこと。統合後のアウトカムは追加探索の焦点化だが、failed-approaches の「単一追跡経路の既定化」と近く見えるため今回は選ばない。

選択: 候補 1。理由は 2 点だけ:
1. Compare の実行時分岐で、チェックリスト到達時に「構造/規模を再ゲートする」か「未解決の verdict-bearing claim へ進む」かが変わる。
2. STRUCTURAL TRIAGE 本体は残すため、研究コアや反証は弱めず、重複による認知負荷と構造差の過剰重みだけを下げられる。

改善仮説:
Compare checklist から STRUCTURAL TRIAGE 本体の重複再掲を 1 行の参照に圧縮すると、モデルは構造・規模判断を二度目の結論ゲートとして扱わず、既に定義済みの triage 後は未解決の test-behavior claim と反証に作業記憶を使えるため、EQUIV/NOT_EQUIV の両方向で premature closure が減る。

SKILL.md の該当箇所と変更:
短い引用:
- 「- **Structural triage first**: compare modified file lists, check for missing modules or test data before any detailed tracing」
- 「- For large patches (>200 lines), rely on structural comparison and high-level semantic analysis rather than exhaustive line-by-line tracing」

提案変更:
上の 2 行を削除し、同じ位置に 1 行だけ置く。STRUCTURAL TRIAGE 本体の S1-S3 と早期結論条件は変更しない。
Payment: add MUST("none — no new required gate") ↔ demote/remove MUST("- **Structural triage first**: compare modified file lists, check for missing modules or test data before any detailed tracing" / "- For large patches (>200 lines), rely on structural comparison and high-level semantic analysis rather than exhaustive line-by-line tracing")

Decision-point delta:
Before: IF the model reaches Compare checklist after STRUCTURAL TRIAGE THEN re-emphasize structural/scale comparison as another checklist gate because the checklist repeats those items as top-level actions.
After:  IF the model reaches Compare checklist after STRUCTURAL TRIAGE THEN do not re-run structural/scale triage; continue with changed files, tests, per-side traces, and counterexample/no-counterexample evidence because the certificate already owns triage.

変更差分プレビュー:
Before:
- **Structural triage first**: compare modified file lists, check for missing modules or test data before any detailed tracing
- For large patches (>200 lines), rely on structural comparison and high-level semantic analysis rather than exhaustive line-by-line tracing
- Identify changed files for both sides
- Identify fail-to-pass AND pass-to-pass tests

After:
- Structural/scale triage is defined above; do not repeat it as a second checklist gate.
- Identify changed files for both sides
- Identify fail-to-pass AND pass-to-pass tests
Trigger line (planned): "Structural/scale triage is defined above; do not repeat it as a second checklist gate."

Discriminative probe:
抽象ケース: 片方だけが補助ファイルを変更しているが、STRUCTURAL TRIAGE 本体ではその補助ファイルが relevant tests の直接 import や missing data に当たるか未確定で、後続 trace が必要な場面。
変更前は checklist で structural/scale が再強調され、未確定の構造差を二度目の強い信号として扱い、偽 NOT_EQUIV または高レベル比較だけの早期結論に寄りやすい。
変更後は新しい必須ゲートを増やさず、重複文言の置換だけで triage を一度に限定し、以後は既存の per-test trace と counterexample/no-counterexample に進むため、誤判定を避けやすい。

failed-approaches.md との照合:
- 原則 3/5 に整合する。差分を新しい抽象ラベルや単一アンカーへ昇格させず、むしろ構造差を二度目のゲートにする重複を減らす。
- 原則 4 にも抵触しない。終盤の証拠十分性チェックや反証は削らず、STRUCTURAL TRIAGE 本体も残すため、confidence への吸収や premature closure は狙わない。

変更規模の宣言:
SKILL.md の Compare checklist で 2 行を 1 行に置換するだけ。差分は 1 行減、合計 15 行以内。新規モードなし、新しい必須ゲートなし、番号付き前提・仮説駆動探索・手続き間トレース・必須反証は維持する。
