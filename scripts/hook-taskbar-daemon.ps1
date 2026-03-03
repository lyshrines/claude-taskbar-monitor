<#
.SYNOPSIS
    Claude Code 任务栏守护进程（后台常驻）
.DESCRIPTION
    由 hook-session-init 在会话启动时启动，持续运行直到新会话取代它。
    核心优化：Add-Type 只执行一次（启动时），之后通过轮询信号文件（每 100ms）
    响应任务栏更新（<200ms），彻底消除每次 hook 调用的 3-5 秒延迟。
    注：FileSystemWatcher 在繁忙的 Temp 目录下事件丢失严重，改用轮询更可靠。
#>
$ErrorActionPreference = "SilentlyContinue"
if ($env:OS -ne "Windows_NT") { exit 0 }

$scriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$signalFile = "$env:TEMP\claude-taskbar-signal.txt"
$hwndFile   = "$env:TEMP\claude-taskbar-hwnd.txt"
$pidFile    = "$env:TEMP\claude-taskbar-daemon.pid"
$stateFile  = "$env:TEMP\claude-taskbar-state.txt"
$dllPath    = "$env:USERPROFILE\.claude\scripts\ClaudeTaskbarOverlay.dll"

# 写入自己的 PID，新实例写入后旧实例会自动退出
"$PID" | Out-File $pidFile -Encoding UTF8 -NoNewline -Force

# ── C# 类型定义 ───────────────────────────────────────────────────────────────
$csDef = @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;

[ComImport]
[Guid("ea1afb91-9e28-4b86-90e9-9e9f8a5eefaf")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ITaskbarList3 {
    [PreserveSig] int HrInit();
    [PreserveSig] int AddTab(IntPtr hwnd);
    [PreserveSig] int DeleteTab(IntPtr hwnd);
    [PreserveSig] int ActivateTab(IntPtr hwnd);
    [PreserveSig] int SetActiveAlt(IntPtr hwnd);
    [PreserveSig] int MarkFullscreenWindow(IntPtr hwnd, [MarshalAs(UnmanagedType.Bool)] bool fFullscreen);
    [PreserveSig] int SetProgressValue(IntPtr hwnd, ulong ullCompleted, ulong ullTotal);
    [PreserveSig] int SetProgressState(IntPtr hwnd, int tbpFlags);
    [PreserveSig] int RegisterTab(IntPtr hwndTab, IntPtr hwndMDI);
    [PreserveSig] int UnregisterTab(IntPtr hwndTab);
    [PreserveSig] int SetTabOrder(IntPtr hwndTab, IntPtr hwndInsertBefore);
    [PreserveSig] int SetTabActive(IntPtr hwndTab, IntPtr hwndMDI, int dwReserved);
    [PreserveSig] int ThumbBarAddButtons(IntPtr hwnd, uint cButtons, IntPtr pButton);
    [PreserveSig] int ThumbBarUpdateButtons(IntPtr hwnd, uint cButtons, IntPtr pButton);
    [PreserveSig] int ThumbBarSetImageList(IntPtr hwnd, IntPtr himl);
    [PreserveSig] int SetOverlayIcon(IntPtr hwnd, IntPtr hIcon, [MarshalAs(UnmanagedType.LPWStr)] string pszDescription);
    [PreserveSig] int SetThumbnailTooltip(IntPtr hwnd, [MarshalAs(UnmanagedType.LPWStr)] string pszTip);
    [PreserveSig] int SetThumbnailClip(IntPtr hwnd, IntPtr prcClip);
}

[ComImport]
[Guid("56fdf344-fd6d-11d0-958a-006097c9a090")]
[ClassInterface(ClassInterfaceType.None)]
class TaskbarInstance {}

public static class ClaudeTaskbarOverlay {
    public const int TBPF_NOPROGRESS = 0;
    public const int TBPF_NORMAL     = 2;
    public const int TBPF_PAUSED     = 8;

    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]   public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")]   public static extern bool DestroyIcon(IntPtr hIcon);

    private static IntPtr LoadSavedHwnd(string f) {
        try {
            if (!System.IO.File.Exists(f)) return IntPtr.Zero;
            long v;
            if (!long.TryParse(System.IO.File.ReadAllText(f).Trim(), out v)) return IntPtr.Zero;
            IntPtr h = new IntPtr(v);
            return (h != IntPtr.Zero && IsWindow(h)) ? h : IntPtr.Zero;
        } catch { return IntPtr.Zero; }
    }

    public static void SetStatus(string status, string hwndFile) {
        IntPtr hwnd = LoadSavedHwnd(hwndFile);
        if (hwnd == IntPtr.Zero) hwnd = GetConsoleWindow();
        if (hwnd == IntPtr.Zero) return;

        ITaskbarList3 t = (ITaskbarList3)new TaskbarInstance();
        t.HrInit();
        IntPtr icon = IntPtr.Zero;
        try {
            switch (status.ToLower()) {
                case "complete":
                    icon = CreateCircleIcon(Color.LimeGreen, 16);
                    t.SetProgressValue(hwnd, 100, 100);
                    t.SetProgressState(hwnd, TBPF_NORMAL);
                    t.SetOverlayIcon(hwnd, icon, "Claude complete");
                    break;
                case "warning":
                    icon = CreateCircleIcon(Color.OrangeRed, 16);
                    t.SetProgressValue(hwnd, 100, 100);
                    t.SetProgressState(hwnd, TBPF_PAUSED);
                    t.SetOverlayIcon(hwnd, icon, "Claude warning");
                    break;
                default:
                    t.SetProgressState(hwnd, TBPF_NOPROGRESS);
                    t.SetOverlayIcon(hwnd, IntPtr.Zero, null);
                    break;
            }
        } finally {
            System.Threading.Thread.Sleep(100);
            if (icon != IntPtr.Zero) DestroyIcon(icon);
        }
    }

    private static IntPtr CreateCircleIcon(Color color, int size) {
        Bitmap bmp = new Bitmap(size, size, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp)) {
            g.Clear(Color.Transparent);
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            using (SolidBrush s = new SolidBrush(Color.FromArgb(70, 0, 0, 0)))
                g.FillEllipse(s, 2, 2, size - 3, size - 3);
            using (SolidBrush br = new SolidBrush(color))
                g.FillEllipse(br, 1, 1, size - 3, size - 3);
            using (SolidBrush h = new SolidBrush(Color.FromArgb(130, 255, 255, 255)))
                g.FillEllipse(h, 3, 2, (size - 5) / 2, (size - 5) / 3);
        }
        IntPtr hIcon = bmp.GetHicon();
        bmp.Dispose();
        return hIcon;
    }
}
"@

