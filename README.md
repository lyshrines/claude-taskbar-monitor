# Claude Taskbar Monitor

Windows 任务栏状态监控插件，适用于 **PowerShell + CCswitch + Claude Code** 的使用场景。

在 Claude Code 运行时，通过任务栏 PowerShell 图标的颜色实时提示状态，无需切换窗口。

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

## 工作原理

### 架构概览

通过 Claude Code 的 Hook 系统（SessionStart / PreToolUse / PostToolUse / Notification / Stop），在 PowerShell 进程的任务栏图标上调用 Windows `ITaskbarList3` COM 接口设置进度条颜色。

### 守护进程设计（低延迟核心）

为消除每次 hook 触发时启动新 PowerShell 进程的 3-5 秒延迟，采用持久化守护进程方案：

```
SessionStart
    └── hook-session-init.ps1
            └── 启动 hook-taskbar-daemon.ps1（后台常驻）
                    └── 预加载 C# DLL（Add-Type 只执行一次）
                            └── 每 100ms 轮询信号文件

PreToolUse / PostToolUse / Notification / Stop
    └── hook-*.ps1
            └── send-taskbar.ps1（分发器）
                    ├── 守护进程存活 → 写入信号文件（<5ms）→ 守护进程响应（<100ms）
                    └── 守护进程不在 → 直接调用 taskbar-overlay.ps1（慢，约 3-5s）
                                            └── 后台重启守护进程
```

**关键文件：**

| 文件 | 说明 |
|------|------|
| `hook-taskbar-daemon.ps1` | 后台守护进程，预加载 DLL，100ms 轮询信号文件 |
| `send-taskbar.ps1` | 分发器，优先走守护进程快速路径 |
| `taskbar-overlay.ps1` | 直接调用 COM 接口的慢路径（回退用） |
| `hook-session-init.ps1` | 会话启动时保存窗口句柄并启动守护进程 |
| `hook-notification.ps1` | Notification hook，触发警告状态 |
| `hook-pre-tool.ps1` | PreToolUse hook，触发忙碌状态 |
| `hook-post-tool.ps1` | PostToolUse hook，触发完成/空闲状态 |
| `hook-focus-watcher.ps1` | 监听窗口焦点，完成后自动清除 |

## /taskbar-monitor 命令

安装后可在 Claude Code 中运行 `/taskbar-monitor` 检查状态并测试显示效果。
