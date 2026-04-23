過去提案との差異: 今回は「構造差→早期 NOT_EQUIV」の結論条件を特定境界へ狭めるのではなく、差分発見後の次アクション順序を変えて、広域比較より先に同一テストでの両側トレースへ切り替える。
Target: 偽 EQUIV（主）だが、真の NOT_EQUIV でも具体的反例到達を早めるので両側を悪化させにくい。
Mechanism (抽象): compare 中に意味差分を見つけた瞬間の既定分岐を「広く読み続ける」から「その差分を通る共有 relevant test の両側トレースを先に行う」へ置き換える。
Non-goal: STRUCTURAL TRIAGE の結論条件を assertion boundary / oracle 可視性 / VERIFIED 接続へ写像して狭めることはしない。

Payment: add MUST("When a semantic difference is observed before a divergent test outcome is established, pause broad comparison and trace one shared relevant test through that differing path on both changes before resuming wider analysis.") ↔ demote/remove MUST("STRUCTURAL TRIAGE (required before detailed tracing)")

カテゴリ A 内での具体的メカニズム選択理由
- 候補1: STRUCTURAL TRIAGE の順序固定。現在のデフォルトは structural-first で広域差分整理に入りがち。変更後は 追加探索 の起点が「差分を通る test trace」に変わり、EQUIV / NOT_EQUIV / CONFIDENCE が早く分岐しうる。
- 候補2: >200 lines の large-patch 優先順。現在のデフォルトは高レベル比較へ寄りやすい。変更後は 保留 や低信頼のまま終わる代わりに shared call path の追加探索へ寄せられる。
- 候補3: semantic difference 発見後の次アクション。現在のデフォルトは広い tracing や再収束説明を続け、impact 確認が後段化しがち。変更後は 追加探索 の内容が即時に変わり、偽 EQUIV / 具体的 NOT_EQUIV / CONFIDENCE に直接差が出る。

選定: 候補3。
1. compare の停滞点は「差分を見つけても、その差分を両変更・同一テストで即検証せず、広域読みに戻る」分岐にあるため、THEN 行動の変更がそのまま実行時アウトカム差になる。
2. これは結論条件の狭義化ではなく探索順序の変更なので、却下済みの“特定境界への写像”とメカニズムが異なる。

改善仮説
- semantic difference を見つけた時点で、その差分を通る共有 relevant test の paired trace を先に固定すると、下流の再収束説明や構造差の印象に引っ張られる前に「同一テストで結果が分かれるか」を判別でき、偽 EQUIV を減らしつつ真の NOT_EQUIV も具体的反例で支えやすくなる。

該当箇所と変更方針
- 現行引用1: "STRUCTURAL TRIAGE (required before detailed tracing):"
- 現行引用2: "When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact"
- 変更: structural triage の「必ず最初」縛りを early guidance に下げ、その支払いで、差分発見時の即時 paired test trace を compare の既定順序として前に出す。

Decision-point delta
Before: IF semantic difference is observed but no divergent test outcome is yet traced THEN continue broad structural/high-level analysis and defer test-impact tracing because the template only requires that trace later when dismissing impact or writing the counterexample.
After:  IF semantic difference is observed but no paired test trace yet exists THEN immediately trace one shared relevant test through that differing path on both changes before resuming broader analysis because paired per-test tracing is the highest-information next step.

変更差分プレビュー
Before:
- STRUCTURAL TRIAGE (required before detailed tracing):
- If S1 or S2 reveals a clear structural gap ... you may proceed directly to FORMAL CONCLUSION
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
After:
- STRUCTURAL TRIAGE (perform early to map scope; it need not precede the first targeted test trace):
- Trigger line (planned): "When a semantic difference is observed before a divergent test outcome is established, pause broad comparison and trace one shared relevant test through that differing path on both changes before resuming wider analysis."
- When a semantic difference is found, use the trigger above before any further high-level comparison or equivalence claim

Discriminative probe
- 抽象ケース: 2変更が同じ downstream validator を呼ぶが、その前段 helper の返値条件だけが異なり、既存 fail-to-pass test の一入力でのみ assert 結果が分かれる。
- Before では shared downstream への再収束や広域比較を先に組み立てて偽 EQUIV になりがち。After では差分発見直後に同一 test を両側トレースするので、その入力での assertion divergence を先に確定でき、誤判定を避ける。
- これは新ゲート追加ではなく、既存の "trace at least one relevant test" を後段の注意書きから前段の順序規則へ置換するだけである。

failed-approaches.md との照合
- 原則1と整合: 「最初の差分＋後段吸収」を EQUIV 側の既定動作にしない。むしろ、再収束説明へ進む前に差分の test-level 含意を先に見る。
- 原則2/3と整合: UNVERIFIED 既定分岐や新しい抽象ラベルは足さず、差分の昇格条件も特定観測境界へ狭めない。変えるのは次に何を読むかという順序だけ。

変更規模の宣言
- 置換中心で 8 行前後。15 行以内に収める。