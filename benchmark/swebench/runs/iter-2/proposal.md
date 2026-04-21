過去提案との差異: 今回は STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件を狭めず、意味差が見つかった後の「比較をどの粒度で続けるか」を変える提案である。
Target: 両方
Mechanism (抽象): 途中の経路差をそのまま差異扱いせず、次の共有されたテスト関連分岐/値状態での reconvergence を比較単位にする。
Non-goal: 構造差を特定の観測境界へ写像して早期 NOT_EQUIV 条件を絞り込むことはしない。

カテゴリ C 内での具体的メカニズム選択理由:
- compare が停滞/誤判定しやすいのは「差が見えた瞬間」に比較粒度が patch-level/path-level のまま固定される分岐で、ここを変えると EQUIV/NOT_EQUIV/追加探索の挙動が実際に変わる。
- docs/design.md の anti-skip は per-item iteration を要求しており、差異の重要度を「最初の差」ではなく「次の共有された判定点まで残る差」で分類するのはカテゴリ C の比較枠組み変更として自然。

改善仮説:
内部実装の差をいったん provisional に落とし、次の共有されたテスト関連判定点で再比較させると、早すぎる偽 NOT_EQUIV と、単一路 tracing からの偽 EQUIV の両方を減らせる。

Payment: add MUST("none") ↔ demote/remove MUST("- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact")

該当箇所と変更方針:
現状引用: "- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact"
変更: 「差がある経路を1本なぞる」から、「次の共有された test-relevant predicate / returned value / asserted state まで差が残るかを分類する」へ置換する。

Decision-point delta:
Before: IF relevant path 上で実装差を見つけた THEN その差を有力な判別材料として 1 本の関連テストを差分経路に通し、影響なし/ありへ進む because 最初の path divergence を比較粒度としている。
After:  IF relevant path 上で実装差を見つけても次の共有された test-relevant predicate/value state で両者が一致する THEN その差を non-discriminative として比較を reconvergence 点から続行し、一致しないときだけ差分結論へ進む because downstream reconvergence の有無を比較粒度としている。

変更差分プレビュー:
Before:
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
After:
- When a semantic difference is found, compare whether the divergence survives to the next shared test-relevant predicate, returned value, or asserted state; if the traces reconverge first, continue comparison from that reconvergence point.
Trigger line (planned): "If two traces diverge internally but re-enter the same test-relevant predicate/value state, treat the earlier difference as non-discriminative and compare from that reconvergence point."
- Provide a counterexample (if different) or justify no counterexample exists (if equivalent)

Discriminative probe:
抽象ケース: 2 つの変更が別々の正規化/補助関数を通るため途中状態は異なるが、その後に同じ branch predicate に同じ canonical value を渡す。変更前は「経路が違う」ことを差異の強い証拠として扱って偽 NOT_EQUIV になりやすく、逆に 1 本だけ traced して偽 EQUIV にも流れうる。変更後は reconvergence を確認した時点で追加探索を下流へ送るので、過度な早期結論を避けられる。

failed-approaches.md との照合:
- failed-approaches.md 自体に残存 blacklist はないが、与えられた却下履歴とは整合する。STRUCTURAL TRIAGE の S1/S2 も早期 NOT_EQUIV 条件も触らず、禁止された「特定観測境界への写像による狭窄」を再演しない。
- 研究コアの番号付き前提・仮説駆動探索・手続き間トレース・必須反証は維持し、差異重要度の分類だけを差し替える。

変更規模の宣言:
1 箇所の置換中心、15 行以内の差分で収まる小変更。