# Iteration 10 Discussion

## 総評
提案は「import されているだけで早期に NOT EQUIVALENT へ飛ぶ」ショートカットを狭め、保留して ANALYSIS に回す条件を明確化しようとしています。compare の意思決定点に触れており、単なる監査向けの美文化だけではありません。

ただし、今回の具体化は failed-approaches.md の禁止原則にかなり近く、特に「既存の判定基準を特定の観測境界だけに過度に還元しすぎない」の再演懸念が強いです。最大の問題は、構造差の有効条件を `call path` / `import-time side effects` という特定の観測境界へ狭めている点です。これは偽 NOT_EQUIV を減らしうる一方で、構造差から得られる他の有力な反例シグナルを取りこぼす方向にも働きます。

## 1. 既存研究との整合性
検索なし（理由: 一般原則の範囲で自己完結）。

README.md と docs/design.md が示す研究コアは、番号付き前提・仮説駆動探索・手続き間トレース・必須反証です。今回の提案はそのコア自体を壊してはいませんが、研究コアが重視する「反例を拾う探索の自由度」を狭める危険があります。

## 2. Exploration Framework のカテゴリ選定
カテゴリ E（表現・フォーマット改善）は一応成立します。実際の変更は新手順追加ではなく、STRUCTURAL TRIAGE の文言の十分条件を絞るものだからです。

ただし実効としては「表現改善」に留まらず compare の分岐条件を書き換える提案です。したがって監査上は E として受理可能でも、中身は軽い wording change ではなく「判定基準の再定義」として扱うべきです。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用
- NOT_EQUIVALENT 側:
  - 早期 NOT_EQUIV の発火条件を狭めるため、偽 NOT_EQUIV は減りうる。
  - 特に「import はあるがテスト結果に効いていない」ケースでは保留して ANALYSIS に進みやすくなる。
- EQUIVALENT 側:
  - 提案文の主張通り、早期 EQUIV 条件は増えていないので直ちに偽 EQUIV を増やす変更ではない。
  - ただし、既存の有力な structural signal を `call path` / `import-time side effects` に限定すると、早期 NOT_EQUIV できたケースが ANALYSIS 依存になり、その ANALYSIS が弱いと偽 EQUIV 側へ漏れる回帰リスクはある。

結論として、片方向にしか作用しない設計ではないです。主目的は偽 NOT_EQUIV の削減ですが、逆方向の回帰リスクはゼロではありません。

## 4. failed-approaches.md との照合
最重要の懸念は failed-approaches.md 11-12 行目の原則です。

- 該当原則:
  - 「既存の判定基準を、特定の観測境界だけに過度に還元しすぎない」
- 今回の提案で危ない文言:
  - `call path で依存` または `import-time side effects に依存`
  - `not mere import`
  - `test-visible structural gap`

問題は、構造差の効力を「どの証拠で可視化されたか」の特定様式へ寄せていることです。これにより、そこに綺麗に写像できない構造差シグナルを弱く扱う実質的な探索固定が起こりえます。

提案者は「証拠種類の固定ではない」と述べていますが、compare の早期 NOT_EQUIV 発火条件として明文化した時点で、実運用ではかなり強い境界条件として働きます。

## 5. 汎化性チェック
- 具体的な数値 ID / リポジトリ名 / テスト名 / 実コード断片:
  - 明確なベンチ固有識別子は見当たりません。
  - SKILL.md 自身の引用は許容範囲です。
- 暗黙のドメイン依存:
  - `import-time side effects` は多くの言語系で通じる一般概念ですが、import/load semantics が薄い言語やビルド形態ではやや言語寄りです。
  - さらに `call path` と `import-time side effects` の二択で書くと、その2種が主要証拠であるかのような印象を与え、証拠型の事前固定に近づきます。

したがって R1 的には即失格ではないものの、表現はもう少し言語非依存・証拠型非固定に寄せた方がよいです。

