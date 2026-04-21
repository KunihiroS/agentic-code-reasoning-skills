Here’s the code-path explanation for each symptom in the report.

## 1) `Templar.set_temporary_context(...None...)` / `copy_with_new_env(...None...)` raises instead of ignoring `None`

### Code path
- `Templar.copy_with_new_env()` takes `**context_overrides` and passes them straight into `self._overrides.merge(context_overrides)` at `lib/ansible/template/__init__.py:148-176`.
- `Templar.set_temporary_context()` only skips `None` for the *explicit* arguments `searchpath` and `available_variables` (`if value is not None:`), but then still merges `context_overrides` unchanged at `lib/ansible/template/__init__.py:181-223`.
- `TemplateOverrides.merge()` does not filter out `None`; it merges the dict into the dataclass values and calls `from_kwargs()` (`lib/ansible/_internal/_templating/_jinja_bits.py:171-184`).
- `from_kwargs()` constructs `TemplateOverrides(**kwargs)` directly (`lib/ansible/_internal/_templating/_jinja_bits.py:178-184`).

### Why it fails
A call like `variable_start_string=None` reaches the dataclass constructor unchanged. Since `TemplateOverrides` defines `variable_start_string` as a `str` field (`lib/ansible/_internal/_templating/_jinja_bits.py:82-93`), `None` is not ignored and can trigger validation/type errors instead of being treated as “no override”.

---

## 2) Legacy YAML types don’t match the construction behavior of their base types

### Code path
The compatibility types are defined as:

- `_AnsibleMapping.__new__(cls, value)` → `dict(value)`  
  `lib/ansible/parsing/yaml/objects.py:12-16`
- `_AnsibleUnicode.__new__(cls, value)` → `str(value)`  
  `lib/ansible/parsing/yaml/objects.py:19-23`
- `_AnsibleSequence.__new__(cls, value)` → `list(value)`  
  `lib/ansible/parsing/yaml/objects.py:26-30`

### Why it fails
These constructors require a positional `value` argument, so `Class()` with no arguments is a `TypeError` immediately at argument binding.

They also do not mirror the built-in type constructor signatures:
- `dict()` / `list()` accept no arguments.
- `str()` supports `object`, `encoding`, and `errors` in the bytes case.
- `_AnsibleUnicode` only accepts one positional argument and always does `str(value)`; it does not support the base type’s bytes-decoding constructor shape.

So the wrappers are not drop-in compatible with the base types.

---

## 3) Module deprecations are not fully controlled by configuration, and the “can be disabled” wording is inconsistent

### Code path
- On the module side, `ansible.module_utils.common.warnings.deprecate()` always stores a `DeprecationSummary` in `_global_deprecations` when not in controller mode (`lib/ansible/module_utils/common/warnings.py:36-68`).
- `AnsibleModule._return_formatted()` always pulls those deprecations with `get_deprecations()` and puts them into the JSON result (`lib/ansible/module_utils/basic.py:1426-1441`).
- Only the controller-side display layer checks `deprecation_warnings_enabled()` before rendering deprecations (`lib/ansible/utils/display.py:712-715`).

### Why it behaves inconsistently
The module-side path records and serializes deprecations unconditionally; the config gate is only applied later during display. That means:
- the deprecation still exists in the module result payload,
- suppression depends on which path consumes the result,
- and the user-visible “can be disabled” warning is only emitted in `Display._deprecated_with_plugin_info()` after the config check (`lib/ansible/utils/display.py:712-715`).

So the configuration is not enforced at the point where module deprecations are recorded, only later at display time.

---

## 4) Lookup `errors: warn/ignore` messaging is inconsistent and sometimes redundant

### Code path
The lookup wrapper in `_jinja_plugins.py` does:

- pop `errors` from kwargs (`lib/ansible/_internal/_templating/_jinja_plugins.py:215-218`)
- run the lookup
- catch exceptions in one broad `except Exception as ex` block (`lib/ansible/_internal/_templating/_jinja_plugins.py:264-278`)

Inside that handler:
- if the exception is an `AnsibleTemplatePluginError`, it uses:
  - `Lookup failed but the error is being ignored: {ex}` (`lines 266-267`)
- otherwise it uses:
  - `An unhandled exception occurred while running the lookup plugin ... Error was a {type(ex)}, original message: {ex}` (`lines 268-269`)

Then:
- `errors == 'warn'` → `_display.warning(msg)` (`line 271-272`)
- `errors == 'ignore'` → `_display.display(msg, log_only=True)` (`line 273-274`)

### Why it’s inconsistent
The message text depends on exception class, not on `warn` vs `ignore`, so:
- some failures include exception type + original message,
- some only say “being ignored”,
- and both warning modes reuse the same message text but send it through different display sinks.

That’s why the output looks redundant in some cases and incomplete in others.

---

## 5) `timedout` is not strictly Boolean

### Code path
The test plugin is:

- `return result.get('timedout', False) and result['timedout'].get('period', False)`  
  `lib/ansible/plugins/test/core.py:48-52`

### Why it behaves unexpectedly
Python’s `and` returns one of its operands, not a coerced `bool`. So:
- if `period` is truthy, the function returns the actual `period` value,
- if `period` is falsey or missing, it returns that falsey value,
- and the result is therefore not guaranteed to be a strict Boolean.

The integration test only checks truthiness (`timed is timedout`) and separately inspects `period` (`test/integration/targets/test_core/tasks/main.yml:372-381`), which matches this behavior.

---

## 6) Early CLI fatal errors don’t include help text

### Code path
Some CLI fatal checks happen at import time, before normal CLI parsing or error display:

- Python version check → `SystemExit(...)` at `lib/ansible/cli/__init__.py:26-32`
- blocking I/O check → `SystemExit(...)` at `lib/ansible/cli/__init__.py:35-54`
- locale initialization → `SystemExit(...)` at `lib/ansible/cli/__init__.py:57-77`

Those execute before the `CLI` object is even created.

Later, the CLI only adds parser help text for `SystemExit` raised by `parse_args()`:
- `parse()` catches `SystemExit` and appends `self.parser.format_help()` for non-zero exits  
  `lib/ansible/cli/__init__.py:533-538`

And the normal fatal-error display path is:
- `cli_executor()` catches `AnsibleError` and calls `display.error(ex)`  
  `lib/ansible/cli/__init__.py:736-750`

### Why help text is missing
The display layer can render `help_text` when it receives an `AnsibleError`/`ErrorSummary` (`lib/ansible/utils/display.py:1210-1224`), but these early import-time failures are plain `SystemExit`s. They bypass:
- `CLI.parse()` help injection, and
- `display.error()`’s error-summary formatting.

So those fatal startup errors never reach the code that would attach help text.

---

If you want, I can turn this into a shorter “root cause summary” or map each symptom to the exact fix that would be needed.
