# SKILL.md 改善提案 監査レポート

## 1. 既存研究との整合性
- **Web 検索結果**: DuckDuckGo MCP を用いて `"software testing \"semantic difference\" propagation assertion"` および `"test assertion propagation software defect"` で検索を実施。
- **要点**: ソフトウェアテストおよびデバッグの分野において、コード上の意味論的差異（欠陥や変更）がプログラムの状態伝播を経てアサーション（テスト観測点）に到達するかどうか（Error Propagation / Fault Propagation）は、テストの有効性やバグ検出の根本的な概念として広く研究されています（例: "An Approach for Analysing the Propagation of Data Errors in Software", "Detecting and Confining Software Errors"など）。
- **結論**: 「コード上の差異がアサーションに伝播するか」を問う本提案は、ソフトウェアテストの理論的裏付け（Propagation of errors/defects to assertions）と完全に整合しています。

## 2. Exploration Framework のカテゴリ選定
- **カテゴリ**: カテゴリ B — 情報の取得方法を改善する（"何を探すかではなく、どう探すかを改善する"）
- **評価**: 適切です。「テスト名、コードパス」という表層的な検索目標から、「差異がアサーションに伝播するか」という動的な振る舞い・因果関係の確認へと検索の質（どう探すか）を深化させており、理にかなっています。

## 3. EQUIVALENT / NOT_EQUIVALENT 判定への作用（非対称性の排除）
- **変更前**: `Searched for: [specific pattern — test name, code path, or input type]`
- **変更後**: `Searched for: [whether the semantic differences between A and B propagate to a test assertion — which differences were checked and which assertion points they were traced against]`
- **分析**: この変更は `NO COUNTEREXAMPLE EXISTS` (EQUIVALENT 判定のパス) のフォーマットのみを変更しています。
  - **EQUIVALENT 判定に対して**: 「ただコードパスが通らないから」といった浅い理由での誤判定を防ぎ、「差異がアサーションに到達しないこと」を具体的に確認させるため、判定の質が向上します。
  - **NOT_EQUIVALENT 判定に対して**: NOT_EQUIVALENT の主張パス（`COUNTEREXAMPLE` セクション）には一切変更を加えていません。また、この変更は「すでに収集済みのトレース証拠をアサーションに対応づける」ことを求めるものであり、新たな証明責任の非対称な追加（例: 絶対にコードを実行して証明せよ、など）ではありません。
- **結論**: 非対称な作用は生じず、安全です。

## 4. failed-approaches.md の汎用原則との照合
- 原則1（非対称操作）、原則5（過剰規定）、原則8（受動的記録）、原則18/19（過剰な立証義務）など、すべての主要原則と照合しました。
- 提案者が分析している通り、これは新規フィールドの追加や非対称な立証責任の押し付けではなく、既存の1行（検索対象の記述）を「より意味のある検証行為（アサーションへの伝播確認）」へと誘導する言い換えに過ぎません。過去の失敗の再演にはなっていません。

## 5. 汎化性チェック
- 提案文中に、特定の数値 ID、リポジトリ名、テストフレームワーク名、言語特有のコード断片などは一切含まれていません。
- 「意味論的差異 (semantic differences)」「アサーション地点 (assertion points)」という、あらゆるプログラミング言語・テストフレームワークに適用可能な抽象的な概念のみが使用されています。
- ルール違反はありません。

## 6. 全体の推論品質への期待効果
- エージェントが「コードの差分があるからテストは落ちるはずだ（NOT_EQUIVALENT）」と早合点する（Control Flow のみの確認で Data Flow / Propagation を無視する）失敗パターンを減らす効果が期待できます。
- 反対に「何となく影響なさそうだ（EQUIVALENT）」と結論づける際にも、どのアサーションに対して影響がないと判断したのかを言語化させることで、ハルシネーションや雑な推論を抑制できます。
- 全体として、推論の解像度（コード行の差異 → アサーションでの観測）が高まることが期待されます。

---

**承認: YES**