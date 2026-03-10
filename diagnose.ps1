Write-Host '=== HWND 文件 ===' -ForegroundColor Cyan
if (Test-Path "$env:TEMP\claude-taskbar-hwnd.txt") {
    $hwndVal = (Get-Content "$env:TEMP\claude-taskbar-hwnd.txt").Trim()
    Write-Host "内容: $hwndVal"
    if ($hwndVal -match '^\d+$' -and [long]$hwndVal -ne 0) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class WinHelper {
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
}
"@ -ErrorAction SilentlyContinue
        $h = [IntPtr][long]$hwndVal
        $valid = [WinHelper]::IsWindow($h)
        $sb = New-Object System.Text.StringBuilder 256
        [WinHelper]::GetWindowTextW($h, $sb, 256) | Out-Null
        $pid2 = [uint32]0
        [WinHelper]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
        $procName = if ($pid2) { (Get-Process -Id $pid2 -ErrorAction SilentlyContinue).ProcessName } else { "?" }
        Write-Host "IsWindow: $valid"
        Write-Host "窗口标题: '$($sb.ToString())'"
        Write-Host "归属进程: $procName (PID=$pid2)"
    } else {
        Write-Host "值为0或无效！" -ForegroundColor Red
    }
} else {
    Write-Host "hwnd 文件不存在！" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== 守护进程 PID ===" -ForegroundColor Cyan
if (Test-Path "$env:TEMP\claude-taskbar-daemon.pid") {
    $daemonPid = (Get-Content "$env:TEMP\claude-taskbar-daemon.pid").Trim()
    Write-Host "PID: $daemonPid"
    $proc = Get-Process -Id ([int]$daemonPid) -ErrorAction SilentlyContinue
    if ($proc) { Write-Host "进程存活: $($proc.ProcessName)" -ForegroundColor Green }
    else { Write-Host "进程不存在（守护进程已死）" -ForegroundColor Red }
} else {
    Write-Host "PID 文件不存在！" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== 状态文件 ===" -ForegroundColor Cyan
foreach ($f in @("claude-taskbar-state.txt","claude-taskbar-signal.txt")) {
    $p = "$env:TEMP\$f"
    if (Test-Path $p) { Write-Host "${f}: '$(Get-Content $p)'" }
    else { Write-Host "${f}: 不存在" }
}

Write-Host ""
Write-Host "=== 文件同步对比 ===" -ForegroundColor Cyan
$src = "C:\Users\tangyutian.IN.000\claude-taskbar-monitor\scripts"
$dst = "C:\Users\tangyutian.IN.000\.claude\plugins\local\taskbar-monitor\scripts"
Get-ChildItem $src | ForEach-Object {
    $name = $_.Name
    $srcTime = $_.LastWriteTime
    $dstFile = Join-Path $dst $name
    if (Test-Path $dstFile) {
        $dstTime = (Get-Item $dstFile).LastWriteTime
        if ($srcTime -eq $dstTime) {
            Write-Host "${name}: 同步" -ForegroundColor Green
        } else {
            Write-Host "${name}: 不同步  src=$srcTime  dst=$dstTime" -ForegroundColor Yellow
        }
    } else {
        Write-Host "${name}: 目标不存在" -ForegroundColor Red
    }
}
