# Taskbar Monitor

Windows 任务栏状态监控工具，通过任务栏图标颜色实时反映 AI 编码工具的工作状态。

支持 **Claude Code**（内置 hook 适配器），同时提供通用 CLI 接口 `taskbar-cli.ps1`，
任何支持调用外部命令的 AI 工具（Cursor、Aider、Continue.dev 等）均可集成。

## 状态说明

| 状态 | 效果 | 触发时机 | 消失时机 |
|------|------|----------|----------|
| 完成 | 🟢 绿色进度条 | 正常结束回复 | 聚焦窗口后 1 秒自动消失 |
| 警告 | 🟡 整个按钮变黄 | 需要用户操作（权限审批、等待输入等） | 用户处理后工具执行时自动清除 |
| 空闲 | 无效果 | 焦点触发 / 自动清除 | — |

## 系统要求

- Windows 10 / 11
- PowerShell 5.1+
- [Claude Code](https://docs.anthropic.com/claude-code) CLI
- Windows Terminal（推荐，但非必须）

## 安装

```powershell
# 1. 下载仓库
git clone https://github.com/lyshrines/claude-taskbar-monitor.git
cd claude-taskbar-monitor

# 2. 运行安装脚本（需要 PowerShell，普通权限即可）
powershell -ExecutionPolicy Bypass -File install.ps1
```

安装完成后**重启 Claude Code** 即可生效。

## 卸载

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

## 架构

```
┌─────────────────────────────────────────────────────────┐
│                    AI 工具层（适配器）                     │
│  ┌──────────────┐  ┌──────────┐  ┌──────────┐          │
│  │ Claude Code   │  │ Cursor   │  │ Aider    │  ...     │
│  │ hook-*.ps1    │  │ 扩展     │  │ 插件     │          │
│  └──────┬───────┘  └────┬─────┘  └────┬─────┘          │
│         │               │             │                  │
│         └───────────────┼─────────────┘                  │
│                         ▼                                │
│              taskbar-cli.ps1（统一 CLI）                  │
├─────────────────────────┼────────────────────────────────┤
│                    核心层（工具无关）                       │
│                         ▼                                │
│              send-taskbar.ps1（分发器）                    │
│           ┌─────────────┼─────────────┐                  │
│           ▼                           ▼                  │
│  hook-taskbar-daemon.ps1    taskbar-overlay.ps1          │
│  （常驻，<100ms 响应）       （回退，3-5s）                │
│           │                                              │
│           ├── hook-focus-watcher.ps1（complete 后清除）    │
│           └── hook-session-init.ps1（HWND + 守护进程）    │
└──────────────────────────────────────────────────────────┘
```

### 关键文件

| 文件 | 层级 | 说明 |
|------|------|------|
| `taskbar-cli.ps1` | 接口 | **统一 CLI 入口**，所有 AI 工具的唯一调用点 |
| `send-taskbar.ps1` | 核心 | 分发器，优先走守护进程快速路径 |
| `hook-taskbar-daemon.ps1` | 核心 | 后台守护进程，预加载 DLL，100ms 轮询 |
| `taskbar-overlay.ps1` | 核心 | 直接调用 COM 接口（守护进程不在时的回退） |
| `hook-session-init.ps1` | 核心 | 保存窗口句柄 (HWND)，启动守护进程 |
| `hook-focus-watcher.ps1` | 核心 | 监听窗口焦点，complete 后自动清除 |
| `hook-pre-tool.ps1` | 适配 | Claude Code PreToolUse 适配器 |
| `hook-post-tool.ps1` | 适配 | Claude Code PostToolUse 适配器 |
| `hook-notification.ps1` | 适配 | Claude Code Notification 适配器 |
| `hook-stop.ps1` | 适配 | Claude Code Stop 适配器 |

## 跨工具使用

`taskbar-cli.ps1` 是通用入口，任何 AI 工具都可以直接调用：

```powershell
$cli = "$env:USERPROFILE\.claude\scripts\taskbar-cli.ps1"

# 初始化（工具启动时调用一次）
powershell -NoProfile -File $cli -Action start

# AI 正常完成回复
powershell -NoProfile -File $cli -Action complete

# 需要用户操作（权限审批、等待输入等）
powershell -NoProfile -File $cli -Action notify

# AI 异常结束
powershell -NoProfile -File $cli -Action error

# 清除状态
powershell -NoProfile -File $cli -Action idle
```

### 可用的 Action

| Action | 效果 | 适用场景 |
|--------|------|---------|
| `start` | 初始化 HWND + 启动守护进程 | 会话/窗口启动时调用一次 |
| `tool-begin` | 标记活跃轮次 | AI 开始执行工具前 |
| `tool-end` | 清除 warning（如果有）| AI 工具执行完毕后 |
| `notify` | 任务栏变黄 | 需要用户注意时 |
| `complete` | 任务栏变绿 | AI 正常完成时 |
| `error` | 任务栏变黄 | AI 异常结束时 |
| `idle` | 清除所有状态 | 手动重置 |

## /taskbar-monitor 命令

安装后可在 Claude Code 中运行 `/taskbar-monitor` 检查状态并测试显示效果。
