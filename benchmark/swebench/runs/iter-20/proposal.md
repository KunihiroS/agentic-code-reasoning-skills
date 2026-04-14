# Iteration 20 — 改善提案

## Exploration Framework カテゴリ: C（強制指定）

### カテゴリ内の具体的メカニズム選択理由

カテゴリ C の3つのメカニズムは以下の通り:

1. テスト単位ではなく関数単位・モジュール単位で比較する
2. 差異の重要度を段階的に評価する  ← 今回選択
3. 変更のカテゴリ分類（リファクタリング/バグ修正/機能追加）を先に行う

メカニズム 2 を選択した理由:

compare モードの STRUCTURAL TRIAGE（S1/S2/S3）はパッチの構造的ギャップを検出する
ためのセクションとして整備されているが、そこで「意味的差異が存在するか」を確認した
後、その差異がテスト結果に影響するかどうかの重要度評価を行うステップが明示されていない。

現状のテンプレートでは、ANALYSIS OF TEST BEHAVIOR セクションで各テストを個別トレース
することで差異の影響を確認するが、構造トリアージ直後の段階に差異重要度の判断軸がないため、
エージェントが微細な差異を発見した際に「重要でない」と早期判断しやすい。

これは Guardrail #4（「微細な差異を無視してはならない」）が対象とする失敗パターンと
直結する。また、README.md に記録された「EQUIVALENT ペアの2件の持続的失敗」も、この
早期除外バイアスに起因する可能性が高い。

メカニズム 3（変更カテゴリ分類先行）は類似しているが、それは変更の意図分類であり、
発見した差異の影響範囲評価とは異なる。メカニズム 2 のほうが STRUCTURAL TRIAGE という
既存フックを活用でき、変更規模が小さく済む。


## 改善仮説

「構造トリアージ完了後に発見された意味的差異に対して、その差異がテスト結果に影響しうる
かどうかを重要度の観点から初期スクリーニングする観点を明示することで、エージェントが
微細な差異を根拠なく無視する early-dismissal バイアスを抑制し、EQUIVALENT と NOT_EQUIVALENT
の両方向で誤判定を減らせる。」

重要度スクリーニングは「高コストな全テストトレース」の前置きとして機能し、差異の
breadth-first な初期評価を促す。これにより、full ANALYSIS セクションに進む前の段階で
「この差異はゼロ個のテストパスに影響しない」という早合点を防ぐ。


## SKILL.md の変更内容

### 変更対象箇所

STRUCTURAL TRIAGE の S3 行（大パッチの取り扱いを規定している行）の末尾に、
差異重要度の初期評価観点を補足する。

### 変更前（SKILL.md 190–193行）

```
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
```

### 変更後（変更行数: 2行を1行追加で精緻化、計+1行）

```
  S3: Scale assessment — if either patch exceeds ~200 lines of diff,
      prioritize structural differences (S1, S2) and high-level semantic
      comparison over exhaustive line-by-line tracing. Exhaustive tracing
      is infeasible for large patches and produces unreliable conclusions.
  S4: Difference significance — for each semantic difference identified
      in S1–S3, classify its potential impact before detailed tracing:
      CRITICAL (alters return value / exception type / control flow on a
      known test path), MINOR (affects only untested branches), or INERT
      (cosmetic/whitespace/log-only). Proceed to full ANALYSIS for all
      CRITICAL differences; justify skipping MINOR or INERT ones.
```

### 変更規模の計算

- 削除行: 0
- 追加行: 4（S4 の本文ブロック）
- 合計変更行数: 4（hard limit 5 行以内に収まる）


## 期待効果（失敗パターンの観点）

### カテゴリ別の失敗パターン低減

1. EQUIVALENT 方向の誤り（NOT_EQUIVALENT を EQUIVALENT と判断する）:
   - S4 の CRITICAL 分類を強制することで、見逃しやすい意味的差異を early に
     フラグ立てし、ANALYSIS セクションでの証拠収集を促す。
   - Guardrail #4「微細な差異を無視してはならない」の遵守を STRUCTURAL TRIAGE
     の段階から開始させることができる。

2. NOT_EQUIVALENT 方向の誤り（EQUIVALENT を NOT_EQUIVALENT と判断する）:
   - INERT 分類を設けることで、コスメティックな差異を MINOR/INERT として明示的に
     処理できる。ただし「INERT なので無視」とするためには正当化を要求しており、
     根拠なき除外を防ぐ。

3. overall 方向（全体的推論品質）:
   - 差異重要度の分類は汎用的な推論観点であり、compare モードの任意のコード・
     言語・フレームワークに適用できる。
   - STRUCTURAL TRIAGE という既存の「早期判断フック」に差異評価を統合することで、
     認知的コストの増加を最小化しつつ品質を向上させる。


## failed-approaches.md との照合

以下の3原則と照合し、抵触しないことを確認した。

### 原則 1: 探索シグナルの捜索への偏り禁止

S4 は「どの差異を探すか」を固定しているのではなく、「発見済みの差異の重要度分類」
を求めている。探索の自由度は削らない。抵触なし。

### 原則 2: 探索ドリフト対策の自由度削減禁止

S4 は新しい探索義務を課していない。STRUCTURAL TRIAGE の完了後（すでに差異を発見
した状態）に、その差異の意義を分類するよう求めるだけである。抵触なし。

### 原則 3: 自己監査チェックの増殖禁止

S4 は Step 5.5 などの自己監査セクションへの追加ではなく、STRUCTURAL TRIAGE の
既存フレームへの拡張である。また「最弱点の特定→確信度への結びつけ」のような
メタ判断軸の追加でもない。抵触なし。


## 変更規模の宣言

- 変更対象: SKILL.md の compare モード STRUCTURAL TRIAGE セクション
- 追加行数: 4行（S4 ブロック）
- 削除行数: 0行
- hard limit（5行）内に収まる: YES
- 新規ステップ・新規フィールド・新規セクション: なし（既存 S1/S2/S3 系列の延長）
