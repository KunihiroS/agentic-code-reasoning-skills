Excellent! Now I have identified the root cause of the bug. Let me document my findings:

## Bug Analysis

**Problem:** When a user sets an estimator to `None` via `set_params()` and then calls `fit()` with `sample_weight`, the code fails with `AttributeError: 'NoneType' object has no attribute 'fit'`.

**Root Cause Flow:**

1. **Lines 79-82** in `_BaseVoting.fit()` - Sample weight validation:
```python
if sample_weight is not None:
    for name, step in self.estimators:
        if not has_fit_parameter(step, 'sample_weight'):
            raise ValueError('Underlying estimator \'%s\' does not'
                             ' support sample weights.' % name)
```

2. The code iterates through ALL estimators in `self.estimators`, including those set to `None`

3. When `step is None`, it calls `has_fit_parameter(None, 'sample_weight')`

4. Inside `has_fit_parameter()` (sklearn/utils/validation.py:808), it does: `signature(estimator.fit)` which tries to access `None.fit`

5. This raises `AttributeError: 'NoneType' object has no attribute 'fit'`

**Why this is inconsistent:**
- **Lines 92-94** (the actual fitting code) correctly handles None estimators:
```python
self.estimators_ = Parallel(n_jobs=self.n_jobs)(
    delayed(_parallel_fit_estimator)(clone(clf), X, y,
                                     sample_weight=sample_weight)
    for clf in clfs if clf is not None)  # <-- Correctly skips None
```

**Fix Location:** The sample_weight validation loop needs to check if `step is not None` before calling `has_fit_parameter()`.

---

## LOCALIZATION:

FILE: sklearn/ensemble/voting.py
FUNCTION: _BaseVoting.fit
