#!/usr/bin/env bash
# invoke_reviewer.sh — Step 5.5 External Audit Gate invoker
#
# Usage: invoke_reviewer.sh <analysis_file>
# Output: reviewer judgment to stdout, saved by caller as review.md
# Exit:   0 = external reviewer succeeded
#         2 = self-check fallback used (no CLI available)
#
# Reviewer priority: codex -> copilot -> claude -> self-check

set -uo pipefail

ANALYSIS_FILE="${1:?Usage: invoke_reviewer.sh <analysis_file>}"

if [ ! -f "$ANALYSIS_FILE" ]; then
  echo "ERROR: analysis file not found: $ANALYSIS_FILE" >&2
  exit 1
fi

REVIEWER_INSTRUCTIONS="You are an adversarial code reasoning reviewer. Review the following analysis critically.

Instructions:
1. Adopt a critical, adversarial perspective — look for weak spots, not just confirmation
2. Evaluate whether each Pass condition rubric item (if present) is PASS or FAIL, with a brief reason
3. Explicitly evaluate OOD (out-of-distribution) cases: edge inputs, rare code paths, or conditions outside the obvious task scope
4. Identify any claim made without sufficient evidence — no file:line citation, or logic that jumps to a conclusion

Required output format (use exactly):
AUDIT_RESULT: PASS
FINDINGS:
- [finding or N/A]

or:
AUDIT_RESULT: FAIL
FINDINGS:
- [specific issue 1 with step reference, e.g. Step 3: hypothesis H2 has no file:line evidence]
- [specific issue 2]"

FULL_PROMPT="${REVIEWER_INSTRUCTIONS}

--- BEGIN ANALYSIS ---
$(cat "$ANALYSIS_FILE")
--- END ANALYSIS ---"

# ── Priority 1: codex ──────────────────────────────────────────────────────
if command -v codex &>/dev/null 2>&1; then
  echo "[reviewer] trying codex..." >&2
  result=$(printf '%s' "$FULL_PROMPT" | codex exec - 2>/dev/null) \
    && [ -n "$result" ] && {
      echo "$result"
      exit 0
    }
  echo "[reviewer] codex failed or returned empty, trying next..." >&2
fi

# ── Priority 2: copilot ────────────────────────────────────────────────────
if command -v copilot &>/dev/null 2>&1; then
  echo "[reviewer] trying copilot..." >&2
  result=$(printf '%s' "$FULL_PROMPT" | copilot 2>/dev/null) \
    && [ -n "$result" ] && {
      echo "$result"
      exit 0
    }
  echo "[reviewer] copilot failed or returned empty, trying next..." >&2
elif command -v gh &>/dev/null 2>&1 \
  && gh extension list 2>/dev/null | grep -q "copilot"; then
  echo "[reviewer] trying gh copilot..." >&2
  result=$(printf '%s' "$FULL_PROMPT" | gh copilot explain - 2>/dev/null) \
    && [ -n "$result" ] && {
      echo "$result"
      exit 0
    }
  echo "[reviewer] gh copilot failed or returned empty, trying next..." >&2
fi

# ── Priority 3: claude (Claude Code) ──────────────────────────────────────
if command -v claude &>/dev/null 2>&1; then
  echo "[reviewer] trying claude..." >&2
  result=$(printf '%s' "$FULL_PROMPT" | claude \
    --model haiku \
    --print \
    --permission-mode bypassPermissions \
    --max-turns 5 2>/dev/null) \
    && [ -n "$result" ] && {
      echo "$result"
      exit 0
    }
  echo "[reviewer] claude failed or returned empty, falling back to self-check..." >&2
fi

# ── Fallback: self-check (original Step 5.5 behavior) ─────────────────────
echo "[reviewer] no external reviewer succeeded — using self-check fallback" >&2
echo "REVIEWER: self-check fallback (no external CLI available or all failed)"
echo ""
echo "Self-check question: Is there any claim stated without explicitly computing it?"
echo ""

UNVERIFIED=$(grep -n "claim\|assert\|conclude\|therefore\|because" "$ANALYSIS_FILE" 2>/dev/null \
  | grep -iv "file:\|:line\|VERIFIED\|verified by\|evidence" \
  | head -15 || true)

if [ -n "$UNVERIFIED" ]; then
  echo "Potentially unverified claims detected:"
  echo "$UNVERIFIED"
  echo ""
  echo "AUDIT_RESULT: REQUIRES_MANUAL_REVIEW"
else
  echo "No obvious unverified claims detected by self-check."
  echo ""
  echo "AUDIT_RESULT: PASS"
fi

exit 2
