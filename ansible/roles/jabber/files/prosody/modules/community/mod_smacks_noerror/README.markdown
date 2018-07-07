---
labels:
- 'Stage-Alpha'
summary: Monkeypatch mod_smacks to silently discard unacked message stanzas when a hibernation times out
...

Introduction
============

By default mod_smacks sends back error stanzas for every unacked message
stanza when the hibernation times out.
This leads to "message not delivered" errors displayed in clients.

When you are certain that *all* your clients use MAM, this is unnecessary and
confuses users (the message will eventually be delivered via MAM).

This module therefore monkeypatches mod_smacks to silently drop those
unacked message stanzas instead of sending error replies.
Unacked iq stanzas are still answered with an error reply though.

If you disable mod_offline, this module will also silence "message not delivered"
error messages that will otherwise be generated when prosody would normally
store offline message but can't do this because of disabled mod_offline.  
If mod_offline is *not* disabled this module will not change offline storage
behaviour at all.

Warning
=======

You most certainly *should not* use this module if you cannot be certain
that *all* your clients support and use MAM!

Compatibility
=============

  ----- -------------------------------------------------------------------
  trunk Untested
  0.10  Works
  0.9   Untested but should work
  0.8   Untested but should work, use version [7693724881b3] of mod_smacks
  ----- -------------------------------------------------------------------

[7693724881b3]: //hg.prosody.im/prosody-modules/raw-file/7693724881b3/mod_smacks/mod_smacks.lua
