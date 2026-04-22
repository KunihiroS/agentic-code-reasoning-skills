# iter-22 discussion

## 総評
提案の主眼は verdict 規則そのものではなく、compare 前半の relevant test 発見を「changed symbol への言及」起点から「assertion / expected output から changed value・exception・branch へ戻る依存トレース」起点へ置換する点にある。これは retrieval heuristic の局所改善として理解でき、Exploration Framework では主に B（情報の取得方法を改善する）に属する。副次的に A（順序変更）と G（支払いとして triage 順序 MUST を外す）が混ざるが、中心は B で妥当。

## 既存研究との整合性
検索なし（理由: assertion から観測境界へ戻る依存追跡、表面的参照ではなく観測可能な出力側から relevance を定める、という主張は一般的なコード推論・プログラム解析の原則の範囲で自己完結しており、この proposal では固有の外部概念や研究主張への強い依拠がない）

## 監査観点別コメント

### 1. Exploration Framework のカテゴリ選定
- 判定: 概ね適切
- 理由: 変更対象が D2 の「relevant tests の見つけ方」であり、結論条件そのものではなく取得トリガの変更だから B が主カテゴリでよい。
- ただし、`STRUCTURAL TRIAGE (required before detailed tracing)` の MUST を外す支払いを伴うため、A/G 成分もある。カテゴリ B として通すなら、「主作用は relevance retrieval、triage 変更は認知負荷・順序の支払い」と位置づけるのが明確。

### 2. EQUIVALENT / NOT_EQUIVALENT への作用
- EQUIVALENT 側:
  - 改善余地あり。表面的に changed symbol を参照するだけのテストを relevant と早期固定しにくくなるため、無関係な差分に引っ張られた偽 NOT_EQUIVALENT を減らしうる。
  - 一方で、間接経路の relevant test を掘れるので、従来の見落とし由来の偽 EQUIVALENT も減らしうる。
- NOT_EQUIVALENT 側:
  - 改善余地あり。direct reference 偏重をやめることで、実際に fail/pass を分ける assertion boundary へ届く間接テストを拾いやすくなる。
  - ただし、この proposal は triage の早期結論まわりにも触れているのに、NOT_EQUIVALENT を出してよい最小根拠を新しく明示していない。この点が片方向最適化ではなく双方向改善として成立するかの最大の弱点。

### 3. failed-approaches.md との照合
- 本質的再演か: 現時点では「完全に同じ失敗の再演」とまでは言えない。
- 理由:
  - 原則 1（再収束の前景化）: 該当薄い。差分の吸収や downstream 再収束を既定化していない。
  - 原則 2（未確定性を保留側へ倒す既定動作）: 該当薄い。UNVERIFIED や保留 fallback の強制ではなく、relevance の取り方を変える案。
  - 原則 3（新しい抽象ラベルや必須言い換え）: 該当薄い。新ラベルや CLAIM 形式は増やしていない。
- ただし注意点として、探索の入口を `start from the concrete fail-to-pass assertion...` にかなり寄せており、局所的には探索経路を半固定している。

### 4. 汎化性チェック
- 明示的な違反なし。
- proposal 内に具体的な数値 ID、ベンチマーク固有のリポジトリ名、テスト名、実コード断片は含まれていない。
- helper / caller / changed branch などの表現は抽象的で、特定言語・特定ドメイン依存も薄い。
- したがって汎化性の下限は満たしている。

### 5. 全体の推論品質への期待効果
- 期待できる点:
  - relevant test の precision 向上
  - direct symbol reference への過剰依存の低減
  - 間接 call path・shared branch・shared exception 由来の差分検出力の向上
- 限界:
  - compare の runtime で「いつ追加探索に倒し、いつ NOT_EQUIVALENT を言ってよいか」の分岐がまだ詰め切れていない。
  - そのため、監査文面としては説得的でも、実際の compare 実行での観測可能な差が NOT_EQUIVALENT 側でまだ曖昧。

## 停滞診断
- 懸念点（1点だけ）: 監査 rubric には刺さる説明だが、triage の早期結論を弱めるだけで「代わりに compare が何を見たら NOT_EQUIVALENT を出すのか」が未定義のため、runtime では単に結論保留や探索増に流れ、compare の意思決定差が十分に固定されない恐れがある。

