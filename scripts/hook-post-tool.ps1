<#
.SYNOPSIS
    Claude Code Hook: PostToolUse - 工具调用后
.DESCRIPTION
    工具执行完毕时触发（= 用户已确认权限 + 工具已运行）。
    若当前状态为 warning，清除为 idle，让守护进程撤销黄色。
    仅在 warning 状态时操作，避免对无权限弹框的普通工具调用产生额外写入。
#>
param()
$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }

$stateFile  = "$env:TEMP\claude-taskbar-state.txt"
$signalFile = "$env:TEMP\claude-taskbar-signal.txt"

try {
    $state = [System.IO.File]::ReadAllText($stateFile).Trim()
    if ($state -eq "warning") {
        [System.IO.File]::WriteAllText($stateFile,  "idle")
        [System.IO.File]::WriteAllText($signalFile, "idle")
    }
} catch {}
