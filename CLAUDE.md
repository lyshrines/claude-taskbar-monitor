# Claude Taskbar Monitor - 项目上下文

## 项目功能

Windows 任务栏状态监控插件，通过 Claude Code Hook 系统，在 Windows Terminal 任务栏图标上实时显示 AI 工作状态（绿色=完成、黄色=需要用户操作、无色=空闲）。

## 关键文件

| 文件 | 职责 |
|------|------|
| `scripts/hook-session-init.ps1` | SessionStart Hook：保存 HWND，启动守护进程 |
| `scripts/hook-taskbar-daemon.ps1` | 后台守护进程：预加载 C# DLL，每 100ms 轮询信号文件 |
| `scripts/send-taskbar.ps1` | 分发器：守护进程存活走快路径（写信号文件），否则走慢路径（直接调用） |
| `scripts/hook-notification.ps1` | Notification Hook → warning 状态 |
| `scripts/hook-pre-tool.ps1` | PreToolUse Hook → 若 warning 状态则清除（用户已处理） |
| `scripts/hook-post-tool.ps1` | PostToolUse Hook |
| `scripts/hook-stop.ps1` | Stop Hook → stop_reason=error 则 warning，否则 complete |
| `scripts/hook-focus-watcher.ps1` | 轮询前台窗口，complete 后用户聚焦则清除 |
| `scripts/taskbar-overlay.ps1` | 直接调用 COM 接口的慢路径（守护进程的回退） |

## 三个目录（重要！只有第三个实际运行）

| 目录 | 说明 | 实际运行？ |
|------|------|---------|
| `claude-taskbar-monitor\scripts\` | 源码，git 管理，改代码改这里 | 否 |
| `.claude\plugins\local\taskbar-monitor\scripts\` | 插件安装目录，已废弃 | 否 |
| `.claude\scripts\` | `settings.json` 直接引用的目录 | **是** |

**修改代码后必须运行 `sync2.ps1` 同步到 `.claude\scripts\`，否则改动不生效。**

## 临时文件（运行时状态）

| 文件 | 内容 |
|------|------|
| `%TEMP%\claude-taskbar-hwnd.txt` | 目标窗口的 HWND（整数） |
| `%TEMP%\claude-taskbar-daemon.pid` | 守护进程 PID |
| `%TEMP%\claude-taskbar-signal.txt` | 向守护进程发送的状态信号 |
| `%TEMP%\claude-taskbar-state.txt` | 当前状态（供 PreToolUse 读取判断是否清除） |
| `%USERPROFILE%\.claude\scripts\ClaudeTaskbarOverlay.dll` | 预编译的 C# DLL 缓存 |

## 已知约束

- Windows Terminal 下 `GetConsoleWindow()` 返回 0，需要遍历父进程查找主窗口
- `FileSystemWatcher` 在 Temp 目录丢事件严重，已改为 100ms 轮询
- 所有脚本使用 `SilentlyContinue`，不会中断主流程，但也导致错误静默
- 守护进程通过 PID 文件判断新旧实例，旧实例检测到 PID 变化后退出

## 调试注意事项

1. **优先查看 DEBUGGING.md** 了解历史尝试和已知失败方案
2. 修改前先确认操作的是哪个位置的文件（源码 vs 已安装）
3. 修改已安装版本后需要重启 Claude Code 才能生效
4. 验证前先手动检查临时文件是否存在且内容正确
5. 不要轻易改变整体架构（守护进程方案是性能必须项）