## failed-approaches 該当性の簡易判定
- 探索経路の半固定: YES
  - 原因文言: `start from the concrete fail-to-pass assertion or expected output, then trace backward...`
- 必須ゲート増: NO
  - 理由: むしろ `required before detailed tracing` を外す支払いが入っている。
- 証拠種類の事前固定: NO
  - 理由: assertion/output 起点を優先するが、changed-symbol search も candidate discovery として残しており、証拠種を単独必須化してはいない。

## compare 影響の実効性チェック
- 0) 実行時アウトカム差:
  - changed symbol への textual reference だけでは relevant test が確定しなくなり、assertion から changed path に届くか追加探索を要求する実行が増える。
  - 一部のケースでは、従来すぐ comparison anchor にしていたテストが候補止まりになり、ANSWER や CONFIDENCE が変わる。

- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Before/After が分岐として変わっているか: YES
  - Trigger line の自己引用があるか: YES
  - ただし、triage/early conclusion にも触れているのに、そこに対する新しい分岐条件が不足しているため、compare 影響は relevant-test selection には効くが NOT_EQUIVALENT 側の停止条件には十分落ちていない。

- 2) Failure-mode target:
  - 対象: 両方
  - メカニズム:
    - 偽 EQUIVALENT: 間接的に changed branch へ届く relevant test を拾い損ねる失敗を減らす。
    - 偽 NOT_EQUIVALENT: changed symbol を参照するだけのテストを relevant と誤固定し、無関係な差分を重く見る失敗を減らす。

- 2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か?: YES
  - impact witness を要求しているか?: NO
  - コメント: `STRUCTURAL TRIAGE (required before detailed tracing)` を `STRUCTURAL TRIAGE:` に弱める提案は早期結論の挙動に触れている。しかし、「NOT_EQUIVALENT は少なくとも 1 つの PASS/FAIL 差に結びつく具体的 assertion boundary を witness したときのみ出せる」等の置換条件がない。このままだと file/module gap の扱いが宙に浮き、偽 NOT_EQUIVALENT か、逆に無限定な追加探索のどちらにも流れうる。

- 3) Non-goal:
  - 新しい verdict ゲートの増設はしない、研究コアは変えない、changed-symbol search 自体は候補発見として残す、という境界は明示されている。
  - この境界設定自体は妥当。

## 追加チェック
### Discriminative probe
- 判定: 概ねある
- 内容: direct reference が見えるテストではなく、別 caller から同じ changed branch に入る間接テストが fail/pass を分けるケースを挙げており、変更前に偽 EQUIVALENT か過度な保留、変更後に assertion-backward tracing で relevant 化できるという runtime 差が説明されている。
- ただし、この probe は relevant-test discovery には効いている一方、早期 NOT_EQUIVALENT の根拠更新までは説明していない。

### 支払い（必須ゲート総量不変）の明示
- 判定: YES
- 理由: `add MUST(...) ↔ demote/remove MUST("STRUCTURAL TRIAGE (required before detailed tracing)")` と A/B 対応付けが書かれている。

## 結論
提案の中核である「relevant test の retrieval trigger を textual reference から assertion-backward tracing に置き換える」は、compare の前半を実際に変えうる良い局所仮説で、汎化性や failed-approaches の観点でも大きな問題はない。

ただし今回は、proposal 自身が STRUCTURAL TRIAGE / 早期結論にも触れている以上、NOT_EQUIVALENT を出してよい条件を `impact witness` 付きで置換していない点が最大ブロッカーになる。ここがないと、監査に通りやすい説明強化に見えても、compare の runtime では「何が観測されたら NOT_EQUIVALENT なのか」が未確定なままで停滞しやすい。

## 修正指示
1. triage の順序 MUST を外すなら、その置換として「早期 NOT_EQUIVALENT は、少なくとも 1 つの relevant test の assertion boundary に結びつく impact witness を traced できた場合に限る。単なる file/module gap は追加探索トリガであって verdict 根拠ではない」という 1 行を差分プレビューに入れてください。

承認: NO（理由: STRUCTURAL TRIAGE / 早期結論に触れているのに、NOT_EQUIVALENT 側の `impact witness` 要求が欠けており、compare の実効的な分岐変更として未完成）
