---

### PHASE 5.5: PRE-CONCLUSION SELF-CHECK

- [x] Both PASS/FAIL claims trace to specific `file:line`:
  - Materialization triggered at `common.py:2026` when accessing `v.data`
  - Secondary materialization at `variable.py:1018` when accessing `self.data`
  - Root-cause mechanism verified: `Variable.data` returns `self.values` for non-duck arrays (variable.py:338–339)

- [x] Function trace table fully VERIFIED with actual source code inspection.

- [x] Alternative-hypothesis check performed: Searched for whether `_data` would have chunks without materialization — found that neither `LazilyIndexedArray` nor `ZarrArrayWrapper` provide a `chunks` attribute, so `hasattr(v._data, "chunks")` returns False correctly *without materialization*.

- [x] Conclusions assert only what traced evidence supports: direct code inspection of materialization paths and property getter logic.

---

### PHASE 6: FORMAL CONCLUSION

**By Premises T1–T4 and Claims D1–D3:**

The root cause of memory materialization when accessing `Dataset.chunks` on zarr-backed datasets is:

1. **Primary:** In `xarray/core/common.py:2026`, the code `hasattr(v.data, "chunks")` accesses the `Variable.data` property instead of directly inspecting `Variable._data`. For zarr-backed variables wrapped in `LazilyIndexedArray`, this property access returns `self.values` (variable.py:338–339), which materializes the entire zarr array via numpy conversion (variable.py:512, indexing.py:423).

2. **Secondary:** In `xarray/core/variable.py:1018`, within the `Variable.chunksizes` property, the code `self.data.chunks` repeats the same materialization, even though the prior line correctly checks `hasattr(self._data, "chunks")`.

**What remains uncertain:** Whether lines 1271 and 1430 in variable.py (which also use `self.data.chunks` in rechunk operations) cause unwanted materialization in other contexts — this is out of scope for the current bug but warrants follow-up.

**Confidence:** **HIGH**

---

## LOCALIZATION:

FILE: xarray/core/common.py
FUNCTION: get_chunksizes

FILE: xarray/core/variable.py
FUNCTION: Variable.chunksizes
