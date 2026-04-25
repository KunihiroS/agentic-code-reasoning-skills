# Iteration 58 — 変更理由

## 前イテレーションの分析

- 前回スコア: proposal.md には未記載
- 失敗ケース: proposal.md には固有ケース一覧なし
- 失敗原因の分析: per-test comparison の単一欄が内部 behavior の差と pass/fail outcome の差を同じ SAME/DIFFERENT 語へ畳み、内部機構差だけを outcome 差として扱う誤判定、または目的の類似だけで outcome 同一とみなす誤判定を誘発しうる。

## 改善仮説

Per-test comparison を behavior relation と outcome relation の二軸に分けることで、結論に使う根拠を D1 の pass/fail outcome relation へ揃える。これにより、内部 mechanism の差だけで NOT EQUIVALENT に寄る誤りと、pass/fail result まで未追跡なのに EQUIVALENT に寄る誤りの両方を抑える。

Trigger line (final): "Outcome relation: SAME / DIFFERENT / UNVERIFIED pass/fail result"

この Trigger line は proposal の差分プレビューにあった Trigger line と一致しており、per-test comparison の分岐を発火させる位置に入っている。

## 変更内容

Compare template の各 per-test analysis で、既存の `Comparison: SAME / DIFFERENT outcome` を削除し、以下の二軸記録へ置換した。

```text
Behavior relation: SAME / DIFFERENT mechanism
Outcome relation: SAME / DIFFERENT / UNVERIFIED pass/fail result
```

新しい必須ゲートを追加するのではなく、既存の Comparison 行の意味を置換・分解したため、結論前の判定手順の総量は増やしていない。

## 期待効果

内部 behavior が異なっても pass/fail result が同じ、または未追跡である場合に、`Outcome relation` を SAME または UNVERIFIED として分離できる。逆に内部 behavior が似ていても pass/fail result まで根拠が届かない場合は UNVERIFIED と明示できるため、EQUIVALENT/NOT EQUIVALENT の判断が test outcome ベースに寄り、compare の実効差が出やすくなる。
