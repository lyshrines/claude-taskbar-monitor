<#
.SYNOPSIS
    Claude Code Hook: PostToolUse - 工具调用后
.DESCRIPTION
    AI 完成一个工具调用时触发。目前无操作。
    warning 状态的清除由 PreToolUse 负责（用户确认后下次工具调用前清除），
    不在此处处理，避免在用户尚未确认权限时提前清除黄色。
    Hook 输入（stdin）为 JSON，包含 tool_name / tool_input / tool_response。
#>
param()
$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }
