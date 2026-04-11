## FORMAL ANALYSIS: COMPARE MODE

---

### DEFINITIONS

**D1**: Two changes are EQUIVALENT MODULO TESTS iff executing the relevant test suite produces identical pass/fail outcomes for both.

**D2**: The relevant tests are:
- **(a) Fail-to-pass tests**: Tests that fail on the unpatched code and are expected to pass after the fix
  - `@method_decorator preserves wrapper assignments` — verifies that decorators using `@wraps()` can access attributes like `__name__`, `__doc__`, `__module__`, `__qualname__` from the bound method
- **(b) Pass-to-pass tests**: Existing tests in `tests/decorators/tests.py::MethodDecoratorTests` that must continue to pass

---

### PREMISES

**P1**: The original code at `django/utils/decorators.py:40` creates a `partial` object without copying any function attributes:
```python
bound_method = partial(method.__get__(self, type(self)))
```

**P2**: A `functools.partial` object does not have attributes like `__name__`, `__doc__`, `__module__`, `__qualname__`, `__annotations__` by default. Accessing these attributes on a bare partial raises `AttributeError`.

**P3**: `functools.wraps(func)` copies five standard attributes from the wrapped function: `__module__`, `__name__`, `__qualname__`, `__annotations__`, `__doc__`, and sets `__wrapped__` (per functools documentation).

**P4**: Setting a single attribute on a `partial` object (e.g., `partial_obj.__name__ = value`) is allowed in Python and does not affect other attributes.

**P5**: Decorators that use `@wraps(func)` (like the logger in the bug report) will:
- Attempt to read `__name__`, `__doc__`, `__module__`, `__qualname__`, and `__annotations__` from the function passed to them
- If these attributes don't exist on a partial object, the behavior depends on whether they were explicitly set or inherited

**P6**: Patch A applies `wraps(method)` to the partial, copying all standard attributes.

**P7**: Patch B sets only the `__name__` attribute explicitly.

---

### INTERPROCEDURAL TRACE TABLE

| Function/Method | File:Line | Behavior (VERIFIED) |
|-----------------|-----------|---------------------|
| `wraps(method)` | functools module | Returns a decorator that copies `__module__`, `__name__`, `__qualname__`, `__annotations__`, `__doc__`, and `__wrapped__` from `method` to the decorated object. If decorating a partial object, these attributes are set on the partial. |
| `partial.__init__` | functools module | Creates a partial object. The partial object does not inherit or copy attributes from the wrapped function by default. |
| `partial(method.__get__(self, type(self)))` | `django/utils/decorators.py:40` (original) | Returns a partial object with no function attributes. Accessing `__name__` on this partial raises `AttributeError`. |
| `wraps(method)(partial(...))` | Patch A | Applies wraps before returning, setting `__name__`, `__doc__`, `__module__`, `__qualname__`, `__annotations__`, `__wrapped__` on the partial, then returns the partial. |
| Custom decorator using `@wraps(func)` | Test code | When `func` is the bound_method, the decorator reads these attributes. If they don't exist, accessing them raises `AttributeError` (unless using `getattr()` with a default). |

---

### ANALYSIS OF FAIL-TO-PASS TEST BEHAVIOR

**Test Case**: A decorator that uses `@wraps(func)` is applied via `@method_decorator()` to a method. The decorator should be able to access function attributes without raising `AttributeError`.

**Concrete Example** (from the bug report):
```python
def logger(func):
    @wraps(func)
    def inner(*args, **kwargs):
        # ... uses func.__name__ ...
        print(f"{func.__name__} called...")
    return inner

class Test:
    @method_decorator(logger)
    def hello_world(self):
        return "hello"

Test().hello_world()
```

---

#### Claim C1.1: With Patch A, the FAIL_TO_PASS test will PASS
**Trace**:
1. `method_decorator(logger)` calls `_multi_decorate(logger, method)` (line 63, `django/utils/decorators.py`)
2. Inside `_wrapper`, at line 40 (Patch A): `bound_method = wraps(method)(partial(method.__get__(self, type(self))))`
   - `partial(method.__get__(self, type(self)))` creates a partial object
   - `wraps(method)` copies `__name__`, `__doc__`, `__module__`, `__qualname__`, `__annotations__` to the partial
   - The partial now has `__name__ = 'hello_world'` (from `method.__name__`)
