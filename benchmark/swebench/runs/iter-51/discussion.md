# Iteration 51 — 改善案の監査結果

## 1. 既存研究やコード推論の知見に基づく改善案の妥当性評価

DuckDuckGo MCP サーバーを使用して「Agentic Code Reasoning Ugare Chandra arXiv:2603.01896」および「Incomplete reasoning chains code reasoning test observable outcome limit」についてWeb検索を行いました。

- **検索結果**: [2603.01896] Agentic Code Reasoning (arXiv), Replicating "Agentic Code Reasoning" - GitHub 等
- **要点**: 原論文（Ugare & Chandra）では、"semi-formal reasoning"（半形式的推論）の導入により、LLMがコードを実行せずにパッチの等価性を検証する精度が向上することが示されています。エラー分析（Error Analysis）のセクションでは、「不完全な推論チェーン（Incomplete reasoning chains）」が主要な失敗要因の一つとして挙げられており、エージェントが複数の関数をトレースしても、下流の処理（downstream handling）を見落とすことで誤った結論に至るケースが指摘されています。

**評価**: 実装者の提案は、この原論文の知見（不完全な推論チェーンの排除）に直接基づいており、学術的背景に強く裏付けられています。特に、チェーンがテスト観測点（test-observable outcome）まで繋がっているかを双方向に確認するというアイデアは、実務的にも「差分が見つかったからといって即座にNOT_EQと判定する」ことや「差分が吸収されたからといって他の経路への影響を無視する」ことを防ぐ上で非常に妥当です。

## 2. Exploration Framework のカテゴリ選択は適切か？

**カテゴリ**: Category F: 原論文の未活用アイデアを導入する

**評価**: 適切です。親イテレーション（iter-39）はCategory B（情報取得方法の改善）でした。Category Fは過去に直接的な失敗が少なく、原論文のError Analysisセクションの知見をガードレールとして明文化することは、フレームワークの意図に完全に合致します。未試行のアプローチとして正当です。

## 3. 変更の実効的差分と両方向への影響分析

- **変更前**: `verify that downstream code does not already handle the edge case or condition you identified` （一方向のチェック：EQUIVの偽陰性を防ぐ方向）
- **変更後**: `verify both that callers do not already normalize or absorb the identified difference before the test observes it, and that the chain connects the change to a test-observable outcome — not just to the changed function's boundary.`

**分析**:
- **EQUIV 正答率への影響**: 既存の一方向のチェックを `callers do not already normalize or absorb` とより具体的に言語化したことで、維持または向上が期待できます。
- **NOT_EQ 正答率への影響**: 新たに追加された `and that the chain connects the change to a test-observable outcome` の部分が、NOT_EQの偽陰性（途中で推論を止めてEQUIVと誤判定する）を防ぐ方向に作用します。
- **実効的差分の対称性**: これまでEQUIV有利に働いていたガードレールに対して、NOT_EQ有利に働く制約を並置することで、実質的に「推論チェーンの完全性」という対称的な基準を設けています。差分が一方向にしか作用しないという懸念は解消されています。

## 4. 変更規模の遵守

- **追加行数**: 0行（既存行の文言変更のみ）
- **評価**: 5行以内の hard limit を完全に遵守しています。新規構造の追加ではなく、既存のガードレールの文言精緻化に留まっています。

## 5. failed-approaches.md との照合

- **BL-14 (逆方向推論の追加) / BL-25 (完全trace義務)**: これらは特定の結論を出す場合のみに過剰な立証責任を課したり（非対称）、全Claimに対する厳格な追跡を義務付けてターンを枯渇させたりしました。本提案はガードレール（原則）の精緻化であり、各Claimでの機械的なcite義務の追加ではありません。「テスト観測点まで繋がっているかを確認せよ」という指示は、推論の質的要件を示すものであり、テンプレートの過剰規定（原則#5）や受動的な記録フィールドの追加（原則#8）には抵触しません。
- **原則#6 (対称化は差分で評価)**: 既存のガードレールがEQUIV寄り（吸収の確認）だったのに対し、NOT_EQ寄り（到達の確認）を追加することでバランスを取っており、適切な対称化です。

## 6. 全体の推論品質への期待効果

この変更により、エージェントは「変更関数の境界」で思考を停止することなく、コードの変更が「テスト観測点（アサーションや例外など）」にどう伝播するかを意識するようになります。これにより、推論ジャンプによる不完全な証拠に基づく誤判定（13821型や11433型）の減少が期待され、全体の推論品質が向上します。

## 7. 結論

承認: YES

（修正や再考を要する致命的な問題は見当たらず、原論文の知見に基づいた非常に堅実な改善案です。）