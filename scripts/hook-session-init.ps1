<#
.SYNOPSIS
    Claude Code 会话启动时保存控制台窗口句柄（HWND）
.DESCRIPTION
    Claude Code Hook: PreToolUse / 首次运行时调用。
    将当前 PowerShell 控制台窗口的 HWND 保存到临时文件，
    供后续 Hook 子进程读取，解决 Windows Terminal 下句柄获取问题。
#>
$ErrorActionPreference = "SilentlyContinue"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class HwndHelper {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
}
"@ -ErrorAction SilentlyContinue

$hwnd = [HwndHelper]::GetConsoleWindow()

# 若 GetConsoleWindow 返回 0（Windows Terminal 场景），
# 尝试从进程树找父进程的主窗口
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

if ($hwnd -ne [IntPtr]::Zero) {
    $hwnd.ToInt64() | Out-File -FilePath "$env:TEMP\claude-taskbar-hwnd.txt" -Encoding UTF8 -Force
}

# 预热 DLL 编译：在后台静默执行一次 taskbar-overlay，
# 首次运行时编译 C# 并保存 DLL，后续 hook 调用可快速加载（< 500ms）
$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$dllPath = "$env:TEMP\ClaudeTaskbarOverlay.dll"
if (-not (Test-Path $dllPath)) {
    Start-Process powershell -ArgumentList "-NoProfile -NonInteractive -WindowStyle Hidden -File `"$scriptsDir\taskbar-overlay.ps1`" -Status idle" -WindowStyle Hidden -ErrorAction SilentlyContinue
}
