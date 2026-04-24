# iter-49 proposal 監査コメント

## 1. 既存研究との整合性

検索なし（理由: 一般原則の範囲で自己完結）。

提案は、README.md / docs/design.md が述べる certificate-based reasoning、premise → trace → refutation → formal conclusion の範囲内で、STRUCTURAL TRIAGE から FORMAL CONCLUSION へ直接飛ぶ例外を弱め、結論前に最短の影響 trace を置く順序変更である。特定の新概念や外部研究用語へ強く依拠していないため、追加 Web 調査は不要と判断する。

## 2. Exploration Framework のカテゴリ選定

カテゴリ A「推論の順序・構造を変える」として概ね適切。

理由:
- 変更対象は、構造差を見つけた後の処理順序であり、「構造差の発見 → 直接結論」を「構造差の発見 → 最短影響 trace → 結論または confidence 低下」に並べ替えるもの。
- 証拠種類を新しく固定するより、既存の structural triage と per-test outcome trace を接続し直す変更なので、汎用原則として理にかなっている。
- ただし、実装時に「shortest trace」が単一アンカー固定として読まれないよう、trace は “relevant PASS/FAIL outcome” への最短説明であり、探索経路そのものを一つに固定するものではないと保つ必要がある。

## 3. EQUIVALENT / NOT_EQUIVALENT への作用

EQUIVALENT への作用:
- 構造差だけで早期 NOT_EQUIVALENT に倒れるケースで、関連テストの PASS/FAIL へ到達する trace が作れない場合、LOW confidence または保留寄りになる。
- これにより、ファイル差・モジュール差があっても既存テスト結果に影響しない場合の偽 NOT_EQUIV を減らす方向に働く。

NOT_EQUIVALENT への作用:
- 構造差が実際に関連テストの failure / pass divergence へ到達する場合、その trace を明示してから NOT_EQUIVALENT に進むため、結論の根拠が強くなる。
- 構造差を単に弱める変更ではなく、verdict-affecting trace が取れる場合は NOT_EQUIV を維持・強化するため、偽 EQUIV を増やしにくい。

片方向最適化の確認:
- 主な改善圧は偽 NOT_EQUIV の抑制だが、trace が取れた構造差は NOT_EQUIV の証拠として残す設計なので、EQUIVALENT 側だけへの一方的最適化ではない。
- ただし、実装文が「trace がなければ常に保留」と読まれると failed-approaches 原則2に寄るため、proposal の “or mark the verdict LOW confidence if that trace is unavailable” は、保留強制ではなく confidence 調整として扱うのがよい。

## 4. failed-approaches.md との照合

原則1「再収束を比較規則として前景化しすぎない」:
- NO。再収束や下流一致を既定化していない。

原則2「未確定 relevance や脆い仮定を、常に保留側へ倒す既定動作にしすぎない」:
- 概ね NO。trace 不在時に LOW confidence とするが、trace が取れれば NOT_EQUIV に進むため、未確定性を常に保留へ送る規則ではない。
- 注意点: 実装時に “unavailable trace = conclusion forbidden” と強く書くと YES に近づく。

原則3「差分の昇格条件を新しい抽象ラベルや必須の言い換え形式で強くゲートしすぎない」:
- 概ね NO。新ラベル分類や固定アンカーは追加していない。
- ただし、failed-approaches.md には「構造差の役割を探索の手掛かりに限定し、traced divergence まで結論利用を禁じる」形も失敗しうるとある。今回の案は structural gap を first ANALYSIS item として verdict 証拠に使えるため、本質的再演には至っていない。

原則4「終盤の証拠十分性チェックを confidence 調整へ吸収しすぎない」:
- NO。終盤 self-check を削る変更ではない。
- ただし Payment で “Complete every section...” を remove する書き方は広すぎるため、実装では structural gap 例外文の置換に限定した方が安全。

原則5「最初に見えた差分から単一の追跡経路を即座に既定化しすぎない」:
- NO 寄り。対象は clear structural gap の早期結論分岐に限られ、全ての意味差分に単一路線 trace を強制するものではない。
- 注意点: “shortest trace” が唯一の探索経路に読まれると YES 化する。実装文は “minimum trace needed for this structural shortcut” 程度に抑えるべき。

原則6「近接欄の統合で探索理由と反証可能性を潰しすぎない」:
- NO。欄の統合・削除が主目的ではない。

## 5. 汎化性チェック

固有識別子・過剰適合:
- 具体的なベンチマークケース ID、リポジトリ名、テスト名、関数名、コード断片は含まれていない。
- SKILL.md 自身の文言引用は Objective.md の R1 減点対象外に該当する。
- “missing file, missing module update, missing test data” は既存 SKILL.md の自己引用であり、特定ドメイン依存ではない。

暗黙のドメイン・言語前提:
- 特定言語、フレームワーク、テストパターンへの依存は見当たらない。
- PASS/FAIL outcome への trace は compare mode の定義 D1 と整合するため、Go/JS/TS/Python などを問わず適用可能。

判定: 汎化性は PASS 水準。

## 6. compare 影響の実効性チェック

0) 実行時アウトカム差:
- clear structural gap を見つけたとき、直接 ANSWER: NO / NOT_EQUIVALENT に進む代わりに、関連 PASS/FAIL outcome への最短 trace を ANALYSIS に記録する。
- trace が作れない場合は、NOT_EQUIVALENT のまま高 confidence にしにくくなり、LOW confidence / 未検証明示が増える。
- trace が作れる場合は、COUNTEREXAMPLE の根拠が構造差単体ではなく outcome divergence へ接続される。

