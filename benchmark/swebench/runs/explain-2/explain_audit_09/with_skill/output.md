QUESTION: What specific code paths and logic are responsible for calendar settings controls staying enabled under restricted permissions?

PREMISES:
P1: The issue is in the calendar settings UI, not a backend execution problem.
P2: `CalendarSubpage` is the composition point for the single-calendar settings screen.
P3: Calendar write capability exists separately from “is a member”: `getCanWrite` checks the WRITE bit, while `getIsMember` checks only AVAILABILITY.
P4: I must support the answer with file:line evidence only.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|-----------------|-----------|-----------------|-------------|---------------------|
| `getIsMember` | `packages/shared/lib/calendar/permissions.ts:17-18` | `(permissions: CALENDAR_PERMISSIONS)` | `boolean` | Returns true when the AVAILABILITY bit is set; it does not check write/share capability. |
| `CalendarSubpage` | `packages/components/containers/calendar/settings/CalendarSubpage.tsx:149-187` | `({ calendars, subscribedCalendars, defaultCalendar, addresses, user }: Props)` | `JSX.Element \| null` | Renders the settings sections and computes `isEditDisabled` from `user.hasNonDelinquentScope` and `getIsMember(calendar.Permissions)`. |
| `CalendarSubpageHeaderSection` | `packages/components/containers/calendar/settings/CalendarSubpageHeaderSection.tsx:27-107` | `({ calendar, defaultCalendar, onEdit, isEditDisabled }: Props)` | `JSX.Element` | Renders the edit button for calendar metadata and disables only that button with `isEditDisabled`. |
| `CalendarEventDefaultsSection` | `packages/components/containers/calendar/settings/CalendarEventDefaultsSection.tsx:42-228` | `({ calendar, bootstrap, isEditDisabled }: Props)` | `JSX.Element \| null` | Shows event duration and notification controls for owned calendars and disables them when `isEditDisabled` is true. |
| `CalendarShareSection` | `packages/components/containers/calendar/settings/CalendarShareSection.tsx:63-159` | `({ calendar, addresses, isLoading, invitations, members, setInvitations, setMembers, user }: Props)` | `JSX.Element` | Renders share controls for paid users; the Share button is disabled only by loading/member limit, not by edit/share permission bits. |
| `CalendarMemberAndInvitationList` | `packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx:26-149` | `({ members, invitations, calendarID, onDeleteMember, onDeleteInvitation }: Props)` | `JSX.Element \| null` | Always wires permission changes to `updateMember`/`updateInvitation`; no permission-based disable logic is present. |
| `CalendarMemberRow` | `packages/components/containers/calendar/settings/CalendarMemberRow.tsx:64-154` | `({ email, name, deleteLabel, permissions, status, displayPermissions, displayStatus, onPermissionsUpdate, onDelete }: Props)` | `JSX.Element` | Renders permission dropdowns and delete button; dropdowns are not disabled, and delete remains enabled. |
| `CalendarShareUrlSection` | `packages/components/containers/calendar/shareURL/CalendarShareUrlSection.tsx:154-166` | `({ calendar, user, noTitle }: Props)` | `JSX.Element` | Renders “Create link” and disables it only when the calendar hit the max-link count. |
| `ShareCalendarModal` | `packages/components/containers/calendar/shareModal/ShareCalendarModal.tsx:423-466` | `({ calendar, addresses, onFinish, members, invitations, ...rest }: Props)` | `JSX.Element` | Allows creating private shares; the “Edit” permission option is hard-disabled, but the modal still permits new share creation. |

DATA FLOW ANALYSIS:
Variable: `isEditDisabled`
- Created at: `packages/components/containers/calendar/settings/CalendarSubpage.tsx:156-166`
- Modified at: NEVER
- Used at:
  - `packages/components/containers/calendar/settings/CalendarSubpageHeaderSection.tsx:103`
  - `packages/components/containers/calendar/settings/CalendarEventDefaultsSection.tsx:128,163,179,202,218`
- Meaning: it gates only the header edit button and event-default controls, not sharing/member-permission controls.

Variable: `permissions` in the share/member flows
- Created at:
  - `packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx:81-140` (per-row prop passed from API data)
  - `packages/components/containers/calendar/shareModal/ShareCalendarModal.tsx:24-26, 425-450` (local state defaulting to `FULL_VIEW`)
