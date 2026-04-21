過去提案との差異: 今回は STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を観測境界へ狭めず、pass-to-pass tests を「未確定のまま落とすか保留するか」という別の分岐の表現を変える。
Target: 両方
Mechanism (抽象): call-path relevance が未検証な既存 PASS テストを silent exclusion できない書式に置き換え、結論ではなく保留/追加探索へ分岐させる。
Non-goal: 構造差から NOT_EQUIV へ進む条件を assertion boundary や test oracle に写像して狭めることはしない。

カテゴリ E 内での具体的メカニズム選択理由
- 候補1: D2(b)「pass-to-pass tests は changed code が call path にあるときのみ relevant」。現在のデフォルト挙動: call path が未検証でも irrelevant 扱いで落としがち。変更後アウトカム: 追加探索または UNVERIFIED 明示に分岐し、EQUIV/NOT_EQUIV の早計を減らせる。
- 候補2: 「Complete every section」と「structural gap なら full ANALYSIS 省略可」の併存。現在のデフォルト挙動: 矛盾した指示により不要な ANALYSIS か、逆に雑な早期結論にぶれがち。変更後アウトカム: 結論保留ではなく、どこまで省略可能かが安定する。
- 候補3: Step 5.5 の「UNVERIFIED ... does not alter the conclusion」。現在のデフォルト挙動: alteration 判定を結論後回しにしがち。変更後アウトカム: CONFIDENCE 低下または保留を出しやすくなる。

選定: 候補1を主対象にし、候補2の矛盾解消を payment に使う。
理由:
1. compare の実行時分岐を直接変える: 未検証の pass-to-pass relevance で「除外して結論」ではなく「trace して除外 / できなければ UNVERIFIED」に変わる。
2. false EQUIV と false NOT_EQUIV の両側に効く: 見落とし回避と speculative impact の抑制を同時に行える。

改善仮説
- 「relevant only if ... lies in their call path」を、未検証時の既定動作まで含む trigger line に具体化すると、モデルは pass-to-pass tests を黙って落とさず、必要時だけ追加探索か UNVERIFIED を選べるため、overall の判定品質が上がる。

該当箇所と変更方針
- 現状引用1: "Pass-to-pass tests: tests that already pass before the fix — relevant only if the changed code lies in their call path."
- 現状引用2: "Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS."
- 変更方針: D2(b) に未検証時の既定動作を 1 行で追加し、後者は structural-gap 例外と衝突しない wording に圧縮する。

Decision-point delta
Before: IF pass-to-pass test の call-path relevance が未検証 THEN irrelevant とみなして分析対象から落としうる because D2(b) が inclusion 条件だけを述べ、未確定時の扱いを規定していない
After:  IF pass-to-pass test の call-path relevance が未検証 THEN provisional relevant として trace で除外するか scope を UNVERIFIED にする because trigger line が未確定時の既定分岐を明示する

Payment: add MUST("If call-path relevance of a pass-to-pass test is unresolved, keep it provisionally relevant until tracing excludes it, or mark the scope UNVERIFIED instead of omitting it.") ↔ demote/remove MUST("Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS.")

変更差分プレビュー
Before:
- "Pass-to-pass tests: tests that already pass before the fix — relevant only if the changed code lies in their call path."
- "Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS."
After:
- "Pass-to-pass tests: tests that already pass before the fix — relevant only if the changed code lies in their call path."
- Trigger line (planned): "If call-path relevance of a pass-to-pass test is unresolved, keep it provisionally relevant until tracing excludes it, or mark the scope UNVERIFIED instead of omitting it."
- "Complete every applicable section; if STRUCTURAL TRIAGE already establishes the outcome, skip only the sections it makes unnecessary."

Discriminative probe
- 抽象ケース: 2 つの変更は failing path では同じ修正を行うが、一方だけ既存 API の前処理位置をずらしている。既存 PASS テストがその API を通るかは diff だけでは即断できない。
- 変更前はその PASS テストを relevance 未確認のまま落として偽 EQUIV、または逆に speculative な影響を語って偽 NOT_EQUIV になりうる。変更後は trace して除外できれば EQUIV、できなければ UNVERIFIED/追加探索に倒れるため、早計な二択を避ける。
- これは新ゲート追加ではなく、既存 D2(b) の omission default を explicit に置換し、別箇所の強すぎる MUST を緩めて総量を不変にするだけである。

failed-approaches.md との照合
- 「再収束を比較規則として前景化しすぎない」に反しない: 下流で再収束するから差を弱める規則ではなく、未確定の relevance を黙殺しない既定動作を定めるだけ。
- 却下済みの「構造差/早期 NOT_EQUIV を特定の観測境界へ狭める」方向とも別物: structural triage の結論条件には触れず、pass-to-pass の inclusion/exclusion 分岐だけを対象にする。

変更規模の宣言
- 追加/置換は 3 行程度、hard limit 15 行以内。