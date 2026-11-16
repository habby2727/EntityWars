#!/bin/sh
set -eu
# Hex-only values are safe in the PostgreSQL and Redis connection URLs.
for name in POSTGRES_PASSWORD REDIS_PASSWORD TOKEN_SIGNING_SECRET EXPERIMENT_SECRET TRADE_SECRET WORLD_SECRET; do
    eval "value=\${$name:-}"
    if ! printf '%s' "$value" | grep -Eq '^[0-9a-fA-F]{64}$'; then
        echo "$name must be an independent 64-character hexadecimal secret" >&2
        exit 1
    fi
done
export DATABASE_URL="postgres://entitywars:${POSTGRES_PASSWORD}@postgres:5432/entitywars"
export REDIS_URL="redis://:${REDIS_PASSWORD}@redis:6379/0"
bun run src/migrate.ts
exec bun run src/index.ts