# ── 一次性加载类型（这是守护进程的核心价值所在）────────────────────────────────
if (Test-Path $dllPath) {
    try {
        Add-Type -Path $dllPath -ErrorAction Stop
    } catch {
        # DLL 损坏，重新编译
        Remove-Item $dllPath -Force -ErrorAction SilentlyContinue
        try { Add-Type -TypeDefinition $csDef -ReferencedAssemblies System.Drawing -OutputAssembly $dllPath -ErrorAction Stop }
        catch { Add-Type -TypeDefinition $csDef -ReferencedAssemblies System.Drawing }
    }
} else {
    try { Add-Type -TypeDefinition $csDef -ReferencedAssemblies System.Drawing -OutputAssembly $dllPath -ErrorAction Stop }
    catch { Add-Type -TypeDefinition $csDef -ReferencedAssemblies System.Drawing }
}

# 加载完成后，处理启动期间积压的信号（防止 hook 在 daemon 启动时就发了信号）
try {
    if (Test-Path $signalFile) {
        $pendingStatus = [System.IO.File]::ReadAllText($signalFile).Trim()
        $pendingState  = if (Test-Path $stateFile) { [System.IO.File]::ReadAllText($stateFile).Trim() } else { "" }
        # 只在状态文件与信号一致时处理（避免处理已被清除的旧信号）
        if ($pendingStatus -and $pendingStatus -eq $pendingState) {
            [ClaudeTaskbarOverlay]::SetStatus($pendingStatus, $hwndFile)
        }
    }
} catch {}

# ── 轮询监听信号文件（每 100ms，可靠性远高于 FileSystemWatcher）────────────────
# 初始化为当前值，避免重复处理启动时已处理过的信号
$lastStatus = try { [System.IO.File]::ReadAllText($signalFile).Trim() } catch { "" }

while ($true) {
    Start-Sleep -Milliseconds 100

    try {
        $current = [System.IO.File]::ReadAllText($signalFile).Trim()
        if ($current -ne $lastStatus) {
            $lastStatus = $current
            [ClaudeTaskbarOverlay]::SetStatus($current, $hwndFile)

            # complete 状态：启动焦点监听器
            if ($current -eq "complete") {
                $watcherPath = Join-Path $scriptsDir "hook-focus-watcher.ps1"
                if (Test-Path $watcherPath) {
                    Start-Process powershell -ArgumentList "-NoProfile -NonInteractive -WindowStyle Hidden -File `"$watcherPath`"" -WindowStyle Hidden -ErrorAction SilentlyContinue
                }
            }
        }
    } catch {}

    # 检查是否被新实例取代（PID 文件变化则旧实例退出）
    try {
        $stored = [System.IO.File]::ReadAllText($pidFile).Trim()
        if ($stored -and $stored -ne "$PID") { break }
    } catch {}
}
