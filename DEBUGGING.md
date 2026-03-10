# Taskbar Monitor - 调试日志

## 用户需求（验收标准）

| 场景 | 期望行为 | 当前状态 |
|------|---------|---------|
| Claude 弹出权限确认弹框 | 任务栏图标立即变黄（<1秒） | ❌ 未触发 |
| 用户确认权限后 Claude 继续工作 | 黄色自动消失 | ❌ 不消失 |
| Claude 正常完成回复 | 任务栏图标变绿 | ❌ 未触发 |
| 用户聚焦 Windows Terminal 窗口 | 绿色 1 秒后自动消失 | 未验证 |

---

## 已验证失败的方案

| 时间 | 尝试 | 目标问题 | 结果 |
|------|------|---------|------|
| ~2026-03 | 使用 FileSystemWatcher 监听信号文件 | 延迟问题 | 失败：Temp 目录事件丢失严重 |
| ~2026-03 | 改为 100ms 轮询信号文件 | 延迟问题 | 部分改善，但主问题未解决 |
| ~2026-03 | 在 COM 操作前先写状态文件 | PreToolUse 竞态 | 已合入，效果未知 |
| ~2026-03 | 提取 taskbar-cli.ps1 作为统一入口 | 架构整理 | 已撤回（revert） |

---

## 环境背景

- **启动方式**：通过 **CCswitch** 打开 Windows Terminal，再在其中运行 Claude Code
- **进程层级**：CCswitch → Windows Terminal → PowerShell/Claude Code（层级比直接打开多一层）
- **影响**：`GetConsoleWindow()` 在 Windows Terminal 下本就返回 0，CCswitch 额外增加了一层父进程，使父进程遍历查找真实窗口句柄的逻辑更容易失效

---

## 框架逻辑问题（2026-03-10 代码审查）

### 🔴 问题1：PostToolUse 与设计文档矛盾，且逻辑有副作用

- SKILL.md 写"PostToolUse 无操作"，但 `hook-post-tool.ps1` 实际会在 state=warning 时清除黄色
- 后果：任何工具执行完毕（PostToolUse）都会清掉 warning，即使用户还没有确认权限弹框

### 🔴 问题2：warning 防抖逻辑是真实需求，但实现方式错误

**背景**：正常 AI 运行中，Notification 有时短暂触发后被 PreToolUse 立刻清掉，导致任务栏"闪一下黄色后消失"。为此在 daemon 中加入了 500ms 防抖（等待后重新确认状态，若已清除则跳过显示）。

**为何这个实现有问题**：500ms 是任意值。如果用户确认速度快于 500ms，合法的 warning 也会被跳过，导致黄色永远不显示。本质是用时间猜场景，猜错则两个需求都不满足。

**正确的区分方式**：正常运行时 PreToolUse 在 <100ms 内清掉 state 文件；真正需要用户操作时 state 文件会持续为 warning。应利用守护进程的下一个 100ms 轮询周期做一次确认，而非固定等待 500ms。

**当前处理（2026-03-10）**：已移除 500ms 防抖。若"闪黄"问题复现，需用"单次轮询确认"方案替代，不要恢复固定等待。

### 🔴 问题3：warning 清除时机假设可能不成立

- 设计意图：Notification（黄）→ 用户确认 → PreToolUse（清黄）
- 实际风险：若 PreToolUse 在弹框出现之前就触发，warning 被立刻清掉，用户看不到黄色
- PreToolUse 和 PostToolUse 都有清除 warning 的逻辑，双重清除加剧问题

### 🟠 问题3：focus-watcher 可能被重复启动

- daemon（快路径）和 taskbar-overlay.ps1（慢路径）都会在 complete 时启动 focus-watcher
- 正常情况下只有一个会触发，但属于重复逻辑，容易在维护时出现不一致

### 🟠 问题4：`busy` 状态是死代码

- send-taskbar.ps1 和 taskbar-overlay.ps1 有 busy 的处理逻辑，但没有任何 hook 脚本发送 busy

### 🟡 问题5：state 文件被写两次（hook-notification.ps1 + send-taskbar.ps1）

- 值相同不影响结果，但职责划分不清晰

---

## 根本原因假设

> 每次调试前，先在这里更新当前最可信的假设，再动手修改。

### 假设 A：HWND 获取失败（可信度：极高）

CCswitch → Windows Terminal 的进程层级下，`GetConsoleWindow()` 返回 0，
父进程遍历逻辑在多层进程树中也很可能找不到 Windows Terminal 的真实窗口句柄。
HWND 无效则所有 COM 调用静默失败，任务栏无任何变化。

**验证方法**：检查 `%TEMP%\claude-taskbar-hwnd.txt` 是否存在、值是否非零，
并用 spy++ 或 PowerShell 确认该 HWND 对应的是否真的是 Windows Terminal 窗口。

### 假设 B：守护进程未在运行（可信度：高）

守护进程启动失败（DLL 编译报错被 SilentlyContinue 静默），或启动后因异常退出。
慢路径同样依赖 HWND，若 A 成立则慢路径也无效。

**验证方法**：检查 PID 文件并确认进程是否存活。