## 6. 全体の推論品質への期待効果
良い点:
- 「import されている」だけで意味論差を即断する雑なショートカットを抑えるので、早計な NOT_EQUIV を減らす方向の改善としては筋が通っています。
- 既存の ANALYSIS を活かす方向で、必須ゲートを増やしていない点もよいです。

限界:
- 改善の核が「どの structural signal を早期確定の十分条件とみなすか」の狭窄なので、compare 全体の推論品質を広く上げるより、特定の誤発火を抑える局所修正に留まりやすいです。
- その狭窄の仕方が failed-approaches の禁則に近いため、長期的には探索の自由度を削る副作用が心配です。

## 停滞診断
- 懸念 1 点:
  - 「mere import ではダメ」と言い換える説明自体は監査 rubric に刺さりやすい一方、実際の compare では依存の観測方法が曖昧なままだと、運用上は従来どおり主観的に dependency ありと見なして NOT_EQUIV に飛ぶ可能性があり、意思決定改善が説明ほど大きくない懸念があります。

- failed-approaches 該当性:
  - 探索経路の半固定: NO
  - 必須ゲート増: NO
  - 証拠種類の事前固定: YES
    - 原因文言: `call path` / `import-time side effects` を早期 NOT_EQUIV の発火条件として列挙している点

## compare 影響の実効性チェック
- 1) Decision-point delta:
  - IF/THEN 形式で 2 行（Before/After）になっているか: YES
  - Trigger line が差分プレビュー内に含まれているか: YES
  - コメント:
    - 条件と行動は実際に変わっており、理由の言い換えだけではありません。
    - ただし分岐条件の具体化が、そのまま観測境界の固定になっているのが問題です。

- 2) Failure-mode target:
  - 主対象は偽 NOT_EQUIV。
  - メカニズムは「import だけ」を structural gap の十分条件から外し、不確実時に ANALYSIS へ送ること。
  - ただし副作用として、従来 structural gap として扱えたケースの一部が ANALYSIS 依存となり、分析失敗時の偽 EQUIV 回帰リスクがある。

- 3) Non-goal:
  - 読解順序の固定はしない。
  - 新しい必須ゲートは増やさない。
  - ただし `call path` / `import-time side effects` の列挙は、非 goal のはずの「証拠種類の事前固定」に近づいているため境界条件の書き方を修正すべき。

- Discriminative probe:
  - 抽象ケース: 片側のみ変更したモジュールをテストが読み込むが、差分はテストが観測しない補助ロジックに留まる。
  - 変更前は `import` だけで NOT_EQUIV に誤って飛びやすい。
  - 変更後は早期即断を避けて ANALYSIS に回せるので改善余地はあるが、これを `call path` / `import-time side effects` だけで表現すると、別の観測可能な構造差を拾いにくくする。

- 支払い（必須ゲート総量不変）:
  - proposal 内では「狭めるだけなので支払い不要」とされており、A/B 対応付け不足で不承認にする類型ではありません。

## 修正指示
1. `call path` / `import-time side effects` の列挙を、そのまま早期 NOT_EQUIV の十分条件にしないでください。削るのではなく、例示へ格下げし、主文を「relevant tests can be shown to observe the omitted module's behavior」程度の抽象度に戻してください。
2. `test-visible structural gap` への置換は維持してよいですが、その直後に証拠型を固定しない一文を統合してください。追加行ではなく、既存の `regardless of the detailed semantics` 置換枠の中でまとめるのがよいです。
3. 偽 EQUIV 回帰を避ける境界を 1 文だけ明示してください。新ゲート追加ではなく、「観測不能なら ANALYSIS へ進むが、structural gap 自体を無効化したわけではない」と書けば十分です。

## 最終判断
承認: NO（理由: failed-approaches.md の「既存の判定基準を特定の観測境界だけに過度に還元しすぎない」の本質的な再演になっているため）
