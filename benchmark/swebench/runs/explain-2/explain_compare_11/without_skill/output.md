The bug occurs because the Subsonic router explicitly does **not** implement the share endpoints; it registers them as permanent 501 stubs.

### Code path

1. **All Subsonic requests are routed through `server/subsonic/api.go`.**  
   In `routes()`, the share-related Subsonic methods are placed under the “Not Implemented” section:
   - `getShares`
   - `createShare`
   - `updateShare`
   - `deleteShare`  
   See `server/subsonic/api.go:165-168`.

2. **Those paths are bound to `h501`, not to real handler functions.**  
   `h501` installs a handler that always writes HTTP **501 Not Implemented** and a fixed message:
   - `server/subsonic/api.go:216-224`

3. **The registered handler applies to both `/method` and `/method.view`.**  
   `addHandler()` attaches the same handler to both route variants:
   - `server/subsonic/api.go:239-242`  
   So Subsonic clients calling either `getShares.view` or `createShare.view` still hit the 501 stub.

### Resulting behavior

Because of that routing, a Subsonic client request never reaches any share business logic or database code. It is short-circuited at the router and returns 501 immediately.

### Why share functionality exists elsewhere but not here

The repository does have share support, but it is wired into **other** APIs:

- The share service and repository logic exist in `core/share.go:17-19`, `core/share.go:32-68`, and `core/share.go:86-143`.
- The native REST API exposes `/share` via `server/nativeapi/native_api.go:36-49`.
- Public share pages load shares via `server/public/handle_shares.go:13-42`.

So the issue is not that share storage is missing; it’s that the **Subsonic API never hooks up share CRUD/listing at all**.

### Bottom line

Subsonic share endpoints are missing because the Subsonic router intentionally routes them to `h501`, which always returns 501. That is why clients cannot create or retrieve shares through the Subsonic API.
