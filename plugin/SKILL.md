---
user-invocable: false
---

# Taskbar Monitor - 任务栏状态监控系统

## 概述

本插件通过 Windows ITaskbarList3 COM 接口，在任务栏图标上显示彩色覆盖图标，
实时反映 AI 编码工具的工作状态。用户无需切换窗口即可了解当前进度。

采用分层架构：核心层（工具无关）+ 适配器层（Claude Code hooks）。
其他 AI 工具可直接调用 `taskbar-cli.ps1` 集成。

## 状态定义

| 状态 | 效果 | 触发时机 | 消失时机 |
|------|------|----------|----------|
| complete | 绿色实心进度条 | Stop（正常结束） | 用户聚焦窗口后 1 秒自动消失 |
| warning | 整个任务栏按钮变黄 | Notification、Stop（异常） | PostToolUse 时自动清除（说明用户已处理），或下次正常 Stop 覆盖 |
| idle | 无效果 | 焦点监听触发 / 手动重置 | — |

## 架构

```
Claude Code hooks → taskbar-cli.ps1 → send-taskbar.ps1 → daemon/overlay
```

- `taskbar-cli.ps1`：统一 CLI 入口（-Action start/tool-begin/tool-end/notify/complete/error/idle）
- `send-taskbar.ps1`：分发器（守护进程快速路径 <100ms / 直接调用回退 3-5s）
- `hook-taskbar-daemon.ps1`：后台守护进程，预加载 DLL，100ms 轮询信号文件
- `hook-session-init.ps1`：保存 HWND（优先 WindowsTerminal → 进程树 → GetConsoleWindow）

## Hook 事件流

1. **SessionStart** → `hook-session-init.ps1`：保存 HWND，启动守护进程
2. **PreToolUse** → `hook-pre-tool.ps1` → `taskbar-cli -Action tool-begin`
3. **PostToolUse** → `hook-post-tool.ps1` → `taskbar-cli -Action tool-end`
4. **Notification** → `hook-notification.ps1` → `taskbar-cli -Action notify`
5. **Stop** → `hook-stop.ps1` → `taskbar-cli -Action complete/error`

## 技术要点

- HWND 缓存文件：`$env:TEMP\claude-taskbar-hwnd.txt`
- 状态文件：`$env:TEMP\claude-taskbar-state.txt`
- 信号文件：`$env:TEMP\claude-taskbar-signal.txt`
- 所有脚本以 SilentlyContinue 模式运行，不会中断主流程
