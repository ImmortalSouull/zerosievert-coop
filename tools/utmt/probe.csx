using System;
using System.Linq;
using System.Reflection;
foreach (var asm in AppDomain.CurrentDomain.GetAssemblies().Where(a => a.GetName().Name.StartsWith("UndertaleModLib")))
foreach (var t in asm.GetTypes())
foreach (var m in t.GetMethods(BindingFlags.Public|BindingFlags.Static|BindingFlags.Instance|BindingFlags.DeclaredOnly))
    if (m.Name.Contains("EnsureDefined") || m.Name.Contains("DefineFunction") || (t.Name.Contains("GlobalDecompileContext") && m.Name.Contains("Build")))
        Console.WriteLine(t.FullName + "." + m.Name + "(" + string.Join(", ", m.GetParameters().Select(p => p.ParameterType.Name + " " + p.Name)) + ")");
var gt = typeof(UndertaleModLib.Compiler.CodeImportGroup).GetProperty("GlobalContext").PropertyType;
Console.WriteLine("GlobalContext type: " + gt.FullName);
foreach (var m in gt.GetMethods(BindingFlags.Public|BindingFlags.Instance|BindingFlags.DeclaredOnly)) Console.WriteLine("  " + m.Name);
