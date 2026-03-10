$src = 'C:\Users\tangyutian.IN.000\claude-taskbar-monitor\scripts'
$dst = 'C:\Users\tangyutian.IN.000\.claude\scripts'
$files = @('hook-session-init.ps1','hook-pre-tool.ps1','hook-post-tool.ps1','hook-stop.ps1','hook-taskbar-daemon.ps1','send-taskbar.ps1','taskbar-overlay.ps1','hook-focus-watcher.ps1','notify-warning.bat','notify-complete.bat','notify-idle.bat')
foreach ($f in $files) {
    Copy-Item (Join-Path $src $f) (Join-Path $dst $f) -Force
    Write-Host "Synced: $f"
}
Write-Host "Done. Please restart Claude Code."
