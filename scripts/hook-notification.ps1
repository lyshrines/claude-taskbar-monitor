<#
.SYNOPSIS
    Claude Code Hook: Notification - Claude 发送通知时
.DESCRIPTION
    当 Claude Code 需要用户注意（请求权限审批、网络问题、等待输入等）时触发。
    设置为警告状态：任务栏图标变黄色高亮。

    立即写入状态文件（先于 COM 操作），避免用户快速确认时 PreToolUse 产生竞争条件。
    PreToolUse 检测到 warning 状态后立即清除，确保黄色在用户决策后消失。
#>
$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }

$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$stateFile  = "$env:TEMP\claude-taskbar-state.txt"

# 立即写入状态（先于 COM 操作），避免 PreToolUse 因竞争读到旧值
try { "warning" | Out-File -FilePath $stateFile -Encoding UTF8 -NoNewline -Force } catch {}

# 设置任务栏视觉效果
& "$scriptsDir\taskbar-overlay.ps1" -Status warning
