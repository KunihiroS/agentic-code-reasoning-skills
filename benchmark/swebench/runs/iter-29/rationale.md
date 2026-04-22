# Iteration 29 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A（この作業では与えられていない）
- 失敗ケース: N/A（この作業では与えられていない）
- 失敗原因の分析: compare で semantic difference は見つかっているのに test impact が未確定な場面で、差分側の実装深掘りを先に続けると relevance 判定が遅れ、観測点ベースでの切り分けが弱くなるおそれがある。

## 改善仮説

relevance 未確定時の次読取先を、差分側の実装深掘りよりも、その差分を最初に観測しうる test assertion / test-side call entry の確認へ寄せると、観測証拠に基づいて relevance を早く確定でき、EQUIVALENT / NOT EQUIVALENT の誤判定を減らせる。

## 変更内容

- relevant tests の同定指示を、changed symbol 参照から始めつつ、それで relevance が確定しない場合は nearest candidate test assertion または test-side call entry を読む優先順位に置換した。
- semantic difference 周辺に、test impact が unclear な場合は classifying より前に nearest candidate test assertion または test-side call entry を確認する trigger line を追加した。
- CLAIM D[N] への再記述義務は維持し、判定前の読取順だけを変更した。

Trigger line (final): "When a semantic difference is found but its test impact is unclear, inspect the nearest candidate test assertion or test-side call entry before classifying the difference."

この Trigger line は、差分プレビューで意図された trigger line と一致しており、relevance 未確定時に観測側の分岐を先に発火させる一般化された指示として機能する。

## 期待効果

差分の存在だけで relevance を早合点せず、どの test が実際にその差分を観測するかを先に確認するようになるため、観測されない差分の過大評価と、観測される差分の見落としの両方を減らせると期待する。変更は compare 内の局所的な読取順の置換に留めており、研究コアや既存の CLAIM D ベースの反証可能性は維持される。