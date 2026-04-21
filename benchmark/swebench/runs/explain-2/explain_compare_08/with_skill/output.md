Selected mode: explain

Step 1: Task and constraints
- Explain why the reported bug happens by tracing the relevant code paths.
- Static inspection only; no execution.
- Use file:line evidence.

Step 2: Premises
P1: The report covers several related behaviors: Templar `None` overrides, legacy YAML constructors, deprecation/lookup messaging, `timedout`, CLI pre-display errors, and unset/exception handling.
P2: The fix commit is `6cc97447aa` (“Miscellaneous DT fixes”), which touched the exact subsystems named in the report.
P3: The current repository contains the fixed code; the buggy pre-fix paths can be recovered from the parent of `6cc97447aa`.
P4: The visible unit tests exercise the intended behaviors for `Templar`, YAML objects, and the `timedout` test plugin.
P5: For module/deprecation/CLI paths, the code itself shows how messages and config gating flow.

FUNCTION TRACE TABLE
| Function/Method | File:Line | Parameter Types | Return Type | Behavior (VERIFIED) |
|---|---:|---|---|---|
| `Templar.copy_with_new_env` | `lib/ansible/template/__init__.py:143-175` | kwargs incl. `None` overrides | `Templar` | Builds a new `Templar` and now filters out `None` values before merging overrides. |
| `Templar.set_temporary_context` | `lib/ansible/template/__init__.py:177-220` | kwargs incl. `None` overrides | context manager | Temporarily swaps context, and now filters out `None` values before merging overrides, then restores originals. |
| `TemplateOverrides.merge` | `lib/ansible/_internal/_templating/_jinja_bits.py:194-199` | `dict[str, Any] | None` | `TemplateOverrides` | Returns `self` when kwargs is falsey; otherwise creates a new override object. |
| `_AnsibleMapping.__new__` | `lib/ansible/parsing/yaml/objects.py:14-21` | `value` optional, `**kwargs` | `dict`-like | No-arg call returns `dict(**kwargs)`; positional input copies and tags. |
| `_AnsibleUnicode.__new__` | `lib/ansible/parsing/yaml/objects.py:24-31` | `object` optional, `**kwargs` | `str` | No-arg call returns `str(**kwargs)`; positional input copies and tags. |
| `_AnsibleSequence.__new__` | `lib/ansible/parsing/yaml/objects.py:34-41` | `value` optional | `list` | No-arg call returns `list()`; positional input copies and tags. |
| `timedout` | `lib/ansible/plugins/test/core.py:48-53` | `result` mapping | `bool` | Returns a strict boolean based on presence of `timedout` and truthiness of `period`. |
| `_invoke_lookup` | `lib/ansible/_internal/_templating/_jinja_plugins.py:205-279` | plugin name, terms, kwargs | lookup result / `None` / `[]` | For `errors='warn'`, uses `error_as_warning`; for `errors='ignore'`, logs type+message only; otherwise raises. |
| `Display._deprecated` | `lib/ansible/utils/display.py:709-727` | deprecation summary | `None` | Controller-side gate: checks config, prints “can be disabled” hint, formats and deduplicates warning. |
| `module_utils.common.warnings.deprecate` | `lib/ansible/module_utils/common/warnings.py:82-115` | msg/version/date/deprecator/help_text | `None` | On controller, forwards to `Display.deprecated`; on target, stores a `DeprecationSummary` for later. |
| `CLI` import-time error handler | `lib/ansible/cli/__init__.py:92-103` | `Exception` during import/display setup | exits | If exception is `AnsibleError`, it prints `message + help_text`; otherwise prints `str(ex)`. |
| `AnsibleModule._load_params` | `lib/ansible/module_utils/basic.py:336-343` | module input buffer | params dict / exception | Uses a dedicated sentinel now; missing `ANSIBLE_MODULE_ARGS` raises explicitly. |
| `AnsibleModule.fail_json` | `lib/ansible/module_utils/basic.py:1533-1589` | `exception` may be base exception/string/None/omitted | `NoReturn` | Distinguishes BaseException, string, explicit `None`, and omitted exception using `_UNSET`. |

DATA FLOW ANALYSIS
Variable: `context_overrides`
- Created at: `lib/ansible/template/__init__.py:148`
- Modified at: `lib/ansible/template/__init__.py:169-170`, `:212-213`
- Used at: `lib/ansible/template/__init__.py:170`, `:213`
- Meaning: `None` values are now stripped before merge, so `merge()` sees falsey kwargs and returns the existing overrides.

