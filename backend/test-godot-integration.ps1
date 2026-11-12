$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'test-backend-integration.ps1') -GodotSmoke
