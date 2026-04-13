# Iteration 21 — 変更理由

## 前イテレーションの分析

- 前回スコア: 不明（iter-20 の scores.json 未参照）
- 失敗ケース: 不明（参照制限により scores.json を参照せず）
- 失敗原因の分析: 前提（P[N]）が仮説更新（REFUTED/REFINED）の後も
  修正されず、後段の推論が誤前提を引き続き参照して誤判定に至るパターンが
  推論品質低下の一因と分析された。

## 改善仮説

仮説が REFUTED または REFINED になった時点で、その根拠となった前提
（P[N]）自体を見直す自問を探索中に促せば、前提の誤りに由来する誤判定を
後段に持ち越す前に検出できる。前提の誤りを後段まで持ち越すことが、
全体推論品質の低下の一因となっている。

## 変更内容

SKILL.md の Step 3 テンプレート内 HYPOTHESIS UPDATE ブロックの既存1行を
精緻化し、2行に拡張した。変更前後は以下の通り。

変更前:
```
HYPOTHESIS UPDATE:
  H[M]: CONFIRMED / REFUTED / REFINED — [explanation]
```

変更後:
```
HYPOTHESIS UPDATE:
  H[M]: CONFIRMED / REFUTED / REFINED — [explanation];
        if REFUTED or REFINED, revisit the premises P[N] that supported H[M]
        and correct any that no longer hold before proceeding.
```

新規ステップ・新規フィールド・新規セクションの追加はなし。
既存行への文言追加・精緻化のみ（変更規模: 2行、hard limit 5行以内）。

## 期待効果

(a) 誤前提の持ち越しによる誤判定の減少:
    探索序盤で設定した前提が途中の観測で覆されても、仮説更新のみで前提が
    修正されず後段で再利用されるパターンを、REFUTED/REFINED のたびに前提
    見直しを自問させることで中断できる。

(b) 確認バイアスの蓄積の抑制:
    仮説が REFINED のまま探索が続く際に古い前提が温存され新証拠の解釈が
    歪まれるパターンを、前提見直しの習慣づけで軽減できる。

(c) 全モード（compare/diagnose/explain/audit-improve）共通の Step 3 に
    均等に適用されるため、特定モードへの過剰適合はない。

Step 5.5 の自己監査チェックリスト、Step 6 の結論フォーマット、
Guardrail 一覧への変更はないため、既存の反証プロセスや確信度付け方式は
そのまま維持される。
