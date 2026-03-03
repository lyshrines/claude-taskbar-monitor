<#
.SYNOPSIS
    Claude Code 任务栏状态指示器 - 核心模块
.DESCRIPTION
    通过 Windows ITaskbarList3 COM 接口，在 PowerShell/Windows Terminal
    任务栏图标上显示彩色圆形覆盖图标，反映 Claude Code 的当前状态。
.PARAMETER Status
    complete - 完成（绿色进度条，用户聚焦后 1 秒消失）
    warning  - 警告（任务栏图标变黄色高亮）
    idle     - 空闲（清除所有指示）
#>
param(
    [ValidateSet("busy", "complete", "warning", "idle")]
    [string]$Status = "idle",
    [int]$AutoClearDelay = 0
)

$ErrorActionPreference = "SilentlyContinue"

if ($env:OS -ne "Windows_NT") { exit 0 }

# ── C# 源码 ──────────────────────────────────────────────────────────────────
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
    public const int TBPF_NOPROGRESS    = 0;
    public const int TBPF_INDETERMINATE = 1;
    public const int TBPF_NORMAL        = 2;
    public const int TBPF_ERROR         = 4;
    public const int TBPF_PAUSED        = 8;

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool DestroyIcon(IntPtr hIcon);

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
        IntPtr hwnd = IntPtr.Zero;
        if (!string.IsNullOrEmpty(hwndFile)) {
            hwnd = LoadSavedHwnd(hwndFile);
        }
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
                    break;

                case "complete":
                    iconHandle = CreateCircleIcon(Color.LimeGreen, 16);
                    taskbar.SetProgressValue(hwnd, 100, 100);
                    taskbar.SetProgressState(hwnd, TBPF_NORMAL);
                    taskbar.SetOverlayIcon(hwnd, iconHandle, "Claude complete");
                    break;

                case "warning":
                    iconHandle = CreateCircleIcon(Color.OrangeRed, 16);
                    taskbar.SetProgressValue(hwnd, 100, 100);
                    taskbar.SetProgressState(hwnd, TBPF_PAUSED);
                    taskbar.SetOverlayIcon(hwnd, iconHandle, "Claude warning");
                    break;

                default: // idle
                    taskbar.SetProgressState(hwnd, TBPF_NOPROGRESS);
                    taskbar.SetOverlayIcon(hwnd, IntPtr.Zero, null);
                    break;
            }
        } finally {
            System.Threading.Thread.Sleep(100);
            if (iconHandle != IntPtr.Zero) DestroyIcon(iconHandle);
        }
    }

    private static IntPtr CreateCircleIcon(Color color, int size) {
        Bitmap bmp = new Bitmap(size, size, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp)) {
            g.Clear(Color.Transparent);
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;

            using (SolidBrush shadow = new SolidBrush(Color.FromArgb(70, 0, 0, 0)))
                g.FillEllipse(shadow, 2, 2, size - 3, size - 3);

            using (SolidBrush brush = new SolidBrush(color))
                g.FillEllipse(brush, 1, 1, size - 3, size - 3);

            using (SolidBrush hi = new SolidBrush(Color.FromArgb(130, 255, 255, 255)))
                g.FillEllipse(hi, 3, 2, (size - 5) / 2, (size - 5) / 3);
        }
        IntPtr hIcon = bmp.GetHicon();
        bmp.Dispose();
        return hIcon;
    }
}
"@

# ── DLL 缓存：首次编译后保存，后续直接加载（避免每次 6 秒延迟）────────────────
$dllPath  = "$env:USERPROFILE\.claude\scripts\ClaudeTaskbarOverlay.dll"
$typeName = "ClaudeTaskbarOverlay"

if (-not ([System.Management.Automation.PSTypeName]$typeName).Type) {
    if (Test-Path $dllPath) {
        # 快速路径：加载预编译 DLL（< 500ms）
        try {
            Add-Type -Path $dllPath -ErrorAction Stop
        } catch {
            # DLL 损坏或版本不匹配，删除并重新编译
            Remove-Item $dllPath -Force -ErrorAction SilentlyContinue
            try {
                Add-Type -TypeDefinition $csDef -ReferencedAssemblies System.Drawing -OutputAssembly $dllPath -ErrorAction Stop
            } catch {
                Add-Type -TypeDefinition $csDef -ReferencedAssemblies System.Drawing -ErrorAction Stop
            }
        }
    } else {
        # 首次：编译并保存 DLL（慢，约 5 秒，仅发生一次）
        try {
            Add-Type -TypeDefinition $csDef -ReferencedAssemblies System.Drawing -OutputAssembly $dllPath -ErrorAction Stop
        } catch {
            # 无法写文件（权限或锁定），退而在内存中编译
            Add-Type -TypeDefinition $csDef -ReferencedAssemblies System.Drawing -ErrorAction Stop
        }
    }
}

# ── 保存当前窗口 HWND 以供子进程读取 ─────────────────────────────────────────
$hwndCacheFile = "$env:TEMP\claude-taskbar-hwnd.txt"

# 主逻辑
try {
    [ClaudeTaskbarOverlay]::SetStatus($Status, $hwndCacheFile)
} catch {
    exit 0
}

# 记录当��状态（busy 为空操作，不覆盖状态文件）
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
