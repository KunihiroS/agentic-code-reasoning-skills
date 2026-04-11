# Iteration 47 — 変更理由

## 前イテレーションの分析

- 前回スコア: 85% (17/20)
- 失敗ケース: django__django-15368, django__django-15382, django__django-14787
- 失敗原因の分析: 15368 は Patch B がパスツーパステストを削除した事実を "test deleted = different outcome" と解釈して NOT_EQ に誤判定。15382 は複雑な例外制御フロートレースで収束不能。14787 は実差異の見落とし。

## 改善仮説

D2(b) の「changed code lies in their call path」という条件は正しいが、モデルがこれを trace 検証なしに適用するため、テスト削除のような観測事実から call path 関連性を誤って仮定してしまう。D2(b) に検証要件（"Verify this by tracing the test's execution; do not assume relevance from file proximity, shared module, or test-level changes such as deletion."）を追記することで、15368 パターンの誤判定を防ぎつつ、検証要件が両方向に等しく作用するため NOT_EQ 正答率を損なわない。

## 変更内容

Compare テンプレート内の `DEFINITIONS` セクション D2(b) の末尾に 2 行を追加: `Verify this by tracing the test's execution; do not assume relevance from file proximity, shared module, or test-level changes such as deletion.`

## 期待効果

- django__django-15368: パスツーパステスト削除からの関連性仮定が call path 検証に誘導され、NOT_EQ 誤判定が EQUIVALENT 正答に転じる可能性が高い（+1）
- NOT_EQ 正答 10/10 は維持（検証要件は両方向に等しく適用）
- 予測: 17/20（85%）→ 18/20（90%）
