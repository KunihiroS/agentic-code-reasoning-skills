提供いただいたClaude APIの「Agent Skills」の仕様と、論文が実証した「準形式的推論（Semi-formal reasoning）」の手法を組み合わせたスキル設計をご提案します。

Agent Skillsは、YAMLフロントマターによる軽量なメタデータ（レベル1）と、詳細な手順やベストプラクティスを記したマークダウン（レベル2）によって構成され、必要に応じて段階的に情報をロード（プログレッシブディスロージャー）できるファイルシステムベースの機能です。

この仕組みを活かし、論文で実証された汎用的なコード推論手法を**「用途別の3つのSkill」**として区分し、Agent Skillsのディレクトリ構造に落とし込む設計案を作成しました。

### Skillセットの全体構成案
論文の3つの評価タスク（パッチ検証、バグ特定、コードQA）を汎化し、以下の3つの独立したSkillとして定義します。

1.  **`patch-equivalence-skill`** (コード比較・影響調査スキル)
2.  **`fault-localization-skill`** (バグ特定・根本原因分析スキル)
3.  **`deep-code-qa-skill`** (深層コードQA・意味解析スキル)

以下に、それぞれのSkillの具体的な実装イメージ（`SKILL.md`の構成）を示します。

---

### 1. コード比較・影響調査スキル (`patch-equivalence-skill`)
複数のコード変更（パッチやPR）が、システムの挙動やテスト結果にどのような違いをもたらすかを実行せずに検証するスキルです。

**`SKILL.md` の構成例:**
```yaml
---
name: patch-equivalence-reasoning
description: Use this skill to determine if two code changes produce the same behavior or test outcomes, without executing the code.
---
### Patch Equivalence Reasoning
#### Instructions
コードの変更点を比較する際は、推測を避け、以下の「準形式的推論証明書（Semi-formal Certificate）」の構造に従って調査・文書化を行ってください。

1. **PREMISES (前提の明文化)**
   - 変更Aがどのファイルをどう変更したか
   - 変更Bがどのファイルをどう変更したか
   - 関連するテストがどのような挙動をチェックしているか
2. **ANALYSIS OF TEST BEHAVIOR (実行経路のトレース)**
   - 各テストについて、変更Aを適用した場合の実行経路（関数呼び出しの連鎖）をファイル・行番号付きでトレースし、PASS/FAILを判定する。
   - 変更Bについても同様にトレースする。
3. **FORMAL CONCLUSION (形式的な結論)**
   - トレース結果から「両者の挙動（テスト結果）が同一か否か」の最終結論を出す。異なる場合は必ず反証（Counterexample）となる具体的なコードトレースの証拠を提示すること。
```
*情報源:*

---

### 2. バグ特定・根本原因分析スキル (`fault-localization-skill`)
エラー報告や失敗したテストから、コードベース内のバグの箇所と根本原因を論理的に特定するスキルです。

**`SKILL.md` の構成例:**
```yaml
---
name: fault-localization-reasoning
description: Use this skill to find the exact buggy lines of code and analyze the root cause based on failing tests or bug reports.
---
### Fault Localization Reasoning
#### Instructions
バグの箇所を特定する際は、直感でファイルを探すのではなく、以下の4フェーズで段階的に推論・探索を行ってください。

1. **Test Semantics Analysis (テスト意味解析)**
   - テスト（またはエラー報告）が呼び出しているメソッドと、期待している挙動・アサーションを「PREMISE（前提）」として明文化する。
2. **Code Path Tracing (コード経路の追跡)**
   - テストの入り口から本番コードへの実行パスを追跡する。呼び出される各メソッドについて、「クラス名・メソッド名」「ファイル名:行番号」「そのメソッドが何をするか」を文書化する。
3. **Divergence Analysis (乖離分析)**
   - 追跡した経路の中で、実装がテストの期待値と矛盾する（Divergence）箇所を特定し、「CLAIM（主張）」として文書化する（例：「行Xのコードが挙動Yを引き起こし、前提Zと矛盾する」）。
4. **Ranked Predictions (結論)**
   - 収集したCLAIMに基づき、最も可能性の高いバグの箇所（ファイルと行番号）をランキング形式で提示する。
```
*情報源:*

---

### 3. 深層コードQA・意味解析スキル (`deep-code-qa-skill`)
コードの仕様、ライブラリの挙動、エッジケースなどに関する複雑な質問に対し、関数名などからの推測を排除して厳密に回答するスキルです。

**`SKILL.md` の構成例:**
```yaml
---
name: deep-code-qa-reasoning
description: Use this skill to answer complex questions about code behavior, data flow, and semantics with strict evidence.
---
### Deep Code QA Reasoning
#### Instructions
コードに関する質問に答える前に、必ず以下の構造化された証拠収集を行ってください。

1. **FUNCTION TRACE TABLE (関数追跡表)**
   - 調査したすべての関数について以下の表を作成する。
   - `| 関数名 | ファイル:行番号 | パラメータ型 | 戻り値 | 確認された挙動 |`
2. **DATA FLOW ANALYSIS (データフロー分析)**
   - 重要な変数が「どこで作成され」「どこで変更され」「どこで使用されるか」をファイル・行番号ベースで追跡する。
3. **SEMANTIC PROPERTIES (意味特性)**
   - コードの性質（例：「このマップは不変である」など）を挙げ、それを裏付ける具体的なファイル・行番号の証拠を提示する。
4. **ALTERNATIVE HYPOTHESIS CHECK (対立仮説の検証)**
   - もし結論が逆であった場合、どのような証拠が存在するはずか？それを探した結果どうだったか（反証）を記述する。
5. **Final Answer**
   - 上記の証拠にのみ基づいて最終的な回答を記述する。
```
*情報源:*

---

### 実装上のベストプラクティス（論文からの知見）
これらのSkillを効果的に機能させるため、Agent Skillsのディレクトリ内に`scripts`フォルダ等を設け、以下のような補助ツールやルールを組み合わせるのが理想的です。

*   **探索のフォーマット化（プロンプトへの組み込み）:**
    エージェントがファイルを読む前に「**何を期待してそのファイルを読むのか（仮説）**」を宣言させ、読んだ後に「**仮説が立証されたか、反証されたか**」を記録させるプロセスをSkillのInstructionsに含めることで、エージェントが道に迷ったり、思い込みで結論を出すことを防ぎます。
*   **汎用性の維持:**
    Skill内に特定のプログラミング言語（JavaやPythonなど）に依存する文法ルールは書き込まず、あくまで「関数を追跡せよ」「証拠となる行番号を明記せよ」という**推論の型**の強制に留めることで、多様なリポジトリに対応可能な強力なAgent Skillとなります。