Variable: `exception`
- Created at: `lib/ansible/module_utils/basic.py:1533`
- Used at: `lib/ansible/module_utils/basic.py:1558-1589`
- Meaning: `_UNSET` vs explicit `None` vs BaseException are now separate paths; before the fix, the code used `...` as the sentinel, which made the “unset” branch rely on an awkward identity check.

Variable: `period`
- Created at: `lib/ansible/plugins/test/core.py:53`
- Used at: same line
- Meaning: now coerced with `bool(...)`; before the fix the raw value was returned, so a non-bool truthy object could leak out.

Variable: `ex_msg`
- Created at: `lib/ansible/cli/__init__.py:97-100`
- Used at: `:102`
- Meaning: `AnsibleError` now contributes its stored help text to early fatal CLI output.

Variable: `errors`
- Created at: `lib/ansible/_internal/_templating/_jinja_plugins.py:220`
- Used at: `:269-279`
- Meaning: drives warn/ignore/strict behavior; the old code built different message strings for different exception types, which was the source of inconsistent output.

SEMANTIC PROPERTIES
Property 1: `TemplateOverrides.merge()` is a no-op on falsey kwargs.
- Evidence: `lib/ansible/_internal/_templating/_jinja_bits.py:194-199`

Property 2: `None` must be treated as “ignore this override,” not as a real override value, in the Templar compatibility APIs.
- Evidence: `lib/ansible/template/__init__.py:169-170` and `:212-213`; tests at `test/units/template/test_template.py:361-375`

Property 3: YAML legacy types should mirror the base constructors’ zero-arg and kwargs behavior.
- Evidence: `lib/ansible/parsing/yaml/objects.py:14-41`; tests at `test/units/parsing/yaml/test_objects.py:121-138`

Property 4: Lookup warning/ignore mode should preserve exception details without duplicating ad hoc text.
- Evidence: `lib/ansible/_internal/_templating/_jinja_plugins.py:269-279`

Property 5: The `timedout` test must be a Boolean predicate, not a raw value passthrough.
- Evidence: `lib/ansible/plugins/test/core.py:48-53`; tests at `test/units/plugins/test/test_all.py:60-63`

Property 6: CLI startup errors must include `AnsibleError._help_text` when available.
- Evidence: `lib/ansible/errors/__init__.py:36-85` and `lib/ansible/cli/__init__.py:96-103`

ALTERNATIVE HYPOTHESIS CHECK
If the opposite answer were true — that these symptoms were unrelated or random — the old code would not show the exact missing normalization/formatting branches at the relevant points.
- Searched for: the pre-fix versions of the same functions in `6cc97447aa^`
- Found:
  - raw `context_overrides` passthrough in `lib/ansible/template/__init__.py:174,216`
  - raw positional-only YAML constructors in `lib/ansible/parsing/yaml/objects.py:15-30`
  - raw lookup error strings in `lib/ansible/_internal/_templating/_jinja_plugins.py:264-274`
  - early CLI error print using only `str(ex)` in `lib/ansible/cli/__init__.py:96-98`
  - raw `period` passthrough in `lib/ansible/plugins/test/core.py:52`
  - `...` sentinel handling in `lib/ansible/module_utils/basic.py:344-345,1462-1503`
- Conclusion: refuted. The buggy behavior is directly explained by those old branches.

Why the bug occurs

1. Templar `None` overrides
- Before the fix, `copy_with_new_env()` and `set_temporary_context()` forwarded `context_overrides` unchanged to `TemplateOverrides.merge()` (`parent of 6cc97447aa`, `lib/ansible/template/__init__.py:174,216`).
- `TemplateOverrides.merge()` only no-ops on falsey kwargs (`lib/ansible/_internal/_templating/_jinja_bits.py:194-199`), so `{'variable_start_string': None}` was still treated as a real override dict.
- That meant `None` was not “ignored”; it flowed into a new override object and then into templating, which is why the calls raised instead of behaving like compatibility no-ops. The fix filters `None` out first (`lib/ansible/template/__init__.py:169-170,212-213`).

