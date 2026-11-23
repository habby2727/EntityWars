Ã¯Â»Â¿# Forest multiplayer: operator checklist

Keep `FOREST_WS_ENABLED=0` until a separate activation decision. The default minimum build remains 5509; do not change it without a release plan.

1. Run the Forest and global-chat backend tests, backend build, Godot headless import and Forest smoke locally. Run `cd backend; bun run src/tests/forest_load.ts`, then run the pending authenticated load and fault tests below and resolve failures.
2. Export the current release client and verify compatibility with the deployed server and protocol. Verify Android and network QA before recommending public activation.
3. Back up the database, persistent volumes, configuration and currently deployed image; verify the restore procedure.
4. Deploy only through the established operational process, with Forest disabled. Check API, PostgreSQL and Redis health and logs; verify `/ws` debug protection and both logout routes.
5. In a private environment with separate test accounts, enable Forest for a controlled real-user smoke: same-room presence, all ten directed portals, cosmetics, leave, suspend and return, duplicate login, logout, server restart, packet loss and reconnection. Verify server names and no cross-room avatars. Do not record credentials in logs or files.
6. Monitor errors, connection counts, queues, CPU, memory, bandwidth, Redis lease health and reconnection behavior. Establish limits and stop criteria before any activation.
7. Only after release-client compatibility and Android/network QA are verified, decide separately whether to activate. If behavior degrades, disable Forest and roll back the image/configuration using the verified backup procedure; check health and client recovery.

## Pending QA

- On a physical Android device or emulator, check 1080p/720p and device aspect ratios: joystick drag/release, talk, leave, mask at top right, selection confirm/cancel, foreground/background, Wi-Fi loss/recovery and portal transitions. Check clipping, touch targets and localization in English and Spanish. An emulator does not replace physical-device network and touch testing.
- Run 50 and 100 authenticated clients distributed across six rooms and 50 in one room; measure updates/s, bytes/s, queue peaks, pending nodes, memory and CPU. Exercise idle, churn, portal cycling, duplicate login and shutdown; verify isolation and bounded resources.
- Verify delayed handshakes, 401/403/409/426/404, Caddy/API restart, Redis lease outage, account changes, packet loss during handoff and server close before acknowledgement against an isolated deployment. Confirm no stale identity or peer returns, and no retry storm.
- Test disabled-account handshake with real PostgreSQL. Confirm suspended state expires after 15 minutes, unexpected disconnect state after two minutes, and leave deletes it.
- Check visual interpolation and direction changes under jitter and repeated zone visits. Verify all three summoners, nameplates, shadows, depth, texture/node stability and selector resume.

## F4C.1 local QA record

The load runner is a deterministic **in-process simulation**, not authenticated WebSockets. It uses the production room service and catalog with fake sockets and a virtual clock; it does not start Redis or a database. Setup reaches rooms via validated walks and portals. It checks snapshots/events for room isolation, peer cleanup, and the 200 ms spacing of successive broadcasts. It does not measure network latency, socket backpressure, database writes or memory leaks. The in-process RSS includes both service and simulated clients; samples are not a process-isolated server peak. CPU covers setup, measured loop and teardown. The 30 virtual-second workloads take less than one real second and do not establish real-time capacity. D also advances the clock during portal walks, so its virtual interval is longer; accepted move rate counts only the regular workload, not the traversal moves, while delivered traffic includes traversals.

Example local run (Bun 1.3.8, Windows; RSS MiB, CPU milliseconds user/system):

| Scenario | Peak clients | Virtual seconds | Regular accepted moves/s | Delivered peer moves/s | Outbound bytes/s | RSS before / sampled peak / after | CPU user / system |
| --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
| 50 across six rooms | 50 | 30 | 250 | 1,840 | 148,073 | 151.2 / 193.6 / 194.0 | 172 / 15 |
| 100 across six rooms | 100 | 30 | 500 | 7,840 | 631,555 | 194.0 / 211.3 / 210.2 | 500 / 16 |
| 50 in one room | 50 | 30 | 250 | 12,250 | 980,980 | 210.2 / 214.2 / 211.1 | 484 / 31 |
| 50 with churn | 50 | 100.75 | 74.4 | 579.3 | 47,316 | 211.1 / 211.6 / 211.6 | 141 / 0 |

The occupancy distributions were 9/9/8/8/8/8 and 17/17/17/17/16/16; the concentrated case used 50 in the clearing. Churn performed ten reconnects and portal walks. Simulated enters were 50, 100, 50 and 60 respectively, with no failed simulated enters. Latency and outbound queue peaks are unavailable. Run each scenario in a fresh process for meaningful independent memory comparisons; the example runs sequentially and retains allocator state.

Automated local results: Godot headless offline smoke, a local authenticated smoke with one Godot client and two raw WebSocket peers, backend Forest/global-chat tests, backend build and Godot headless import passed. The live smoke covers movement, a portal, cross-room isolation, suspend ACK, resume and leave ACK. Godot previously lost an ACK when the server close frame arrived in the same poll; the server now sends the ACK and provides a 500 ms fallback close for older clients. This is not a guarantee that an ACK survives a stalled or failed transport: navigation remains bounded and the next welcome is authoritative.

Fault coverage status:

- **PASSED (automated, limited):** simulated 2-minute disconnect and 15-minute suspend expiry, leave, duplicate session/old socket, all ten directed portals, peer isolation and coalescing; local authenticated 401/409/426, disabled endpoint 404, logout eviction, Redis lease fencing/outage and recovery; real Bun socket ACK ordering; local Godot suspend/resume/leave ACK.
- **NOT TESTED:** real PostgreSQL disabled-account handshake/sweep (Docker daemon and PostgreSQL binaries unavailable); 403; authenticated 50/100-client load, queues and DB/Redis write counts; lost/delayed ACK and terminal close or timeout in Godot, stalled TCP, account switch during pending operations, portal timeout/restart, Caddy restart, two concurrent Godot clients, jitter/memory soak; real deployed-server smoke.
- **NOT TESTED (manual):** visual desktop checks and Android touch, layout, background/foreground and network checks. Headless geometry tests do not establish visual or device correctness.

Before activation, complete these pending tests, ship a compatible release client, and verify Android and network behavior on target devices. Keep credentials out of logs and artifacts. No activation or deployment was performed as part of this record.
