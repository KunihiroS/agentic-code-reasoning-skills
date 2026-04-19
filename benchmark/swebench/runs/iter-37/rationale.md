# Iteration 37 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（このイテレーションの参照範囲では提供されていない）
- 失敗ケース: 不明（このイテレーションの参照範囲では提供されていない）
- 失敗原因の分析: STRUCTURAL TRIAGE で「構造差」を検出しただけで NOT EQUIVALENT を早期確定できると、後段で要求されている counterexample witness（テスト影響を示す観測点）なしに結論へ到達しうる。その結果、「ファイル差（構造差）はあるが relevant tests の outcome は同一」という状況で偽 NOT EQUIVALENT を生みやすい。

## 改善仮説

STRUCTURAL TRIAGE は差異検出には有効だが、それ自体を結論根拠にすると誤判定（特に偽 NOT EQUIVALENT）を誘発する。よって、STRUCTURAL TRIAGE から NOT EQUIVALENT を結論する場合でも、結論根拠の型を counterexample witness（例: diverging assertion）に揃えるようにし、witness を提示できない structural gap は ANALYSIS へ押し戻す。

Trigger line (final): "If you conclude NOT EQUIVALENT from STRUCTURAL TRIAGE, cite a counterexample witness (e.g., a diverging assertion) rather than file-list difference alone."

上の Trigger line は提案で計画された Trigger line と同一（少なくとも同等の一般化）であることを確認した。

## 変更内容

Compare セクションの STRUCTURAL TRIAGE 早期終了ルールを置換し、(1) ANALYSIS のスキップ自体は許容しつつ、(2) NOT EQUIVALENT 結論には concrete counterexample witness を必須化し、(3) witness を提示できない場合は ANALYSIS を完了する、という分岐へ変更した。また、この分岐を発火させるための Trigger line を該当箇所に直接配置した。

## 期待効果

- 偽 NOT EQUIVALENT の抑制: 「構造差のみ」→「テスト影響の観測点（witness）を伴う差異」へ根拠型を統一することで、結論が structural gap の存在だけに引きずられるのを防ぐ。
- 双方向の判定品質の安定: witness が示せない場合に ANALYSIS へ戻すため、EQUIVALENT に到達できるケース（または根拠不足の不確実性明示）を閉ざしにくくなり、NOT_EQ 側への片方向最適化になりにくい。