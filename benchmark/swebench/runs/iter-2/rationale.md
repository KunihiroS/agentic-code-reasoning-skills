# Iteration 2 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（未提供）
- 失敗ケース: 不明（未提供）
- 失敗原因の分析: compare において「差分を見つけた」こと自体を重要差分と誤認し、テストの観測点（test oracle / assertion）への結線が弱いまま EQUIV/NOT_EQUIV を早期確定しがち、という失敗メカニズムを想定。

## 改善仮説

差分を (1) テストの観測点に影響しうる差分（oracle-visible）と (2) 表現・構造の差（oracle-invisible）に分類してから追跡優先度を決めることで、表層差分に探索が吸い込まれにくくなり、比較判断（overall）の安定性が上がる。

## 変更内容

- Compare の STRUCTURAL TRIAGE に optional な S4（Difference importance: ORACLE-VISIBLE / ORACLE-INVISIBLE の分類と、oracle-visible を優先して concrete test oracle へ結線する指針）を 3 行追加。
- Compare checklist に、差分を oracle-visibility で分類してトレース優先度を付ける optional ガイドを 1 行追加。

## 期待効果

- 「差分の存在」と「差分の重要度（oracle 可視性）」の混同を減らし、根拠（具体的な assertion へのトレース）に結び付いた比較結論を増やす。
- その結果として、oracle 連結が薄いままの NOT_EQUIV 断定（偽 NOT_EQ）と、重要差分の見落とし（偽 EQUIV）の双方を減らしやすくなることを期待する。
