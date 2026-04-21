# Iteration 7 — 変更理由

## 前イテレーションの分析

- 前回スコア: N/A（この作業では未参照）
- 失敗ケース: 構造差を見つけた時点で premature NOT_EQUIV に倒れやすい比較ケース
- 失敗原因の分析: STRUCTURAL TRIAGE が relevance analysis の前提必須ゲートとして強く働き、clear structural gap を十分な証拠として扱うことで、実際の relevant test/assertion まで届く反例追跡より先に NOT EQUIVALENT を確定しやすかった。

## 改善仮説

構造差は即時結論の根拠ではなく、counterexample search の優先順位づけ信号として使うほうがよい。先に「どの relevant test/assertion が割れるか」を書かせ、その witness を trace できたときだけ NOT EQUIVALENT に進ませれば、偽 NOT_EQUIV を減らしつつ、真の差分は assertion-level の反例として残せる。

## 変更内容

- `STRUCTURAL TRIAGE (required before detailed tracing)` を `STRUCTURAL TRIAGE (early; use it to prioritize, not to skip relevance analysis)` に置換した。
- completeness の説明を、構造差を十分条件として扱う文から、counterexample search の優先信号として扱う文へ置換した。
- direct conclusion を許す文を削除し、candidate diverging test/assertion を先に書いて trace し、witness が追えなければ UNVERIFIED にして ANALYSIS を継続する trigger line に置換した。
- 「A structural gap is sufficient to prioritize counterexample search, not by itself to skip ANALYSIS.」を加え、構造差の役割を priority signal に限定した。

Trigger line (final): "If S1 or S2 suggests NOT EQUIVALENT, first write the candidate diverging test/assertion and trace it before concluding; if no witness is traceable, mark the gap UNVERIFIED and continue ANALYSIS."

この Trigger line は proposal の差分プレビューにあった planned trigger line と一致しており、構造差検出後の分岐を結論ショートカットから witness-first の追跡へ実際に切り替えている。

## 期待効果

構造差だけで NOT EQUIVALENT を確定していた比較で、まず assertion-level の反例有無を確認するようになるため、premature NOT_EQUIV が減ることを期待する。一方で、実際に relevant test/assertion の差が追えるケースでは、その witness を伴うため NOT_EQUIVALENT の根拠がより明示的になる。