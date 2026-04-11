# Iteration 41 — 変更理由

## 前イテレーションの分析

- 前回スコア: 65%（13/20）※ iter-40 の EDGE CASES 削除変更（BL-19）はスコア低下によりロールバック済み。有効ベースラインは iter-35 相当の 85%（17/20）
- 失敗ケース（ロールバック後の現 SKILL.md 基準）: django__django-15368, django__django-13821, django__django-11433
- 失敗原因の分析:
  - 15368（EQUIV → NOT_EQ）: 変更関数でコード差分を発見した後、その差分が test call path 上の消費関数（nearest consumer）で吸収されているかを確認せずに NOT_EQ を結論した。
  - 13821（EQUIV → NOT_EQ）: 同上のパターン。変更関数に差分あり → Comparison: DIFFERENT → NOT_EQ という短絡が起きた。
  - 11433（NOT_EQ → UNKNOWN）: ターン枯渇が主因。直接的な改善対象ではない。

## 改善仮説

Compare checklist の既存行「When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact」が曖昧であり、エージェントはこれを「変更関数のコードを読んだ（差分を見た）」時点で満たしたと解釈できる。

差分が **変更関数を呼び出す側（すでにトレース済みの test call path 上の nearest consumer）** で正規化・吸収されるかを確認せずにトレースを終えることが EQUIV 偽陰性の根本原因である。

既存行を「差分発見後は test call path 上の nearest consumer を読み、差分が伝播するか吸収されるかを記録してから Claim を確定せよ」という方向に書き換えることで、変更関数で止まらず消費関数まで読む行動を誘発し、吸収されているケースで EQUIV に正しく判定できるようになる。

## 変更内容

`### Compare checklist` の 5 番目の bullet を置換（1 行 → 1 行）:

**変更前:**
```
- When a semantic difference is found, trace at least one relevant test through the differing path before concluding it has no impact
```

**変更後:**
```
- When a behavioral difference is found in a changed function (return value, exception, or side-effect), do not stop tracing at that function: read the function on the already-traced relevant test call path that consumes the changed output, and record whether it propagates or absorbs the difference before assigning the Claim outcome.
```

変更規模: 置換 1 行（追加・削除 ±0）、新セクション追加なし。

## 期待効果

- **django__django-15368（EQUIV → NOT_EQ）**: 変更関数で差分発見後、test call path 上の nearest consumer を読む義務が明示され、消費関数が差分を吸収していることを発見すれば Claim を PASS に修正できる。改善可能。
- **django__django-13821（EQUIV → NOT_EQ）**: 同上。改善可能。
- **django__django-11433（NOT_EQ → UNKNOWN）**: 変化なし。ターン枯渇が主因であり本変更の直接的な作用は限定的。
- **既存正答ケース（EQUIV 8件, NOT_EQ 8件）**: 真の NOT_EQ では nearest consumer が差分を伝播させるためすぐに確認でき結論は変わらない。真の EQUIV では吸収確認が既存の正答を補強する。回帰リスクは極めて低い。

期待スコア: 85%（17/20）→ 88〜90%（EQUIV が +1〜2 改善）
