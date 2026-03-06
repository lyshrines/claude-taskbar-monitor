<#
.SYNOPSIS
    Claude Code 适配器: PreToolUse → taskbar-cli tool-begin
.DESCRIPTION
    Claude Code Hook: PreToolUse。AI 开始执行工具时触发。
    将事件转发给 taskbar-cli.ps1，由其处理 HWND 初始化和活跃轮次标记。
#>
$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }

$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptsDir\taskbar-cli.ps1" -Action tool-begin
