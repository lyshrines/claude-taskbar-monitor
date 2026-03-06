<#
.SYNOPSIS
    Claude Code 会话启动时保存控制台窗口句柄（HWND）并启动守护进程
.DESCRIPTION
    Claude Code Hook: SessionStart。
    1. 将当前 PowerShell 控制台窗口的 HWND 保存到临时文件
    2. 启动后台守护进程 hook-taskbar-daemon.ps1（预加载 DLL，监听信号）
       守护进程消除每次 hook 调用 Add-Type 的 3-5 秒延迟。
#>
$ErrorActionPreference = "SilentlyContinue"

$hwnd = [IntPtr]::Zero

# 策略1: 优先查找 Windows Terminal 进程（用户主力终端）
try {
    $wtProc = Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue |
              Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
              Select-Object -First 1
    if ($wtProc) {
        $hwnd = $wtProc.MainWindowHandle
    }
} catch {}

# 策略2: 回退到进程树向上遍历（兼容其他终端）
if ($hwnd -eq [IntPtr]::Zero) {
    try {
        $proc = Get-Process -Id $PID -ErrorAction Stop
        while ($proc -and $proc.MainWindowHandle -eq [IntPtr]::Zero) {
            $parentId = (Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)" `
                         -ErrorAction SilentlyContinue).ParentProcessId
            if (-not $parentId) { break }
            $proc = Get-Process -Id $parentId -ErrorAction SilentlyContinue
        }
        if ($proc -and $proc.MainWindowHandle -ne [IntPtr]::Zero) {
            $hwnd = $proc.MainWindowHandle
        }
    } catch {}
}

# 策略3: 最后尝试 GetConsoleWindow（兼容传统 PowerShell 控制台）
if ($hwnd -eq [IntPtr]::Zero) {
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class HwndHelper {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
}
"@ -ErrorAction SilentlyContinue
        $hwnd = [HwndHelper]::GetConsoleWindow()
    } catch {}
}

if ($hwnd -ne [IntPtr]::Zero) {
    $hwnd.ToInt64() | Out-File -FilePath "$env:TEMP\claude-taskbar-hwnd.txt" -Encoding UTF8 -Force
}

# 启动守护进程（后台常驻，预加载 DLL，监听信号文件）
# 若已有存活的守护进程则跳过，避免重复启动
$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pidFile    = "$env:TEMP\claude-taskbar-daemon.pid"

$needStart = $true
if (Test-Path $pidFile) {
    try {
        $storedPid = (Get-Content $pidFile -ErrorAction Stop).Trim()
        if ($storedPid -and $storedPid -match '^\d+$') {
            if (Get-Process -Id ([int]$storedPid) -ErrorAction SilentlyContinue) {
                $needStart = $false
            }
        }
    } catch {}
}

if ($needStart) {
    Start-Process powershell -ArgumentList @(
        "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden",
        "-File", "`"$scriptsDir\hook-taskbar-daemon.ps1`""
    ) -WindowStyle Hidden -ErrorAction SilentlyContinue
}
