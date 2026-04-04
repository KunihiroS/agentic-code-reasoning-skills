# Iteration 18 — 変更理由

## 前イテレーションの分析

- 前回スコア: 75% (15/20)
- 失敗ケース: django__django-15368, django__django-15315, django__django-15382, django__django-14122, django__django-12663
- 失敗原因の分析:

  **失敗パターンの内訳:**
  - EQUIVALENT → NOT_EQUIVALENT（2 件）: 15368, 15382
  - EQUIVALENT → UNKNOWN（1 件）: 15315（31 ターン枯渇、コスト $0.19）
  - NOT_EQUIVALENT → UNKNOWN（2 件）: 14122（31 ターン枯渇、コスト $0.23）、12663（31 ターン枯渇、コスト $0.23）

  **UNKNOWN ケースの分析（3/5 failures — 支配的パターン）:**
  - 3 件すべてが最大ターン数（31 ターン）に達した後に UNKNOWN を出力。
  - 高コスト（$0.19〜$0.23）かつ多ターンであることから、エージェントは広範な探索を行いながらも最終的な結論にコミットできていない。
  - SKILL.md の compare テンプレート FORMAL CONCLUSION の `ANSWER` フィールドは `[YES equivalent / NO not equivalent]` とあるが、UNKNOWN が無効であることを明示していない。
  - エージェントは不確実性が残る場合に UNKNOWN を選択する「退路」を持っている状態であり、これがターン枯渇後の出力選択に影響している可能性が高い。

  **iter-17 変更（到達性確認フィールド追加）の評価:**
  - iter-17 では per-test 分析ブロックに `Changed code on this test's execution path:` フィールドを追加した。
  - この変更により iter-14 からの回帰ケース（11433）は正解に戻ったが、UNKNOWN ケース（15315, 14122, 12663）は依然として解消されていない。
  - EQUIVALENT → NOT_EQUIVALENT の誤判定（15368, 15382）も未解消。

## 改善仮説

**compare テンプレートの `ANSWER` フィールドに UNKNOWN 禁止の明示的な注記を追加することで、エージェントがターン枯渇後または不確実な状況下でも YES/NO のいずれかにコミットするよう誘導できる。**

根拠:
- UNKNOWN 出力は benchmark 上は常に誤答であり、低信頼度の推測（CONFIDENCE: LOW）より悪い結果をもたらす。
- エージェントが UNKNOWN を選択するのは、テンプレートが高信頼度を要求しているように見え、確信が持てない場合の「合法的な逃げ道」として UNKNOWN が機能しているためと推測される。
- `ANSWER` フィールドのすぐ後に「UNKNOWN は無効、不確実な場合は CONFIDENCE: LOW で最も支持される答えにコミットせよ」と明記することで、この退路を塞ぐことができる。
- これは推論プロセスの変更ではなく、「決定の強制」であり、探索フェーズには影響しない。探索が不十分でも十分でも、最終的に YES/NO を出力することを要求するだけである。
- UNKNOWN を出力せざるを得ない状況は、実際には LOW 信頼度の判定として扱われるべきであり、この変更はその正しい対処法を明示する。

## 変更内容

compare テンプレートの `FORMAL CONCLUSION` セクション内、`ANSWER` フィールドの直後に 2 行の注記を追加:

```diff
-ANSWER: [YES equivalent / NO not equivalent]
-CONFIDENCE: [HIGH / MEDIUM / LOW]
+ANSWER: [YES equivalent / NO not equivalent]
+  (UNKNOWN is not a valid answer — if certainty is unachievable after thorough exploration,
+   commit to the best-supported answer and set CONFIDENCE: LOW, stating what evidence is missing.)
+CONFIDENCE: [HIGH / MEDIUM / LOW]
```

変更規模: 2 行追加（≤ 20 行の制約内）。
変更箇所: compare テンプレートの FORMAL CONCLUSION セクションのみ。他のモード・ステップへの影響なし。

## 期待効果

- **15315・14122・12663（UNKNOWN → 改善期待）**: UNKNOWN が無効と明示されることで、エージェントはターン枯渇前または探索完了後に YES/NO を選択するようになる。正解率への影響は探索品質次第だが、少なくとも 0 点（UNKNOWN）から +1 点のチャンスが生まれる。
- **15368・15382（NOT_EQUIVALENT 誤判定）**: この変更では主対象ではないが、NOT_EQUIVALENT を選んだ際に CONFIDENCE: LOW を付けやすくなることで、判定の確からしさが記録される副作用がある。
- **回帰リスク**: 変更は FORMAL CONCLUSION の ANSWER フィールドへの注記のみ。探索プロセス・仮説・反証ステップ・他モードに一切変更なし。現在正解しているケース（15/20）への影響は極めて限定的。
