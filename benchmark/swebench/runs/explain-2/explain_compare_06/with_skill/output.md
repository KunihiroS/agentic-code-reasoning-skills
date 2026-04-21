Selected mode: explain

QUESTION: What specific code paths and logic are responsible for the `RovingAccessibleTooltipButton` consolidation behavior?

DEFINITIONS:
- The meaningful path is: `useRovingTabIndex` → `RovingAccessibleButton` → `AccessibleButton` → `Tooltip`.
- The historical `RovingAccessibleTooltipButton` wrapper was removed; its job was only to provide roving tabindex around `AccessibleButton`, not tooltip logic.

PREMISES:
P1: `RovingTabIndex.tsx` now re-exports only `RovingAccessibleButton`; the tooltip wrapper export is gone.  
P2: `RovingAccessibleButton` is a thin wrapper that calls `useRovingTabIndex`, forwards focus/mouseover handlers, and sets `tabIndex` from `isActive`.  
P3: `AccessibleButton` is the component that actually creates the `Tooltip` when `title` is present, and `disableTooltip` controls whether that tooltip is enabled.  
P4: In `ExtraTile`, `disableTooltip` is explicitly set to `!isMinimized`, so minimized tiles keep the tooltip while expanded tiles suppress it.  
P5: The historical consolidation commit (`8f3c8b3515`) mechanically replaced `RovingAccessibleTooltipButton` with `RovingAccessibleButton` in the listed callers; the only semantic change in that commit is the `ExtraTile` tooltip toggle.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `useRovingTabIndex` | `apps/web/src/accessibility/RovingTabIndex.tsx:362-403` | `(inputRef?: RefObject<T | null>)` | `[FocusHandler, boolean, RefCallback<T>, RefObject<T | null>]` | Registers/unregisters DOM nodes in the roving-tabindex context, tracks the active node, and returns `onFocus`, `isActive`, and a ref callback. |
| `RovingAccessibleButton` | `apps/web/src/accessibility/roving/RovingAccessibleButton.tsx:20-41` | props extending `ButtonProps<T>` plus `inputRef?`, `focusOnMouseOver?` | `JSX.Element` | Wraps `AccessibleButton`, calls `useRovingTabIndex`, forwards `onFocus`, optionally updates focus on mouseover, and sets `tabIndex={isActive ? 0 : -1}`. |
| `AccessibleButton` | `apps/web/src/components/views/elements/AccessibleButton.tsx:119-223` | `ButtonProps<T>` | `JSX.Element` | Builds the button element, wires keyboard activation, and if `title` exists wraps the element in `Tooltip`; `disableTooltip` is passed through to the tooltip’s `disabled` prop. |
| `ExtraTile` | `apps/web/src/components/views/rooms/ExtraTile.tsx:27-86` | `ExtraTileProps` | `JSX.Element` | Computes `name`, hides the nested name container when minimized, and renders `RovingAccessibleButton` with `title={name}` and `disableTooltip={!isMinimized}`. |
| `FormatButton` | `apps/web/src/components/views/rooms/MessageComposerFormatBar.tsx:133-149` | `IFormatButtonProps` | `React.ReactNode` | Renders `RovingAccessibleButton` with `element="button"`, `title`, and `caption`; no `disableTooltip`, so the tooltip stays enabled whenever `title` exists. |

DATA FLOW ANALYSIS:
Variable: `isMinimized`
- Created at: `apps/web/src/components/views/rooms/ExtraTile.tsx:27-34`
- Modified at: NEVER MODIFIED
- Used at: `apps/web/src/components/views/rooms/ExtraTile.tsx:66`, `:76`
- Effect: controls both whether the inner name container is rendered and whether `disableTooltip` is set.

Variable: `title`
- Created at: caller props in `AccessibleButton` and `ExtraTile`/`FormatButton`
- Modified at: NEVER MODIFIED in the relevant paths
- Used at: `apps/web/src/components/views/elements/AccessibleButton.tsx:209-217`
- Effect: if present, `AccessibleButton` renders a `Tooltip`; this is the central tooltip branch.

Variable: `isActive`
- Created at: `apps/web/src/accessibility/RovingTabIndex.tsx:402-403`
- Modified at: only by context updates from `useRovingTabIndex`
- Used at: `apps/web/src/accessibility/roving/RovingAccessibleButton.tsx:40`
- Effect: decides whether the roving button is tabbable (`tabIndex` 0 vs -1).

SEMANTIC PROPERTIES:
Property 1: The old tooltip wrapper did not implement tooltip behavior itself.
- Evidence: historical file `src/accessibility/roving/RovingAccessibleTooltipButton.tsx:20-37` only forwarded `onFocus`, `ref`, and `tabIndex` to `AccessibleButton`.

Property 2: Tooltip display is centralized in `AccessibleButton`, not in the roving wrapper.
- Evidence: `apps/web/src/components/views/elements/AccessibleButton.tsx:209-217`.

Property 3: The consolidation preserves roving focus semantics.
- Evidence: `apps/web/src/accessibility/roving/RovingAccessibleButton.tsx:27-40` uses the same `useRovingTabIndex` state flow that the deleted wrapper used.

OBSERVATIONS from commit `8f3c8b3515`:
  O1: `RovingTabIndex.tsx` removed the `RovingAccessibleTooltipButton` export.
  O2: `src/accessibility/roving/RovingAccessibleTooltipButton.tsx` was deleted entirely.
  O3: `UserMenu`, `DownloadActionButton`, `MessageActionBar`, `WidgetPip`, `EventTileThreadToolbar`, `ExtraTile`, and `MessageComposerFormatBar` were updated to import/use `RovingAccessibleButton` instead.
  O4: In `ExtraTile`, the old conditional component choice
      `const Button = isMinimized ? RovingAccessibleTooltipButton : RovingAccessibleButton`
      was collapsed into a single `RovingAccessibleButton` with `title={name}` and `disableTooltip={!isMinimized}`.
  O5: In `MessageComposerFormatBar`, the button change is mechanical: the same `title`/`caption` semantics now flow through `RovingAccessibleButton`.

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, evidence should exist for a surviving `RovingAccessibleTooltipButton` code path or a caller still branching between two separate components.
- Searched for: `RovingAccessibleTooltipButton` in `apps/web/src` and `packages`
- Found: no matches in the current tree; historical commit `8f3c8b3515` shows the export removal and file deletion, and the old wrapper body is only a thin `AccessibleButton` passthrough.
- Conclusion: REFUTED

FORMAL CONCLUSION:
By P1 and P2, there is no separate tooltip wrapper left in the current code path: the roving helper is `RovingAccessibleButton`, and it only supplies focus-state behavior.  
By P3, tooltip creation is handled by `AccessibleButton` itself, specifically the `if (title)` branch and the `disableTooltip` prop at `apps/web/src/components/views/elements/AccessibleButton.tsx:209-217`.  
By P4, `ExtraTile` is the only verified caller here that changes tooltip behavior materially: `disableTooltip={!isMinimized}` means minimized tiles still show the title tooltip, while expanded tiles suppress it.  
By P5 and the commit diff, the other updated callers were mechanical swaps from the removed wrapper to `RovingAccessibleButton`, so their behavior is still governed by the same `title`/`caption`/`placement`/`disabled` props.

ANSWER: The responsible code path is `RovingAccessibleButton` → `AccessibleButton` → `Tooltip`, with `ExtraTile`’s `disableTooltip={!isMinimized}` controlling whether the tooltip actually opens. The deleted `RovingAccessibleTooltipButton` was only a thin roving-focus wrapper and did not contain separate tooltip logic.

CONFIDENCE: HIGH
