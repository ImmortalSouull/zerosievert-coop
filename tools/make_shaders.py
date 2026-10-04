"""Compile the replacement shaders in mod/shaders/*.hlsl to DXBC with the system d3dcompiler_47.dll.
usage: python tools/make_shaders.py   (writes mod/shaders/<name>.dxbc; build.csx splices them into data.win)"""
import ctypes, glob, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
d3d = ctypes.WinDLL("d3dcompiler_47.dll")


def blob_bytes(p):
    vt = ctypes.cast(p, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
    ptr = ctypes.WINFUNCTYPE(ctypes.c_void_p, ctypes.c_void_p)(vt[3])(p)
    size = ctypes.WINFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p)(vt[4])(p)
    return ctypes.string_at(ptr, size)


def compile_file(path, target):
    src = open(path, "rb").read()
    code, err = ctypes.c_void_p(), ctypes.c_void_p()
    hr = d3d.D3DCompile(src, len(src), path.encode(), None, None, b"main", target.encode(), 1 << 15, 0,
                        ctypes.byref(code), ctypes.byref(err))  # D3DCOMPILE_OPTIMIZATION_LEVEL3
    if hr != 0:
        sys.exit(f"{path}: compile failed {hr & 0xffffffff:x}\n" + (blob_bytes(err).decode("latin1") if err else ""))
    return blob_bytes(code)


for f in glob.glob(os.path.join(ROOT, "mod", "shaders", "*_ps.hlsl")):
    out = f[:-5] + ".dxbc"
    data = compile_file(f, "ps_4_0")
    open(out, "wb").write(data)
    print(os.path.basename(out), len(data), "bytes")
