# Ranked PvP: two-account smoke check

Prerequisites: use a test server with SQLite migrations through 0013, `PVP_ENABLED=1`, and a stable `PVP_RNG_SECRET` of at least 32 bytes. Sign in on two separate clients and save an Attack seal on each. Use server-equipped spells.

1. Open loadout on both clients, select Ranked and check MP/division. Press READY on both. Verify the timer, cancel and rejoin once; the two players should enter the existing Combat scene. Usernames should appear above their own/opponent entity names on both clients.
2. Choose spells on both clients. Confirm the first player waits without revealing the pending choice, then both see the same exchange in the same order, with themselves on the left. Check HP, effects, spell links, type icons, weapon sprites, weapon switching and a homunculus action.
3. Play to a BO3 result. At 1–1 verify Ultraturn; if possible force a draw into sudden death. Check score, final result, MP change and return to loadout. The leaderboard scene is intentionally unavailable until 0.61i.
4. Start another match and let one player miss the 60-second deadline. Confirm the forfeit and MP result; when both miss a deadline, confirm a draw without MP change. Trigger Inspiration on either or both players, choose/decline and verify waiting and restoration at the next battle.
5. Send chat from both clients, check ordering and privacy, the 200-character limit and the ten-second cooldown. Restart or reconnect one client while queued and during a match; verify recovery, no repeated log entries, and no duplicate decisions. Confirm leaving an active match prompts for forfeit.
6. Compare the Ranked screen with Practice at the same resolution: both fighter panels, crowns, HP/status indicators, equipment, sprites, spell controls and combat log should remain aligned. Check network loss and `PVP_DISABLED` messaging without trusting the client countdown as authority.
