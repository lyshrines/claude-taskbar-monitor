<#
.SYNOPSIS
    Claude Code Hook: Notification - Claude 发送通知时
.DESCRIPTION
    当 Claude Code 需要用户注意（请求权限审批、网络问题、等待输入等）时触发。
    设置为警告状态：任务栏图标变黄色高亮。

    立即写入状态文件（先于信号），避免用户快速确认时 PreToolUse 产生竞争条件。
    通过 send-taskbar.ps1 信号守护进程，响应时间 <50ms（原来 3-5s）。
#>
$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }

$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$stateFile  = "$env:TEMP\claude-taskbar-state.txt"

# 立即写入状态（先于信号），避免 PreToolUse 因竞争读到旧值
try { "warning" | Out-File -FilePath $stateFile -Encoding UTF8 -NoNewline -Force } catch {}

# 通过守护进程更新任务栏（快速路径 <50ms）
& "$scriptsDir\send-taskbar.ps1" -Status warning
