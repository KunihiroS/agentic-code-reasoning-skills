The behavior comes from three layers of code:

1. **Roving focus state and `tabIndex` management**
   - `useRovingTabIndex()` in `src/accessibility/RovingTabIndex.tsx` registers each button, tracks the active ref, and updates focus on mount/unmount and keyboard navigation:
     - register/unregister/set-focus logic: `src/accessibility/RovingTabIndex.tsx:114-166`
     - keyboard traversal + focus movement: `src/accessibility/RovingTabIndex.tsx:211-345`
     - hook that returns `onFocus`, `isActive`, and `ref`: `src/accessibility/RovingTabIndex.tsx:353-387`
   - Both wrapper components consume this hook and set `tabIndex={isActive ? 0 : -1}`:
     - `src/accessibility/roving/RovingAccessibleButton.tsx:23-55`
     - `src/accessibility/roving/RovingAccessibleTooltipButton.tsx:23-45`

2. **Tooltip rendering is actually handled by `AccessibleButton`, not by the tooltip wrapper**
   - `AccessibleButton` takes `title`, `caption`, `placement`, and `disableTooltip`, and only wraps the rendered element in a Compound `<Tooltip>` when `title` is present:
     - props: `src/components/views/elements/AccessibleButton.tsx:93-113`
     - conditional Tooltip render: `src/components/views/elements/AccessibleButton.tsx:218-230`
   - So the “tooltip” behavior is driven by `title`/`disableTooltip` on `AccessibleButton`, not by `RovingAccessibleTooltipButton` itself.

3. **Call sites choose between the two wrappers today**
   - `RovingTabIndex.tsx` re-exports both wrappers, so imports throughout the app use the same central module path:
     - `src/accessibility/RovingTabIndex.tsx:390-393`
   - The current usages are split across several components:
     - `UserMenu`: theme button uses `RovingAccessibleTooltipButton` with a dynamic `title` (`src/components/structures/UserMenu.tsx:429-444`)
     - `DownloadActionButton`: download spinner/action button uses `RovingAccessibleTooltipButton` and a dynamic `title` (`src/components/views/messages/DownloadActionButton.tsx:96-105`)
     - `MessageActionBar`: edit/cancel/retry/reply/expand actions use `RovingAccessibleTooltipButton` (`src/components/views/messages/MessageActionBar.tsx:237-246`, `390-444`)
     - `WidgetPip`: back uses `RovingAccessibleButton`, leave uses `RovingAccessibleTooltipButton` (`src/components/views/pips/WidgetPip.tsx:117-135`)
     - `EventTileThreadToolbar`: both buttons use `RovingAccessibleTooltipButton` (`src/components/views/rooms/EventTile/EventTileThreadToolbar.tsx:35-50`)
     - `ExtraTile`: the component switches wrappers based on `isMinimized`:
       - `const Button = isMinimized ? RovingAccessibleTooltipButton : RovingAccessibleButton;`
       - tooltip title is only set when minimized (`src/components/views/rooms/ExtraTile.tsx:76-84`)
     - `MessageComposerFormatBar`: all format buttons use `RovingAccessibleTooltipButton` (`src/components/views/rooms/MessageComposerFormatBar.tsx:134-142`)

### Key takeaway
There is no separate tooltip-specific behavior living in `RovingAccessibleTooltipButton`. The real logic is:

- **roving focus**: `useRovingTabIndex()`
- **tooltip display**: `AccessibleButton`’s `title` + `disableTooltip`
- **behavior differences**: decided at each call site by choosing one wrapper or the other, or by conditionally passing `title`

That is why consolidating into `RovingAccessibleButton` is mechanically safe: the tooltip machinery already exists in `AccessibleButton`, and the wrapper difference is mostly duplication.
