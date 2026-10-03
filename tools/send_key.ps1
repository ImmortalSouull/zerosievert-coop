# Focus the main window of a process id and tap one virtual key: send_key.ps1 -ProcId 1234 -Vk 0x20
param([int]$ProcId, [int]$Vk, [int]$HoldMs = 60)
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class K {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint type);
}
"@
$p = Get-Process -Id $ProcId
$h = $p.MainWindowHandle
[K]::ShowWindow($h, 9) | Out-Null
[K]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 150
$scan = [byte][K]::MapVirtualKey($Vk, 0)
[K]::keybd_event([byte]$Vk, $scan, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds $HoldMs
[K]::keybd_event([byte]$Vk, $scan, 2, [UIntPtr]::Zero)
"ok $ProcId"
