# Taskbar Monitor - 任务栏状态监控

## 用途

管理任务栏状态监控系统。在 AI 编码工具完成任务或遇到问题时，
通过任务栏进度条颜色实时提示结果状态。

## 状态说明

| 状态 | 效果 | 含义 | 消失时机 |
|------|------|------|----------|
| 完成 | 🟢 绿色进度条 | 任务成功完成 | 用户聚焦窗口后 1 秒自动消失 |
| 警告 | 🟡 整个按钮变黄 | 错误/网络问题/需要用户操作 | 下次正常完成时被覆盖 |
| 空闲 | 无效果 | 无任务 / 已确认 | — |

## 当用户执行此命令时，请执行以下操作：

1. **检查脚本文件** - 验证以下核心文件是否存在：
   - `$env:USERPROFILE\.claude\scripts\taskbar-cli.ps1`（统一 CLI 入口）
   - `$env:USERPROFILE\.claude\scripts\taskbar-overlay.ps1`（核心 COM 模块）
   - `$env:USERPROFILE\.claude\scripts\send-taskbar.ps1`（分发器）
   - `$env:USERPROFILE\.claude\scripts\hook-taskbar-daemon.ps1`（守护进程）
   - `$env:USERPROFILE\.claude\scripts\hook-session-init.ps1`（HWND 初始化）
   - `$env:USERPROFILE\.claude\scripts\hook-focus-watcher.ps1`（焦点监听）

2. **检查 Hooks 配置** - 读取 `$env:USERPROFILE\.claude\settings.json`，
   确认 hooks 章节包含正确的 PreToolUse / PostToolUse / Notification / Stop 配置。

3. **测试状态显示** - 通过 taskbar-cli.ps1 依次测试：
   ```powershell
   powershell -NoProfile -File "$env:USERPROFILE\.claude\scripts\taskbar-cli.ps1" -Action complete
   ```
   观察任务栏出现绿色进度条，点击窗口后 1 秒应自动消失。
   ```powershell
   powershell -NoProfile -File "$env:USERPROFILE\.claude\scripts\taskbar-cli.ps1" -Action notify
   ```
   观察任务栏按钮整体变黄，需手动清除：
   ```powershell
   powershell -NoProfile -File "$env:USERPROFILE\.claude\scripts\taskbar-cli.ps1" -Action idle
   ```

4. **输出结果** - 告诉用户测试完成，并展示当前 hooks 配置状态。

## 注意事项

- 若任务栏无变化，可能是 HWND 未正确捕获，运行 `taskbar-cli.ps1 -Action start` 重新初始化。
- 警告状态会在下次正常完成时自动被绿色覆盖；若需立即清除，执行 `-Action idle`。
- complete 的焦点监听由后台 `hook-focus-watcher.ps1` 负责，若绿色长时间不消失可执行 `-Action idle`。
