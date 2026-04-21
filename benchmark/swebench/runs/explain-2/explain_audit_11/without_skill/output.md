The bug happens because the v3 write-API route returns the raw user record without running the privacy-filtering logic that other user-profile code paths use.

### Code path that leads to the leak

1. **The endpoint is wired to `src/controllers/write/users.js#get`**
   - `/api/v3/users` is mounted in `src/routes/write/index.js:24-30`.
   - The specific route is `GET /:uid` in `src/routes/write/users.js:15-23`.
   - Its only checks are:
     - `middleware.ensureLoggedIn` for authentication
     - `middleware.assert.user` to verify the target uid exists
   - `middleware.assert.user` only checks existence, not permissions (`src/middleware/assert.js:22-28`).

2. **The controller returns user data directly**
   - `Users.get` is just:
     ```js
     helpers.formatApiResponse(200, res, await user.getUserData(req.params.uid));
     ```
     in `src/controllers/write/users.js:46-48`.
   - There is **no caller-vs-target user check**, no admin/global-mod check, and no filtering by privacy settings here.

3. **`user.getUserData()` fetches the full whitelisted object**
   - `User.getUserData` calls `User.getUsersData([uid])` (`src/user/data.js:135-141`).
   - `User.getUsersData` calls `User.getUsersFields(uids, [])` with an **empty field list** (`src/user/data.js:140-141`).
   - In `getUsersFields`, an empty `fields` array means “use the whole whitelist”:
     ```js
     if (!fields.length) {
         fields = results.whitelist;
     }
     ```
     (`src/user/data.js:59-65`)

4. **That whitelist explicitly includes private fields**
   - The whitelist contains `email` and `fullname` (`src/user/data.js:22-29`).
   - So the raw model fetch is designed to include those fields unless a higher-level controller strips them later.

### Why privacy settings are ignored

The endpoint never consults user settings or caller privileges before returning the object.

By contrast, the privacy-aware profile code does this filtering:

- `src/controllers/accounts/helpers.js:25-54`
  - loads `userSettings`
  - blanks `email` and `fullname` unless the caller is admin/global mod/self and the target user’s settings allow it
- `src/controllers/user.js:56-76`
  - checks `privileges.global.can('view:users', callerUid)`
  - fetches `user.getUserData(uid)` and `user.getSettings(uid)`
  - then clears `email` / `fullname` based on `settings.showemail`, `settings.showfullname`, and `meta.config.hideEmail/hideFullname`

That filtering path is **not used** by `/api/v3/users/:uid`.

### Bottom line

`/api/v3/users/:uid` exposes private fields because:

- it only enforces “logged in” + “target user exists”
- it calls `user.getUserData(uid)` directly
- `getUserData()` returns the full whitelist, which includes `email` and `fullname`
- no controller-level privacy filtering or privilege check is applied afterward

So any authenticated user can request another uid and receive those fields unredacted.
