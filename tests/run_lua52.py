"""Run isolated Lua tests using the audited game's Lua DLL, without launching Hades."""
import ctypes
from pathlib import Path
import sys

dll = ctypes.CDLL(str(Path(sys.argv[1]).resolve()))
dll.luaL_newstate.restype = ctypes.c_void_p
dll.luaL_openlibs.argtypes = [ctypes.c_void_p]
dll.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
dll.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                         ctypes.c_int, ctypes.c_void_p]
dll.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
dll.lua_tolstring.restype = ctypes.c_char_p
dll.lua_close.argtypes = [ctypes.c_void_p]
default_tests = [
    "tests/probe_spec.lua", "tests/phase2_spec.lua", "tests/scoring_spec.lua",
    "tests/partial_ranking_spec.lua", "tests/ui_spec.lua", "tests/localization_spec.lua",
    "tests/attack_branches_spec.lua",
    "tests/profile_resolver_spec.lua", "tests/focus_spec.lua", "tests/lobby_probe_spec.lua",
    "tests/argent_skull_medea_spec.lua", "tests/moonstone_axe_spec.lua",
    "tests/core_advisory_spec.lua", "tests/god_pool_context_spec.lua",
]
args = sys.argv[2:]
if args and args[0] == "--only":
    if len(args) == 1:
        raise ValueError("--only requires at least one test file")
    test_files = [path.encode("utf-8") for path in args[1:]]
else:
    test_files = [path.encode("utf-8") for path in default_tests + args]
for test_file in test_files:
    state = dll.luaL_newstate()
    if not state:
        raise RuntimeError("luaL_newstate failed")
    try:
        dll.luaL_openlibs(state)
        status = dll.luaL_loadfilex(state, test_file, None)
        if not status:
            status = dll.lua_pcallk(state, 0, -1, 0, 0, None)
        if status:
            raise RuntimeError(dll.lua_tolstring(state, -1, None).decode("utf-8", "replace"))
    finally:
        dll.lua_close(state)
