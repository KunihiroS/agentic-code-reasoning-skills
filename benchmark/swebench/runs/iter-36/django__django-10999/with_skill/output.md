## FORMAL ANALYSIS: PATCH EQUIVALENCE

---

### **DEFINITIONS**

**D1:** Two patches are **EQUIVALENT MODULO TESTS** if executing the relevant test suite produces identical pass/fail outcomes for both.

**D2:** The relevant tests are:
- **Fail-to-pass tests** (must pass after fix):
  - `test_negative` (utils_tests.test_dateparse.DurationParseTests)
  - `test_parse_postgresql_format` (utils_tests.test_dateparse.DurationParseTests)
- **Pass-to-pass tests** (regression checks):
  - Other duration tests in the same file

---

### **PREMISES**

**P1:** Patch A modifies the regex to add `(?P<sign>-?)` group and removes `-?` from hours/minutes/seconds, plus rewrites parse_duration logic with special handling for days/time sign combinations.

**P2:** Patch B modifies only the regex lookahead from `(?=\d+:\d+)` to `(?=-?\d+:-?\d+)`, and copies the same parse_duration logic as Patch A but **removes** the microseconds sign application logic that exists in the original code.

**P3:** The `test_negative` test includes cases where each time component can have independent signs: 
- `-15:30` should parse as (minutes=-15, seconds=30) = -870 seconds
- `-1:15:30` should parse as (hours=-1, minutes=15, seconds=30) = -2670 seconds  
- `-30.1` should parse as (seconds=-30, microseconds=-100000) = -30.1 seconds

**P4:** The test_parse_postgresql_format test uses inputs with spaces before time (e.g., `-4 days -15:00:30`), which neither patch's modified regex will match due to the space, causing both to defer to `postgres_interval_re`.

---

### **ANALYSIS OF TEST BEHAVIOR**

**Test: test_negative case `-15:30` (FAIL_TO_PASS)**

- **Patch A:** 
  - Regex captures: `sign=''` (empty), `minutes=15`, `seconds=30` (converts `-15:` to separate sign + unsigned minutes)
  - Code interprets: sign=1 (empty string ≠ '-'), time_seconds=930
  - Result: `total_seconds = 930 * 1 = 930` → **-930 seconds** ✗
  - Expected: **-870 seconds** ✗

- **Patch B:**
  - Regex captures: `minutes=-15`, `seconds=30` (preserves original structure)
  - Code interprets: sign=1 (no sign group), time_seconds=(-15×60)+30=-870
  - Result: `total_seconds = -870 * 1 = -870` → **-870 seconds** ✓
  - Expected: **-870 seconds** ✓

**Comparison:** DIFFERENT outcomes. Patch B PASSES, Patch A FAILS.

---

**Test: test_negative case `-1:15:30` (FAIL_TO_PASS)**

- **Patch A:**
  - Regex captures: `sign=''`, `hours=1`, `minutes=15`, `seconds=30`  
  - Result: `total_seconds = (3600+900+30) * 1 = 4530` → **-4530 seconds** ✗
  - Expected: **-2670 seconds** ✗

- **Patch B:**
  - Regex captures: `hours=-1`, `minutes=15`, `seconds=30`
  - Result: `time_seconds=(-3600+900+30)=-2670`, `total_seconds=-2670*1` → **-2670 seconds** ✓
  - Expected: **-2670 seconds** ✓

**Comparison:** DIFFERENT outcomes. Patch B PASSES, Patch A FAILS.

---

**Test: test_negative case `-30.1` (FAIL_TO_PASS)**

- **Patch A:**
  - Regex captures: `sign=''`, `seconds=30`, `microseconds=1`
  - Original code had: `if kw['seconds'].startswith('-'): kw['microseconds']='-'+kw['microseconds']`
  - Patch A preserves this logic → microseconds gets `-` prepended
  - Result: `seconds=-30`, `microseconds=-100000` → **-30.1 seconds** ✓
  - Expected: **-30.1 seconds** ✓

- **Patch B:**
  - Regex captures: `seconds=-30`, `microseconds=1`
  - **CRITICALLY:** Patch B removes the microseconds sign application logic
  - Result: `time_seconds = -30 + (1/1e6) = -29.999999`, then normalized → **-29.9 seconds** ✗
  - Expected: **-30.1 seconds** ✗

**Comparison:** DIFFERENT outcomes. Patch A PASSES, Patch B FAILS.

---

**Test: test_parse_postgresql_format (FAIL_TO_PASS)**

Input: `-4 days -15:00:30`

- **Patch A regex:** Does NOT match (space after "days" before "-15")
- **Patch B regex:** Does NOT match (space after "days" before "-15")
- Both defer to `postgres_interval_re`, which correctly handles the PostgreSQL format

**Comparison:** SAME outcome (both pass via postgres_interval_re).

---

### **EDGE CASE ANALYSIS**

- **`-4 15:30`:** Both patches produce identical (but incorrect) results due to shared logic flaw with days/time sign handling. Not a differentiator.
- **`-172800`:** Both pass identically (simple seconds case, no component complexity).

---

### **COUNTEREXAMPLE CHECK** (Required for NOT_EQUIVALENT)

**Counterexample 1:** Test `-15:30`
- **Patch A:** Returns timedelta(seconds=-930) → FAILS `test_negative`
- **Patch B:** Returns timedelta(seconds=-870) → PASSES `test_negative`
- Conclusion: **Different test outcomes confirmed**

**Counterexample 2:** Test `-30.1`
- **Patch A:** Returns timedelta(seconds=-30.1) → PASSES `test_negative`
- **Patch B:** Returns timedelta(seconds=-29.9) → FAILS `test_negative`
- Conclusion: **Different test outcomes confirmed**

---

### **STRUCTURAL DIFFERENCES**

| Aspect | Patch A | Patch B |
|--------|---------|---------|
| Regex approach | Adds separate sign group, removes `-?` from components | Fixes lookahead only, keeps original component structure |
| Semantics | Treats `-15:30` as "negate (15:30)" | Treats `-15:30` as "(negative 15):(positive 30)" |
| Microseconds sign logic | **PRESERVED** from original code | **REMOVED** - introduces bug |
| test_negative pass rate | 2/5 (`-172800`, `-30.1`) | 3/5 (`-172800`, `-15:30`, `-1:15:30`) |
| test_postgresql_format | Passes (via postgres_interval_re) | Passes (via postgres_interval_re) |

---

### **FORMAL CONCLUSION**

By Definition D1, two patches are equivalent modulo tests only if they produce identical pass/fail outcomes across the test suite.

**EVIDENCE:**
- `-15:30`: Patch A FAILS, Patch B PASSES
- `-1:15:30`: Patch A FAILS, Patch B PASSES  
- `-30.1`: Patch A PASSES, Patch B FAILS
- test_parse_postgresql_format: Both PASS (identical outcome)

Since the patches produce **different test outcomes** on `test_negative`, they are **NOT EQUIVALENT**.

**Summary of test outcomes:**
- Patch A: 2/5 on test_negative, 2/2 on test_postgresql_format
- Patch B: 3/5 on test_negative, 2/2 on test_postgresql_format

**ANSWER: NO (not equivalent)**

**CONFIDENCE: HIGH** — The test outputs are concrete and reproducible. The patches diverge on 3 specific test cases within the FAIL_TO_PASS test suite.
