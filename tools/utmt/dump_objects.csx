using System;
using System.IO;
using System.Linq;
var sb = new System.Text.StringBuilder();
foreach (var o in Data.GameObjects) {
    var parent = o.ParentId?.Name?.Content ?? "-";
    sb.AppendLine(o.Name.Content + "\tparent=" + parent + "\tsprite=" + (o.Sprite?.Name?.Content ?? "-") + "\tpersistent=" + o.Persistent + "\tvisible=" + o.Visible);
}
File.WriteAllText(@"C:\Users\pasha\zerosievert-coop-work\objects.tsv", sb.ToString());
var sb2 = new System.Text.StringBuilder();
foreach (var r in Data.Rooms) sb2.AppendLine(r.Name.Content + "\t" + r.Width + "x" + r.Height + "\tinst=" + r.GameObjects.Count);
File.WriteAllText(@"C:\Users\pasha\zerosievert-coop-work\rooms.tsv", sb2.ToString());
var sb3 = new System.Text.StringBuilder();
foreach (var r in Data.Rooms.Take(1)) {}
sb3.AppendLine("RoomOrder:"); foreach (var r in Data.GeneralInfo.RoomOrder) sb3.AppendLine(r.Resource.Name.Content);
File.WriteAllText(@"C:\Users\pasha\zerosievert-coop-work\roomorder.txt", sb3.ToString());
Console.WriteLine("done");
