"""Read-only runtime comparison of main and the existing showcase commit.

Extracts Git content into dist/audit only. No game execution or installation changes.
"""
import ctypes
import hashlib
import io
import json
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/audit'
WORK = ROOT / 'dist/audit'
WORK.mkdir(parents=True, exist_ok=True)
BRANCH = '4a647f607023602a34b1d705a15a39cfbb3bc19d'
matrix = json.loads((OUT / 'v02-registry-matrix.json').read_text(encoding='utf-8'))['rows']
dll = ctypes.CDLL('D:/Dev/Games/HadesII-Dev/Ship/lua52.dll')
dll.luaL_newstate.restype = ctypes.c_void_p
dll.luaL_openlibs.argtypes = [ctypes.c_void_p]
dll.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
dll.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
dll.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
dll.lua_tolstring.restype = ctypes.c_char_p
dll.lua_close.argtypes = [ctypes.c_void_p]
def lua(code):
    state = dll.luaL_newstate()
    try:
        dll.luaL_openlibs(state)
        status = dll.luaL_loadstring(state, code.encode())
        if not status:
            status = dll.lua_pcallk(state, 0, -1, 0, 0, None)
        return dll.lua_tolstring(state, -1, None).decode('utf-8', 'replace') if status else None
    finally:
        dll.lua_close(state)
def quote(value):
    return json.dumps(str(value).replace('\\', '/'))
archive = subprocess.check_output(['git', 'archive', '--format=zip', BRANCH], cwd=ROOT)
branch_root = WORK / BRANCH[:7]
branch_root.mkdir(exist_ok=True)
with zipfile.ZipFile(io.BytesIO(archive)) as z:
    for member in z.infolist():
        assert (branch_root / member.filename).resolve().is_relative_to(branch_root.resolve())
    z.extractall(branch_root)
encoding = []
for rel in ('ROADMAP.md', 'tests/canonical_profiles_spec.ps1', 'tests/scoring_spec.lua'):
    data = (branch_root / rel).read_bytes()
    try:
        data.decode('utf-8-sig')
        valid = True
    except UnicodeDecodeError:
        valid = False
    encoding.append({'path': rel, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                     'validUtf8': valid, 'nulBytes': data.count(b'\0')})
compile_error = lua('assert(loadfile(' + quote(branch_root / 'tests/scoring_spec.lua') + '))')
results = {}
for label, root in [('main', ROOT), ('showcase', branch_root)]:
    dest = WORK / (label + '-runtime.tsv')
    calls = []
    for row in matrix:
        if row['nativeId'] and row['category'] in ('Boon', 'Support', 'Hammer'):
            calls.append('probe(' + ','.join(quote(x) for x in [row['recommendationId'], row['profile'], row['nativeId'],
                         'hammer' if row['category'] == 'Hammer' else 'boon']) + ')')
    code = '''
local score = assert(loadfile(ROOT .. '/src/ScoringEngine.lua'))()
local output = assert(io.open(OUTPUT, 'w'))
local function probe(id, profileId, trait, kind)
    local p = assert(loadfile(ROOT .. '/data/builds/' .. profileId .. '.lua'))()
    local snapshot = {weapon=p.weapon, aspect=p.aspect, godTraits={}, hammers={}, activeArcana={},
        offerKind=kind, offers={{originalIndex=1,ItemName=trait,Rarity='Common'}}}
    local r = score.scoreOffers(snapshot,p)[1]
    local reasons = {}
    for _, reason in ipairs(r.reasons or {}) do reasons[#reasons+1]=reason.code end
    output:write(table.concat({id,trait,tostring(r.score),tostring(r.covered),tostring(r.scoreComplete),
        table.concat(reasons,',')}, '\\t') .. '\\n')
end
CALLS
output:close()
'''.replace('ROOT', quote(root)).replace('OUTPUT', quote(dest)).replace('CALLS', '\n'.join(calls))
    error = lua(code)
    assert error is None, error
    results[label] = [dict(zip(('recommendationId', 'nativeId', 'score', 'covered', 'complete', 'reasons'), line.split('\t')))
                      for line in dest.read_text().splitlines()]
deltas = []
for old, new in zip(results['main'], results['showcase']):
    assert old['recommendationId'] == new['recommendationId']
    if old != new:
        deltas.append({'main': old, 'showcase': new})
report = {'showcaseCommit': BRANCH, 'encodingChecks': encoding,
          'showcaseScoringTestLoadError': compile_error,
          'scenario': 'Single Common offer, empty slots, no owned traits/hammers/Arcana; not live evidence or a ranking test',
          'results': results, 'deltas': deltas}
scenario_error = lua('BOON_AUDIT_ROOT=' + quote(branch_root) + '\nassert(loadfile('
                     + quote(OUT / 'v02-showcase-scenarios.lua') + '))()')
report['isolatedShowcaseScenarios'] = scenario_error or 'PASS'
(OUT / 'v02-runtime-comparison.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'encodingChecks': encoding, 'testLoadError': compile_error,
                  'isolatedShowcaseScenarios': report['isolatedShowcaseScenarios'],
                  'probedPerRevision': len(results['main']), 'changedRows': len(deltas)}))
