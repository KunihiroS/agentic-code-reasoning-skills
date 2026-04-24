過去提案との差異: 直近却下案のように特定の観測境界へ構造差を写像して狭めるのではなく、早期結論の順序を「構造差の発見→最短の影響トレース→結論」に並べ替える。
Target: 両方
Mechanism (抽象): 構造差を見つけた直後の直接結論を、verdict に効く最短トレースを先に作る順序へ置換する。
Non-goal: 特定のテスト種別、言語、リポジトリ、または固定された観測境界を新しい判定条件にしない。

禁止方向の確認:
- 再収束を比較規則として前景化しすぎる変更は避ける。
- 未確定 relevance を常に保留へ倒す既定動作は避ける。
- 差分を新しい抽象ラベルや固定アンカーで強くゲートする変更は避ける。
- 終盤の証拠十分性チェックを confidence 調整だけへ吸収しない。
- 最初に見えた差分から単一の追跡経路を既定化しない。
- 近接欄を統合して探索理由と反証可能性を潰さない。
- 直近却下案と同じ、具体的なイテレーション識別子や特定ケース識別子に依存する記述はしない。

カテゴリ A 内での具体的メカニズム選択理由:
1. Compare の現在の強い分岐は STRUCTURAL TRIAGE 後に直接 FORMAL CONCLUSION へ進める点で、ここを「結論前に最短影響トレースを挟む」順序へ変えると、ANSWER と CONFIDENCE が実際に変わりうる。
2. これは結論条件を特定の境界へ狭めるのではなく、構造差を発見した後の処理順を変えるため、探索経路の半固定ではなく偽 EQUIV/偽 NOT_EQUIV の両方に効く。

意思決定ポイント候補と Step 2.5:
- 候補1: STRUCTURAL TRIAGE の clear structural gap。現在は証拠が薄くても直接 NOT EQUIVALENT に進みがち。変更後は追加探索または CONFIDENCE 低下を伴う最短影響トレースにアウトカムが変わる。
- 候補2: UNVERIFIED third-party/library behavior。現在は仮定を注記して結論へ進みがち。変更後は ANSWER より UNVERIFIED/CONFIDENCE の明示が変わる。
- 候補3: semantic difference 発見後の relevance 判断。現在は関連テストを一つ辿って影響なしとしがち。変更後は反証探索の継続/打ち切り条件が変わる。

選択: 候補1。
選定理由:
- 早期 NOT EQUIVALENT の直接分岐は、詳細 ANALYSIS を省略できるため、誤った構造差の過大評価が ANSWER に直結する。
- 一方で構造差を弱めすぎると偽 EQUIV が増えるため、構造差は保ちつつ結論前の順序だけを最短トレースへ変えるのが overall に向く。

改善仮説:
構造差を verdict として即時消費せず、まず「その差が少なくとも一つの関連テスト結果へ到達する最短経路」を構成してから結論へ進ませると、構造差の判別力を維持しながら、根拠の薄い早期 NOT_EQUIV と差分見落としによる偽 EQUIV の両方を減らせる。

SKILL.md の該当箇所と変更方針:
現在の自己引用:
"If S1 or S2 reveals a clear structural gap (missing file, missing module
update, missing test data), you may proceed directly to FORMAL CONCLUSION
with NOT EQUIVALENT without completing the full ANALYSIS section."

変更方針:
この直接ジャンプを、STRUCTURAL TRIAGE で見つけた gap を最短の verdict-affecting trace として ANALYSIS に先に記録する指示へ置換する。full ANALYSIS の完全実施を増やすのではなく、直接結論の前に最短経路だけを置く順序変更にする。

Payment: add MUST("Before using a structural gap for NOT EQUIVALENT, record the shortest trace from the gap to a relevant PASS/FAIL outcome, or mark the verdict LOW confidence if that trace is unavailable.") ↔ demote/remove MUST("Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS.")

Decision-point delta:
Before: IF S1 or S2 reveals a clear structural gap THEN proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT because structural absence is treated as sufficient evidence.
After:  IF S1 or S2 reveals a clear structural gap THEN first record the shortest trace from that gap to a relevant PASS/FAIL outcome, and only then conclude or lower confidence because the gap is used as verdict-affecting evidence rather than a standalone shortcut.

変更差分プレビュー:
Before:
"If S1 or S2 reveals a clear structural gap (missing file, missing module
update, missing test data), you may proceed directly to FORMAL CONCLUSION
with NOT EQUIVALENT without completing the full ANALYSIS section."

After:
"If S1 or S2 reveals a clear structural gap (missing file, missing module
update, missing test data), treat it as the first ANALYSIS item, not as a
standalone verdict."
Trigger line (planned): "Before using a structural gap for NOT EQUIVALENT, record the shortest trace from the gap to a relevant PASS/FAIL outcome, or mark the verdict LOW confidence if that trace is unavailable."
"You may keep the remaining ANALYSIS minimal when this trace already decides
all relevant outcomes."

Discriminative probe:
抽象ケース: 片方の変更だけが補助ファイルを編集しているが、その補助ファイルが関連テストの実行経路に入るかは未確認。
Before では「片方にだけファイル差がある」ことから偽 NOT_EQUIV へ進みがち。After では最短影響トレースが作れなければ LOW confidence/保留寄りになり、作れれば正しい NOT_EQUIV として強化される。
これは新しい必須ゲートの純増ではなく、既存の直接ジャンプ文言を置換し、full ANALYSIS 必須の圧を一部支払いとして下げる範囲に留める。

failed-approaches.md との照合:
- 原則3の「差分昇格条件を抽象ラベルや固定アンカーで強くゲートしすぎる」失敗を避けるため、missing file 等を新ラベル分類せず、既存の構造差から最短の影響トレースへ順序だけを変える。
- 原則2の「未確定 relevance を常に保留へ倒す」失敗を避けるため、未確認なら必ず保留ではなく、trace が取れた場合は NOT_EQUIV へ進める。

変更規模の宣言:
SKILL.md の変更は STRUCTURAL TRIAGE 直後の 3 行を 5 行程度へ置換する想定で、差分は 15 行以内。研究のコア構造である番号付き前提、仮説駆動探索、手続き間トレース、必須反証は維持する。
