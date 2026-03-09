<#
.SYNOPSIS
    Claude Code Hook: PreToolUse - 工具调用前
.DESCRIPTION
    AI 开始执行工具时触发。
    - 首次运行时保存 HWND 并确保守护进程启动
    - 若当前为 warning 状态，说明用户已处理完毕，清除黄色
    Hook 输入（stdin）为 JSON，包含 tool_name 和 tool_input。
#>
$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }

$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$hwndCache  = "$env:TEMP\claude-taskbar-hwnd.txt"

# 首次调用时初始化 HWND 缓存（也会确保守护进程启动）
if (-not (Test-Path $hwndCache)) {
    & "$scriptsDir\hook-session-init.ps1"
}

# 若当前为 warning 状态，说明用户已批准操作，清除黄色
$stateFile = "$env:TEMP\claude-taskbar-state.txt"
try {
    $currentState = [System.IO.File]::ReadAllText($stateFile).Trim()
    if ($currentState -eq "warning") {
        & "$scriptsDir\send-taskbar.ps1" -Status idle
    }
} catch {}
