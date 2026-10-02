using System;
using System.Linq;
using System.Reflection;
var ty = typeof(UndertaleModLib.Compiler.CodeImportGroup);
foreach (var m in ty.GetMethods(BindingFlags.Public|BindingFlags.Instance|BindingFlags.DeclaredOnly))
    Console.WriteLine(m.Name + "(" + string.Join(", ", m.GetParameters().Select(p => p.ParameterType.Name + " " + p.Name)) + ")");
foreach (var p in ty.GetProperties()) Console.WriteLine("prop " + p.Name);
foreach (var e in Data.Extensions) {
    Console.WriteLine("EXT " + e.Name.Content);
    foreach (var f in e.Files) {
        Console.WriteLine("  file " + f.Filename.Content + " funcs=" + f.Functions.Count);
        foreach (var fn in f.Functions) Console.WriteLine("    " + fn.Name.Content + " ext=" + fn.ExtName.Content + " ret=" + fn.RetType + " args=" + string.Join(",", fn.Arguments.Select(a => a.Type.ToString())));
    }
}
Console.WriteLine("GMVersion " + Data.GeneralInfo.Major + "." + Data.GeneralInfo.Minor + "." + Data.GeneralInfo.Release + "." + Data.GeneralInfo.Build);
