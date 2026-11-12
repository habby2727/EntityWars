param([ValidateSet('up', 'status', 'down')][string]$Command = 'status')

$compose = Join-Path $PSScriptRoot 'compose.test.yaml'
switch ($Command) {
    'up' { docker compose -p entitywars-test-infra -f $compose up -d --wait }
    'status' { docker compose -p entitywars-test-infra -f $compose ps }
    'down' { docker compose -p entitywars-test-infra -f $compose down }
}
exit $LASTEXITCODE
