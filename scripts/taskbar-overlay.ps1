<#
.SYNOPSIS
    Claude Code 任务栏状态指示器 - 核心模块
.DESCRIPTION
    通过 Windows ITaskbarList3 COM 接口，在 PowerShell/Windows Terminal
    任务栏图标上显示彩色圆形覆盖图标，反映 Claude Code 的当前状态。
.PARAMETER Status
    busy    - 繁忙（黄色圆圈）
    complete - 完成（绿色圆圈）
    warning  - 警告（红色圆圈 + 任务栏图标变黄色高亮）
    idle     - 空闲（清除所有指示）
.PARAMETER AutoClearDelay
    状态显示后自动切换为 idle 的延迟秒数（0 = 不自动清除）
#>
param(
    [ValidateSet("busy", "complete", "warning", "idle")]
    [string]$Status = "idle",
    [int]$AutoClearDelay = 0
)

$ErrorActionPreference = "SilentlyContinue"

# 仅在 Windows 平台运行
if ($env:OS -ne "Windows_NT") { exit 0 }

# ── 只加载一次 C# 类型 ──────────────────────────────────────────────────────
$typeName = "ClaudeTaskbarOverlay"
if (-not ([System.Management.Automation.PSTypeName]$typeName).Type) {
    Add-Type -TypeDefinition @"
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
    // TaskbarList 进度条状态标志
    public const int TBPF_NOPROGRESS    = 0;   // 清除
    public const int TBPF_INDETERMINATE = 1;   // 动画（蓝色）
    public const int TBPF_NORMAL        = 2;   // 正常（绿色）
    public const int TBPF_ERROR         = 4;   // 错误（红橙色）
    public const int TBPF_PAUSED        = 8;   // 暂停/警告（黄色）

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool DestroyIcon(IntPtr hIcon);

    // 从保存的 HWND 文件读取窗口句柄
    private static IntPtr LoadSavedHwnd(string hwndFile) {
        try {
            if (!System.IO.File.Exists(hwndFile)) return IntPtr.Zero;
            string raw = System.IO.File.ReadAllText(hwndFile).Trim();
            long val;
            if (!long.TryParse(raw, out val)) return IntPtr.Zero;
            IntPtr hwnd = new IntPtr(val);
            return (hwnd != IntPtr.Zero && IsWindow(hwnd)) ? hwnd : IntPtr.Zero;
        } catch { return IntPtr.Zero; }
    }

    public static void SetStatus(string status, string hwndFile) {
        // 优先使用缓存文件中保存的可见窗口句柄（PowerShell / Windows Terminal 均适用）
        IntPtr hwnd = IntPtr.Zero;
        if (!string.IsNullOrEmpty(hwndFile)) {
            hwnd = LoadSavedHwnd(hwndFile);
        }

        // 缓存不可用时，回退到当前进程的控制台窗口
        if (hwnd == IntPtr.Zero) {
            hwnd = GetConsoleWindow();
        }
        if (hwnd == IntPtr.Zero) return;

        ITaskbarList3 taskbar = (ITaskbarList3)new TaskbarInstance();
        taskbar.HrInit();

        IntPtr iconHandle = IntPtr.Zero;
        try {
            switch (status.ToLower()) {
                case "busy":
                    // No-op: busy state removed, keep existing visual unchanged
                    break;

                case "complete":
                    iconHandle = CreateCircleIcon(Color.LimeGreen, 16);
                    taskbar.SetProgressValue(hwnd, 100, 100);
                    taskbar.SetProgressState(hwnd, TBPF_NORMAL);
                    taskbar.SetOverlayIcon(hwnd, iconHandle, "Claude \u5df2\u5b8c\u6210");
                    break;

                case "warning":
                    iconHandle = CreateCircleIcon(Color.OrangeRed, 16);
                    // TBPF_PAUSED 使任务栏按钮变为黄色高亮
                    taskbar.SetProgressValue(hwnd, 100, 100);
                    taskbar.SetProgressState(hwnd, TBPF_PAUSED);
                    taskbar.SetOverlayIcon(hwnd, iconHandle, "Claude \u9700\u8981\u6ce8\u610f");
                    break;

                default: // idle
                    taskbar.SetProgressState(hwnd, TBPF_NOPROGRESS);
                    taskbar.SetOverlayIcon(hwnd, IntPtr.Zero, null);
                    break;
            }
        } finally {
            // 稍等后释放 HICON（系统已复制副本，可安全释放）
            System.Threading.Thread.Sleep(100);
            if (iconHandle != IntPtr.Zero) DestroyIcon(iconHandle);
        }
    }

    private static IntPtr CreateCircleIcon(Color color, int size) {
        Bitmap bmp = new Bitmap(size, size, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp)) {
            g.Clear(Color.Transparent);
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;

            // 阴影层
            using (SolidBrush shadow = new SolidBrush(Color.FromArgb(70, 0, 0, 0)))
                g.FillEllipse(shadow, 2, 2, size - 3, size - 3);

            // 主圆
            using (SolidBrush brush = new SolidBrush(color))
                g.FillEllipse(brush, 1, 1, size - 3, size - 3);

            // 高光（左上角半透明白色，增加立体感）
            using (SolidBrush hi = new SolidBrush(Color.FromArgb(130, 255, 255, 255)))
                g.FillEllipse(hi, 3, 2, (size - 5) / 2, (size - 5) / 3);
        }
        IntPtr hIcon = bmp.GetHicon();
        bmp.Dispose();
        return hIcon;
    }
}
"@ -ReferencedAssemblies System.Drawing -ErrorAction Stop
}

# ── 保存当前窗口 HWND 以供子进程读取 ─────────────────────────────────────────
$hwndCacheFile = "$env:TEMP\claude-taskbar-hwnd.txt"

# 主逻辑
try {
    [ClaudeTaskbarOverlay]::SetStatus($Status, $hwndCacheFile)
} catch {
    exit 0
}

# 记录当前状态供 focus-watcher 判断（busy 为空操作，不覆盖状态文件）
$stateFile = "$env:TEMP\claude-taskbar-state.txt"
if ($Status -ne "busy") {
    try { $Status | Out-File -FilePath $stateFile -Encoding UTF8 -Force } catch {}
}

# complete 状态：启动焦点监听进程，用户看到后延迟 1 秒自动清除
if ($Status -eq "complete") {
    $watcherPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "hook-focus-watcher.ps1"
    if (Test-Path $watcherPath) {
        Start-Process powershell -ArgumentList "-NoProfile -NonInteractive -WindowStyle Hidden -File `"$watcherPath`"" -WindowStyle Hidden -ErrorAction SilentlyContinue
    }
}
