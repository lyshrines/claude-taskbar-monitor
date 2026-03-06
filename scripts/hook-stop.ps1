<#
.SYNOPSIS
    Claude Code 适配器: Stop → taskbar-cli complete/error
.DESCRIPTION
    Claude Code Hook: Stop。AI 完成本轮回复时触发。
    解析 stdin 中的 JSON（含 stop_reason），根据结果调用 complete 或 error。
#>
$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }

$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 解析 Claude Code 传入的 JSON（含 stop_reason）
$hookInput = $null
try {
    $rawJson = $input | Out-String
    if ($rawJson.Trim()) {
        $hookInput = $rawJson | ConvertFrom-Json
    }
} catch {}

$stopReason = if ($hookInput -and $hookInput.stop_reason) { $hookInput.stop_reason } else { "end_turn" }

if ($stopReason -match "error|Error|ERROR|exception|timeout|network") {
    & "$scriptsDir\taskbar-cli.ps1" -Action error
} else {
    & "$scriptsDir\taskbar-cli.ps1" -Action complete
}
