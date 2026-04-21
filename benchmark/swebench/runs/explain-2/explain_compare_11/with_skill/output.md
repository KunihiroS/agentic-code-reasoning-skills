HYPOTHESIS H9: The server’s router-mount helper routes `/rest/...` to the Subsonic handler, so the request path is fully accounted for before Subsonic dispatch.
EVIDENCE: `cmd/root.go` calls `MountRouter("Subsonic API", consts.URLPathSubsonicAPI, CreateSubsonicAPIRouter())`.
CONFIDENCE: high

NEXT ACTION RATIONALE: We already have enough for the path mount; no additional file is needed unless the mount helper itself changes the routing semantics. Search is enough.
Selected mode: **explain**

QUESTION: Why Subsonic share endpoints are missing, and what code path leads to the behavior?

DEFINITIONS:
- The relevant request path is the Subsonic API mounted at `/rest` (`consts.URLPathSubsonicAPI = "/rest"`).
- A share request such as `GET /rest/getShares` should reach the Subsonic router and either be handled by a controller or fail via the router’s fallback.

PREMISES:
P1: The Subsonic API is mounted under `/rest` in the server startup path.  
P2: The Subsonic router is built by `CreateSubsonicAPIRouter()` and `subsonic.New(...)`.  
P3: The Subsonic router’s `routes()` function explicitly registers `getShares`, `createShare`, `updateShare`, and `deleteShare` via `h501`, not via a controller.  
P4: `h501` returns HTTP 510 and a “not implemented” body without invoking any share backend logic.  
P5: Share persistence exists in the backend (`model.Share`, `model.DataStore.Share`, `core.Share`, `persistence/share_repository.go`), but that backend is not wired into the Subsonic router.  
P6: The Subsonic response schema has no `Shares` field, so there is no response model for a share list in the current API payload type.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `startServer` | `cmd/root.go:74-79` | `() (func() error, func(err error))` | server startup closures | Mounts the Subsonic API router under `/rest` via `MountRouter("Subsonic API", consts.URLPathSubsonicAPI, CreateSubsonicAPIRouter())`. |
| `CreateSubsonicAPIRouter` | `cmd/wire_gen.go:43-58` | `() *subsonic.Router` | `*subsonic.Router` | Constructs datastore and other services, then calls `subsonic.New(...)`; no share dependency is passed. |
| `subsonic.New` | `server/subsonic/api.go:40-54` | `(model.DataStore, core.Artwork, core.MediaStreamer, core.Archiver, core.Players, core.ExternalMetadata, scanner.Scanner, events.Broker, scrobbler.PlayTracker) *Router` | `*Router` | Stores dependencies and assigns `r.Handler = r.routes()`. |
| `(*Router).routes` | `server/subsonic/api.go:57-172` | `(*Router) http.Handler` | `http.Handler` | Registers implemented endpoints with `h(...)`; registers share methods (`getShares`, `createShare`, `updateShare`, `deleteShare`) with `h501(...)`. |
| `h501` | `server/subsonic/api.go:201-210` | `(chi.Mux, ...string)` | void | For each path, installs a handler for `/<path>` and `/<path>.view` that returns HTTP 510 and the text “This endpoint is not implemented, but may be in future releases”. |
| `SQLStore.Share` | `persistence/persistence.go:59-61` | `(context.Context) model.ShareRepository` | `model.ShareRepository` | Returns `NewShareRepository(...)`; backend share storage is available in the datastore layer. |
| `NewShareRepository` | `persistence/share_repository.go:12-19` | `(context.Context, orm.Ormer) model.ShareRepository` | `model.ShareRepository` | Builds the `share` table repository. |
| `(*shareService).NewRepository` | `core/share.go:25-32` | `(context.Context) rest.Repository` | `rest.Repository` | Wraps the datastore share repository for REST-style persistence. |
| `(*shareRepositoryWrapper).Save` | `core/share.go:41-49` | `(interface{}) (string, error)` | `(string, error)` | Generates a random 9-character ID, stores it in `Name`, then delegates to persistence `Save`. |

DATA FLOW ANALYSIS:
Variable: `api` / `router`
- Created at: `cmd/wire_gen.go:43-58` (`CreateSubsonicAPIRouter`) and `server/subsonic/api.go:40-54` (`subsonic.New`)
- Modified at: `server/subsonic/api.go:53` (`r.Handler = r.routes()`)
- Used at: `server/subsonic/api.go:57-172` to register routes, including the share endpoints mapped to `h501`

Variable: `paths`
- Created at: `server/subsonic/api.go:201` as the variadic parameter to `h501`
- Modified at: NEVER modified
- Used at: `server/subsonic/api.go:202-209` to install handlers for `getShares`, `createShare`, `updateShare`, `deleteShare`

SEMANTIC PROPERTIES:
Property 1: Share storage exists, but it is backend-only.
- Evidence: `model.DataStore.Share` exists at `model/datastore.go:22-33`; `SQLStore.Share` returns `NewShareRepository` at `persistence/persistence.go:59-61`; `core.Share` wraps that repository at `core/share.go:11-32`.

Property 2: The Subsonic share endpoints are explicitly marked unimplemented.
- Evidence: `server/subsonic/api.go:157-166` registers `getShares`, `createShare`, `updateShare`, and `deleteShare` with `h501`, not with any controller.

Property 3: The Subsonic API response type does not currently have a share-list field.
- Evidence: `server/subsonic/responses/responses.go:8-49` lists the fields on `responses.Subsonic`; there is no `Shares` field there.

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, evidence would exist for a real Subsonic share controller and normal route registration.
- Searched for: `GetShares`, `CreateShare`, `UpdateShare`, `DeleteShare`, `ShareController`, `New.*Share.*Controller` in `repo_nav/server/subsonic`
- Found: no matches
- Also found: route registration explicitly uses `h501(r, "getShares", "createShare", "updateShare", "deleteShare")` at `server/subsonic/api.go:161`
- Conclusion: REFUTED — there is no implemented Subsonic share endpoint path in the current codebase.

FINAL ANSWER:
The bug occurs because the Subsonic API router deliberately routes all share-related method names to the generic “not implemented” handler instead of to a share controller.

Concrete path:
1. The server mounts the Subsonic API under `/rest` (`cmd/root.go:76-79`, `consts/consts.go:32-34`).
2. The router is built by `CreateSubsonicAPIRouter()` and `subsonic.New(...)` (`cmd/wire_gen.go:43-58`, `server/subsonic/api.go:40-54`).
3. In `(*Router).routes()`, the share methods are registered here:
   - `getShares`
   - `createShare`
   - `updateShare`
   - `deleteShare`
   and all four are sent to `h501` (`server/subsonic/api.go:157-166`).
4. `h501` installs handlers that return HTTP 510 with “This endpoint is not implemented...” and never call any share backend (`server/subsonic/api.go:201-210`).

So a request like `GET /rest/getShares?...` reaches the Subsonic router and is immediately answered by the `h501` fallback, which is why clients cannot create or retrieve shares through the Subsonic API.

The codebase does contain share storage primitives (`model.Share`, `model.DataStore.Share`, `core.Share`, `persistence/share_repository.go`), but those are not wired into the Subsonic router. The API layer has no `GetShares`/`CreateShare` controller, no share dependency in `subsonic.Router`, and no `responses.Subsonic.Shares` field for serializing share lists.

CONFIDENCE: **HIGH**
