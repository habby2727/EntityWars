# Core Defense persistence benchmark

Local Windows, Intel i7-9750H (6 cores / 12 logical CPUs), Bun 1.3.8. One baseline run at 449db62 and one modified run. File-backed SQLite uses `journal_mode=WAL`, `synchronous=FULL` (2), `busy_timeout=5000`, default `wal_autocheckpoint=1000`, and the migrations relevant to each revision. No production data.

Each scenario executes 50 consecutive scheduler pulses after seeding each match with 20 allied and 10 enemy units in two groups; these synthetic crowded starting positions are not a replayed natural match. Humans poll once per 10 ticks and attempt an affordable deployment once per 20 ticks. Coop has two polling humans per match. Mixed uses alternating CD solo and WOE 1v1 with one bot (the 1-match mixed case is CD solo). Starting decks are seeded, but server-assigned bot IDs vary, so bot decisions and event counts can vary. WOE human replay responses retain full snapshots, unlike compact CD deployment acknowledgements. There was occasional concurrent test activity on the machine; this is a short, noisy local comparison, not a capacity or VPS estimate.

Pulse latency excludes polling/deployment. Estimated Hz accounts for measured whole-cycle time and a 100 ms minimum cycle, without sleeping. Measured Hz is a separate approximately 1.2-second `setInterval(100)` sample following the 50-pulse workload; it includes one poll per 10 pulses but does not attempt deployments. CPU is process CPU / unslept benchmark wall time, not CPU utilization at real-time 10 Hz.

| Scenario | Matches | Pulse p50 ms before/after | p95 ms before/after | max ms before/after | Measured Hz before/after | Est. Hz before/after | CPU % before/after | WAL MiB before/after |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| solo | 1 | 2.8 / 4.4 | 3.3 / 7.1 | 6.3 / 8.9 | 9.14 / 9.09 | 10.00 / 10.00 | 70 / 39 | 2.46 / 1.56 |
| solo | 8 | 21.2 / 37.0 | 28.8 / 46.7 | 29.3 / 48.9 | 8.90 / 8.80 | 10.00 / 10.00 | 72 / 42 | 3.98 / 3.95 |
| solo | 16 | 42.1 / 71.8 | 83.7 / 93.2 | 92.9 / 94.5 | 8.03 / 8.66 | 9.79 / 9.33 | 43 / 29 | 3.98 / 3.96 |
| solo | 32 | 149.3 / 78.8 | 171.2 / 154.8 | 182.6 / 159.4 | 5.19 / 5.35 | 5.87 / 8.50 | 27 / 42 | 3.98 / 3.95 |
| solo_bot | 1 | 4.6 / 5.3 | 8.1 / 8.6 | 14.4 / 11.0 | 9.11 / 9.20 | 10.00 / 10.00 | 27 / 39 | 2.66 / 1.67 |
| solo_bot | 8 | 36.2 / 35.4 | 49.8 / 188.2 | 54.3 / 270.9 | 8.82 / 8.23 | 10.00 / 9.22 | 34 / 23 | 3.97 / 3.96 |
| solo_bot | 16 | 72.9 / 72.1 | 93.9 / 92.3 | 96.6 / 103.9 | 7.81 / 8.01 | 9.32 / 9.28 | 30 / 23 | 3.97 / 3.95 |
| solo_bot | 32 | 153.4 / 149.6 | 184.7 / 233.3 | 188.8 / 367.1 | 5.81 / 6.19 | 5.69 / 5.44 | 33 / 24 | 3.98 / 3.96 |
| coop | 1 | 4.6 / 4.4 | 7.0 / 6.1 | 8.3 / 8.2 | 9.06 / 9.00 | 10.00 / 10.00 | 32 / 6 | 2.88 / 1.81 |
| coop | 8 | 36.5 / 34.9 | 47.2 / 41.1 | 49.4 / 44.1 | 8.01 / 7.87 | 9.70 / 9.74 | 23 / 29 | 3.96 / 3.98 |
| coop | 16 | 73.3 / 85.7 | 97.7 / 103.3 | 111.9 / 116.4 | 7.37 / 7.65 | 8.57 / 8.19 | 25 / 21 | 3.98 / 3.95 |
| coop | 32 | 152.8 / 144.4 | 180.2 / 189.8 | 189.5 / 283.2 | 5.54 / 5.71 | 5.16 / 5.19 | 29 / 28 | 3.98 / 3.96 |
| mixed | 1 | 4.5 / 4.4 | 7.2 / 5.5 | 7.8 / 9.7 | 9.12 / 9.15 | 10.00 / 10.00 | 24 / 31 | 2.46 / 1.56 |
| mixed | 8 | 35.4 / 36.7 | 48.1 / 55.3 | 50.8 / 106.4 | 8.64 / 8.98 | 10.00 / 9.99 | 38 / 17 | 3.95 / 3.97 |
| mixed | 16 | 69.9 / 69.1 | 85.8 / 86.4 | 95.9 / 99.6 | 8.25 / 8.14 | 9.52 / 9.61 | 27 / 27 | 3.97 / 3.96 |
| mixed | 32 | 147.1 / 142.6 | 164.0 / 171.4 | 180.5 / 181.1 | 5.98 / 6.18 | 6.12 / 6.23 | 27 / 26 | 3.98 / 3.96 |

The WAL column is file size just before a passive checkpoint, not cumulative writes: automatic checkpoints reuse the WAL file. Actual OS write volume was not measured. In the one-match solo run the WAL was 2,583,272 / 1,639,792 bytes and the final passive checkpoint reported 627 / 398 frames, all checkpointed (before / after). At larger counts the WAL approached the default roughly 4 MiB automatic-checkpoint size, so file size is not a measure of total bytes written. All final passive checkpoints reported zero busy and checkpointed all remaining frames.

At 32 matches after the change, average state JSON was 17.5 kB solo, 19.0 kB solo-bot, 18.8 kB coop, and 16.0 kB mixed; average final populations were 34.8 to 37.4 units. Coop produced 354 events / 93,800 event JSON bytes and 155 action records / 40,091 payload-and-response bytes over 320 polls. Mixed produced 274 events / 63,626 event JSON bytes and 80 actions / 236,015 payload-and-response bytes over 160 polls; WOE full-snapshot responses account for much of that action storage. JSON byte totals exclude SQLite index, row, and page overhead.

Reproduce with `bun run src/tests/core_defense_benchmark.ts LABEL` from `backend` on each revision; copy the benchmark source into an isolated baseline checkout first. Each run creates uniquely named temporary SQLite files. The script attempts to remove only those exact files and prints their directory if Windows still holds them. The raw rows are in `core-defense-before.jsonl` and `core-defense-after.jsonl`.