### 假设 C：warning 被过早清除（可信度：高，解释"变黄后立刻消失"）

即使黄色短暂触发，PostToolUse 或 PreToolUse 也会在用户确认前将其清掉。

### 假设 D：两个部署位置不同步（可信度：中）

已安装目录是旧版本，Claude Code 运行的不是最新逻辑。

**验证方法**：对比两个目录文件的修改时间。

---

## 当前调试状态

### 2026-03-10 诊断 + 修复

**诊断结果：**
- HWND 文件值为 524926，但 `IsWindow` 返回 False → **HWND 完全无效**，所有 COM 调用静默失败
- 守护进程存活（PID 正常）→ 守护进程本身没问题，是 HWND 导致调用无效
- 已安装 daemon 与源码不同：安装版有 500ms 防抖逻辑 → 这是之前的错误修复，导致 warning 在 PreToolUse 清掉后永远不显示

**本次修复（2026-03-10）：**
1. `hook-session-init.ps1`：重写 HWND 获取逻辑，改为4层策略（GetForegroundWindow → WindowsTerminal进程 → GetConsoleWindow → 父进程遍历）；始终写入 HWND 文件防止旧值残留
2. `hook-post-tool.ps1`：移除错误的 warning 清除逻辑（该职责只属于 PreToolUse）
3. `hook-taskbar-daemon.ps1`：已安装版恢复为源码版本，移除错误的 500ms 防抖
4. 所有脚本已同步到已安装目录

**验收标准（测试时逐一确认）：**
- [ ] 重启 Claude Code 后 HWND 文件内容有效（IsWindow = True，窗口标题含 Windows Terminal）
- [ ] 权限弹框出现时任务栏图标变黄
- [ ] 确认权限后黄色消失
- [ ] Claude 完成回复时任务栏图标变绿
- [ ] 聚焦窗口后绿色消失

**下次若仍有问题，优先排查：**
- GetForegroundWindow() 返回的是否真的是 Windows Terminal 的 HWND（而非其他前台窗口）
- PreToolUse 与 Notification 的实际触发顺序（在弹框前还是后）

### 2026-03-10 追加：发现第三个目录（根本原因之二）

