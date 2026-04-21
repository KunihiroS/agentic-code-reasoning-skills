The behavior comes from a few concrete UI paths in the calendar settings tree where permission state is either hardcoded, never passed down, or only partially applied.

## 1) The settings page never derives `canEdit/canShare` from calendar permissions
`VisualCalendar` carries a `Permissions` field, and there is a helper to interpret it:

- `packages/shared/lib/interfaces/calendar/Calendar.ts:25-33` — `VisualCalendar` includes `Permissions: number`
- `packages/shared/lib/calendar/permissions.ts:6-14` — `getCanWrite(permissions)` exists

But in the settings page subtree, those permission checks are not used to gate the editing UI.

### Root render path
- `packages/components/containers/calendar/settings/CalendarSubpage.tsx:167-186`

This is where the page renders:
- `CalendarSubpageHeaderSection`
- `CalendarEventDefaultsSection`
- `CalendarShareSection`

And it passes:

- `canEdit={true}` to `CalendarSubpageHeaderSection` at `:167-174`
- `canEdit={true}` to `CalendarEventDefaultsSection` at `:174`

So the parent is **not** deriving editability from `calendar.Permissions`; it hardcodes the edit flag to `true`.

---

## 2) The header edit button is only disabled if `canEdit` is false — but the parent always passes `true`
- `packages/components/containers/calendar/settings/CalendarSubpageHeaderSection.tsx:32-35`
- `packages/components/containers/calendar/settings/CalendarSubpageHeaderSection.tsx:135`

The edit button is rendered as:

```tsx
<ButtonLike shape="outline" onClick={handleEdit} icon disabled={!canEdit}>
```

That would work **if** `canEdit` were computed from permissions. But because `CalendarSubpage.tsx` passes `canEdit={true}`, this button stays enabled.

---

## 3) Event-default controls are permission-gated only by `canEdit`, but `canEdit` is always true
- `packages/components/containers/calendar/settings/CalendarEventDefaultsSection.tsx:39-64`
- `packages/components/containers/calendar/settings/CalendarEventDefaultsSection.tsx:168-217`

This component does have a permission gate:

```tsx
const cannotEdit = !canEdit;
```

and it disables:
- event duration selector: `disabled={loadingDuration || cannotEdit}` at `:168-181`
- notifications widget: `disabled={... || cannotEdit}` at `:194-201` and `:223-230`
- save buttons: `disabled={!hasTouched... || cannotEdit}` at `:213-218` and later in the file

But because `CalendarSubpage.tsx` hardcodes `canEdit={true}`, those disabled branches never activate.

### Important detail
The “Show others when I'm busy” toggle is **not disabled at all**:
- `packages/components/containers/calendar/settings/CalendarEventDefaultsSection.tsx:143-156`

`Toggle` has no `disabled` prop there, so that control is always interactive regardless of `canEdit`.

---

## 4) Sharing controls are not permission-gated
### Internal sharing section
- `packages/components/containers/calendar/settings/CalendarShareSection.tsx:56-165`

This component:
- has **no** `canEdit` or `canShare` prop in its interface (`:56-66`)
- renders the share button with only these guards:

```tsx
disabled={isLoading || isMaximumMembersReached}
```

at `:146-154`

So there is no access-control check here beyond loading/max-members.

It then opens:

- `ShareCalendarModal` at `:122-130`

### New-share modal
- `packages/components/containers/calendar/shareProton/ShareCalendarModal.tsx:275-297`
- `packages/components/containers/calendar/shareProton/ShareCalendarModal.tsx:412-465`
- `packages/components/containers/calendar/shareProton/ShareCalendarModal.tsx:617-660`

This modal:
- defaults the share permission to `MEMBER_PERMISSIONS.FULL_VIEW` (`:275`)
- lets the user pick View/Edit via `RadioGroup` (`:617-642`)
- sends the chosen permission in the API payload:

```tsx
Permissions: permissions
```

at `:447-465`

There is no `canShare` check anywhere in this path.

### Public link sharing
- `packages/components/containers/calendar/shareURL/CalendarShareUrlSection.tsx:169-183`
- `packages/components/containers/calendar/shareURL/CalendarShareUrlSection.tsx:187-197`

The “Create link” button is only blocked by `maxLinksReached`:
```tsx
{!maxLinksReached && (
    <Button onClick={() => updateModal('shareLinkModal', { isOpen: true })}>
```

No permission restriction is applied here either.

---

## 5) Member permission editing is fully reachable and unguarded
### List component
- `packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx:19-24`
- `packages/components/containers/calendar/settings/CalendarMemberAndInvitationList.tsx:87-136`

This component:
- does **not** accept a permission prop
- passes `onPermissionsUpdate` down to each row
- updates permissions directly via API:

```tsx
updateMemberPermission(calendarID, ID, { Permissions: newPermissions })
updateInvitation(calendarID, CalendarInvitationID, { Permissions: newPermissions })
```

### Row component
- `packages/components/containers/calendar/settings/CalendarMemberRow.tsx:56-99`
- `packages/components/containers/calendar/settings/CalendarMemberRow.tsx:121-153`

The permission dropdown is rendered as:

```tsx
<SelectTwo loading={isLoadingPermissionsUpdate} value={perms} onChange={handleChangePermissions}>
```

There is **no** `disabled` prop here, and `handleChangePermissions` immediately calls the callback that performs the API update.

### Member removal stays enabled
The delete buttons in the same row are always enabled:
- `packages/components/containers/calendar/settings/CalendarMemberRow.tsx:129-153`

So the current behavior matches “member removal remains enabled,” but it also leaves permission escalation enabled.

---

## Bottom line
The responsible code path is:

`CalendarSubpage.tsx`
→ `CalendarSubpageHeaderSection` / `CalendarEventDefaultsSection` / `CalendarShareSection`
→ `CalendarMemberAndInvitationList`
→ `CalendarMemberRow`
→ `updateMemberPermission` / `updateInvitation` or `ShareCalendarModal` / `addMember`

And the specific logic problem is:

1. `canEdit` is hardcoded to `true` in `CalendarSubpage.tsx`
2. `CalendarShareSection` has no `canShare`/permission prop at all
3. `CalendarMemberAndInvitationList` and `CalendarMemberRow` never consult `calendar.Permissions`
4. share creation and permission changes are sent directly to the API without client-side access checks

If you want, I can also map this to the exact controls mentioned in the bug report one by one:
- permission dropdowns
- duration selector
- notification settings
- busy-sharing toggle
- share button / create-link button
