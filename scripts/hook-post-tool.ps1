<#
.SYNOPSIS
    Claude Code 适配器: PostToolUse → taskbar-cli tool-end
.DESCRIPTION
    Claude Code Hook: PostToolUse。AI 工具调用完成时触发。
    将事件转发给 taskbar-cli.ps1，由其判断是否需要清除 warning 状态。
#>
param()
$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }

$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptsDir\taskbar-cli.ps1" -Action tool-end
