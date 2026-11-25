# Core Defense backend contract

Core Defense is disabled by default (`FOREST_CORE_DEFENSE_ENABLED=0`). It uses the Forest lease and the existing WOE scheduler and shared `FOREST_WOE_MAX_MATCHES` running-match limit. `FOREST_CORE_DEFENSE_INACTIVITY_MS` defaults to 300000 ms and is clamped to 1000–86400000 ms.

Authenticated routes are `/forest/core-defense/rooms`, `/state`, `/create`, `/join`, `/start`, `/leave`, and `/match/current`, `/match/state`, `/match/deploy`, `/match/forfeit` beneath the same prefix. New modes are `solo` (one human, starts immediately) and `coop` (two human friends, host starts). `solo_bot` creation is rejected. Both blue lanes remain available. The coop rooms list is empty and direct `/join` returns `INVITE_REQUIRED`; admission uses the shared invitation API below. Only creation and acceptance require live presence in `duel_clearing`; match and lobby recovery works after Forest suspension. An explicit forfeit by either coop human ends the match for both. Disconnection never creates bot deployments; all-human inactivity retains the existing abandonment behavior. Terminal scores and access are retained for 24 hours.

Legacy running `solo_bot` matches remain readable and can continue with their original mode and existing units, but no further bot deployments occur. They can be forfeited or abandoned normally, and their original result classification is preserved. A legacy running coop match whose human already forfeited terminates as `forfeit` on its next scheduler tick; no takeover occurs. A legacy `solo_bot` room still waiting cannot start (`LEGACY_MODE_UNAVAILABLE`); the host can leave. Existing terminal results are not rewritten.

## Online friend invitations

All routes require authentication, `SOCIAL_ENABLED=1`, an active Forest lease, and the relevant game flag (`FOREST_WOE_ENABLED` or `FOREST_CORE_DEFENSE_ENABLED`). When both games are disabled or the lease is unavailable, the invitation service returns `MINIGAMES_UNAVAILABLE`; social disabled returns `SOCIAL_DISABLED`; a disabled game returns `GAME_UNAVAILABLE`. The service uses the existing `globalChat.isOnline` signal, which is local to the server process and considers a player online for 45 seconds after `/chat/state` activity. It does not require the host's Forest connection to remain active.

- `GET /forest/minigames/invitations`: private incoming and outgoing pending invitations, recent resolved invitations from the last five minutes, and `server_time_unix_ms`.
- `GET /forest/minigames/invite-friends?room_id=...`: the host's currently online and available friends for that waiting room.
- `POST /forest/minigames/invite`: `{room_id, game_kind: "woe" | "core_defense", target_player_id, client_action_id}`.
- `POST /forest/minigames/invite/respond`: `{invite_id, accept: boolean, client_action_id}`. Successful acceptance returns `{invite_id, status: "ACCEPTED", room, server_time_unix_ms}`; decline returns status `DECLINED`. Admission and acceptance commit atomically. If the recipient is outside the clearing, `FOREST_PRESENCE_REQUIRED` leaves the invitation pending and permits retrying the same action ID.
- `POST /forest/minigames/invite/cancel`: `{invite_id, client_action_id}`; only the inviter can cancel.

Only confirmed friends can be invited. Online status, friendship, game flag, host, room state and capacity, and conflicting activity are checked on send and acceptance. The recipient is not reserved or teleported by an invitation. WOE continues to support public discovery and ordinary direct joining. Invitations expire after `FOREST_MINIGAME_INVITE_MS` (default 180000, clamped to 10000?600000 ms). Pending limits are 20 outgoing and 50 incoming, with a 30-second per-pair send cooldown and a global 10000-record cap. Expiry and cleanup occur in bounded batches on invitation requests, without a polling scheduler.

Invitation action IDs use the same `<13-digit server-time-ms>:<nonce>` format and 10-minute replay window described below. The nonce is 1?110 non-whitespace, non-colon characters. Use `server_time_unix_ms` from an invitation response and retain the exact request for retries. Actions and acknowledgements survive restart; expired IDs return `ACTION_EXPIRED` even after pruning, including after clock rollback. A maximum of 2048 retained actions per player is enforced. Completed invitation records are retained for at least seven days, until bounded cleanup removes them; only participants can read pending invitations.

`FOREST_WOE_MAX_MATCHES` remains the shared running-match cap. For a beta deployment, 8 total matches is a conservative starting setting to evaluate with load testing; this change does not activate either game.

## Deployment replay

Deployment `client_action_id` must be `<13-digit server-time-ms>:<nonce>`, where the nonce has 1–110 non-whitespace, non-colon characters and the full ID is at most 128 characters. Take the timestamp from `server_time_unix_ms` on a match response. The timestamp may be at most 60 seconds ahead and 10 minutes behind the server's persisted activity and replay-expiry high-water marks. A client must retain the exact request for retries. Within the window, committed requests replay their compact acknowledgement, and changing the payload with the same ID returns `ACTION_CONFLICT`. After expiry, an ID is rejected with `ACTION_EXPIRED`, even after its replay record is removed; a pruned ID can never become a new deployment. Server clock rollback does not lower the persisted watermark. At most 2048 deploy records per controller and match are retained; if the window is full, deploy returns `ACTION_LIMIT` until records expire. Forfeit uses a separate arbitrary action ID and remains available at the deploy limit. Terminal cleanup removes all associated replay records.

The journal retains the latest 2000 events per match, paginates 100 at a time and requires a snapshot resync when a cursor has fallen out of retention. State, events, results and admission changes commit transactionally under the Forest lease. Results contain immutable mode, wave count, kill count, remaining laboratory HP, elapsed ticks, reason and assistance status for future ranking work.


## Persistence and maintenance

The committed match row is the sole runtime state; started lobby snapshots read it inside the lobby transaction. Terminal score and event retention remain 24 hours. Scheduler maintenance runs under the Forest lease even with only Core Defense enabled, processes expired rooms and replay records in bounded batches, and removes orphaned Core Defense records with foreign key enforcement either enabled or disabled. Replay cleanup advances a separate durable watermark; it does not refresh player activity. Repeating the successful forfeit ID returns its original response; a different ID after forfeiting is rejected without adding a replay record.

## Monthly leaderboards

`GET /forest/core-defense/leaderboard?mode=solo|coop&month=current|previous` requires the same authentication, feature flag, lease and rate limit as other Core Defense routes. Both filters are required exactly once; other parameters are rejected. The response contains `current_month`, `previous_month`, `viewed_month` (UTC `YYYY-MM`), `mode`, and up to 100 `entries` containing only `display_name` and `completed_waves`. Scores order by waves descending, completion time ascending, then player ID ascending.

Only authoritative natural defeats with positive waves and the exact unassisted human roster are recorded in the terminal transaction. Each player has one best per mode and month, independent of 24-hour match retention. Maintenance removes old rows in bounded batches; reads expose only the two permitted months. A durable month watermark prevents clock rollback from reopening an expired month. No historical results are backfilled.
