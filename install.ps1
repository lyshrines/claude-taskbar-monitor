<#
.SYNOPSIS
    Claude Taskbar Monitor - 瀹夎 / 鍗歌浇鑴氭湰
.EXAMPLE
    # 瀹夎
    powershell -ExecutionPolicy Bypass -File install.ps1
    # 鍗歌浇
    powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
#>
param([switch]$Uninstall)

$ErrorActionPreference = "Stop"
$sourceDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$claudeDir   = "$env:USERPROFILE\.claude"
$scriptsDir  = "$claudeDir\scripts"
$commandsDir = "$claudeDir\commands"
$pluginDir   = "$claudeDir\plugins\local\taskbar-monitor\skills\taskbar-monitor"
$settingsFile = "$claudeDir\settings.json"

$scriptFiles = @(
    "taskbar-overlay.ps1","hook-session-init.ps1","hook-pre-tool.ps1",
    "hook-post-tool.ps1","hook-notification.ps1","hook-stop.ps1","hook-focus-watcher.ps1"
)

if ($Uninstall) {
    Write-Host "Uninstalling Claude Taskbar Monitor..."
    $scriptFiles | ForEach-Object { Remove-Item "$scriptsDir\$_" -ErrorAction SilentlyContinue }
    Remove-Item "$commandsDir\taskbar-monitor.md" -ErrorAction SilentlyContinue
    Remove-Item "$claudeDir\plugins\local\taskbar-monitor" -Recurse -ErrorAction SilentlyContinue
    if (Test-Path $settingsFile) {
        $s = Get-Content $settingsFile -Raw | ConvertFrom-Json
        if ($s.hooks) {
            foreach ($h in @("SessionStart","PreToolUse","PostToolUse","Notification","Stop")) {
                $s.hooks.PSObject.Properties.Remove($h)
            }
        }
        $s | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
    }
    Write-Host "Uninstalled. Restart Claude Code to apply."
    exit 0
}

Write-Host "Installing Claude Taskbar Monitor..."

# Create directories
@($scriptsDir, $commandsDir, $pluginDir) | ForEach-Object {
    New-Item -ItemType Directory -Force -Path $_ | Out-Null
}

# Copy scripts
$scriptFiles | ForEach-Object {
    Copy-Item "$sourceDir\scripts\$_" "$scriptsDir\$_" -Force
}

# Copy command and skill
Copy-Item "$sourceDir\commands\taskbar-monitor.md" "$commandsDir\taskbar-monitor.md" -Force
Copy-Item "$sourceDir\plugin\SKILL.md" "$pluginDir\SKILL.md" -Force

# Update settings.json
$hookMap = [ordered]@{
    SessionStart = "hook-session-init.ps1"
    PreToolUse   = "hook-pre-tool.ps1"
    PostToolUse  = "hook-post-tool.ps1"
    Notification = "hook-notification.ps1"
    Stop         = "hook-stop.ps1"
}

$settings = if (Test-Path $settingsFile) {
    Get-Content $settingsFile -Raw | ConvertFrom-Json
} else {
    [PSCustomObject]@{}
}

if (-not $settings.PSObject.Properties['hooks']) {
    $settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{})
}

foreach ($hookName in $hookMap.Keys) {
    $cmd = "powershell -NoProfile -NonInteractive -WindowStyle Hidden -File `"$scriptsDir\$($hookMap[$hookName])`""
    $entry = @(@{ matcher = ".*"; hooks = @(@{ type = "command"; command = $cmd }) })
    $settings.hooks | Add-Member -NotePropertyName $hookName -NotePropertyValue $entry -Force
}

if (-not $settings.PSObject.Properties['permissions']) {
    $settings | Add-Member -NotePropertyName permissions -NotePropertyValue ([PSCustomObject]@{ allow = @() })
}
if (-not $settings.permissions.PSObject.Properties['allow']) {
    $settings.permissions | Add-Member -NotePropertyName allow -NotePropertyValue @() -Force
}
foreach ($rule in @("Bash(powershell*)", "Bash(sleep*)", "Bash(echo*)")) {
    if ($settings.permissions.allow -notcontains $rule) {
        $settings.permissions.allow += $rule
    }
}

$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
Write-Host ""
Write-Host "Installation complete!"
Write-Host "Please restart Claude Code to activate."