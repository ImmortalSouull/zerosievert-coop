# Print the text of every GameMaker "Code Error" dialog.
Add-Type -AssemblyName UIAutomationClient
$r = [Windows.Automation.AutomationElement]::RootElement
$c = New-Object Windows.Automation.PropertyCondition([Windows.Automation.AutomationElement]::NameProperty, 'Code Error')
foreach ($w in $r.FindAll([Windows.Automation.TreeScope]::Children, $c)) {
  foreach ($e in $w.FindAll([Windows.Automation.TreeScope]::Descendants, [Windows.Automation.Condition]::TrueCondition)) {
    $n = $e.Current.Name
    if ($n.Length -gt 20) { $n.Substring(0, [Math]::Min(1500, $n.Length)) }
  }
  '-----'
}
