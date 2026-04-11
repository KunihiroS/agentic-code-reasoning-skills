# Iter-99 改善提案

## フォーカスドメイン

`not_eq` — 2 つの実装が**異なる**振る舞いを持つと判定する精度の向上

---

## Exploration Framework カテゴリと選定理由

**カテゴリ B: 情報の取得方法を改善する**

選定理由:
- `not_eq` の典型的な失敗パターンは「意味的差異を発見したが、それをテストアサーションまで追跡せずに "影響なし" と棄却してしまう」である。
- これは「何を探すか」ではなく「どう追跡するか」の問題であり、カテゴリ B に合致する。
- Guardrail #4 は既に「意味的差異を発見したら相違するコードパスを通じてテストをトレースせよ」と規定しているが、そのトレースが**何を示さなければならないか**を明示していない。その結果、モデルは物語的・表面的なトレースだけで「影響なし」を主張できてしまう。

---

## 改善仮説

> 意味的差異のトレースに「発散した値がテストアサーションに到達するか、あるいはどこで吸収されるかを明示する」という要件を付加することで、モデルが差異を根拠なく棄却することを防ぎ、`not_eq` の正検出率を改善できる。

現状の Guardrail #4 は「トレースせよ」と命じるが、トレースの終点を規定していない。
モデルはコードレベルの差異の存在を指摘するだけで「影響なし」と結論付けるショートカットを取れる。
終点の明示（アサーション到達 or 吸収点の特定）を要求することで、このショートカットを塞ぐ。

---

## 変更内容

### 対象箇所

SKILL.md — Guardrails セクション、Guardrail #4

### 変更前

```
4. **Do not dismiss subtle differences.** If you find a semantic difference between compared items, trace at least one relevant test through the differing code path before concluding the difference has no impact.
```

### 変更後

```
4. **Do not dismiss subtle differences.** If you find a semantic difference between compared items, trace at least one relevant test through the differing code path before concluding the difference has no impact. Show explicitly where the diverging value either reaches a test assertion or is absorbed before any assertion — not merely that the code-level difference exists.
```

（追加文: `Show explicitly where the diverging value either reaches a test assertion or is absorbed before any assertion — not merely that the code-level difference exists.`）

---

## 期待効果

### 減少が期待される失敗パターン

| 失敗パターン | メカニズム |
|---|---|
| 意味的差異を発見したが「テストには影響しない」と根拠なく棄却 → 誤 EQUIVALENT | トレースの終点（アサーション到達 or 吸収点）の明示義務が、この早期棄却を阻止する |
| 変更後の値の変化がコードレベルで確認されたが、その値がどこに使われるかを追わない | 「発散した値がどこに到達するか」を示す要件が追跡継続を強制する |

### 対称性の確認

- **NOT_EQUIVALENT 結論時**: 発散した値がアサーションに到達することを示す → `not_eq` 精度向上
- **EQUIVALENT 結論時**: 発散した値がアサーション前に吸収されることを示す → `equiv` 精度も向上（根拠のある棄却が可能になる）

変更は EQUIV と NOT_EQ の双方に適用される対称な要件であり、判定閾値の一方向的移動ではない。

---

## failed-approaches.md 汎用原則との照合

| 原則 | 判定 | 理由 |
|---|---|---|
| #1 判定の非対称操作は必ず失敗する | 非抵触 | 追加要件は対称：EQUIV は吸収点を、NOT_EQ はアサーション到達点を示す。立証責任の閾値は両方向に同様に作用する |
| #2 出力側の制約は効果がない | 非抵触 | 「こう答えろ」ではなく「トレースで何を示すか」というプロセス要件 |
| #3 探索量の削減は常に有害 | 非抵触 | 探索量を削減しない。むしろ終点まで追跡を継続させる |
| #12 アドバイザリな非対称指示も非対称に作用する | 非抵触 | 要件が双方向に対称（到達 or 吸収）であり、片方向の結論にのみ高いハードルを課さない |
| #16 ネガティブプロンプトによる局所的禁止は過剰適応を招く | 非抵触 | 禁止ではなく「何を示すか」のポジティブな要件仕様 |
| #18 特定証拠カテゴリへの厳格な物理的裏付けの要求は探索予算を枯渇させる | 非抵触 | `file:line` の引用を義務付けていない。「どこで」は意味論的な位置付けであり物理的な証拠要件ではない |
| #20 目標証拠の厳密な言い換えは立証責任の引き上げとして作用する | 非抵触 | 既存の "has no impact" という棄却要件を厳格化するのではなく、既に義務付けられているトレースの内容を具体化する |
| #22 抽象原則での具体物の例示は物理的探索目標として過剰適応される | 非抵触 | "test assertion" と "absorbed" は抽象的なカテゴリであり、特定のコード要素名ではない |
| #23 具体的検証手順を伴わない抽象的な問いは認知負荷のみを増やす | 非抵触 | 「到達 or 吸収の明示」は具体的な終点の確認を促す行動的要件である |

---

## 変更規模の宣言

- **追加行数**: 1 文（約 1–2 行）
- **削除行数**: 0 行
- **変更種別**: 既存 Guardrail #4 への文言追加（精緻化）
- **新規ステップ / フィールド / セクション**: なし
- **ハードリミット（5行）**: ✅ 適合
