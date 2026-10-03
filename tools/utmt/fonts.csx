using System;
using System.Linq;
foreach (var f in Data.Fonts) Console.WriteLine(f.Name.Content + " size=" + f.EmSize + " glyphs=" + f.Glyphs.Count + " cyr=" + f.Glyphs.Count(g => g.Character >= 0x410 && g.Character <= 0x44F) + " range=" + f.RangeStart + "-" + f.RangeEnd);
