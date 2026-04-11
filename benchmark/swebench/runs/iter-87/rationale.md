# Iteration 87 — 変更理由

## 前イテレーションの分析

- 前回スコア: 前イテレーション結果に基づく
- 失敗ケース: 記載なし（具体的 ID は省略）
- 失敗原因の分析: 仮説が REFUTED となった後にエージェントが方向性のない探索（exploratory drift）に陥り、仮説駆動の連鎖が途切れるケースが確認された。これが「不完全な推論チェーン」の一因と分析された。

## 改善仮説

仮説が REFUTED となった際に次の仮説 H[M+1] を即時に生成することを手続きとして明示することで、探索全体を通じた仮説駆動構造が維持され、「仮説否定後の漂流」に起因する不完全な推論チェーンが減少する。

## 変更内容

Step 3 の HYPOTHESIS UPDATE ブロック内の既存行に後続アクションを追記した。

- **変更前**: `H[M]: CONFIRMED / REFUTED / REFINED — [explanation]`
- **変更後**: `H[M]: CONFIRMED / REFUTED / REFINED — [explanation]; if REFUTED, state H[M+1] targeting what the refutation exposed before reading the next file`

変更規模: 1 行（既存行への追記のみ）

## 期待効果

- REFUTED 後に次の仮説を即座に生成することで、仮説チェーンが途切れず探索の焦点が維持される
- 「差異なし」と判断した仮説が REFUTED された後も代替仮説を持って再探索するため、見落としの発見率が向上する
- 仮説 → 証拠 → 更新 → 次仮説 のループが明示的に閉じられ、探索の構造的一貫性が保たれる
- 全モード（compare / localize / explain / audit-improve）および EQUIV / NOT_EQ 両方向に対称的に作用する
