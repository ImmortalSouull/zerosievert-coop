// Decompiles every code entry of the loaded data.win into $COOP_DECOMP (default: <work>/decomp/CodeEntries).
// Run via tools/decompile.sh. Needed after every game update: hooks.txt is matched against this code.
using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using UndertaleModLib.Models;

string outDir = Environment.GetEnvironmentVariable("COOP_DECOMP");
if (string.IsNullOrEmpty(outDir)) throw new Exception("COOP_DECOMP is not set");
Directory.CreateDirectory(outDir);

var ctx = new GlobalDecompileContext(Data);
var settings = Data.ToolInfo.DecompilerSettings;
var todo = Data.Code.Where(c => c.ParentEntry is null).ToList();
int failed = 0;
Parallel.ForEach(todo, code =>
{
    string path = Path.Combine(outDir, code.Name.Content + ".gml");
    try
    {
        File.WriteAllText(path, new Underanalyzer.Decompiler.DecompileContext(ctx, code, settings).DecompileToString());
    }
    catch (Exception e)
    {
        System.Threading.Interlocked.Increment(ref failed);
        File.WriteAllText(path, "/*\nDECOMPILER FAILED!\n\n" + e + "\n*/");
    }
});
Console.WriteLine($"DECOMPILE OK: {todo.Count} entries, {failed} failed");
