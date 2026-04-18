# meta-11 template update rationale

## 1) 停滞の診断（どのテンプレートのどの部分が問題か）

観測された症状:
- compare が長期的に 55〜65% 付近で停滞し、audit は高めに出るが振れもある。
- この形は「監査で褒められる説明強化・整形はできているが、compare の意思決定（EQUIV/NOT_EQUIV, 結論/保留/追加探索）が実効的に変わっていない」時に典型的に起きる。

テンプレート起因のボトルネック（主因）:
- prompts/propose-normal.txt の『思考の順序 — ボトルネックから入るな、未探索の方向から入れ』
  - “未探索”を優先させることで、比較スコア（compare）に直結する「分岐（IF/THEN）」の改善よりも、
    監査 rubic に刺さりやすい一般論・整形・説明の追加へ誘導しやすい。
  - また Step 2 の探索観点が「compare 以外のモード」「基盤」「圧縮」などに寄り、
    『どの条件で結論/保留/追加探索が変わるか』という分岐の設計を第一級の対象として扱っていない。

テンプレート間の整合不全（副因）:
- prompts/discuss.txt では Trigger line（差分プレビューに自己引用があるか）や Decision-point delta を厳格に見ている一方、
  prompts/propose-normal.txt / prompts/propose-escape.txt は proposal の必須要件として Trigger line を明示していない。
  - 結果として、議論段階で「compare 影響が曖昧」という理由で差し戻しになりやすく、
    反復コストが上がって探索効率が落ちる（=停滞しやすい）。

「抽象ケースでの挙動差」要求の弱さ（副因）:
- prompts/discuss.txt に Discriminative probe はあるが “追加チェック” として扱われ、
  提案の実効性（compare に効くか）を早期に保証する強制力が弱い。
  - その結果、見かけ上の Decision-point delta が書かれていても、実際には分岐が発火しない/行動が変わらない提案が通りやすい。

## 2) 変更の仮説（なぜこの変更で改善が期待できるか）

仮説:
- propose 段階から「1つの意思決定ポイント（IF/THEN の分岐）」にフォーカスさせ、
  その分岐が発火する Trigger line と、抽象ケースでの Before/After の挙動差（Discriminative probe）を必須化すると、
  「監査に通りやすいが compare に効かない」提案の比率が下がり、compare 側の改善が出やすくなる。

期待するメカニズム:
- 分岐の挙動差（結論/保留/追加探索）が proposal 内で固定される → implement が理由の言い換えに堕ちにくい。
- Trigger line を proposal に含める → discuss が要求する“発火文言”と整合し、差し戻しが減って探索効率が上がる。
- Discriminative probe を discuss 側でも必須扱いに寄せる → 「抽象ケースで差が説明できない＝分岐が効いてない」提案を早期に落とせる。

## 3) 変更したファイルと変更内容の要約

変更したファイル:
- prompts/propose-normal.txt
  - 「未探索の方向から入れ」中心の探索指示を、
    “停滞の主因になりやすい分岐（IF/THEN）を 1 つ選び、挙動差を作る” という手順に置換。
  - proposal.md 必須要件に以下を追加:
    - Trigger line (planned) を差分プレビューに 1 行自己引用で含める。
    - Discriminative probe（抽象ケースでの Before/After の挙動差）を必須化。

- prompts/propose-escape.txt
  - エスケープ提案でも、Trigger line (planned) と Discriminative probe を明示的に必須項目へ追加。

- prompts/discuss.txt
  - Discriminative probe を “追加チェック” ではなく「必須」と明記し、
    欠けている/抽象すぎる場合はそれを最大ブロッカーとして承認しない方針を追加。
