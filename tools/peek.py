"""Read the co-op phase buffer (see coop_phase in coop_core.gml) from a running/frozen game process.
usage: python tools/peek.py <pid> <address>"""
import ctypes, sys, time
k32 = ctypes.windll.kernel32
k32.OpenProcess.restype = ctypes.c_void_p
h = k32.OpenProcess(0x0010 | 0x0400, False, int(sys.argv[1]))
addr = int(sys.argv[2])
for _ in range(int(sys.argv[3]) if len(sys.argv) > 3 else 3):
    buf = ctypes.create_string_buffer(256); n = ctypes.c_size_t()
    if not k32.ReadProcessMemory(ctypes.c_void_p(h), ctypes.c_void_p(addr), buf, 256, ctypes.byref(n)):
        sys.exit("read failed")
    count = int.from_bytes(buf.raw[:4], "little")
    print(count, buf.raw[4:].split(b"\0")[0].decode("utf-8", "replace"))
    time.sleep(0.5)
