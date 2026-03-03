---
user-invocable: false
---

# Taskbar Monitor - 任务栏状态监控系统

## 概述

本插件通过 Windows ITaskbarList3 COM 接口，在任务栏图标上显示彩色圆形覆盖图标，
实时反映 Claude Code 的工作状态。用户无需切换窗口即可了解 AI 当前进度。

## 状态定义

| 状态 | 效果 | 触发时机 | 消失时机 |
|------|------|----------|----------|
| complete | 绿色实心进度条 | Stop（正常结束） | 用户聚焦窗口后 1 秒自动消失 |
| warning | 整个任务栏按钮变黄 | Notification、Stop（异常） | 下次 PreToolUse 时自动清除（Claude 继续工作说明问题已解决），或下次正常 Stop 覆盖 |
| idle | 无效果 | 焦点监听触发 / 手动重置 | — |

## Hook 事件流

1. **SessionStart** → `hook-session-init.ps1`：保存控制台窗口句柄 (HWND)
2. **PreToolUse** → `hook-pre-tool.ps1`：HWND 初始化 fallback；若当前为 warning 状态则清除（说明用户已处理完毕）
3. **PostToolUse** → `hook-post-tool.ps1`：无操作（工具失败由 Claude 内部处理，不触发 warning）
4. **Notification** → `hook-notification.ps1`：需要用户注意 → warning
5. **Stop** → `hook-stop.ps1`：正常结束 → complete（启动焦点监听），异常 → warning

## 技术要点

- HWND 缓存文件：`$env:TEMP\claude-taskbar-hwnd.txt`
- Windows Terminal 下 `GetConsoleWindow()` 可能返回 0，需要遍历进程树查找父窗口
- 所有脚本以 SilentlyContinue 模式运行，不会中断 Claude Code 主流程
