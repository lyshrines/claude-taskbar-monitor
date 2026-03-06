<#
.SYNOPSIS
    Taskbar Monitor - 统一 CLI 入口（工具无关）
.DESCRIPTION
    提供语义化的 -Action 参数，任何 AI 编码工具都可以通过此脚本控制任务栏状态。
    内部调用 send-taskbar.ps1（快速路径）和 hook-session-init.ps1（初始化）。

    这是整个 Taskbar Monitor 的唯一对外接口。Claude Code 的 hook 脚本、
    Cursor 扩展、Aider 插件等都应该调用此脚本，而非直接操作信号文件。

.PARAMETER Action
    语义化动作：
      start       - 初始化窗口句柄 (HWND) 并启动守护进程
      tool-begin  - AI 开始执行工具（标记活跃轮次，确保守护进程已启动）
      tool-end    - AI 工具执行完毕（仅当前为 warning 时清除为 idle）
      notify      - 需要用户注意（任务栏变黄）
      complete    - AI 正常完成回复（任务栏变绿，聚焦窗口后自动消失）
      error       - AI 异常结束（任务栏变黄警告）
      idle        - 手动清除所有状态

.EXAMPLE
    # 初始化（会话启动时调用一次）
    .\taskbar-cli.ps1 -Action start

    # AI 正常完成
    .\taskbar-cli.ps1 -Action complete

    # 需要用户操作
    .\taskbar-cli.ps1 -Action notify

    # 清除状态
    .\taskbar-cli.ps1 -Action idle
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("start", "tool-begin", "tool-end", "notify", "complete", "error", "idle")]
    [string]$Action
)

$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }

$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$stateFile  = "$env:TEMP\claude-taskbar-state.txt"
$hwndCache  = "$env:TEMP\claude-taskbar-hwnd.txt"

switch ($Action) {

    # ── 初始化：保存 HWND + 启动守护进程 ──────────────────────────────────────
    "start" {
        & "$scriptsDir\hook-session-init.ps1"
    }

    # ── 工具开始：确保守护进程存活 + 标记活跃轮次 ──────────────────────────────
    "tool-begin" {
        if (-not (Test-Path $hwndCache)) {
            & "$scriptsDir\hook-session-init.ps1"
        }
        try {
            "1" | Out-File -FilePath "$env:TEMP\claude-taskbar-active-turn.txt" `
                           -Encoding UTF8 -NoNewline -Force
        } catch {}
    }

    # ── 工具结束：仅当 warning 时清除（避免覆盖 complete 等状态）──────────────
    "tool-end" {
        try {
            $currentState = [System.IO.File]::ReadAllText($stateFile).Trim()
            if ($currentState -eq "warning") {
                & "$scriptsDir\send-taskbar.ps1" -Status idle
            }
        } catch {}
    }

    # ── 通知：需要用户注意 → 黄色 ────────────────────────────────────────────
    "notify" {
        # 先写状态文件（防竞态：其他 hook 可能同时读取状态）
        try {
            "warning" | Out-File -FilePath $stateFile -Encoding UTF8 -NoNewline -Force
        } catch {}
        & "$scriptsDir\send-taskbar.ps1" -Status warning
    }

    # ── 正常完成 → 绿色 ──────────────────────────────────────────────────────
    "complete" {
        & "$scriptsDir\send-taskbar.ps1" -Status complete
    }

    # ── 异常结束 → 黄色警告 ──────────────────────────────────────────────────
    "error" {
        & "$scriptsDir\send-taskbar.ps1" -Status warning
    }

    # ── 手动清除 ──────────────────────────────────────────────────────────────
    "idle" {
        & "$scriptsDir\send-taskbar.ps1" -Status idle
    }
}