1) Decision-point delta:
- IF/THEN 形式で 2 行（Before/After）になっているか？ YES。
  - Before: IF S1 or S2 reveals a clear structural gap THEN proceed directly to FORMAL CONCLUSION with NOT EQUIVALENT.
  - After: IF S1 or S2 reveals a clear structural gap THEN first record the shortest trace from that gap to a relevant PASS/FAIL outcome, and only then conclude or lower confidence.
- 条件も行動も同じで理由だけ言い換えか？ NO。直接結論から、trace 記録または confidence 低下へ分岐が変わる。
- 差分プレビュー内に Trigger line の自己引用が含まれているか？ YES。proposal line 57 に planned Trigger line がある。

2) Failure-mode target:
- 対象は両方。
- 偽 NOT_EQUIV: 構造差のみで関連 outcome への影響未確認のまま NOT_EQUIV とする早期結論を抑える。
- 偽 EQUIV: 構造差が実際に関連 outcome へ到達する場合、その trace を明示して NOT_EQUIV 証拠として強める。

2.5) STRUCTURAL TRIAGE / 早期結論に触れる提案か？ YES。
- NOT_EQUIV の根拠が「ファイル差がある」だけに退化していないか？ 退化していない。proposal は “relevant PASS/FAIL outcome” への trace を要求している。
- impact witness を要求しているか？ YES と評価する。ただし実装時には PASS/FAIL outcome だけでなく、可能なら “assert/check boundary” へ接続する wording にするとより安全。

3) Non-goal:
- 探索経路を半固定しない: structural gap 例外に限った最短 trace であり、全差分に単一経路を強制しない。
- 必須ゲート総量を増やさない: 既存の直接ジャンプ文言を置換し、full ANALYSIS 完遂圧を structural shortcut 場面で緩める支払いがある。
- 証拠種類を事前固定しない: 新しいラベル分類ではなく、compare mode 既存の PASS/FAIL outcome へ接続するだけ。

## 7. 停滞診断

監査 rubric に刺さる説明強化へ偏り、compare の意思決定を変えていない懸念:
- 低い。Before/After が直接結論の可否と confidence の扱いを変えており、実行時に ANSWER / CONFIDENCE / ANALYSIS 記載が観測可能に変わる。

failed-approaches 該当確認:
- 探索経路の半固定: NO。ただし “shortest trace” を全ケースの固定経路として一般化すると YES になりうる。
- 必須ゲート増: NO。proposal は Payment を明示している。ただし “Complete every section...” の remove は広すぎるため、実装では structural shortcut 例外文の置換に限定すること。
- 証拠種類の事前固定: NO。既存の PASS/FAIL outcome 定義に接続しているだけで、新しい証拠カテゴリは作っていない。

## 8. Discriminative probe

抽象ケース:
- Change A だけが補助データファイルを追加し、Change B は追加していない。ただし関連テストがその補助データを読み込むかはコード上で分岐しており未確認。
- 変更前は S1 の missing test data / missing file から早期 NOT_EQUIV としやすい。変更後は、そのファイル差が実際に関連 assert/check の PASS/FAIL へ届く trace が必要になり、届かなければ LOW confidence、届けば NOT_EQUIV をより強く出せる。
- これは新しい必須ゲートの純増ではなく、既存の早期結論ショートカットを outcome trace へ置換するため、compare の意思決定に直接効く。

## 9. 支払い（必須ゲート総量不変）の確認

proposal 内で A/B の対応付けは明示されている:
- add MUST: “Before using a structural gap for NOT EQUIVALENT, record the shortest trace...”
- demote/remove MUST: “Complete every section. Do not skip to FORMAL CONCLUSION without completing ANALYSIS.”

ただし、後者を全体から remove すると研究コアの anti-skip mechanism を弱めるおそれがある。支払いとしては、グローバルな complete every section を削るより、既存の structural gap 直接ジャンプ文を置換し、そこに “remaining ANALYSIS may be minimal when this trace decides all relevant outcomes” を置く方が安全。

## 10. 全体の推論品質向上の見込み

期待できる改善:
- 構造差を見た瞬間の premature NOT_EQUIV を減らす。
- それでも構造差が本当に outcome に効く場合は、NOT_EQUIV の counterexample を強化する。
- ANALYSIS を全量要求するのではなく、早期結論に必要な最短 witness へ置換するため、認知負荷の増加を抑えつつ判定根拠を改善できる。
- SKILL.md の既存コアである per-test outcome、trace、counterexample obligation と整合する。

## 11. 最小修正指示

1. Payment の削除対象を、グローバルな “Complete every section...” 全体ではなく、STRUCTURAL TRIAGE の直接ジャンプ文に限定する。
   - 目的: 研究コアの anti-skip mechanism を弱めず、支払いを局所化する。

2. Trigger line の “relevant PASS/FAIL outcome” に、可能なら “assert/check boundary” への接続を 1 語句だけ足す。
   - 例: “relevant PASS/FAIL outcome or assertion/check boundary”。
   - 目的: STRUCTURAL TRIAGE が「ファイル差だけの NOT_EQUIV」に退化しないことをさらに明確化する。

3. “shortest trace” は全探索の固定経路ではなく、structural shortcut を使う場合の最小 witness であると書きぶりを維持する。
   - 目的: failed-approaches 原則5の「単一追跡経路の既定化」への接近を避ける。

## 結論

承認: YES

理由: 提案は汎化性違反がなく、failed-approaches.md の本質的再演にも当たらない。Decision-point delta と Trigger line が具体で、STRUCTURAL TRIAGE の早期 NOT_EQUIV 分岐に対して、実行時に ANSWER / CONFIDENCE / ANALYSIS の観測可能な差を生む。上記の最小修正、特に Payment の局所化と impact witness 表現の明確化を入れれば、監査 PASS の下限を満たしたまま compare の実効改善に結びつく可能性がある。