<#
.SYNOPSIS
    Claude Code Hook: Notification - Claude 发送通知时
.DESCRIPTION
    当 Claude Code 需要用户注意（请求权限审批、网络问题、等待输入等）时触发。
    设置为警告状态：红色圆圈 + 任务栏图标变黄色高亮。

    Hook 输入（stdin）为 JSON，包含 message 等通知内容。
#>
$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }

$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 读取通知内容（可选，用于调试）
# $notification = $input | Out-String | ConvertFrom-Json

# 所有 Notification 事件均视为需要用户注意 → 警告状态
& "$scriptsDir\taskbar-overlay.ps1" -Status warning