- Modified at:
  - `CalendarMemberRow.tsx:81-84` via dropdown changes
  - `ShareCalendarModal.tsx:449-450` via radio-group selection
- Used at:
  - `CalendarMemberAndInvitationList.tsx:93-95,125-131` to call `updateMember` / `updateInvitation`
  - `ShareCalendarModal.tsx:461-466` to create new shares
- Meaning: permission values are directly actionable; the UI does not guard them with a permission-restriction predicate.

SEMANTIC PROPERTIES:
Property 1: `getIsMember` is not a write/share check.
- Evidence: `packages/shared/lib/calendar/permissions.ts:13-18`
- Consequence: using `!isMember` as an edit gate only blocks non-members, not read-only members.

Property 2: The settings page only applies restriction state to some sections.
- Evidence: `CalendarSubpage.tsx:156-166`
- Consequence: the header and event-default section get `isEditDisabled`, but the share section does not.

Property 3: Share/member editing paths lack a permission-restriction gate.
- Evidence:
  - `CalendarShareSection.tsx:124-141` share button and member list
  - `CalendarMemberAndInvitationList.tsx:89-140` direct API update calls
  - `CalendarMemberRow.tsx:109-149` enabled dropdowns and delete button
  - `CalendarShareUrlSection.tsx:154-166` create-link button
- Consequence: users can still modify member permissions or create new shares if they can reach these components.

ALTERNATIVE HYPOTHESIS CHECK:
If the opposite answer were true, I would expect to find a `getCanWrite`/`canShare`-style gate wrapping the share button, member permission dropdowns, and link creation.
- Searched for: permission-gating logic in the traced settings/share path, especially `getCanWrite`, `canShare`, and `disabled` props on the relevant controls.
- Found:
  - `getCanWrite` exists only as a utility in `packages/shared/lib/calendar/permissions.ts:13-14`
  - the settings page instead uses `hasNonDelinquentScope` and `getIsMember` in `CalendarSubpage.tsx:156-166`
  - share controls are gated only by plan/limits in `CalendarShareSection.tsx:124-141` and `CalendarShareUrlSection.tsx:160-166`
- Conclusion: the opposite answer is REFUTED.

FINAL ANSWER:
The behavior comes from a split between the settings page’s restriction state and the sections that actually perform sharing/permission edits.

1. The restriction flag is computed in `CalendarSubpage.tsx:156-166`, but it is based on `user.hasNonDelinquentScope` and `getIsMember(calendar.Permissions)`, where `getIsMember` only checks the AVAILABILITY bit (`permissions.ts:17-18`). That means it does not represent “can edit/can share” capability.

2. That `isEditDisabled` flag is only passed to:
   - the header edit button in `CalendarSubpageHeaderSection.tsx:101-104`, and
   - the event defaults controls in `CalendarEventDefaultsSection.tsx:127-179, 195-219`.
   So event-default controls are protected only by that coarse flag, not by a write/share permission check.

3. The share path does not receive the restriction flag at all:
   - `CalendarShareSection.tsx:113-141` renders the Share button and member list with no permission-based disable condition.
   - `CalendarMemberAndInvitationList.tsx:89-140` directly calls `updateMember` / `updateInvitation` when a permission dropdown changes.
   - `CalendarMemberRow.tsx:109-149` renders the permission `SelectTwo` with no `disabled` prop, while the delete button remains enabled, which matches the “member removal should stay enabled” requirement but also leaves permission escalation enabled.
   - `CalendarShareUrlSection.tsx:154-166` renders “Create link” and disables it only at the max-link limit, not based on share permissions.

4. `ShareCalendarModal.tsx:423-466` still allows creating new private shares; it only hard-disables the “Edit” choice inside the radio group, but it does not block opening the modal or submitting a new share.

So the specific code path responsible is:
`CalendarSubpage` → `CalendarShareSection` → `CalendarMemberAndInvitationList` → `CalendarMemberRow` for member permission changes, and
`CalendarSubpage` → `CalendarShareSection` → `CalendarShareUrlSection` for public link creation.

The root logic issue is that the page uses the wrong predicate (`hasNonDelinquentScope` / `getIsMember`) and fails to propagate any `canEdit/canShare` restriction into the sharing components.

CONFIDENCE: HIGH
