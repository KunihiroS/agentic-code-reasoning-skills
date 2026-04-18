過去提案との差異: 構造差→早期 NOT_EQUIV の条件を観測境界へ狭めたり新トリガを足すのではなく、探索の“順序/構造”として Step 3 を「二仮説並走」に置換する。
Target: 両方（偽 EQUIV と 偽 NOT_EQUIV の同時低減）
Mechanism (抽象): 1つの仮説だけで読み進めず、最初から競合する2仮説と“判別観測”を並置して、以後の探索を判別駆動にする。
Non-goal: STRUCTURAL TRIAGE の早期結論条件・観測境界・VERIFIED/UNVERIFIED 由来のゲート設計は一切変更しない。

カテゴリ A（推論の順序・構造）内での具体メカニズム選択理由
- 現状 Step 3 は「単一仮説→探索→更新」の直列構造が強く、実務的には最初の仮説が“探索の入口”を固定しやすい。
- A の範囲で、追加ゲートを増やさずに全モード共通で効かせるには、Step の中身を「逆方向推論（結論の反対も同時に立てる）」へ構造変換するのが最小差分。
- compare だけを局所最適化するのではなく、diagnose / explain / audit-improve でも確認バイアスを弱め、反証（Step 5）で狙う対象の質を上げる（“やり方”ではなく“どれを反証候補にするか”）。

改善仮説（1つ）
- 仮説を単発で立てるよりも「最有力仮説と、その最強の競合仮説」を同時に保持し、両者を分ける“判別観測”を先に書くほうが、探索が特定シグナル捜索に固定されにくく、偽 EQUIV（反例の見落とし）と偽 NOT_EQUIV（差の過大評価）を同時に減らせる。

SKILL.md の該当箇所（短い引用）と変更内容
引用（Step 3: Hypothesis-driven exploration）:
"Before opening any file, write:
  HYPOTHESIS H[N]: ...
  EVIDENCE: ...
  CONFIDENCE: ..."
変更: 上の単一仮説テンプレを「二仮説 + 判別観測」テンプレへ置換する（Step の追加はしない）。

Decision-point delta（IF/THEN 2行）
Before: IF これからファイルを開いて探索を始める THEN 単一の HYPOTHESIS と EVIDENCE を書く because 探索の当たりを付けて読む順序を決めるため
After:  IF これからファイルを開いて探索を始める THEN 競合する2仮説と DISCRIMINATOR（両者を分ける観測）を書く because 探索を“片仮説の正当化”ではなく“判別”に寄せて誤判定の両側を同時に抑えるため

変更差分プレビュー（Before/After, 3–10行）
Before:
  HYPOTHESIS H[N]: [what you expect to find and why]
  EVIDENCE: [what supports this hypothesis — cite premises or prior observations]
  CONFIDENCE: high / medium / low
After:
  HYPOTHESIS H[N]: [most likely explanation / equivalence claim]
  ALT H[N]: [strongest competing explanation / non-equivalence claim]
  DISCRIMINATOR: [what observation would separate H vs ALT, and where to look]
  CONFIDENCE: high / medium / low

failed-approaches.md との照合（整合 1–2 点）
- 「証拠の種類をテンプレートで事前固定しすぎる変更は避ける」: DISCRIMINATOR は固定の証拠種を列挙せず、ケースごとに“どの観測が分岐点になるか”を自分で選ぶため、探索を特定シグナルの捜索へ一律固定しない。
- 「探索の自由度を削りすぎない／読解順序の半固定は危険」: 二仮説並走は入口を一つに固定せず、むしろ初手から代替経路を同時に開く構造であり、観測境界への還元や早期ゲート増設とは逆方向。

変更規模の宣言
- SKILL.md の Step 3 テンプレ部分の置換のみ（変更は最大 4 行、hard limit 5 行以内）。
