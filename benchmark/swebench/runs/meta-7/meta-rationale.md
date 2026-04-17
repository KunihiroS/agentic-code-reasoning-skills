# meta-7 template evolution rationale

## 停滞の診断（どのテンプレートのどの部分が問題か）

1) prompts/propose-normal.txt の構造が、提案を「監査 rubic に刺さる説明の充実」へ寄せやすい
- 現行 propose-normal は proposal.md に含めるべき内容が多く、フォーマット充足（自己チェック・整合性説明・ミニケース等）にリソースが割かれやすい。
- その結果、compare を実際に改善する鍵である「意思決定（結論/保留/追加探索）の分岐が変わる」という行動差が、理由の言い換え（姿勢語・一般論）に着地しやすい。
- これは、スコア推移で audit は高めに出る一方 compare が 60〜70% 帯で頭打ちになりやすい状況（形式は満たすが判定品質が上がり切らない）と整合する。

2) prompts/propose-escape.txt が短すぎ、エスケープ時に「構造改革の名目での増量」へ流れやすい
- propose-escape は許可事項の宣言はあるが、compare に効く“分岐”の書き方（Decision-point delta）や、避けるべき半固定化（読む順序/証拠種類固定）の明示が薄い。
- そのため escape で局所最適を抜けるはずが、単なる説明増量・diff 散りに繋がりやすい。

3) prompts/implement.txt が「diff を散らさない」圧が弱く、実装で無関係な編集が混入しやすい
- 実装段階で差分が広がると、audit 的に“過剰適合/汎化性不安”に見えやすく、また compare で効いている変更点も不明瞭になり、改善ループが鈍る。


## 変更の仮説（なぜこの変更で改善が期待できるか）

仮説: propose 段階の最初に「減らしたい誤判定（偽EQUIV/偽NOT_EQUIV）」「現在の失敗ストーリー」「改善メカニズム」「非目標（半固定化/必須ゲート増をしない）」を短く固定し、さらに“姿勢語”を禁じて具体行動差へ落とし込ませることで、
- 監査に通る説明（audit）を維持しつつ
- compare の本体である意思決定分岐（結論/保留/追加探索）が実際に変わる提案が増え
- 停滞の主因になりがちな「理由だけ言い換え」を減らせる

また escape テンプレにも同様の最小要件（Decision-point delta と Non-goal boundary）を入れることで、
- 構造改革が「増量」になりにくく
- 局所最適脱出時の提案が compare に直結しやすい

さらに implement に「無関係な整形で diff を広げない」注意を追加し、
- audit 観点での過剰適合疑いを抑えつつ
- compare に効く差分が明確なまま実装される確率を上げる


## 変更したファイルと変更内容の要約

1) prompts/propose-normal.txt
- 追加: 「停滞が起きやすい落とし穴」セクション（説明強化偏重、実質ゲート増、探索半固定化の回避）
- 追加: proposal 冒頭に置くべき「最初の4行」(Target misclassification / failure story / mechanism / non-goal boundary)
- 追加: 「姿勢語」を禁じ、compare に効く具体行動差（追加探索対象、保留条件、重要差分の基準）に限定する指示

2) prompts/propose-escape.txt
- 追加: エスケープで陥りやすい失敗の明示（増量、半固定化、diff 散り）
- 追加: proposal の必須明記項目に Decision-point delta（IF/THEN Before/After）と Non-goal boundary を追加

3) prompts/implement.txt
- 追加: 無関係な整形・言い換え・並べ替えで diff を広げない（audit・compare 両面で不利）という注意
