ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â»ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¿# Forest multiplayer: operator checklist

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

The F4C.1 results in this section are the historical **pose-only** in-process simulation, not authenticated WebSockets or sustained movement. It uses the production room service and catalog with fake sockets and a virtual clock; it does not start Redis or a database. Setup reaches rooms via validated walks and portals. It checks snapshots/events for room isolation, peer cleanup, and the 200 ms spacing of successive broadcasts. It does not measure network latency, socket backpressure, database writes or memory leaks. The in-process RSS includes both service and simulated clients; samples are not a process-isolated server peak. CPU covers setup, measured loop and teardown. The 30 virtual-second workloads take less than one real second and do not establish real-time capacity. D also advances the clock during portal walks, so its virtual interval is longer; accepted move rate counts only the regular workload, not the traversal moves, while delivered traffic includes traversals.

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

## F4C.2 ? local validation

**Private controlled VPS test: NO-GO for now.** The local tests do not cover a real PostgreSQL disabled account, a real proxy/network interruption, full two-client portal/scene recovery, Android or release-client compatibility. Finish those checks and the private-smoke preparation above before reconsidering; this is not approval for public activation.

Run from `backend`:

- `bun run src/tests/forest_load.ts` ? in-process movement simulation, virtual clock.
- `bun run src/tests/forest_load_e2e.ts` ? real loopback WebSockets, isolated test SQLite and Redis, normally three 30-second scenarios. Fixture players and Redis bearer records are generated locally as in `seed_auth_token.ts`; the API performs its ordinary auth and idle checks. Credentials are generated at runtime and are not logged.
- `bun run src/tests/forest_transport_fixture.ts` ? Godot against an isolated fake transport, not an authenticated API.
- `bun run src/tests/forest_two_godot_fixture.ts` ? two Godot processes using independent accounts plus a raw WebSocket peer against an isolated authenticated API.

### Simulated actual movement

The runner moves 5 pixels every 200 ms, changes direction within valid polygon segments, uses validated portal walks and confirms final positions on reconnect. Each test advances a virtual clock; these are **not network capacity measurements**. Values below are per virtual second; D includes extra virtual time for the ten portal walks, whose movement requests are excluded from the regular movement numerator.

| Scenario | Clients | Virtual s | Regular move requests/s | Peer-move deliveries/s | Server-to-fake-client bytes/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| Six rooms | 50 | 30 | 250 | 1,840 | 148,073 |
| Six rooms | 100 | 30 | 500 | 7,840 | 631,555 |
| One room | 50 | 30 | 250 | 12,250 | 980,980 |
| Six rooms and ten reconnect/portal cycles | 50 | 101.5 | 73.9 | 575.3 | 46,998 |

The runner checks corrections, 200 ms broadcast spacing, peer isolation/cleanup and saved state. CPU and RSS are printed by the runner and include the simulated clients; they are not server-only measurements.

### Authenticated loopback movement

The following is one run on Windows with Bun 1.3.8, the local API, Redis, SQLite, and clients on loopback. It sends valid 5-pixel moves around short in-polygon segments at a target 5 Hz. Measurements include a 500 ms drain period; movement counts are **attempts**, with zero server corrections and five final positions per scenario confirmed against authoritative reconnect welcomes. Latency is local client send to receipt of a corresponding peer event, including server coalescing and client scheduling; it is not Internet RTT. Bytes are JSON payload bytes, not TCP/TLS wire bandwidth.

| Clients / rooms | Time s | Handshakes (including reconnects), failed | Attempted moves/s | Peer deliveries/s | Sent / received bytes/s | Peer delay p50 / p95 ms |
| --- | ---: | --- | ---: | ---: | --- | --- |
| 50 / six | 30.60 | 55, 0 | 240.2 | 1,617.9 | 13,854 / 183,918 | 11.1 / 192.2 |
| 100 / six | 30.65 | 105, 0 | 473.0 | 6,811.0 | 27,274 / 774,126 | 37.6 / 209.6 |
| 50 / one | 30.61 | 55, 0 | 238.5 | 10,561.7 | 13,655 / 1,196,215 | 95.3 / 219.3 |

| Clients / rooms | API RSS before / process-lifetime peak / after client teardown MiB | API CPU seconds over measurement plus reconnections/teardown | Client outbound buffered peak |
| --- | --- | ---: | ---: |
| 50 / six | 191.2 / 199.4 / 188.8 | 3.58 | 0 bytes |
| 100 / six | 194.4 / 207.5 / 188.4 | 7.30 | 0 bytes |
| 50 / one | 198.6 / 202.7 / 196.0 | 10.42 | 0 bytes |

Six-room occupancies were 9/9/8/8/8/8 and 17/17/17/17/16/16. All sessions connected using bearer tokens, five reconnected in each scenario, and a remaining witness observed all peers leave. Each target room was reached through validated walking and portal requests. The API peak is OS-reported over its process lifetime, including setup; after-teardown RSS is before API exit. The client buffer number is sampled immediately after sends; server-side queues, TCP backpressure and DB/Redis writes were not measured. This local test is not production or VPS capacity evidence. The real 50-client ten-reconnect/portal churn scenario remains NOT TESTED; only five reconnects per measured run and the simulated ten-cycle case were exercised.

### Fault matrix

| Fault | Status and limit |
| --- | --- |
| Immediate ACK, 400 ms delayed ACK, close before ACK, withheld ACK/stalled socket, duplicate handoff and generation change during handoff | PASSED in Godot against the isolated fake transport; the withheld ACK completes within the bounded deadline. Full menu navigation and a real transport proxy remain untested. |
| Old delayed close after a replacement session | PASSED with two real Bun WebSockets against the room service; the replacement stays open and responds. Timer accumulation under sustained handoff churn is NOT TESTED. |
| Two-minute disconnect, 15-minute suspend and leave | PASSED service tests with virtual time; no real 15-minute wait. |
| Duplicate session, stale old socket, ten directed portals, corrections and room isolation | PASSED service tests; not all ten portals exercised by both Godot processes. |
| Missing/invalid/expired token, 401/409/426/404, Redis lease fencing/outage, API restart and both logout paths | PASSED within the existing isolated tests, subject to their SQLite/test configuration. |
| Delayed old-socket messages, identity change during handshake or pending portal, stalled/dropped actual TCP, API restart during portal, reconnect storm | NOT TESTED. |
| Disabled-account 403 and mid-session sweep on real PostgreSQL | NOT TESTED: local PostgreSQL binaries and Docker daemon were unavailable. |
| Two Godot accounts plus third peer | PASSED for reciprocal presence, server names, movement and cosmetic messages. Portal traversal, disconnect/rejoin and remote sprite duplication with both processes are NOT TESTED. |
| Desktop visual and Android touch/device QA | NOT TESTED. |

F4C.2 changes are limited to the movement simulation, new authenticated loopback/transport/two-process fixtures, an old-socket fallback-close regression test, and extensions to the existing Godot smoke. No product defect was reproduced and no gameplay, authentication semantics, production Compose, minimum build or Forest activation was changed. On a real desktop/device, manually check 1080p, 720p and a non-16:9 aspect ratio; joystick and touch NPC action, mask tooltip/accessibility and confirm/cancel, portals, nameplates, EN/ES, foreground/background and Wi-Fi interruption/recovery. Confirm the current release client matches the server protocol before any VPS smoke.