**发现**：实际被 Claude Code 加载的是 `settings.json`，而不是插件的 `hooks.json`。
实际运行的脚本在 `C:\Users\tangyutian.IN.000\.claude\scripts\`，
之前所有同步都打到了插件目录 `.claude\plugins\local\taskbar-monitor\scripts\`，完全没有生效。

**另外发现**：`settings.json` 从来没有 `SessionStart` 配置，因此 `hook-session-init.ps1` 从未被执行过，HWND 文件里的值一直是某次手动触发留下的过期值。

**本次修复：**
1. `settings.json` 新增 `SessionStart` hook，指向 `.claude\scripts\hook-session-init.ps1`
2. 将源码中 4 个有差异的文件同步到正确目录 `.claude\scripts\`
3. 更新 `sync2.ps1` 为正确的同步脚本（目标为 `.claude\scripts\`）

**三个目录的职责（重要，避免混淆）：**

| 目录 | 职责 | 是否实际运行 |
|------|------|------------|
| `claude-taskbar-monitor\scripts\` | 源码，git 管理 | 否 |
| `.claude\plugins\local\taskbar-monitor\scripts\` | 插件安装目录 | 否（settings.json 不用它） |
| `.claude\scripts\` | settings.json 直接引用 | **是，这里才是实际运行的** |

**今后修改代码后，必须用 `sync2.ps1` 同步到 `.claude\scripts\`。**

### 2026-03-10 优化：变黄延迟

**问题**：权限弹框出现后，黄色要延迟 3-5 秒才出现。

**根本原因**：Notification hook 每次都要启动新的 `powershell.exe` 进程，Windows 下 PowerShell 启动本身需要 1-3 秒，加上 Windows Defender 扫描可达 5 秒。`send-taskbar.ps1` 本身只需 38ms，守护进程响应也只需 100ms，瓶颈完全在进程启动。

**已尝试（失败）**：`cmd /c echo warning > file` 直接写入 —— Claude Code 不把 settings.json 命令当 shell 语句执行，`>` 重定向不生效，文件未写入。

**当前方案**：改用 `.bat` 文件（`notify-warning.bat`）。`cmd.exe` 启动 bat 文件约 50ms，远快于 PowerShell。settings.json 里 Notification hook 直接调用 bat 路径，绕过 PowerShell 启动开销。

**最终方案（2026-03-10 验证有效）**：
- settings.json Notification hook 改用内联 PowerShell 命令（`[IO.File]::WriteAllText`），避免加载 .ps1 脚本
- 移除 `"matcher": "permission_prompt"` —— git/Bash 权限弹框使用不同的 notification 类型，有 matcher 时不触发；去掉 matcher 后全类型都能触发
- 实测：git commit 权限弹框出现时黄色正常触发 ✅

### 2026-03-10 修复：变黄延迟 6 秒 + 黄色消失过慢

**问题1根本原因**：Notification hook 即使用内联命令，`powershell.exe` 进程启动本身在 Defender 扫描下需 3-6 秒。

**问题2根本原因**：确认弹框后的延迟链：
- PostToolUse：启动 powershell（3-6s）+ 什么都不做
- Stop 调试日志命令：再启动 powershell（3-6s）
- hook-stop.ps1：再启动 powershell（3-6s）
- 合计：用户确认后 9-18 秒黄色才消失

**本次修复（2026-03-10）：**
1. 创建 `notify-warning.bat` / `notify-complete.bat`：cmd.exe 调用 bat 文件启动耗时 ≤50ms（vs powershell 3-6s）
2. Notification hook 改用 `cmd /c notify-warning.bat` → 变黄延迟从 3-6s 降至 ≤200ms
3. 删除 PostToolUse hook（该 hook 启动 powershell 但什么都不做，纯浪费 3-6s）
4. Stop hook：增加 `cmd /c notify-complete.bat` 作为**第一个命令**（快速路径），保留 hook-stop.ps1 为第二命令处理错误情况
5. 删除 PreToolUse 和 Stop 中的调试日志命令（各减少 3-6s 开销）

**副作用：**
- hook_fired.txt 和 hook_stop.txt 不再更新（调试日志已移除）
- 错误停止时会有短暂绿色闪烁（bat 先写 complete，PS1 后覆盖为 warning），可接受
- sync2.ps1 已更新，包含 bat 文件同步

### 2026-03-10 修复：确认后黄色不消失（PreToolUse 时机错误）✅ 已验证

**问题**：用户确认权限后，黄色一直不消失，直到下一个权限弹框出现才消失。

**根本原因**：Hook 触发顺序是：

```
PreToolUse → 权限弹框出现 → Notification（变黄）→ 用户确认 → 工具执行 → PostToolUse
```

PreToolUse 在弹框出现**之前**触发，清的是上一个弹框的黄色，永远晚一步。正确的清除时机是 **PostToolUse**（工具执行完毕 = 用户已确认之后）。

**尝试过的失败方案（不要重复）：**
- `cmd /c notify-idle.bat`：bat 文件在 Claude Code hook 执行环境下会挂起，无法使用
- `powershell -Command "inline..."` 内联命令：引号在 hook 执行环境中解析有问题，文件不写入

**最终有效方案（2026-03-10 验证）：**
1. `hook-post-tool.ps1` 加入清除逻辑：读取 state 文件，仅在 `warning` 状态时写入 `idle`
2. settings.json PostToolUse hook 使用 `powershell -File hook-post-tool.ps1`（`-File` 方式是 hook 系统唯一可靠的调用方式）
3. PreToolUse 的 warning 清除逻辑保留作为兜底

---

### 2026-03-10 结论：变黄延迟的根本限制（已知无法消除）

**最终结论**：变黄延迟约 3-6 秒是 **Windows Defender 扫描 powershell.exe 进程的固定开销**。

- `cmd /c bat` 方案：bat 文件在 Claude Code hook 系统中会挂起，无效
- `powershell -Command "内联"` 方案：引号解析失败，无效
- `powershell -File xxx.ps1` 方案：唯一可靠，但有 3-6s Defender 扫描延迟
- **唯一根治方案**：请 IT 管理员将 PowerShell 加入 Defender 排除列表（个人无权限）

**诊断关键步骤（已验证有效）：**
```powershell
# 手动写 warning 到信号文件，验证守护进程→HWND链路
[IO.File]::WriteAllText("$env:TEMP\claude-taskbar-signal.txt","warning")
# 若任务栏立即变黄 → 守护进程和HWND正常，问题在hook写入
# 若任务栏无变化 → 检查HWND有效性和守护进程存活状态
```

**最终稳定的 settings.json hook 配置（2026-03-10 验证通过）：**

| Hook | 命令 | 说明 |
|------|------|------|
| SessionStart | `hook-session-init.ps1` | 启动守护进程，保存 HWND |
| PreToolUse | `hook-pre-tool.ps1` | warning 状态兜底清除 |
| Notification | `hook-notification-wrapper.ps1` | 变黄（3-6s Defender 延迟，已知限制） |
| PostToolUse | `hook-post-tool.ps1` | 工具完成后清除 warning（主清除路径） |
| Stop | `hook-stop.ps1` | 变绿（正常完成）/ 变黄（error） |

---

## 诊断命令速查

```powershell
# 检查 HWND
Get-Content "$env:TEMP\claude-taskbar-hwnd.txt"

# 检查守护进程 PID 及存活状态
$pid = Get-Content "$env:TEMP\claude-taskbar-daemon.pid"
Get-Process -Id $pid -ErrorAction SilentlyContinue

# 检查当前状态文件
Get-Content "$env:TEMP\claude-taskbar-state.txt"
Get-Content "$env:TEMP\claude-taskbar-signal.txt"

# 对比两个目录文件时间
Get-ChildItem "C:\Users\tangyutian.IN.000\claude-taskbar-monitor\scripts\" | Select Name, LastWriteTime
Get-ChildItem "C:\Users\tangyutian.IN.000\.claude\plugins\local\taskbar-monitor\scripts\" | Select Name, LastWriteTime
```
