using System;
var o = Data.GameObjects.ByName("obj_coop");
Console.WriteLine("obj_coop visible=" + o.Visible + " persistent=" + o.Persistent + " depth=" + o.Depth);
for (int t = 0; t < o.Events.Count; t++)
    foreach (var e in o.Events[t])
        foreach (var a in e.Actions)
            Console.WriteLine("  type " + t + " sub " + e.EventSubtype + " -> " + a.CodeId?.Name?.Content);
