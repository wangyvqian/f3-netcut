# f3-netcut.ps1 — 按 F3 全局热键断网 5 秒后自动恢复
# 需要以管理员身份运行

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "错误：请以管理员身份运行本脚本！" -ForegroundColor Red
    Read-Host "按回车退出"
    exit 1
}

Add-Type -AssemblyName System.Windows.Forms

$src = @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class HotkeyWindow : NativeWindow, IDisposable {
    [DllImport("user32.dll")]
    static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")]
    static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    const int WM_HOTKEY = 0x0312;
    const int HOTKEY_ID = 0xF301;
    Action onHotkey;

    public HotkeyWindow(Action cb) {
        onHotkey = cb;
        CreateHandle(new CreateParams());
        if (!RegisterHotKey(Handle, HOTKEY_ID, 0, (uint)Keys.F3))
            throw new Exception("F3 热键注册失败（可能被其他程序占用）");
    }

    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_HOTKEY && m.WParam.ToInt32() == HOTKEY_ID) {
            try { onHotkey(); } catch {}
        }
        base.WndProc(ref m);
    }

    public void Dispose() {
        UnregisterHotKey(Handle, HOTKEY_ID);
        DestroyHandle();
    }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Windows.Forms, System.Drawing

$cutNet = {
    # 找到当前已连接的物理网卡（WLAN / 以太网）
    $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
    if (-not $adapters) {
        Write-Host "[{0}] 没有检测到已连接的物理网卡" -f (Get-Date -Format 'HH:mm:ss')
        return
    }
    foreach ($a in $adapters) {
        Write-Host ("[{0}] 断开网卡: {1}" -f (Get-Date -Format 'HH:mm:ss'), $a.Name) -ForegroundColor Yellow
        Disable-NetAdapter -Name $a.Name -Confirm:$false
    }
    Start-Sleep -Seconds 5
    foreach ($a in $adapters) {
        Enable-NetAdapter -Name $a.Name -Confirm:$false
        Write-Host ("[{0}] 已恢复网卡: {1}" -f (Get-Date -Format 'HH:mm:ss'), $a.Name) -ForegroundColor Green
    }
}

Write-Host "==============================================" 
Write-Host " F3 快速断网 5 秒 已启动" -ForegroundColor Cyan
Write-Host " 按 F3：断开所有已连接物理网卡，5 秒后自动恢复"
Write-Host " 退出：直接关闭本窗口"
Write-Host "=============================================="

$hw = New-Object HotkeyWindow($cutNet)
try {
    [System.Windows.Forms.Application]::Run()
} finally {
    $hw.Dispose()
}
