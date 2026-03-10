<#
.SYNOPSIS
    Claude Code Hook: Notification wrapper
.DESCRIPTION
    Notification 事件触发时，直接调用 overlay 设置 warning 状态（可靠性优先）。
    同时同步 signal file，确保 daemon 的 lastStatus 更新为 "warning"，
    使后续 "idle" 信号能被 daemon 检测到变化并正确清除。
#>
$ErrorActionPreference = "SilentlyContinue"

# 调试日志：确认 hook 是否被触发
try { "$(Get-Date -Format 'HH:mm:ss') notification-wrapper fired" | Add-Content "C:\Users\tangyutian.IN.000\hook-notification.log" } catch {}

$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 走快路径：send-taskbar.ps1 会优先写信号文件让守护进程处理（<100ms），
# 守护进程不存在时自动回退慢路径并在后台重启守护进程
& "$scriptsDir\send-taskbar.ps1" -Status warning
