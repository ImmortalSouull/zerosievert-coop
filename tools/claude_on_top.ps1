# Keep the Claude desktop app window above every other window (game windows included), or release it.
# usage: powershell -NoProfile -File tools/claude_on_top.ps1 [-Off]
param([switch]$Off)
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class OnTop {
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@
$TOPMOST = [IntPtr](-1); $NOTOPMOST = [IntPtr](-2)
$SWP_NOSIZE_NOMOVE_NOACTIVATE = 0x0001 -bor 0x0002 -bor 0x0010
$wins = Get-Process claude -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
foreach ($p in $wins) {
  $after = if ($Off) { $NOTOPMOST } else { $TOPMOST }
  $ok = [OnTop]::SetWindowPos($p.MainWindowHandle, $after, 0, 0, 0, 0, $SWP_NOSIZE_NOMOVE_NOACTIVATE)
  "{0} '{1}': {2}" -f $p.Id, $p.MainWindowTitle, $(if ($Off) { "normal" } else { "always on top" })
}
if (-not $wins) { "Claude window not found" }
