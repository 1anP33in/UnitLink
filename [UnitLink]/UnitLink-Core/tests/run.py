"""Runs UnitLink Core Lua checks with a real Lua 5.4 interpreter (lupa).
1. Syntax-compiles every .lua file in the resource.
2. Runs tests.lua (pure-logic unit tests) with FiveM stubs.
Usage (from anywhere): python -P tests/run.py   (needs: pip install lupa)
"""
import os
import sys
from lupa import lua54

root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
here = os.path.dirname(os.path.abspath(__file__))

lua = lua54.LuaRuntime(unpack_returned_tuples=True)
compile_check = lua.eval('function(src, name) local f, err = load(src, "@" .. name) if f then return true end return err end')

failures = 0
count = 0
for dirpath, _, files in os.walk(root):
    for f in files:
        if f.endswith('.lua'):
            p = os.path.join(dirpath, f)
            with open(p, encoding='utf-8') as fh:
                src = fh.read()
            count += 1
            r = compile_check(src, os.path.relpath(p, root))
            if r is not True:
                failures += 1
                print('SYNTAX ERROR:', r)
print(f'syntax: {count} files compiled, {failures} errors')

rt = lua54.LuaRuntime(unpack_returned_tuples=True)
rt.globals().UNITLINK_ROOT = root.replace('\\', '/')
with open(os.path.join(here, 'tests.lua'), encoding='utf-8') as fh:
    ok = rt.execute(fh.read())
sys.exit(1 if failures or not ok else 0)
