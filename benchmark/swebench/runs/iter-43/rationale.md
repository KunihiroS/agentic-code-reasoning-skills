# Iteration 43 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（この作業では未参照）
- 失敗ケース: 未参照
- 失敗原因の分析: 関連テスト探索が direct reference に偏ると、shared helper・wrapper・re-export 経由の到達経路を見落として、pass-to-pass relevance を早く閉じすぎる可能性がある。

## 改善仮説

関連テストの見つけ方を「名前一致で止まりやすい取得」から「direct reference を起点にしつつ、疎い場合は caller/importer/re-export へ外向き探索する取得」へ置き換えると、比較前提となる relevant test の取りこぼしを減らせる。これにより、構造差や表層差だけで早く寄り切る判断を減らし、EQUIVALENT と NOT EQUIVALENT の両方向で判定精度の改善が期待できる。

## 変更内容

- D2 の relevant tests 定義で、関連テスト特定の手順を direct reference 優先 + sparse/absent 時の caller/importer/re-export expansion に置換した。
- compare checklist の「fail-to-pass AND pass-to-pass tests を識別する」を、「fail-to-pass を先に特定しつつ、direct-reference または caller/importer search を尽くすまで pass-to-pass relevance を閉じない」に置換した。
- Trigger line (final): "If direct test references are absent, expand outward through callers/importers before marking pass-to-pass tests irrelevant or N/A."
- この Trigger line は proposal の差分プレビューにあった Trigger line と一致しており、direct reference 不足時に外向き探索へ分岐させる意図をそのまま保持している。

## 期待効果

direct reference が薄いケースでも、wrapper・importer・re-export を介した実際の到達経路に沿って関連テストを回収しやすくなる。その結果、pass-to-pass tests を早期に irrelevant/N/A 扱いしてしまう誤りが減り、偽の EQUIVALENT と偽の NOT EQUIVALENT の両方を抑制できる。