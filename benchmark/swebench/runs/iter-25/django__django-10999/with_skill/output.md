## FORMAL CERTIFICATE ANALYSIS (Compare Mode)

### DEFINITIONS:

**D1**: Two patches are **EQUIVALENT MODULO TESTS** if executing the fail-to-pass tests with both patches produces identical pass/fail outcomes.

**D2**: The relevant tests are those listed in FAIL_TO_PASS:
- `test_negative` (lines 112-122): Tests cases like '-15:30', '-1:15:30', '-4 15:30', etc.
- `test_parse_postgresql_format` (lines 68-81): Tests PostgreSQL interval format like '1 day -0:00:01'

### PREMISES:

**P1**: Patch A modifies `standard_duration_re` to:
- Add a new `(?P<sign>-?)` group after the days part
- Remove `-?` from hours, minutes, seconds patterns (making them `\d+` only)
- Keep lookahead as `(?=\d+:\d+)`
- Does NOT modify `parse_duration()` function

**P2**: Patch B modifies `standard_duration_re` to:
- ONLY change lookahead from `(?=\d+:\d+)` to `(?=-?\d+:-?\d+)`
- Keep `-?\d+` for hours, minutes, seconds
- ALSO significantly rewrites `parse_duration()` with complex sign/seconds conversion logic

**P3**: The original `parse_duration()` function (line 140) contains: `sign = -1 if kw.pop('sign', '+') == '-' else 1`
- It expects an optional 'sign' key in the regex match groups
- iso8601_duration_re provides this; standard_duration_re does NOT (in original)

**P4**: Test case semantics:
- `('-1:15:30', timedelta(hours=-1, minutes=15, seconds=30))` expects:
  - The minus sign to apply ONLY to hours (-1), not to minutes/seconds (+15, +30)  
  - Total seconds: -3600 + 900 + 30 = -2670 seconds

### ANALYSIS OF TEST BEHAVIOR:

**Test: test_negative with input '-1:15:30'**

**Patch A execution:**

1. Regex matching:
   - `sign` group at position 0: matches "-" → sign captured as "-"
   - Position now at "1:15:30"  
   - `hours` pattern `\d+:`: matches "1:" → hours="1"
   - Lookahead at "15:30": matches `\d+:\d+` ✓
   - `minutes` pattern `\d+:`: matches "15:" → minutes="15"
   - `seconds` pattern `\d+`: matches "30" → seconds="30"

2. parse_duration() logic:
   - `kw.groupdict()` → `{'sign': '-', 'hours': '1', 'minutes': '15', 'seconds': '30'}`
   - `sign = -1 if kw.pop('sign', '+') == '-' else 1` → sign = **-1**
   - `kw = {'hours': 1.0, 'minutes': 15.0, 'seconds': 30.0}`
   - `return days + sign * timedelta(**kw)`
   - = `timedelta(0) + (-1) * timedelta(hours=1, minutes=15, seconds=30)`
   - = `-timedelta(hours=1, minutes=15, seconds=30)`
   - = `timedelta(seconds=-(3600+900+30))` = `timedelta(seconds=-4530)`

3. Expected: `timedelta(hours=-1, minutes=15, seconds=30)` = `timedelta(seconds=-2670)`

**Claim C1.1**: Patch A produces `timedelta(seconds=-4530)` for input '-1:15:30'
**Claim C1.2**: Test expects `timedelta(seconds=-2670)` for the same input
**Comparison**: DIFFERENT outcomes → **TEST FAILS with Patch A**

---

**Patch B execution:**

1. Regex matching (only lookahead changes):
   - No sign group at beginning
   - At position 0: `hours` pattern `-?\d+:` matches "-1:" → hours="-1"
   - Lookahead at "15:30": matches `-?\d+:-?\d+` ✓  
   - `minutes` pattern `-?\d+:` matches "15:" → minutes="15"
   - `seconds` pattern `-?\d+`: matches "30" → seconds="30"

2. parse_duration() with Patch B's new logic:
   - `kw.groupdict()` → `{'hours': '-1', 'minutes': '15', 'seconds': '30'}`
   - `sign = -1 if kw.pop('sign', '+') == '-' else 1` → sign = **1** (no 'sign' key)
   - Extract time_parts: `{'hours': -1.0, 'minutes': 15.0, 'seconds': 30.0, 'microseconds': 0.0}`
   - Convert to total seconds: `-1*3600 + 15*60 + 30 + 0 = -3600 + 900 + 30 = -2670`
   - Since `days == 0`: `total_seconds = time_seconds * sign = -2670 * 1 = -2670`
   - `return timedelta(seconds=-2670)`

3. Expected: `timedelta(seconds=-2670)`

**Claim C2.1**: Patch B produces `timedelta(seconds=-2670)` for input '-1:15:30'
**Claim C2.2**: Test expects `timedelta(seconds=-2670)`
**Comparison**: SAME outcome → **TEST PASSES with Patch B**

---

**Test: test_negative with input '-15:30' (minutes only)**

**Patch A:**
- sign="-", hours fails (at position 1, "1:" doesn't have lookahead match for "5:30"), minutes="15", seconds="30"
- `sign=-1`; `kw={'minutes': 15.0, 'seconds': 30.0}`
- Returns: `-timedelta(minutes=15, seconds=30)` = `timedelta(seconds=-930)`
- Expected: `timedelta(minutes=-15, seconds=30)` = `timedelta(seconds=-870)`
- **FAIL**

**Patch B:**
- hours="-1" fails lookahead; minutes="-15", seconds="30"
- `sign=1`; time_seconds = `-15*60 + 30 = -870`
- Returns: `timedelta(seconds=-870)`
- Expected: `timedelta(seconds=-870)`
- **PASS**

---

**Test: test_parse_postgresql_format with input '1 day -0:00:01'**

**Patch A:**
- Regex fails at the space between "day" and minus (no character matches the space)
- Falls through to `postgres_interval_re.match()`
- **Behavior unchanged from original** → Depends on postgres_interval_re handling

**Patch B:**
- Same as Patch A (regex change doesn't affect space handling)
- **Falls through to postgres_interval_re** → Unchanged behavior

### COUNTEREXAMPLE (Required):

**Test '-1:15:30'**:
- With Patch A: produces `timedelta(seconds=-4530)` ✗
- With Patch B: produces `timedelta(seconds=-2670)` ✓

The tests produce **DIFFERENT outcomes** between the two patches.

### FORMAL CONCLUSION:

By Definition D1, the patches are NOT equivalent modulo the failing tests.

**Test outcomes with Patch A**:
- test_negative ('-1:15:30'): **FAIL** (produces wrong timedelta)
- test_negative ('-15:30'): **FAIL** (produces -930 instead of -870 seconds)

**Test outcomes with Patch B**:
- test_negative ('-1:15:30'): **PASS** (correctly produces -2670 seconds)
- test_negative ('-15:30'): **PASS** (correctly produces -870 seconds)

Since test outcomes differ, the patches produce **DIFFERENT results**.

---

**ANSWER: NO (not equivalent)**

**CONFIDENCE: HIGH**

The fundamental difference is that Patch A incorrectly applies the sign to all time components via multiplication in the final return statement, whereas Patch B correctly handles the sign at the component level by summing signed components before creating the timedelta. Patch B's approach preserves the semantic where the minus sign applies to the first component mentioned, not the entire duration.
