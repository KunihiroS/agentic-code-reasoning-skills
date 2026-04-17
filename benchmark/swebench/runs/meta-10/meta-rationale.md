# Meta-template improvement rationale (template version 10 → 11, proposal)

## 1) 停滞の診断（どのテンプレートのどの部分が問題か）

観測された停滞パターン:
- audit は高止まりしやすい（82–92%）一方で compare が 60–75% のレンジ内で往復し、改善が累積しにくい。

診断:
- prompts/propose-normal.txt は「Decision-point delta」「支払い」「差分プレビュー」等の要件を既に強く課しているが、
  実際には proposal が “監査 rubic に刺さる説明強化” に寄りやすく、compare を左右する分岐条件（IF 条件と行動）の実装が
  SKILL.md の具体文言へ確実に落ちないまま通過しうる。
  - 症状: Before/After が形式上 IF/THEN でも、実装では「理由の言い換え」や「抽象的説明の追加」に吸い込まれやすい。
  - 根本: propose/discuss/implement の間で、Decision-point delta を“発火させる最小の文言（トリガ句）”が明示的に固定されていない。

- prompts/discuss.txt は compare 影響の実効性チェックを要求しているが、
  proposal 内の差分プレビューが「どの 1 行が分岐を起こすか（トリガ句）」まで含んでいるかを必須にしていないため、
  実装ズレ（proposal の意図が SKILL.md に入らない / 入っても弱い言い換えになる）を早期に弾けない。

- prompts/implement.txt は “反映されているか確認” を促すが、
  実装者が最終的に SKILL.md に入れた文言を rationale に固定・照合する要求がなく、
  propose → implement のズレが残ったまま audit 用の整合説明だけが強化されやすい。

## 2) 変更の仮説（なぜこの変更で改善が期待できるか）

仮説:
- compare 改善に必要なのは「説明が増えること」ではなく、
  結論（結論を出す/保留する/追加で探す）を変える “分岐可能な条件” が SKILL.md の具体文言として安定的に注入されること。

このために、proposal の差分プレビュー内に Decision-point delta を発火させる最小単位の文言を 1 行固定（Trigger line）し、
- discuss 段階で Trigger line が提示されていない proposal を不承認にする（実装ズレと compare 停滞の主要因を遮断）
- implement 段階で最終的に入った Trigger line を rationale に再掲し、proposal の Trigger line と一致/同等であることを明示確認する（ズレを検出）

…という “トリガ句の鎖” を導入すると、
- audit で褒められる説明追加だけの変更が通りにくくなる
- 変更が比較器の実際の意思決定分岐に落ちる確率が上がる
- 小さな差分でも compare に効く累積改善が起きやすくなる

という改善が期待できる。

## 3) 変更したファイルと変更内容の要約

変更したファイル:
- prompts/propose-normal.txt
  - 追加: 「分岐可能性（停滞対策の最重要・追加要求）」セクション
  - 内容:
    - IF 条件を観測可能な状態/証拠へ落とすことを明示（姿勢語を禁止）
    - proposal の差分プレビュー内に Trigger line（発火する文言の自己引用）を必須化
    - Before/After は理由の言い換えではなく分岐であることを再強制

- prompts/discuss.txt
  - 追加: compare 影響の実効性チェックに「Trigger line が差分プレビュー内にあるか（YES/NO）」を追加
  - ルール: Trigger line が無い proposal は、他が良くても承認しない（実装ズレ抑止）

- prompts/implement.txt
  - 追加: rationale.md に最終的に SKILL.md に入った Trigger line を 1 行だけ自己引用して載せ、
    proposal の Trigger line と一致/同等であることを確認する要件を追加

注意:
- manifest.json の構造・変数は変更していない。
- 既存の ${...} プレースホルダーは維持している。
- auto-improve.sh / ベンチマーク定義 / モデルには干渉していない。
- SKILL.md 自体は編集していない（テンプレートのみ変更）。
