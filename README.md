# Claude Taskbar Monitor

Windows 浠诲姟鏍忕姸鎬佺洃鎺ф彃浠讹紝閫傜敤浜?**PowerShell + CCswitch + Claude Code** 鐨勪娇鐢ㄥ満鏅€?

鍦?Claude Code 杩愯鏃讹紝閫氳繃浠诲姟鏍?PowerShell 鍥炬爣鐨勯鑹插疄鏃舵彁绀虹姸鎬侊紝鏃犻渶鍒囨崲绐楀彛銆?

## 鐘舵€佽鏄?

| 鐘舵€?| 鏁堟灉 | 瑙﹀彂鏃舵満 | 娑堝け鏃舵満 |
|------|------|----------|----------|
| 瀹屾垚 | 馃煝 缁胯壊杩涘害鏉?| 姝ｅ父缁撴潫鍥炲 | 鑱氱劍绐楀彛鍚?1 绉掕嚜鍔ㄦ秷澶?|
| 璀﹀憡 | 馃煛 鏁翠釜鎸夐挳鍙橀粍 | 闇€瑕佺敤鎴锋搷浣滐紙鏉冮檺瀹℃壒銆佺綉缁滃紓甯哥瓑锛?| 鐢ㄦ埛澶勭悊鍚庡伐鍏锋墽琛屾椂鑷姩娓呴櫎 |
| 绌洪棽 | 鏃犳晥鏋?| 鐒︾偣瑙﹀彂 / 鑷姩娓呴櫎 | 鈥?|

## 绯荤粺瑕佹眰

- Windows 10 / 11
- PowerShell 5.1+
- [Claude Code](https://docs.anthropic.com/claude-code) CLI
- Windows Terminal锛堟帹鑽愶紝浣嗛潪蹇呴』锛?

## 瀹夎

```powershell
# 1. 涓嬭浇浠撳簱
git clone https://github.com/lyshrines/claude-taskbar-monitor.git
cd claude-taskbar-monitor

# 2. 杩愯瀹夎鑴氭湰锛堥渶瑕?PowerShell锛屾櫘閫氭潈闄愬嵆鍙級
powershell -ExecutionPolicy Bypass -File install.ps1
```

瀹夎瀹屾垚鍚?*閲嶅惎 Claude Code** 鍗冲彲鐢熸晥銆?

## 鍗歌浇

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

## 宸ヤ綔鍘熺悊

閫氳繃 Claude Code 鐨?Hook 绯荤粺锛圫essionStart / PreToolUse / PostToolUse / Notification / Stop锛夛紝
鍦?PowerShell 杩涚▼鐨勪换鍔℃爮鍥炬爣涓婅皟鐢?Windows `ITaskbarList3` COM 鎺ュ彛璁剧疆杩涘害鏉￠鑹层€?

## /taskbar-monitor 鍛戒护

瀹夎鍚庡彲鍦?Claude Code 涓繍琛?`/taskbar-monitor` 妫€鏌ョ姸鎬佸苟娴嬭瘯鏄剧ず鏁堟灉銆?