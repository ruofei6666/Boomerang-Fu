param([switch]$Editor)

$ErrorActionPreference = 'Stop'
$godotCommand = Get-Command godot -ErrorAction SilentlyContinue
$taskGodotPath = if ($godotCommand) { $godotCommand.Source } else { $null }
if (-not $taskGodotPath) {
    $taskGodotInstall = Join-Path $env:LOCALAPPDATA 'Programs\Godot'
    $taskGodotExe = Get-ChildItem -LiteralPath $taskGodotInstall -Recurse -Filter 'Godot*_win64.exe' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($taskGodotExe) { $taskGodotPath = $taskGodotExe.FullName }
}
if (-not $taskGodotPath) {
    throw 'Godot was not found. Open project.godot in Godot 4.7.2 or newer.'
}
$taskLaunchArgs = @('--path', $PSScriptRoot)
if ($Editor) { $taskLaunchArgs += '--editor' }
& $taskGodotPath @taskLaunchArgs