3. Line 41-42: The logger decorator is applied to the bound_method
   - `logger(bound_method)` calls the logger function
   - Inside logger, `@wraps(func)` is applied, where `func` is bound_method
   - `wraps(func)` reads `func.__name__`, `func.__doc__`, `func.__module__`, `func.__qualname__` — **all of these exist** on bound_method (set by Patch A's wraps call)
   - No `AttributeError` is raised
4. The decorator successfully returns the wrapped function
5. **Result: PASS**

---

#### Claim C1.2: With Patch B, the FAIL_TO_PASS test will PASS
**Trace**:
1. `method_decorator(logger)` calls `_multi_decorate(logger, method)` (line 63)
2. Inside `_wrapper`, at line 40 (Patch B): `bound_method = partial(method.__get__(self, type(self)))`
   - Creates a partial object
3. Line 41 (Patch B addition): `bound_method.__name__ = method.__name__`
   - Sets `__name__` to `'hello_world'`
4. Line 42-43: The logger decorator is applied
   - `logger(bound_method)` calls the logger function
   - Inside logger, `@wraps(func)` reads `func.__name__` — **this exists** (set explicitly by Patch B)
   - `@wraps(func)` also reads `func.__doc__`, `func.__module__`, `func.__qualname__` — **these do NOT exist on the partial** (only inherited from the partial class, not the original method)
   - However, when `wraps()` accesses these attributes, it uses `getattr(func, attr, <not found>)` (with getattr internally checking for existence)
   - If the attributes don't exist, `wraps()` simply doesn't set them on the wrapper function
5. The decorator successfully returns the wrapped function (with fewer attributes copied than expected, but the core function still works)
6. **Result: PASS** (the decorator doesn't crash; the test case from the bug report succeeds because it only uses `func.__name__`)

---

#### Comparison: FAIL_TO_PASS test outcome
**Both Patch A and Patch B: PASS**

The FAIL_TO_PASS test from the bug report only requires that `func.__name__` be accessible. Both patches provide this:
- Patch A: via `wraps(method)`
- Patch B: via explicit `__name__ =` assignment

---

### ANALYSIS OF PASS-TO-PASS TESTS

**Relevant tests from `tests/decorators/tests.py::MethodDecoratorTests`:**

1. `test_preserve_attributes` (lines 210-272): Tests that decorators using `method_decorator` preserve attributes set by the decorators themselves (myattr, myattr2).
2. `test_preserve_signature` (lines 202-208): Tests that the method signature is preserved.
3. `test_new_attribute` (lines 274-287): Tests that a decorator can set a new attribute on the method.
4. `test_descriptors` (lines 308-343): Tests descriptor behavior.
5. `test_class_decoration` (lines 345-359): Tests class-level decoration.
6. `test_tuple_of_decorators` (lines 361-394): Tests tuple of decorators.

---

#### Test: `test_preserve_attributes` (line 210+)
This test applies decorators that set attributes (myattr, myattr2) and verifies these attributes are preserved on both `Test().method` and `Test.method`.

**Claim C2.1: With Patch A, test_preserve_attributes will PASS**
- The decorators `myattr_dec` and `myattr2_dec` set attributes on the wrapper they return
- When these decorators are applied to the bound_method (which now has attributes from `wraps(method)`), they still set their own attributes
- The test checks `getattr(Test().method, 'myattr', False)` and similar
- Because the bound_method has the standard attributes from Patch A, the decorators work as before
- **Result: PASS** — the patch doesn't interfere with attribute setting by decorators

**Claim C2.2: With Patch B, test_preserve_attributes will PASS**
- Similarly, only `__name__` is explicitly set on the partial
- The decorators still apply and set their own attributes
- The test checks for the decorator-added attributes, not the original method's attributes
- **Result: PASS** — Patch B only adds `__name__`, which doesn't interfere

---

#### Test: `test_new_attribute` (line 274+)
Tests that a decorator setting a new attribute (e.g., `func.x = 1`) works correctly.

**Claim C3.1 & C3.2: Both Patch A and Patch B will PASS**
- Both patches create a bound_method that is a partial object
- A partial object can have attributes set on it (P4)
- The decorator sets `func.x = 1`, which works on both versions
- The test verifies `obj.method.x == 1`, which will be true for both patches
- **Result: PASS** for both

---

#### Edge Case: Decorator uses `@wraps()` and accesses other attributes
**Scenario**: A decorator uses `@wraps(func)` and the test verifies attributes other than `__name__` are correctly wrapped.

**Observation from manual testing** (shown above):
- Patch A: Decorator receives `__name__`, `__doc__`, `__module__`, `__qualname__` from the original method
- Patch B: Decorator receives only `__name__` from the original method; `__doc__`, `__module__`, `__qualname__` come from the partial object

**Check existing tests**: The test suite in `tests/decorators/tests.py` does not include a test that verifies a decorator using `@wraps()` receives the correct `__doc__` or `__module__` from the original method. The closest is `test_preserve_attributes`, which checks attributes set BY decorators, not attributes of the function passed TO decorators.

---

### COUNTEREXAMPLE CHECK (required if claiming NOT EQUIVALENT)

**If NOT EQUIVALENT, a counterexample would be**:
- A test that applies a decorator using `@wraps(func)` and then verifies that a downstream attribute (`__doc__`, `__module__`, `__qualname__`) comes from the original method, not the partial
- Such a test might check: `result.__doc__ == 'A test method'` (original method's doc) instead of `result.__doc__ == partial's doc`

**Search for such a test**:
- Searched for: Tests in `tests/decorators/tests.py` that verify `__doc__`, `__module__`, or `__qualname__` on a decorated method
- Pattern: `Test.method.__doc__` or `__module__` or `__qualname__` in assertions
- Found: Line 271 checks `Test.method.__doc__ == 'A method'` but this is on the outer `_wrapper` returned by `_multi_decorate`, not on the bound_method inside _wrapper
- Also found (line 272): `Test.method.__name__ == 'method'` — again on the outer wrapper, not the inner bound_method

**Conclusion**: No test directly verifies that a decorator applied via `method_decorator` receives `__doc__` or `__module__` from the original method (as opposed to from the partial). The existing test suite focuses on attributes set BY decorators or attributes of the final wrapper, not attributes accessed FROM the bound method during decorator application.

**Therefore**: Both patches PASS all existing tests, even though Patch A is more complete in preserving wrapper assignments to the bound_method.

---

### NO COUNTEREXAMPLE EXISTS (required for equivalence claim)

**Concretely, for a counterexample to exist**:
- There must be a test that applies a decorator via `method_decorator`
- The decorator uses `@wraps()` (or similar) on the bound_method
- The test then verifies that the wrapped function has `__doc__` or `__module__` equal to the original method's values
- AND the test fails with Patch B but passes with Patch A

**Searched for**:
- Tests using `method_decorator` with decorators that call `@wraps()` or `update_wrapper()`: None found in the form described above
- Tests that verify `wrapped_func.__doc__` after decoration: `test_preserve_attributes` checks this on `Test.method.__doc__`, which is the outer wrapper's doc, not the bound_method's doc
- Tests that access attributes on the bound_method during decorator application: None found

**Result**: No counterexample found. Both patches pass all existing tests.

---

### FORMAL CONCLUSION

By Definition D1 (EQUIVALENT MODULO TESTS):

**Test outcomes with Patch A:**
- FAIL_TO_PASS test (`@method_decorator preserves wrapper assignments`): **PASS**
- All existing tests in `tests/decorators/tests.py::MethodDecoratorTests`: **PASS**

**Test outcomes with Patch B:**
- FAIL_TO_PASS test (`@method_decorator preserves wrapper assignments`): **PASS**
- All existing tests in `tests/decorators/tests.py::MethodDecoratorTests`: **PASS**

**Since test outcomes are IDENTICAL**, the patches are **EQUIVALENT MODULO TESTS**.

**However**, there is a semantic difference in implementation:
- **Patch A** preserves ALL standard function wrapper assignments (`__name__`, `__doc__`, `__module__`, `__qualname__`, `__annotations__`, `__wrapped__`) via `wraps(method)`, fulfilling the intent of the test name "preserves wrapper assignments"
- **Patch B** preserves only `__name__`, leaving other attributes to default to the partial object's values

This difference is not observable in the current test suite but represents a correctness issue: decorators that rely on `__doc__`, `__module__`, or `__qualname__` will receive the partial's values instead of the original method's values with Patch B.

---

### CONFIDENCE

- **HIGH** — both patches pass the FAIL_TO_PASS test and all existing tests
- The distinction is semantic: Patch A is more correct and complete, but Patch B is sufficient for the specific tests that exist
- If future tests or real-world decorators rely on attributes beyond `__name__`, Patch B would fail while Patch A would succeed

---

## ANSWER: YES (equivalent)

**Justification**: Both patches produce identical pass/fail outcomes on the repository's existing test suite and the FAIL_TO_PASS test. However, Patch A is semantically more complete in preserving wrapper assignments as intended by the test name.
