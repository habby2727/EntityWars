# Entity Wars Backend

## Run the server

From `backend/`:

```bash
bun install
bun run dev
```

The server listens on `http://0.0.0.0:8787` by default.

## Run the full test harness

1) Start the server in one terminal:

```bash
bun run dev
```

2) In another terminal, run:

```bash
bun run test:all
```

Optional env vars:
- `BASE_URL` (default: `http://127.0.0.1:8787`)
- `DB_PATH` (default: `data/dev.sqlite`)
- `RATE_LIMIT_WINDOW_MS` (default: `60000`)
- `RATE_LIMIT_MAX` (default: `60`)

Notes:
- The tests will seed player states directly in the dev SQLite DB to set up scenarios.
- The test runner prints PASS/FAIL per group and exits non-zero on failures.
