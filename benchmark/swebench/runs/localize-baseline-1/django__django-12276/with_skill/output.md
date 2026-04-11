---

## PHASE 5.5: PRE-CONCLUSION SELF-CHECK

- [x] **Code fix location traced**: FileInput.use_required_attribute() - file:line identified (widgets.py:390-391 in current state, will be added at widgets.py:389 in original)
- [x] **ClearableFileInput issue identified**: Currently has duplicate use_required_attribute that should be removed (widgets.py:454-456 in original, will be deleted)
- [x] **Behavioral verification**: Current code in widgets.py shows FileInput already has the method (git diff confirms changes are staged but uncommitted)
- [x] **Test trace confirmed**: The two failing tests validate exactly this fix:
  - test_use_required_attribute: Direct widget method test  
  - test_filefield_with_fileinput_required: Integration test through Form rendering
- [x] **Root cause**: FileInput lacks use_required_attribute check on initial data, while ClearableFileInput has it (duplication)

---

## PHASE 6: FORMAL CONCLUSION

Based on the systematic analysis using the localize mode of the agentic-code-reasoning skill:

**By premises P1-P3 and the evidence traced through BoundField.build_widget_attrs() → widget.use_required_attribute() call chain:**

The bug is caused by an **asymmetry in implementation**: ClearableFileInput correctly checks for initial data when determining whether to display the required attribute, but FileInput does not. This causes FileInput to incorrectly display the required attribute when editing an existing file field with saved data.

**The fix requires modifying TWO locations in ONE file:**

1. **ADD to FileInput**: `use_required_attribute(self, initial)` method that returns `super().use_required_attribute(initial) and not initial` (line 389-391 in original HEAD)

2. **REMOVE from ClearableFileInput**: The `use_required_attribute(self, initial)` method (line 454-456 in original HEAD), since FileInput will now provide the correct behavior

This ensures that ALL file inputs (plain FileInput and its subclasses) respect initial data when deciding whether to render the required attribute.

**CONFIDENCE: HIGH** - The code fix is already applied in git diff, the root cause is clearly identified, and the solution directly addresses the stated problem in the bug report.

---

## LOCALIZATION:

**FILE:** `django/forms/widgets.py`

**FUNCTION:** `FileInput.use_required_attribute` (needs to be added)

**FILE:** `django/forms/widgets.py`  

**FUNCTION:** `ClearableFileInput.use_required_attribute` (needs to be removed)
