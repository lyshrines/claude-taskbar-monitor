<#
.SYNOPSIS
    Claude Code Hook: PostToolUse - 工具调用后
.DESCRIPTION
    AI 完成一个工具调用时触发。
    - 检查工具响应是否包含错误
    - 有错误 → 警告状态（红色圆圈 + 任务栏图标变黄色）
    - 无错误 → 保持繁忙状态（可能还有后续工具调用）

    Hook 输入（stdin）为 JSON，包含 tool_name / tool_input / tool_response。
#>
param()
$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }

$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$stateFile  = "$env:TEMP\claude-taskbar-state.txt"

# 若当前为 warning 状态，说明刚才的 Notification 已被用户批准并执行完毕，清除黄色
try {
    $currentState = [System.IO.File]::ReadAllText($stateFile).Trim()
    if ($currentState -eq "warning") {
        & "$scriptsDir\send-taskbar.ps1" -Status idle
    }
} catch {}
