---

## LOCALIZATION:
FILE: django/db/models/fields/__init__.py
FUNCTION: Field.contribute_to_class

**Specific Location**: Lines 766-768 in the `contribute_to_class` method of the `Field` class

The fix needs to add a `hasattr` check before unconditionally setting the `get_FIELD_display` method, allowing user-defined overrides to be preserved instead of being overwritten by Django's auto-generated version.
