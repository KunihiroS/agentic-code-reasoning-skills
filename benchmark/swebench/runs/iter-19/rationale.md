# Iteration 19 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A
- 失敗ケース: N/A
- 失敗原因の分析: obligation ラベル段階で差分を吸収または断定すると、どの premise/assertion に対する差かが曖昧なまま verdict に使われ、無害差分の過剰昇格と有害差分の早すぎる吸収が起きうる。

## 改善仮説

semantic difference を verdict に使う前に、各 surviving difference を特定の test premise/assertion に結びついた CLAIM D[N] に言い換え、premise-to-assertion trace を 1 回通すようにすると、差分の扱いが test-facing になり、EQUIV / NOT_EQ の両側で判定の根拠が具体化される。

## 変更内容

compare の edge-case 部分で、semantic difference 発見後の obligation-level classification を置換し、まず CLAIM D[N] と TRACE TARGET を書かせてから Status を判定する形に変更した。あわせて compare checklist の同趣旨の bullet も同じ trigger line に置換し、追加ではなく統合で decision point を差し替えた。

Trigger line (final): "If a semantic difference survives tracing, restate it as CLAIM D[N] against a specific test premise/assertion before classifying it."

この Trigger line は proposal の差分プレビューにある planned trigger line と一致しており、差分を premise/assertion に結びつけてから classify するという意図をそのまま反映している。

## 期待効果

semantic difference を理由の言い換えではなく条件と行動の変化として処理できるため、test-facing premise/assertion に届く差だけを NOT_EQ の根拠にし、届かない差は preserved として扱いやすくなる。これにより compare の判定が assertion-level evidence に寄り、過剰吸収と過剰昇格の両方の抑制が期待できる。
