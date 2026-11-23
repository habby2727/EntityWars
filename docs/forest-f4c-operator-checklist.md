# Forest multiplayer: operator checklist

Keep `FOREST_WS_ENABLED=0` until a separate activation decision. The default minimum build remains 5509; do not change it without a release plan.

1. Run the Forest and global-chat backend tests, backend build, Godot headless import and Forest smoke locally. Run the pending load and fault tests below and resolve failures.
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
