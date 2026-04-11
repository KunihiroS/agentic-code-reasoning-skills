Looking at the Patch B code from the problem statement, I can see lines 313-327:

```python
if unhandled_params:
    # Some positional arguments were not supplied
    raise TemplateSyntaxError(
        "'%s' did not receive value(s) for the argument(s): %s" %
        (name, ", ".join("'%s'" % p for p in unhandled_params)))
if unhandled_kwargs:
    # Some keyword-only arguments without default values were not supplied
    raise TemplateSyntaxError(
        "'%s' did not receive value(s) for the keyword
