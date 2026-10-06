param([int]$Port = 8060, [switch]$NoBrowser)

$ErrorActionPreference = 'Stop'
$taskGameUrl = "http://localhost:$Port"
$taskServerReady = $false
try {
    $taskServerReady = (Invoke-RestMethod -Uri "$taskGameUrl/health" -TimeoutSec 1).game -eq 'StrawberryWalk'
} catch { }
if (-not $taskServerReady) {
    $taskNodePath = (Get-Command node -ErrorAction Stop).Source
    $taskServerScript = Join-Path $PSScriptRoot 'tools\serve_web.mjs'
    $taskServerArguments = @(('"{0}"' -f $taskServerScript), '--port', "$Port")
    Start-Process -FilePath $taskNodePath -ArgumentList $taskServerArguments -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $PSScriptRoot 'artifacts\web-server.log') -RedirectStandardError (Join-Path $PSScriptRoot 'artifacts\web-server-errors.log') | Out-Null
}
Write-Output "Computer: $taskGameUrl"
Write-Output "Use the computer's Wi-Fi IP and this port on your phone."
if (-not $NoBrowser) {
    Start-Sleep -Milliseconds 500
    Start-Process -FilePath $taskGameUrl -WindowStyle Hidden
}
