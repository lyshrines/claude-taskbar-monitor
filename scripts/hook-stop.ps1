<#
.SYNOPSIS
    Claude Code Hook: Stop - AI 完成本轮回复时
.DESCRIPTION
    当 Claude 结束当前回合（turn）时触发。
    - stop_reason = "error"  → 警告状态（红色圆圈 + 黄色任务栏）
    - stop_reason = 其他     → 完成状态（绿色圆圈），3 秒后自动切换为空闲

    Hook 输入（stdin）为 JSON，包含 stop_reason 等信息。
#>
$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }

$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 读取 Hook 输入
$hookInput = $null
try {
    $rawJson = $input | Out-String
    if ($rawJson.Trim()) {
        $hookInput = $rawJson | ConvertFrom-Json
    }
} catch {}

# 判断停止原因
$stopReason = if ($hookInput -and $hookInput.stop_reason) { $hookInput.stop_reason } else { "end_turn" }

if ($stopReason -match "error|Error|ERROR|exception|timeout|network") {
    # 异常停止 → 警告状态（保持直到用户处理）
    & "$scriptsDir\send-taskbar.ps1" -Status warning
} else {
    # 正常完成 → 绿色圆圈，用户聚焦窗口后 1 秒自动消失
    & "$scriptsDir\send-taskbar.ps1" -Status complete
}
