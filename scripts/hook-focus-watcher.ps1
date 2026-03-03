<#
.SYNOPSIS
    Claude Code - 窗口焦点监听器
.DESCRIPTION
    当 complete 状态显示后，监听用户是否打开窗口。
    窗口获得焦点后延迟 1 秒清除任务栏图标（若状态仍为 complete）。
    若期间被 warning 或其他状态覆盖，则自动退出不做处理。
#>
$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class FocusHelper {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
}
"@

$hwndFile  = "$env:TEMP\claude-taskbar-hwnd.txt"
$stateFile = "$env:TEMP\claude-taskbar-state.txt"
$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 读取目标窗口 HWND
$hwnd = [IntPtr]::Zero
try {
    $raw = [System.IO.File]::ReadAllText($hwndFile).Trim()
    $hwnd = [IntPtr][long]::Parse($raw)
} catch { exit 0 }

if ($hwnd -eq [IntPtr]::Zero -or -not [FocusHelper]::IsWindow($hwnd)) { exit 0 }

# 轮询焦点（最多等待 2 小时 = 14400 次 * 0.5s）
for ($i = 0; $i -lt 14400; $i++) {
    # 若状态已被 warning/idle 覆盖，放弃清除
    try {
        $currentState = [System.IO.File]::ReadAllText($stateFile).Trim()
        if ($currentState -ne "complete") { exit 0 }
    } catch {}

    $fg = [FocusHelper]::GetForegroundWindow()
    if ($fg -eq $hwnd) {
        # 窗口已获焦点，等 1 秒后再次确认状态
        Start-Sleep -Seconds 1
        try {
            $currentState = [System.IO.File]::ReadAllText($stateFile).Trim()
        } catch { $currentState = "" }
        if ($currentState -eq "complete") {
            & "$scriptsDir\taskbar-overlay.ps1" -Status idle
        }
        exit 0
    }
    Start-Sleep -Milliseconds 500
}
