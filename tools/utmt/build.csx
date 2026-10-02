// Builds the co-op data.win: imports mod/gml/*.gml and applies mod/hooks.txt.
// Run via tools/build.sh (UndertaleModCli load <vanilla> -s build.csx -o <out>).
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using UndertaleModLib;
using UndertaleModLib.Models;

string root = Environment.GetEnvironmentVariable("COOP_ROOT") ?? @"C:\Users\pasha\zerosievert-coop";
string gmlDir = Path.Combine(root, "mod", "gml");
string hooksFile = Path.Combine(root, "mod", "hooks.txt");

var group = new UndertaleModLib.Compiler.CodeImportGroup(Data)
{
    AutoCreateAssets = true,
    ThrowOnNoOpFindReplace = true
};

int files = 0;
foreach (string file in Directory.GetFiles(gmlDir, "*.gml").OrderBy(f => f))
{
    group.QueueReplace(Path.GetFileNameWithoutExtension(file), File.ReadAllText(file).Replace("\r\n", "\n"));
    files++;
}

int hooks = 0;
string[] lines = File.ReadAllText(hooksFile).Replace("\r\n", "\n").Split('\n');
for (int i = 0; i < lines.Length; i++)
{
    if (!lines[i].StartsWith("### ")) continue;
    string[] head = lines[i].Substring(4).Split(' ');
    string op = head[0], code = head[1];
    var body = new List<string>();
    int j = i + 1;
    while (j < lines.Length && lines[j] != "<<<END") { body.Add(lines[j]); j++; }
    i = j;
    if (op == "findreplace")
    {
        int f = body.IndexOf("<<<FIND"), r = body.IndexOf("<<<REPLACE");
        string find = string.Join("\n", body.Skip(f + 1).Take(r - f - 1));
        string repl = string.Join("\n", body.Skip(r + 1));
        group.QueueFindReplace(code, find, repl, true);
    }
    else if (op == "prepend") group.QueuePrepend(code, string.Join("\n", body));
    else if (op == "append") group.QueueAppend(code, string.Join("\n", body));
    else throw new Exception("unknown hook op " + op);
    hooks++;
}

group.Import(true);

var coopObj = Data.GameObjects.ByName("obj_coop");
coopObj.Persistent = true;
coopObj.Visible = true;

Console.WriteLine($"COOP BUILD OK: {files} gml files, {hooks} hooks");
