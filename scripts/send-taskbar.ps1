<#
.SYNOPSIS
    任务栏状态分发器 - 优先使用守护进程（快），回退到直接调用（慢）
.DESCRIPTION
    供所有 hook 脚本调用，替代直接调用 taskbar-overlay.ps1。
    - 守护进程存活：写信号文件，<1ms 返回，守护进程 <50ms 更新任务栏
    - 守护进程不存在：回退直接调用（3-5s），同时在后台重启守护进程
#>
param([string]$Status = "idle")
$ErrorActionPreference = "SilentlyContinue"

$signalFile = "$env:TEMP\claude-taskbar-signal.txt"
$pidFile    = "$env:TEMP\claude-taskbar-daemon.pid"
$stateFile  = "$env:TEMP\claude-taskbar-state.txt"

# 更新状态文件（pre/post tool hook 依赖此文件判断当前状态）
if ($Status -ne "busy") {
    try { $Status | Out-File $stateFile -Encoding UTF8 -NoNewline -Force } catch {}
}

# 检查守护进程是否存活
$daemonAlive = $false
try {
    $storedPid = [System.IO.File]::ReadAllText($pidFile).Trim()
    if ($storedPid -and $storedPid -match '^\d+$') {
        $daemonAlive = ($null -ne (Get-Process -Id ([int]$storedPid) -ErrorAction SilentlyContinue))
    }
} catch {}

if ($daemonAlive) {
    # 快速路径：信号守护进程，本调用 <1ms 返回
    try { $Status | Out-File $signalFile -Encoding UTF8 -NoNewline -Force } catch {}
} else {
    # 回退路径：直接调用（慢，约 3-5s）
    $scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    & "$scriptsDir\taskbar-overlay.ps1" -Status $Status

    # 同时在后台重启守护进程（下次调用就快了）
    try {
        Start-Process powershell -ArgumentList @(
            "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden",
            "-File", "`"$scriptsDir\hook-taskbar-daemon.ps1`""
        ) -WindowStyle Hidden -ErrorAction SilentlyContinue
    } catch {}
}
