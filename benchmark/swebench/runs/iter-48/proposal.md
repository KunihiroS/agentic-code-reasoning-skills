過去提案との差異: 直近却下案のように特定の観測境界へ構造差を写像せず、探索ログ内の重複した任意欄を既存の次アクション欄へ統合する認知負荷削減である。
Target: 両方
Mechanism (抽象): 次に読む理由と情報利得の二重記入を一つの分岐欄に圧縮し、探索継続/保留/結論へ進む判断の入力を短くする。
Non-goal: STRUCTURAL TRIAGE の早期 NOT_EQUIV 条件や、特定の assertion/test 境界への結論条件の固定は行わない。

カテゴリ G 内での具体的メカニズム選択理由

禁止方向の整理:
- 再収束を比較規則として前景化し、差分シグナルを弱める変更は避ける。
- relevance 未確定や脆い仮定を広く保留側へ倒す既定動作は避ける。
- 差分昇格を新しい抽象ラベルや必須の言い換え形式で強くゲートする変更は避ける。
- 終盤の証拠十分性チェックを単なる CONFIDENCE 調整へ吸収する変更は避ける。
- 最初の差分から単一追跡経路を即座に固定する変更は避ける。

削除・統合候補:
1. Step 3 の `NEXT ACTION RATIONALE` と `OPTIONAL — INFO GAIN` は、どちらも「次に何を見る理由」を書かせる近接欄であり、optional 欄は軽量モデルに無視されやすい。
   現在のデフォルト挙動: optional 欄を省き、次アクションが単なる説明で終わりがち。
   変更後の観測可能アウトカム: 追加探索の目的が claim/verdict 変化に結びつき、過度な保留や早期結論が減る。
2. Compare checklist の Structural triage first とテンプレート内 STRUCTURAL TRIAGE は内容が重複している。
   現在のデフォルト挙動: 同じ確認を二度読むが、実行時の分岐はほぼ増えない。
   変更後の観測可能アウトカム: checklist の読解負荷は減るが、結論条件自体は変わりにくい。
3. Minimal Response Contract は certificate template と Step 5.5 に近い必須要素を再列挙している。
   現在のデフォルト挙動: 終盤で重複チェックが増える。
   変更後の観測可能アウトカム: 出力形式の負荷は減るが、compare の探索分岐差は限定的。

選択: 候補 1 を選ぶ。
- optional な情報利得欄を既存の required 欄へ統合するだけなので、研究コアである番号付き前提・仮説駆動探索・手続き間トレース・必須反証は維持される。
- compare の実行時には「次に読む」か「結論へ進む」かの分岐で、次アクションが claim/verdict を変えうるかを一つの欄で判断できるため、行動差が出る。

改善仮説

この optional な情報利得欄は認知負荷を増やす一方で、意思決定に必要な内容は既存の NEXT ACTION RATIONALE に統合できるため、削除・統合しても判定品質は維持または改善する。

SKILL.md の該当箇所と変更案

現在の短い引用:
- `NEXT ACTION RATIONALE: [why the next file or step is justified]`
- `OPTIONAL — INFO GAIN: [what uncertainty this action resolves; which hypothesis/claim it would confirm vs refute]`

変更案:
- 上記 2 行を 1 行に統合し、optional 欄を削除する。
- 既存の次アクション欄の中で、解く不確実性と claim/verdict への影響を要求する。

Payment: add MUST("NEXT ACTION RATIONALE: [what uncertainty this action resolves and what claim/verdict could change]") ↔ demote/remove MUST("OPTIONAL — INFO GAIN: [what uncertainty this action resolves; which hypothesis/claim it would confirm vs refute]")

Decision-point delta

Before: IF observations leave multiple possible next files or a possible conclusion THEN choose a next action and optionally state its information gain because the required field only asks why the step is justified.
After:  IF observations leave multiple possible next files or a possible conclusion THEN choose a next action only by naming the uncertainty it resolves and the claim/verdict it could change because the single required field carries the discriminative criterion.

変更差分プレビュー

Before:
```
UNRESOLVED:
  - [remaining questions]
NEXT ACTION RATIONALE: [why the next file or step is justified]
OPTIONAL — INFO GAIN: [what uncertainty this action resolves; which hypothesis/claim it would confirm vs refute]
```

After:
```
UNRESOLVED:
  - [remaining questions]
NEXT ACTION RATIONALE: [what uncertainty this action resolves and what claim/verdict could change]
```
Trigger line (planned): "NEXT ACTION RATIONALE: [what uncertainty this action resolves and what claim/verdict could change]"

Discriminative probe

抽象ケース: 片方の変更だけに補助関数経由の挙動差が見え、別ファイルを読むか現時点で同等/非同等へ進むか迷う。
変更前は optional 情報利得欄が省かれ、単に「関連しそうだから読む」または「差分があるから結論」となり、偽 EQUIV / 偽 NOT_EQUIV のどちらにも倒れうる。
変更後は新しい必須ゲートを増やさず、既存の NEXT ACTION RATIONALE の置換だけで「その読解がどの claim/verdict を変えるか」を要求するため、不要探索ではなく判定に効く追加探索へ絞れる。

failed-approaches.md との照合

- 差分を新しい抽象ラベルに分類したり、昇格条件を強いゲートにしたりしないため、原則 3 に抵触しない。
- 未確定性を常に保留側へ倒す既定動作を追加せず、次アクションの理由欄を圧縮するだけなので、原則 2 に抵触しない。
- 終盤の証拠十分性チェックや必須反証は削らないため、原則 4 の premature closure も避ける。

変更規模の宣言

SKILL.md の変更は 2 行を 1 行へ置換するだけで、差分は 3 行以内。新規モード追加なし。新しい必須ゲートの純増なし。研究のコア構造は維持する。
