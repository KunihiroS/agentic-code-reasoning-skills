# Iter-83 Proposal

## フォーカスドメイン
`equiv` — 2 つの実装が同じ振る舞いを持つと判定する精度の向上

---

## Exploration Framework カテゴリと選定理由

**カテゴリ B: 情報の取得方法を改善する**（"コードの読み方の指示を具体化する"）

`equiv` 判定の失敗パターンを分析すると、モデルは A と B の間の意味論的差異を検出した後、その差異がテストの観測点に届くかどうかを検証せずに NOT_EQUIVALENT と結論する傾向がある。  
これは「どう探すか」の不足であり、探索する情報量や探索順序の問題ではない。  
既存の guardrail #4 は「差異のある コードパスを少なくとも 1 つのテストでトレースせよ」と指示しているが、そのトレースがテストのアサーション（観測可能な出力）まで到達することを要求していない。そのため、中間コードパスのトレースで止まり、「差異がある → NOT_EQUIVALENT」という推論ジャンプが生じる。

カテゴリ B の「どう探すか（トレースの終点）を具体化する」アプローチで guardrail #4 を精緻化することで、この問題を直接解消できる。

---

## 改善仮説

**意味論的差異を検出した後、そのトレースをテストの観測可能な結果（アサーションが実際に評価する値）まで到達させることを明示的に要求すると、EQUIV および NOT_EQ の両方向において「差異の観測可能性」の判断精度が向上する。**

根拠: 現在の guardrail #4 の指示する「differing code path をトレースする」は中間ノードで止まりうる。トレースの終点を「テストが実際にチェックする観測可能な結果」と明示することで、エンドツーエンドの因果連鎖が完結し、差異がテストから見えるか否かの判断が直接的に可能になる。  
この変更は EQUIV・NOT_EQ を対称に扱う: 差異が観測点に届けば NOT_EQUIVALENT の根拠となり、届かなければ EQUIVALENT の根拠となる。

---

## SKILL.md への変更内容

**変更対象**: Guardrails セクション、item 4

**変更前**:
```
4. **Do not dismiss subtle differences.** If you find a semantic difference between compared items, trace at least one relevant test through the differing code path before concluding the difference has no impact.
```

**変更後**:
```
4. **Do not dismiss subtle differences.** If you find a semantic difference between compared items, trace at least one relevant test through the differing code path before concluding the difference has no impact. The trace must reach the test's observable outcome — verify whether the semantic difference is what the test assertion actually checks.
```

**変更規模**: 既存行への1文追加（+1行、削除なし）

---

## 一般的な推論品質への期待効果

| 失敗パターン | 改善後の変化 |
|-------------|--------------|
| 意味論的差異 → 即 NOT_EQUIVALENT への推論ジャンプ（equiv 失敗） | 差異がテストのアサーションに届かない場合、トレースがそれを証明するため EQUIVALENT の根拠が得られる |
| 意味論的差異を「無害と却下」しての EQUIVALENT 誤判定（not_eq 失敗） | 差異がテストのアサーションに届く場合、トレースがそれを明示するため NOT_EQUIVALENT の根拠が強化される |
| 中間ノードでの分析停止（エンドツーエンドの因果連鎖の欠落） | トレースの終点をアサーション（観測可能な結果）と明示することで、エンドツーエンド追跡が促進される |

EQUIV・NOT_EQ 両方向への効果が期待できるため、判定の非対称バイアスは生じない。

---

## failed-approaches.md との照合

| 原則 | 照合結果 |
|------|----------|
| #1 判定の非対称操作 | **クリア** — EQUIV / NOT_EQ 両方向に等しく作用する（差異が届く→NOT_EQ根拠、届かない→EQUIV根拠） |
| #2 出力側の制約 | **クリア** — 「こう答えろ」という指示ではなく、トレースの終点（プロセス側）を具体化 |
| #3 探索量の削減 | **クリア** — 探索を削減しない。むしろアサーションまでのトレースを追加要求 |
| #8 受動的な記録フィールドの追加 | **クリア** — 新規フィールドや列の追加ではなく、能動的なトレース行動を直接要求 |
| #9 メタ認知的自己チェック | **クリア** — 「自分はトレースしたか？」という自己評価ではなく、「差異がアサーションに届くか」という外部検証可能な行動を要求 |
| #12 アドバイザリな非対称指示 | **クリア** — 追加されるトレース要件は EQUIV / NOT_EQ どちらを主張する場合にも等しく適用 |
| #15 固定長の局所追跡ルール | **クリア** — hop 数の固定ではなく、意味論的な終点（observable outcome）を指定 |
| #17 中間ノードの局所的な分析義務化 | **クリア** — 中間ノードではなく終点（アサーション）へのトレースを要求しており、むしろエンドツーエンド追跡を強化 |
| #18/#19 物理的裏付けの過剰要求 | **クリア** — file:line の新規引用義務を追加していない |
| #22 具体物の例示 | **クリア** — 具体的なコード要素ではなく状態・性質（"observable outcome"）で指示 |

その他の原則との抵触なし。

---

## 変更規模の宣言

- **追加行数**: 1 行（既存 guardrail #4 への1文追加）
- **削除行数**: 0 行
- **新規セクション・新規ステップ・新規フィールド**: なし
- **ハードリミット（5行）**: 遵守
