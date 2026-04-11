# Iteration 94 — Proposal

## Exploration Framework カテゴリと選定理由

**カテゴリ: B — 情報の取得方法を改善する（コードの読み方の指示を具体化する）**

not_eq の失敗パターンを分析すると、「差異を発見しても test outcome に接続できない」という問題が
中心にある。エージェントは変更された関数の戻り値の違いを検出するが、その差異がテストのアサーション
まで伝播するかどうかをトレースし切らずに「影響なし」と結論する。これは「どこまで読むか」という
探索の終了判断基準の問題であり、カテゴリ B（コードの読み方の指示を具体化する）に分類できる。

---

## 改善仮説

**仮説**: 伝播トレースの停止判断を「中間関数で伝播/吸収が確認できた時点」から
「テストアサーション到達 または 明確な吸収点到達」まで延長することで、
差異が正しく test outcome まで接続されるケースが増加し、
NOT_EQ の見落としが減少する。

現状の compare checklist 5番目の項目は、差異発見後に「call path 上の次の関数を読み、
伝播か吸収かを記録せよ」と指示している。しかし停止条件が明示されていないため、
エージェントは中間ノードで「伝播している」と記録したまま Claim を確定させ、
アサーションへの接続を省略しやすい。停止条件を「テストアサーション到達 or
確認済み吸収点到達」と明示することで、この省略を防ぐ。

---

## SKILL.md のどこをどう変えるか

### 変更箇所

`## Compare` セクション内の `### Compare checklist` の5番目の箇条書き。

### 変更前

```
- When a behavioral difference is found in a changed function (return value, exception, or side-effect), do not stop tracing at that function: read the function on the already-traced relevant test call path that consumes the changed output, and record whether it propagates or absorbs the difference before assigning the Claim outcome.
```

### 変更後

```
- When a behavioral difference is found in a changed function (return value, exception, or side-effect), do not stop tracing at that function: read the function on the already-traced relevant test call path that consumes the changed output, and record whether it propagates or absorbs the difference — continuing until the trace reaches a test assertion or a confirmed absorption point — before assigning the Claim outcome.
```

### 変更の説明

既存の1行に対し、`— continuing until the trace reaches a test assertion or a confirmed absorption point —`
というフレーズを追加する。これにより「伝播/吸収の記録」の停止条件が意味論的に明確になる。

- **テストアサーション到達**: 差異がアサーションの評価値に影響することを確認 → NOT_EQ の根拠確定
- **確認済み吸収点到達**: 差異が中間関数内で消費され、呼び出し元へ伝播しないことを確認 → SAME の根拠確定

どちらに到達したかに応じて Claim を確定することで、中途半端なトレースによる誤判定を防ぐ。

---

## 期待効果（失敗パターンの低減）

### 主な効果: NOT_EQ の見落とし減少

- 現状の失敗: 差異を中間関数で検出 → 「伝播有り」と記録しても、
  アサーションまでトレースせずに Claim を確定 → SAME（誤判定）
- 変更後: 停止条件が「テストアサーション到達」であるため、
  アサーションでの影響を確認するまでトレースを継続
  → 差異がアサーションに到達すれば DIFFERENT として正しく検出

### 副次的効果: EQUIV の偽陰性防止

- EQUIV 判定においても「差異がアサーションに到達しない」ことをトレースで確認することになるため、
  中間ノードで差異を発見しても吸収点を明確に同定してから SAME を確定できる
  → EQUIV の根拠もより堅牢になる

### 対応する失敗パターン（docs/design.md の分類）

| 失敗パターン | 低減される理由 |
|---|---|
| Subtle difference dismissal | アサーションまでのトレースを義務化することで、差異発見後の「影響なし」ジャンプを防ぐ |
| Incomplete reasoning chains | 停止条件を意味論的な境界（アサーション/吸収点）にすることで途中打ち切りを防ぐ |

---

## failed-approaches.md の汎用原則との照合

| 原則 | 照合結果 |
|---|---|
| #1 判定の非対称操作 | 非抵触。変更は SAME/DIFFERENT の両方向に対称的に適用され、どちらの結論も求める証拠の質は同等 |
| #2 出力側の制約 | 非抵触。推論プロセス（トレースの停止条件）の変更であり、出力の制約ではない |
| #3 探索量の削減 | 非抵触。停止条件の延長はトレース量の増加を促す |
| #9 メタ認知的自己チェック | 非抵触。「自分はトレースしたか？」という自己評価ではなく、「テストアサーションに到達したか？」という外的に検証可能な条件を直接要求している |
| #15 固定長の局所追跡ルール | 非抵触。hop 数や固定距離でなく、意味論的な境界（テストアサーション/吸収点）を停止条件としている |
| #17 中間ノードの局所的な分析義務化 | 非抵触。中間ノードの分析を義務化するのではなく、エンドツーエンドのトレースを促す方向 |
| #18/19 探索予算の枯渇 | 軽微なリスクあり。ただし「テストアサーション」は Step 3/4 で既トレース済みの関数上にあることが多く、新規の大量読込を強いるものではない。また既存の指示と同方向（トレースを続けよ）であり、追加コストは限定的 |
| #24 収束条件への物理的証拠必須化 | 非抵触。停止条件はコードの意味論的状態（差異がアサーションに達したか否か）であり、`file:line` 引用形式の強制ではない |

その他の原則（#4, #5, #6, #7, #8, #10〜#14, #16, #20〜#23, #25〜#27）についても
本変更は抵触しない。

---

## 変更規模の宣言

- **変更行数**: 1行（既存の checklist 項目への文言追加）
- **新規ステップ/フィールド/セクション**: なし
- **削除行**: なし
- **合計変更規模**: 1行（hard limit 5行以内 ✓）
