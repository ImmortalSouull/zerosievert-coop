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

// Extension functions the game never calls itself (e.g. Steam lobby/P2P) have no FUNC entry, so the
// compiler would treat calls to them as variable calls. Declare every one our code uses.
var modText = string.Join("\n", Directory.GetFiles(gmlDir, "*.gml").Select(File.ReadAllText));
int declared = 0;
foreach (var ext in Data.Extensions)
    foreach (var file in ext.Files)
        foreach (var fn in file.Functions)
        {
            string name = fn.Name.Content;
            if (System.Text.RegularExpressions.Regex.IsMatch(modText, @"\b" + name + @"\s*\(") && Data.Functions.ByName(name) == null)
            {
                Data.Functions.EnsureDefined(name, Data.Strings);
                declared++;
            }
        }
Console.WriteLine($"declared {declared} extension functions");

var group = new UndertaleModLib.Compiler.CodeImportGroup(Data)
{
    AutoCreateAssets = true,
    ThrowOnNoOpFindReplace = true
};

// UTMT's compiler does not share #macro across code entries: expand them textually here.
var sources = new Dictionary<string, string>();
var macros = new Dictionary<string, string>();
var macroRx = new System.Text.RegularExpressions.Regex(@"^#macro\s+(\w+)\s+(.+)$", System.Text.RegularExpressions.RegexOptions.Multiline);
foreach (string file in Directory.GetFiles(gmlDir, "*.gml").OrderBy(f => f))
{
    string text = File.ReadAllText(file).Replace("\r\n", "\n");
    foreach (System.Text.RegularExpressions.Match m in macroRx.Matches(text)) macros[m.Groups[1].Value] = m.Groups[2].Value.Trim();
    sources[Path.GetFileNameWithoutExtension(file)] = macroRx.Replace(text, "");
}
int files = 0;
foreach (var kv in sources)
{
    string text = kv.Value;
    for (int pass = 0; pass < 3; pass++)
        foreach (var m in macros)
            text = System.Text.RegularExpressions.Regex.Replace(text, @"\b" + m.Key + @"\b", m.Value);
    var left = System.Text.RegularExpressions.Regex.Match(text, @"\bCOOP_[A-Z0-9_]+\b");
    if (left.Success) throw new Exception($"unexpanded macro {left.Value} in {kv.Key}");
    group.QueueReplace(kv.Key, text);
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
