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

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class HwndHelper {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]   public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]   public static extern bool IsWindow(IntPtr hWnd);
}
"@ -ErrorAction SilentlyContinue

$hwnd = [IntPtr]::Zero

# 策略1：SessionStart 时前台窗口即为 Windows Terminal（CCswitch 场景可靠）
try {
    $fg = [HwndHelper]::GetForegroundWindow()
    if ($fg -ne [IntPtr]::Zero -and [HwndHelper]::IsWindow($fg)) {
        $hwnd = $fg
    }
} catch {}

# 策略2：直接查找 WindowsTerminal 进程的主窗口
if ($hwnd -eq [IntPtr]::Zero) {
    try {
        $wt = Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue |
              Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
              Select-Object -First 1
        if ($wt) { $hwnd = $wt.MainWindowHandle }
    } catch {}
}

# 策略3：GetConsoleWindow（传统控制台场景）
if ($hwnd -eq [IntPtr]::Zero) {
    try { $hwnd = [HwndHelper]::GetConsoleWindow() } catch {}
}

# 策略4：遍历父进程树查找有主窗口的进程
if ($hwnd -eq [IntPtr]::Zero) {
    try {
        $proc = Get-Process -Id $PID -ErrorAction Stop
        while ($proc -and $proc.MainWindowHandle -eq [IntPtr]::Zero) {
            $parentId = (Get-WmiObject Win32_Process -Filter "ProcessId=$($proc.Id)" `
                         -ErrorAction SilentlyContinue).ParentProcessId
            if (-not $parentId) { break }
            $proc = Get-Process -Id $parentId -ErrorAction SilentlyContinue
        }
        if ($proc -and $proc.MainWindowHandle -ne [IntPtr]::Zero) {
            $hwnd = $proc.MainWindowHandle
        }
    } catch {}
}

# 始终写入文件（即使为0也要写，防止旧的失效 HWND 残留）
$hwnd.ToInt64() | Out-File -FilePath "$env:TEMP\claude-taskbar-hwnd.txt" -Encoding UTF8 -Force

# 启动守护进程（后台常驻，预加载 DLL，监听信号文件）
# 每次 SessionStart 都无条件启动新守护进程，旧实例检测到 PID 文件变化后自行退出
$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Start-Process powershell -ArgumentList @(
    "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden",
    "-File", "`"$scriptsDir\hook-taskbar-daemon.ps1`""
) -WindowStyle Hidden -ErrorAction SilentlyContinue
