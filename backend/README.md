# Entity Wars Backend

## Persistent local Docker development

From `backend/`, create `.env.local` once with independent random hexadecimal
values. It is ignored by Git. Do not overwrite it after PostgreSQL has been
initialized: its password and signing secret are needed to reuse the volumes.
For example, in PowerShell:

```powershell
if (Test-Path .env.local) { throw '.env.local already exists; keep it' }
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$values = @()
foreach ($length in @(24, 32, 32, 32, 32)) {
    $bytes = New-Object byte[] $length
    $rng.GetBytes($bytes)
    $values += -join ($bytes | ForEach-Object { $_.ToString('x2') })
}
$rng.Dispose()
@("POSTGRES_PASSWORD=$($values[0])", "TOKEN_SIGNING_SECRET=$($values[1])", `
  "EXPERIMENT_SECRET=$($values[2])", "TRADE_SECRET=$($values[3])", `
  "WORLD_SECRET=$($values[4])") | Set-Content -Encoding ascii .env.local
```

Alternatively, use `.env.local.example` as a template and replace every value.
Start and manage the separate `entitywars-local` project:

```powershell
docker compose --env-file .env.local -f compose.local.yaml up -d --build --wait
docker compose --env-file .env.local -f compose.local.yaml ps
docker compose --env-file .env.local -f compose.local.yaml logs -f api
docker compose --env-file .env.local -f compose.local.yaml down
```

`down` removes containers and the project network but retains the three named
SQLite, PostgreSQL and Redis volumes. `down -v` **deletes those volumes and all
local progression**; do not use it unless intentionally discarding the data.
After changing code or static data, run the `up -d --build --wait` command
again. The API runs SQLite and PostgreSQL migrations before starting.

The API is published only on `127.0.0.1:8787`; PostgreSQL and Redis have no host
ports. Compose explicitly enables dev login for the Docker bridge gateway, not
other containers. This is a local development configuration, not production
authentication: anyone with access to the local host can impersonate a dev
account. Production always rejects these login routes. `DEBUG_BYPASS` is off.
Godot defaults to `http://127.0.0.1:8787`; for a future server, set the
`ENTITYWARS_BACKEND_URL` environment variable before launching Godot, or set an
explicit client URL in the scene/script. Server-authoritative combat verification
does not yet exist, so online combat rewards remain unavailable.

### Backup

Backups contain player data, Redis sessions and potentially credentials. Store
them privately, and keep the matching `.env.local` separately and securely.
The following PowerShell example stops the services for a consistent snapshot,
archives the volumes read-only, then starts the original services again:

```powershell
$backup = Join-Path (Get-Location) ("backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backup -ErrorAction Stop | Out-Null
docker compose --env-file .env.local -f compose.local.yaml stop api postgres redis
foreach ($name in @('sqlite', 'postgres', 'redis')) {
    docker run --rm --mount "type=volume,source=entitywars-local_$name,target=/snapshot,readonly" `
      --mount "type=bind,source=$backup,target=/backup" --entrypoint tar entitywars-local-api `
      -czf "/backup/$name.tar.gz" -C /snapshot .
    if ($LASTEXITCODE -ne 0) { throw "Backup failed: $name; services remain stopped" }
}
docker compose --env-file .env.local -f compose.local.yaml up -d --wait
```

### Restore into separate volumes

Restore to a **new** project, never over existing volumes. Set `$backup` to the
absolute directory containing the three archives and use the `.env.local`
that matches that backup. Stop the original project first because both projects
publish port 8787. The random project name ensures Compose creates fresh volumes:

```powershell
$backup = (Resolve-Path '.\backup-YYYYMMDD-HHMMSS').Path
$restore = 'entitywars-restore-' + [guid]::NewGuid().ToString('N').Substring(0, 12)
docker compose --env-file .env.local -f compose.local.yaml stop api postgres redis
docker compose -p $restore --env-file .env.local -f compose.local.yaml create
foreach ($name in @('sqlite', 'postgres', 'redis')) {
    docker run --rm --mount "type=volume,source=${restore}_$name,target=/snapshot" `
      --mount "type=bind,source=$backup,target=/backup,readonly" --entrypoint tar entitywars-local-api `
      -xzf "/backup/$name.tar.gz" -C /snapshot
    if ($LASTEXITCODE -ne 0) { throw "Restore failed: $name; do not start restored services" }
}
docker compose -p $restore --env-file .env.local -f compose.local.yaml up -d --wait
```

The original volumes remain intact. To return to the original project, stop the
restored project and run the normal `up` command above. `compose.test.yaml` and
its disposable test project remain independent of either project.

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

All backend processes serving the same players must use the same SQLite database file. Separate SQLite databases do not share action IDs or player state and are not a supported multi-server deployment. SQLite WAL also requires a filesystem that supports its locking and shared-memory semantics.
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
