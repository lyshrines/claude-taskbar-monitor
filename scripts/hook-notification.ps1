<#
.SYNOPSIS
    Claude Code 适配器: Notification → taskbar-cli notify
.DESCRIPTION
    Claude Code Hook: Notification。当 AI 需要用户注意时触发（权限审批、等待输入等）。
    将事件转发给 taskbar-cli.ps1，任务栏变黄提醒用户。
#>
$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }

$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptsDir\taskbar-cli.ps1" -Action notify
