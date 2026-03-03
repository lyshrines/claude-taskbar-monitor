<#
.SYNOPSIS
    Claude Code Hook: PostToolUse - 工具调用后
.DESCRIPTION
    工具执行完成时触发。
    - 若当前为 warning 状态，说明刚才的 Notification（权限请求）已被用户批准并执行完毕，清除黄色
    - 新的错误由后续 Notification 或 Stop hook 重新触发 warning
#>
param()
$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }

$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$stateFile  = "$env:TEMP\claude-taskbar-state.txt"

try {
    $currentState = [System.IO.File]::ReadAllText($stateFile).Trim()
    if ($currentState -eq "warning") {
        & "$scriptsDir\taskbar-overlay.ps1" -Status idle
    }
} catch {}
