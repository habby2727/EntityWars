#!/bin/sh
# Run from any directory on the Docker host; downtime is intentional.
set -eu
cd "$(dirname "$0")/.."
umask 077
compose() { docker compose --env-file .env.prod -f compose.prod.yaml "$@"; }
for volume in sqlite postgres redis; do
    docker volume inspect "entitywars-prod_$volume" >/dev/null
done
docker image inspect entitywars-prod-api:local >/dev/null
mkdir -p backups
backup="$(pwd)/backups/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir "$backup"
echo "Stopping API, PostgreSQL and Redis; restart manually if any command fails."
compose stop -t 120 api postgres redis
for service in api postgres redis; do
    id=$(compose ps -aq "$service")
    [ -n "$id" ] && [ "$(docker inspect -f '{{.State.Running}}' "$id")" = false ] || { echo "$service is not stopped" >&2; exit 1; }
    if [ "$service" != api ] && [ "$(docker inspect -f '{{.State.ExitCode}}' "$id")" != 0 ]; then
        echo "$service did not shut down cleanly; snapshot aborted" >&2
        exit 1
    fi
done
for volume in sqlite postgres redis; do
    docker run --rm --user 0 --network none \
        --mount "type=volume,source=entitywars-prod_$volume,target=/snapshot,readonly" \
        --mount "type=bind,source=$backup,target=/backup" \
        --entrypoint tar entitywars-prod-api:local -czf "/backup/$volume.tar.gz" -C /snapshot .
    test -s "$backup/$volume.tar.gz"
done
(cd "$backup" && sha256sum sqlite.tar.gz postgres.tar.gz redis.tar.gz > SHA256SUMS)
echo "Snapshot stored in $backup; restarting services."
compose up -d --wait
echo "Backup complete; verify it by restoring to fresh volumes on an isolated host."
