# Iter-81 Proposal

## Exploration Framework カテゴリと選定理由

**カテゴリ C: 比較の枠組みを変える**

選定理由: `equiv` ドメインの失敗モードは「2 つの変更を比較するとき、コードレベルの構造的差異を振る舞いの差異と同一視してしまう」ことにある。判定枠組みそのものを「コード構造の差異」ではなく「テストアサーションへの観測可能な効果」へ明確に固定することが、このカテゴリの中核的アプローチに合致する。

---

## 改善仮説（1 つ）

構造的に異なるが機能的に等価な 2 つの実装を比較するとき、エージェントは Change A と Change B の間に観察された構造的差異を、テストアサーションへの影響をトレースすることなく、振る舞いの差異の十分な証拠として扱ってしまう。このため、真に等価なケースで誤った NOT_EQUIVALENT 判定が生じる。「構造的差異は、テストアサーションへの効果としてトレースされるまで振る舞い上の差異の証拠にならない」という原則を既存のガードレール #4 に追加することで、この誤推論を抑制できる。

---

## SKILL.md の変更内容

**対象**: Guardrails セクション、項目 #4

**変更前**:
```
4. **Do not dismiss subtle differences.** If you find a semantic difference between compared items, trace at least one relevant test through the differing code path before concluding the difference has no impact.
```

**変更後**（末尾に 1 文を追加）:
```
4. **Do not dismiss subtle differences.** If you find a semantic difference between compared items, trace at least one relevant test through the differing code path before concluding the difference has no impact. Conversely, when two changes diverge structurally, trace that divergence to its effect on the test assertion before treating it as evidence of a behavioral difference.
```

追加文: `Conversely, when two changes diverge structurally, trace that divergence to its effect on the test assertion before treating it as evidence of a behavioral difference.`

---

## 一般的な推論品質への期待効果

**抑制される失敗パターン**: 構造から振る舞いへの早計な推論飛躍。エージェントが Change A と Change B の変更箇所や実装スタイルの違いを観察し、因果連鎖を「テストアサーション」まで辿ることなく NOT_EQUIVALENT と結論する誤り。

**メカニズム**: 既存のガードレール #4 は「差異を見つけたとき、EQUIVALENT と結論する前に少なくとも 1 つの関連テストを辿れ」という片方向の要件を定めている。追加文はその対称方向を明示する: 「構造的差異を見つけたとき、NOT_EQUIVALENT の証拠として使う前にテストアサーションへの効果を辿れ」。これにより、構造的差異を証拠の端緒ではなく結論の根拠と混同する推論パスが封じられる。

**他モードへの影響**: `localize` / `explain` / `audit-improve` では「2 つの変更を比較する」という枠組みが主役にならないため、実質的な影響は minimal。

---

## failed-approaches.md との照合

| 原則 | 照合結果 |
|------|---------|
| #1 (判定の非対称操作) | 追加文は NOT_EQ 方向に追加トレース要件を課す。ただし真の NOT_EQ ケースでは振る舞い上の差異がトレース可能であり、要件を満たすことはコストが低い。偽の NOT_EQ ケース（真に EQUIV）では差異がトレースできず判定を保留・修正する機会が生まれる。判定閾値の移動ではなく証拠の質の改善であるため #1 の「ゼロサムゲーム」に該当しないと判断する。 |
| #2 (出力側の制約) | 「こう答えるな」という出力制約ではなく、「テストアサーションまでトレースせよ」というプロセス要件。抵触しない。 |
| #3 (探索量の削減) | 構造的差異が見つかった場合に追加トレースを求める。探索量を増やす方向。抵触しない。 |
| #6 (「対称化」は差分で評価せよ) | 差分は「NOT_EQ 方向の新規制約」のみ。既存の EQUIV 方向の制約には変化なし。差分が非対称であることは意図的（EQUIV 精度向上が目標）。 |
| #8 (受動的な記録フィールド) | 追加文はフィールド追加ではなく能動的なトレース行動（コードを辿る）を直接要求。抵触しない。 |
| #9 (メタ認知的自己チェック) | 「自分がトレースしたか？」という自己評価ではなく、「テストアサーションへの効果をトレースせよ」という直接的な行動指示。抵触しない。 |
| #16 (ネガティブプロンプト) | 「〜するな」という禁止ではなく「〜をするまでは証拠として扱うな」という条件付き要件。「Conversely」による対称的な文脈付けにより過剰適応リスクは低い。 |
| #19 (エンドツーエンドの完全な立証義務) | "trace that divergence to its effect on the test assertion" は完全なコールパスの引用を義務付けるものではなく、観測可能な効果への到達を求めるもの。完全 E2E トレースの義務化とは異なる。 |
| その他 (#4, #5, #7, #10-15, #17-18, #20-26) | 変更の構造・方向・粒度のいずれからも抵触なし。 |

---

## 変更規模の宣言

- 変更行数: **1 行**（既存のガードレール #4 末尾に 1 文を追加）
- 新規ステップ・新規フィールド・新規セクション: なし
- 削除行: なし
- 合計変更規模: **1 行**（ハードリミット 5 行以内）
