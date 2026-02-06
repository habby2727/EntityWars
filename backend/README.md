# Entity Wars Backend

## Run the server

From `backend/`:

```bash
bun install
bun run migrate
bun run dev
```

The server listens on `http://0.0.0.0:8787` by default.

## Run the worker

In another terminal:

```bash
bun run worker
```

## Postgres + Redis (local)

This backend runs without Docker. Install and run Postgres + Redis locally, then set env vars in `backend/.env.example`.

Minimum setup:
- Create a Postgres database named `entity_wars` and update `DATABASE_URL` if needed.
- Start Redis on `127.0.0.1:6379` or update `REDIS_URL`.

Example commands (Windows):
- Start Postgres service: `net start postgresql-x64-18` (adjust service name)
- Start Redis service: `net start Redis`

Optional on-boot examples:
- `PG_EXAMPLE=1` runs a simple Postgres create/insert/select.
- `REDIS_EXAMPLE=1` runs a simple Redis set/get.

## Quick auth test (v1)

```bash
curl -X POST http://127.0.0.1:8787/v1/auth/login \\
  -H "Content-Type: application/json" \\
  -d '{\"name\":\"DevUser\"}'
```

Copy `access_token` from the response, then:

```bash
curl http://127.0.0.1:8787/player/state \\
  -H "Authorization: Bearer <access_token>"
```

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
- `DATABASE_URL` (default: `postgres://postgres:postgres@127.0.0.1:5432/entity_wars`)
- `REDIS_URL` (default: `redis://127.0.0.1:6379/0`)
- `PG_POOL_SIZE` (default: `10`)
- `PG_IDLE_TIMEOUT_SECONDS` (default: `30`)
- `PG_CONNECT_TIMEOUT_SECONDS` (default: `10`)
- `PG_MAX_LIFETIME_SECONDS` (default: `0` = disabled)
- `PG_EXAMPLE` (set to `1` to run the Postgres example on boot)
- `REDIS_EXAMPLE` (set to `1` to run the Redis example on boot)
- `ACCESS_TTL_SECONDS` (default: `900`)
- `REFRESH_TTL_SECONDS` (default: `1209600`)
- `CORS_ORIGINS` (comma-separated list)
- `MAX_BODY_BYTES` (default: `262144`)

Notes:
- The tests will seed player states directly in the dev SQLite DB to set up scenarios.
- The test runner prints PASS/FAIL per group and exits non-zero on failures.