2. Legacy YAML constructors
- Before the fix, `_AnsibleMapping`, `_AnsibleUnicode`, and `_AnsibleSequence` each required one positional `value` and had no zero-arg or kwargs-only branch (`parent of 6cc97447aa`, `lib/ansible/parsing/yaml/objects.py:15-30`).
- So `()` or keyword-only construction hit Python constructor argument errors, unlike the base `dict`/`str`/`list`.
- The fix adds explicit no-arg handling and kwargs-compatible paths (`current`, `lib/ansible/parsing/yaml/objects.py:14-41`), matching the tests at `test/units/parsing/yaml/test_objects.py:121-138`.

3. `timedout` returning non-boolean values
- Before the fix, `timedout()` returned `result.get('timedout', False) and result['timedout'].get('period', False)` directly (`parent of 6cc97447aa`, `lib/ansible/plugins/test/core.py:48-52`).
- That expression can return the raw `period` value, not a strict boolean.
- So a truthy non-bool period produced a non-bool result, which is why the plugin’s behavior was inconsistent. The fix wraps the `period` check in `bool(...)` (`current`, `lib/ansible/plugins/test/core.py:48-53`).

4. Lookup `errors: warn/ignore` messaging
- Before the fix, `_invoke_lookup()` built two ad hoc message strings: one special-case for `AnsibleTemplatePluginError`, another generic “unhandled exception” string, then reused those strings for both warn and ignore (`parent of 6cc97447aa`, `lib/ansible/_internal/_templating/_jinja_plugins.py:264-274`).
- That produced inconsistent and redundant output across `warn` and `ignore`.
- The fix standardizes the branches: `warn` goes through `error_as_warning()`, which preserves exception context; `ignore` logs the exception type and message in log-only mode (`current`, `lib/ansible/_internal/_templating/_jinja_plugins.py:269-279`).

5. Deprecations and the “can be disabled” message
- Module-side deprecations are recorded in `module_utils/common/warnings.deprecate()` and later rendered on the controller (`lib/ansible/module_utils/common/warnings.py:82-115`).
- The old `Display.deprecated()` path did the config check before the controller-side summary/rendering step (`parent of 6cc97447aa`, `lib/ansible/utils/display.py:712-740`), so the warning could be dropped before the controller had the final say.
- The fix moves the config gate into the controller-side `_deprecated()` method, after the warning has been captured/transported (`current`, `lib/ansible/utils/display.py:709-727`), and adds the standardized “can be disabled” hint there.
- That is why the old behavior was inconsistent: the decision was made too early in the pipeline.

6. CLI early fatal errors missing help text
- Before the fix, if CLI startup failed while importing constants or initializing `Display`, the handler printed only `str(ex)` and the traceback (`parent of 6cc97447aa`, `lib/ansible/cli/__init__.py:92-98`).
- `AnsibleError` stores both a message and a separate `_help_text` (`lib/ansible/errors/__init__.py:59-85`).
- Because the old handler ignored `_help_text`, early fatal errors lost the diagnostic hint.
- The fix concatenates `ex.message` and `ex._help_text` before printing (`current`, `lib/ansible/cli/__init__.py:96-103`).

7. Unset values / traceback selection in `AnsibleModule`
- Before the fix, `basic.py` used `...` as the sentinel both for missing `ANSIBLE_MODULE_ARGS` and for the default `fail_json(exception=...)` value (`parent of 6cc97447aa`, `lib/ansible/module_utils/basic.py:344-345,1462-1503`).
- That made “unset” handling rely on a special ellipsis identity check, which is brittle and confusing.
- The current code replaces that with a dedicated `_UNSET` object and separates omitted `exception` from explicit `None` (`current`, `lib/ansible/module_utils/basic.py:66,342-343,1533-1589`), which is the root of the traceback/“unset” cleanup in the fix.

FORMAL CONCLUSION
By P1–P5 and the traced code paths above, the bug is caused by a repeated pattern of missing normalization and wrong-stage decision making:
- `None` overrides were forwarded as real overrides instead of being dropped.
- Legacy YAML constructors had no no-arg / kwargs-compatible branches.
- `timedout()` returned a raw value instead of a boolean.
- Lookup errors used ad hoc message strings instead of a single exception-aware formatter.
- Deprecation gating happened too early in the display pipeline.
- CLI startup errors printed only `str(ex)`, dropping `AnsibleError` help text.
- `AnsibleModule` used `...` as an awkward sentinel, making unset/traceback handling brittle.

The current fix addresses each by moving the decision to the right stage or by normalizing inputs first.

CONFIDENCE: HIGH
