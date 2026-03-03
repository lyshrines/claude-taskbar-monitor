# Taskbar Monitor - Claude Code 任务栏状态监控

## 用途

管理 PowerShell 任务栏状态监控系统。在 Claude Code 完成任务或遇到问题时，
通过任务栏进度条颜色实时提示结果状态。

## 状态说明

| 状态 | 效果 | 含义 | 消失时机 |
|------|------|------|----------|
| 完成 | 🟢 绿色进度条 | 任务成功完成 | 用户聚焦窗口后 1 秒自动消失 |
| 警告 | 🟡 整个按钮变黄 | 错误/网络问题/需要用户操作 | 下次正常完成时被覆盖 |
| 空闲 | 无效果 | 无任务 / 已确认 | — |

## 当用户执行此命令时，请执行以下操作：

1. **检查脚本文件** - 验证以下文件是否存在：
   - `$env:USERPROFILE\.claude\scripts\taskbar-overlay.ps1`
   - `$env:USERPROFILE\.claude\scripts\hook-focus-watcher.ps1`
   - `$env:USERPROFILE\.claude\scripts\hook-pre-tool.ps1`
   - `$env:USERPROFILE\.claude\scripts\hook-post-tool.ps1`
   - `$env:USERPROFILE\.claude\scripts\hook-notification.ps1`
   - `$env:USERPROFILE\.claude\scripts\hook-stop.ps1`

2. **检查 Hooks 配置** - 读取 `C:\Users\tangyutian.IN.000\.claude\settings.json`，
   确认 hooks 章节包含正确的 PreToolUse / PostToolUse / Notification / Stop 配置。
   如果缺失，提示用户运行 `/taskbar-setup` 完成配置。

3. **测试状态显示** - 依次测试 complete 和 warning 状态：
   ```powershell
   powershell -NoProfile -NonInteractive -WindowStyle Hidden -File "$env:USERPROFILE\.claude\scripts\taskbar-overlay.ps1" -Status complete
   ```
   观察任务栏出现绿色进度条，点击窗口后 1 秒应自动消失。
   ```powershell
   powershell -NoProfile -NonInteractive -WindowStyle Hidden -File "$env:USERPROFILE\.claude\scripts\taskbar-overlay.ps1" -Status warning
   ```
   观察任务栏按钮整体变黄，需手动清除：
   ```powershell
   powershell -NoProfile -NonInteractive -WindowStyle Hidden -File "$env:USERPROFILE\.claude\scripts\taskbar-overlay.ps1" -Status idle
   ```

4. **输出结果** - 告诉用户测试完成，并展示当前 hooks 配置状态。

## 注意事项

- 若任务栏无变化，可能是 HWND 未正确捕获，手动运行一次 `hook-session-init.ps1` 重新保存窗口句柄。
- 警告状态会在下次正常完成时自动被绿色覆盖；若需立即清除，执行 `-Status idle`。
- complete 的焦点监听由后台 `hook-focus-watcher.ps1` 进程负责，若绿色长时间不消失可手动执行 `-Status idle`。
