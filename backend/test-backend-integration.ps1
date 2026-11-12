param([switch]$GodotSmoke)
$ErrorActionPreference = 'Stop'
$project = "entitywars-integration-$PID"
$compose = Join-Path $PSScriptRoot 'compose.test.yaml'
$temp = Join-Path ([IO.Path]::GetTempPath()) ("entitywars-integration-" + [guid]::NewGuid().ToString())
$server = $null
$proxy = $null
$productionServer = $null
$oldLocation = Get-Location
$savedEnv = @{}
foreach ($key in @('DATABASE_URL', 'REDIS_URL', 'DB_PATH', 'NODE_ENV', 'BUN_ENV', 'HOST', 'PORT', 'DEBUG_BYPASS', 'LOGIN_RATE_LIMIT_MAX', 'APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP', 'FORGE_SMOKE_URL', 'FORGE_SMOKE_ISOLATED', 'FORGE_SMOKE_USER_ROOT', 'FORGE_SMOKE_FIXTURE', 'COMBAT_RESTART_TEST', 'LOST_RESPONSE_URL', 'LOST_RESPONSE_PORT', 'LOST_RESPONSE_MARKER', 'LOST_RESPONSE_RESTART', 'TEST_AUTH_USER_ID')) {
    $savedEnv[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
}
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    docker compose -p $project -f $compose up -d --wait
    if ($LASTEXITCODE -ne 0) { throw 'Docker Compose failed to start test services' }
    $pg = (docker compose -p $project -f $compose port postgres 5432).Trim().Split(':')[-1]
    $redis = (docker compose -p $project -f $compose port redis 6379).Trim().Split(':')[-1]
    $env:DATABASE_URL = "postgres://entitywars_test:entitywars_test_only@127.0.0.1:$pg/entitywars_test"
    $env:REDIS_URL = "redis://127.0.0.1:$redis"
    $env:DB_PATH = Join-Path $temp 'test.sqlite'
    $env:NODE_ENV = 'development'
    $env:BUN_ENV = 'development'
    $env:DEBUG_BYPASS = '0'
    $env:LOGIN_RATE_LIMIT_MAX = '50'
    $env:HOST = '127.0.0.1'
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $env:PORT = [string]$listener.LocalEndpoint.Port
    $listener.Stop()
    Set-Location $PSScriptRoot
    bun run src/migrate.ts
    if ($LASTEXITCODE -ne 0) { throw 'Test migrations failed' }
    $server = Start-Process -FilePath (Get-Command bun).Source -ArgumentList 'src/index.ts' -WorkingDirectory $PSScriptRoot -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $temp 'server.out') -RedirectStandardError (Join-Path $temp 'server.err')
    $ready = $false
    for ($i = 0; $i -lt 100; $i++) {
        if ($server.HasExited) { throw "Backend exited: $(Get-Content -Raw (Join-Path $temp 'server.err'))" }
        try { $response = Invoke-RestMethod -Uri "http://127.0.0.1:$($env:PORT)/health" -TimeoutSec 1; $ready = $true; break } catch { Start-Sleep -Milliseconds 100 }
    }
    if (-not $ready) { throw 'Backend health endpoint did not become ready' }
    Write-Output "PASS backend /health on $($env:PORT); PostgreSQL $pg; Redis $redis; SQLite $($env:DB_PATH)"
    $base = "http://127.0.0.1:$($env:PORT)"
    $login = Invoke-RestMethod -Method Post -Uri "$base/v1/auth/login" -ContentType 'application/json' -Body '{"email":"integration@example.test","name":"integration"}'
    if (-not $login.access_token -or -not $login.refresh_token) { throw 'Login did not return tokens' }
    $state = Invoke-RestMethod -Uri "$base/player/state" -Headers @{ Authorization = "Bearer $($login.access_token)" }
    if (-not $state.updated_player_state) { throw 'Authenticated state missing' }
    $refreshBody = @{ refresh_token = $login.refresh_token } | ConvertTo-Json -Compress
    $rotated = Invoke-RestMethod -Method Post -Uri "$base/v1/auth/refresh" -ContentType 'application/json' -Body $refreshBody
    if (-not $rotated.refresh_token -or $rotated.refresh_token -eq $login.refresh_token) { throw 'Refresh token was not rotated' }
    try { Invoke-RestMethod -Method Post -Uri "$base/v1/auth/refresh" -ContentType 'application/json' -Body $refreshBody | Out-Null; throw 'Old refresh token was accepted' } catch { if ($_.Exception.Response.StatusCode.value__ -ne 401) { throw } }
    $logoutBody = @{ refresh_token = $rotated.refresh_token } | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Post -Uri "$base/v1/auth/logout" -ContentType 'application/json' -Headers @{ Authorization = "Bearer $($rotated.access_token)" } -Body $logoutBody | Out-Null
    try { Invoke-RestMethod -Uri "$base/player/state" -Headers @{ Authorization = "Bearer $($rotated.access_token)" } | Out-Null; throw 'Revoked access token was accepted' } catch { if ($_.Exception.Response.StatusCode.value__ -ne 401) { throw } }
    Write-Output 'PASS login, authenticated state, refresh rotation and logout revocation'
    $enabled = Invoke-RestMethod -Method Post -Uri "$base/v1/auth/login" -ContentType 'application/json' -Body '{"email":"integration@example.test","name":"integration"}'
    docker compose -p $project -f $compose exec -T postgres psql -U entitywars_test -d entitywars_test -c "UPDATE users SET disabled = true WHERE email = 'integration@example.test';" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not disable temporary test account' }
    try { Invoke-RestMethod -Uri "$base/player/state" -Headers @{ Authorization = "Bearer $($enabled.access_token)" } | Out-Null; throw 'Disabled account was accepted' } catch { if ($_.Exception.Response.StatusCode.value__ -ne 403) { throw } }
    docker compose -p $project -f $compose exec -T postgres psql -U entitywars_test -d entitywars_test -c "UPDATE users SET disabled = false WHERE email = 'integration@example.test';" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not re-enable temporary test account' }
    Invoke-RestMethod -Uri "$base/player/state" -Headers @{ Authorization = "Bearer $($enabled.access_token)" } | Out-Null
    Write-Output 'PASS disabled and re-enabled PostgreSQL account'
    if ($GodotSmoke) {
        $env:TEMP = [IO.Path]::GetTempPath().TrimEnd('\')
        $env:TMP = $env:TEMP
        Invoke-RestMethod -Method Post -Uri "$base/auth/dev_login" -ContentType 'application/json' -Body '{"name":"godot_forge_smoke"}' | Out-Null
        Invoke-RestMethod -Method Post -Uri "$base/auth/dev_login" -ContentType 'application/json' -Body '{"name":"combat_account_a"}' | Out-Null
        Invoke-RestMethod -Method Post -Uri "$base/auth/dev_login" -ContentType 'application/json' -Body '{"name":"combat_account_b"}' | Out-Null
        Invoke-RestMethod -Method Post -Uri "$base/auth/dev_login" -ContentType 'application/json' -Body '{"name":"lost_response_smoke"}' | Out-Null
        Invoke-RestMethod -Method Post -Uri "$base/auth/dev_login" -ContentType 'application/json' -Body '{"name":"world_gate_smoke"}' | Out-Null
        $env:FORGE_SMOKE_FIXTURE = '1'
        bun run src/tests/seed_godot_forge.ts
        if ($LASTEXITCODE -ne 0) { throw 'Godot fixture preparation failed' }
        $env:APPDATA = Join-Path $temp 'godot-user'
        $env:LOCALAPPDATA = $env:APPDATA
        New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
        $env:FORGE_SMOKE_USER_ROOT = $env:APPDATA
        $env:FORGE_SMOKE_ISOLATED = '1'
        $env:FORGE_SMOKE_URL = $base
        $godot = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { Join-Path ([Environment]::GetFolderPath('Desktop')) 'Godot_v4.6.exe' }
        if (-not (Test-Path -LiteralPath $godot)) { throw 'Set GODOT_BIN to the Godot 4.6 executable' }
        $godotLog = Join-Path $temp 'godot.log'
        $godotArgs = @('--headless', '--path', ('"' + (Split-Path $PSScriptRoot -Parent) + '"'), '--log-file', ('"' + $godotLog + '"'), '--script', 'res://scripts/tests/smoke_forge_backend.gd')
        $godotProcess = Start-Process -FilePath $godot -ArgumentList $godotArgs -WindowStyle Hidden -PassThru
        if (-not $godotProcess.WaitForExit(35000)) { Stop-Process -Id $godotProcess.Id; throw 'Godot smoke test exceeded 35 seconds' }
        if (Test-Path -LiteralPath $godotLog) { Get-Content -LiteralPath $godotLog }
        if ($godotProcess.ExitCode -ne 0) { throw "Godot smoke test failed with exit code $($godotProcess.ExitCode)" }
        Write-Output 'PASS Godot smoke process exit code 0'
        $accountLog = Join-Path $temp 'godot-account.log'
        $accountArgs = @('--headless', '--path', ('"' + (Split-Path $PSScriptRoot -Parent) + '"'), '--log-file', ('"' + $accountLog + '"'), '--script', 'res://scripts/tests/smoke_account_isolation.gd')
        $accountProcess = Start-Process -FilePath $godot -ArgumentList $accountArgs -WindowStyle Hidden -PassThru
        if (-not $accountProcess.WaitForExit(35000)) { Stop-Process -Id $accountProcess.Id; throw 'Godot account test exceeded 35 seconds' }
        if (Test-Path -LiteralPath $accountLog) { Get-Content -LiteralPath $accountLog }
        if ($accountProcess.ExitCode -ne 0) { throw "Godot account test failed with exit code $($accountProcess.ExitCode)" }
        $combatLog = Join-Path $temp 'godot-combat.log'
        $combatArgs = @('--headless', '--path', ('"' + (Split-Path $PSScriptRoot -Parent) + '"'), '--log-file', ('"' + $combatLog + '"'), '--script', 'res://scripts/tests/smoke_combat_accounts.gd')
        $combatProcess = Start-Process -FilePath $godot -ArgumentList $combatArgs -WindowStyle Hidden -PassThru
        if (-not $combatProcess.WaitForExit(35000)) { Stop-Process -Id $combatProcess.Id; throw 'Godot combat test exceeded 35 seconds' }
        if (Test-Path -LiteralPath $combatLog) { Get-Content -LiteralPath $combatLog }
        if ($combatProcess.ExitCode -ne 0) { throw "Godot combat test failed with exit code $($combatProcess.ExitCode)" }
        $env:COMBAT_RESTART_TEST = '1'
        $restartLog = Join-Path $temp 'godot-combat-restart.log'
        $restartArgs = @('--headless', '--path', ('"' + (Split-Path $PSScriptRoot -Parent) + '"'), '--log-file', ('"' + $restartLog + '"'), '--script', 'res://scripts/tests/smoke_combat_accounts.gd')
        $restartProcess = Start-Process -FilePath $godot -ArgumentList $restartArgs -WindowStyle Hidden -PassThru
        if (-not $restartProcess.WaitForExit(35000)) { Stop-Process -Id $restartProcess.Id; throw 'Godot restart test exceeded 35 seconds' }
        if (Test-Path -LiteralPath $restartLog) { Get-Content -LiteralPath $restartLog }
        if ($restartProcess.ExitCode -ne 0) { throw "Godot restart test failed with exit code $($restartProcess.ExitCode)" }
        $env:APPDATA = Join-Path $temp 'world-user'
        $env:LOCALAPPDATA = $env:APPDATA
        New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
        $env:FORGE_SMOKE_USER_ROOT = $env:APPDATA
        $worldLog = Join-Path $temp 'world.log'
        $worldArgs = @('--headless', '--path', ('"' + (Split-Path $PSScriptRoot -Parent) + '"'), '--log-file', ('"' + $worldLog + '"'), '--script', 'res://scripts/tests/smoke_world_entry.gd')
        $worldProcess = Start-Process -FilePath $godot -ArgumentList $worldArgs -WindowStyle Hidden -PassThru
        if (-not $worldProcess.WaitForExit(35000)) { Stop-Process -Id $worldProcess.Id; throw 'World Gate test exceeded 35 seconds' }
        if (Test-Path -LiteralPath $worldLog) { Get-Content -LiteralPath $worldLog }
        if ($worldProcess.ExitCode -ne 0) { throw "World Gate test failed with exit code $($worldProcess.ExitCode)" }
        $env:APPDATA = Join-Path $temp 'forge-debug-user'
        $env:LOCALAPPDATA = $env:APPDATA
        New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
        $env:FORGE_SMOKE_USER_ROOT = $env:APPDATA
        $debugLog = Join-Path $temp 'forge-debug.log'
        $debugArgs = @('--headless', '--path', ('"' + (Split-Path $PSScriptRoot -Parent) + '"'), '--log-file', ('"' + $debugLog + '"'), '--script', 'res://scripts/tests/smoke_forge_debug.gd')
        $debugProcess = Start-Process -FilePath $godot -ArgumentList $debugArgs -WindowStyle Hidden -PassThru
        if (-not $debugProcess.WaitForExit(35000)) { Stop-Process -Id $debugProcess.Id; throw 'Forge debug test exceeded 35 seconds' }
        if (Test-Path -LiteralPath $debugLog) { Get-Content -LiteralPath $debugLog }
        if ($debugProcess.ExitCode -ne 0) { throw "Forge debug test failed with exit code $($debugProcess.ExitCode)" }
        $env:APPDATA = Join-Path $temp 'lost-user'
        $env:LOCALAPPDATA = $env:APPDATA
        New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
        $env:FORGE_SMOKE_USER_ROOT = $env:APPDATA
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $env:LOST_RESPONSE_PORT = [string]$listener.LocalEndpoint.Port
        $listener.Stop()
        $env:LOST_RESPONSE_URL = "http://127.0.0.1:$($env:LOST_RESPONSE_PORT)"
        $env:LOST_RESPONSE_MARKER = Join-Path $temp 'committed.json'
        $proxy = Start-Process -FilePath (Get-Command bun).Source -ArgumentList 'src/tests/lost_response_proxy.ts' -WorkingDirectory $PSScriptRoot -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $temp 'proxy.out') -RedirectStandardError (Join-Path $temp 'proxy.err')
        $proxyReady = $false
        for ($i = 0; $i -lt 100; $i++) {
            if ($proxy.HasExited) { throw "Proxy exited: $(Get-Content -Raw (Join-Path $temp 'proxy.err'))" }
            try { Invoke-RestMethod -Uri "$($env:LOST_RESPONSE_URL)/health" -TimeoutSec 1 | Out-Null; $proxyReady = $true; break } catch { Start-Sleep -Milliseconds 100 }
        }
        if (-not $proxyReady) { throw 'Lost-response proxy did not start' }
        foreach ($phase in @('first', 'restart')) {
            $env:LOST_RESPONSE_RESTART = if ($phase -eq 'restart') { '1' } else { '0' }
            $lostLog = Join-Path $temp "lost-$phase.log"
            $lostArgs = @('--headless', '--path', ('"' + (Split-Path $PSScriptRoot -Parent) + '"'), '--log-file', ('"' + $lostLog + '"'), '--script', 'res://scripts/tests/smoke_lost_response.gd')
            $lostProcess = Start-Process -FilePath $godot -ArgumentList $lostArgs -WindowStyle Hidden -PassThru
            if (-not $lostProcess.WaitForExit(30000)) { Stop-Process -Id $lostProcess.Id; throw "Lost-response $phase timed out" }
            if (Test-Path -LiteralPath $lostLog) { Get-Content -LiteralPath $lostLog }
            if ($lostProcess.ExitCode -ne 0) { throw "Lost-response $phase failed with exit code $($lostProcess.ExitCode): $(Get-Content -Raw (Join-Path $temp 'proxy.err'))" }
            if ($phase -eq 'first' -and -not (Test-Path -LiteralPath $env:LOST_RESPONSE_MARKER)) { throw 'Proxy did not verify the committed response' }
        }
        Write-Output 'PASS Godot account test process exit code 0'
    }
    $devPort = $env:PORT
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $env:PORT = [string]$listener.LocalEndpoint.Port
    $listener.Stop()
    $prodBase = "http://127.0.0.1:$($env:PORT)"
    $env:NODE_ENV = 'production'
    $env:BUN_ENV = 'production'
    $productionServer = Start-Process -FilePath (Get-Command bun).Source -ArgumentList 'src/index.ts' -WorkingDirectory $PSScriptRoot -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $temp 'production.out') -RedirectStandardError (Join-Path $temp 'production.err')
    $env:NODE_ENV = 'development'
    $env:BUN_ENV = 'development'
    $env:PORT = $devPort
    $prodReady = $false
    for ($i = 0; $i -lt 100; $i++) {
        if ($productionServer.HasExited) { throw "Production test server exited: $(Get-Content -Raw (Join-Path $temp 'production.err'))" }
        try { Invoke-RestMethod -Uri "$prodBase/health" -TimeoutSec 1 | Out-Null; $prodReady = $true; break } catch { Start-Sleep -Milliseconds 100 }
    }
    if (-not $prodReady) { throw 'Production test server not ready' }
    Invoke-RestMethod -Uri "$prodBase/player/state" -Headers @{ Authorization = "Bearer $($enabled.access_token)" } | Out-Null
    foreach ($service in @('redis', 'postgres')) {
        docker compose -p $project -f $compose stop $service | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not stop test $service" }
        try {
            Invoke-RestMethod -Uri "$prodBase/player/state" -Headers @{ Authorization = "Bearer $($enabled.access_token)" } -TimeoutSec 15 | Out-Null
            throw "Production accepted a request while $service was unavailable"
        } catch {
            $expected = if ($service -eq 'redis') { 401 } else { 503 }
            if ($_.Exception.Response.StatusCode.value__ -ne $expected) { throw }
        }
        Write-Output "PASS production $service unavailable: HTTP $expected"
        docker compose -p $project -f $compose up -d --wait $service | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not restart test $service" }
        if ($service -eq 'redis') {
            $env:TEST_AUTH_USER_ID = [string]$state.updated_player_state.player_id
            $env:FORGE_SMOKE_FIXTURE = '1'
            bun run src/tests/seed_auth_token.ts
            if ($LASTEXITCODE -ne 0) { throw 'Could not seed isolated Redis token' }
            $enabled.access_token = 'integration-recovery-token'
        }
        $recovered = $false
        for ($i = 0; $i -lt 40; $i++) {
            try {
                Invoke-RestMethod -Uri "$prodBase/player/state" -Headers @{ Authorization = "Bearer $($enabled.access_token)" } -TimeoutSec 2 | Out-Null
                $recovered = $true; break
            } catch { Start-Sleep -Milliseconds 250 }
        }
        if (-not $recovered) { throw "Authentication did not recover after restarting $service" }
        Write-Output "PASS $service recovery"
    }
} finally {
    if ($productionServer -and -not $productionServer.HasExited) { Stop-Process -Id $productionServer.Id; $productionServer.WaitForExit() }
    if ($proxy -and -not $proxy.HasExited) { Stop-Process -Id $proxy.Id; $proxy.WaitForExit() }
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id; $server.WaitForExit() }
    foreach ($key in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($key, $savedEnv[$key], 'Process') }
    Set-Location $oldLocation
    docker compose -p $project -f $compose down
    if (Test-Path -LiteralPath $temp) {
        $resolved = (Resolve-Path -LiteralPath $temp).Path
        $prefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if ($resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolved).StartsWith('entitywars-integration-')) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
