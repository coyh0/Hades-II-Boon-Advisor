"""Reproduce the read-only Registry audit against local canonical and native text.

Run from repository root; outputs documentation only, never canonical/runtime data.
Native-name matches establish identity, not mechanics or recommendation eligibility.
"""
import collections
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/audit'
GAME_ROOT = os.environ.get('HADES2_GAME_ROOT')
if not GAME_ROOT:
    raise SystemExit('Set HADES2_GAME_ROOT to the local Hades II installation directory.')
NATIVE = Path(GAME_ROOT) / 'Content'
source = json.loads((OUT / 'v02-registry-source.json').read_text(encoding='utf-8'))
rows = source['rows']
assert len(rows) == len({r['recommendationId'] for r in rows}) == 118
assert collections.Counter(r['canonicalProfileId'] for r in rows) == {
    'sister_blades_melinoe_intermediate': 38,
    'sister_blades_morrigan_meta': 45,
    'black_coat_melinoe_intermediate': 35,
}
assert all(r['runtimeImportStatus'] == 'documentation_only' for r in rows)
text_path = NATIVE / 'Game/Text/en/TraitText.en.sjson'
native_text = text_path.read_text(encoding='utf-8-sig')
meta_path = NATIVE / 'Scripts/MetaUpgradeData.lua'
trait_meta_path = NATIVE / 'Scripts/TraitData_MetaUpgrade.lua'
meta_text = meta_path.read_text(encoding='utf-8-sig')
trait_meta_text = trait_meta_path.read_text(encoding='utf-8-sig')
names = collections.defaultdict(list)
for match in re.finditer(r'\bId\s*=\s*"([^"\n]+)"([\s\S]*?)(?=\bId\s*=|\Z)', native_text):
    display = re.search(r'\bDisplayName\s*=\s*"([^"\n]+)"', match[2])
    if display and not match[1].endswith('_Expired'):
        names[display[1]].append((match[1], native_text.count('\n', 0, match.start()) + 1))
profiles = {p.stem: json.loads(p.read_text(encoding='utf-8-sig'))
            for p in (ROOT / 'data/canonical/profiles').glob('*.json')}
mechanics = {p.stem: json.loads(p.read_text(encoding='utf-8-sig'))
             for p in (ROOT / 'data/canonical/mechanics').glob('*.json')}
# These Arcana display names are spoken/displayed from MetaUpgradeData entries,
# whose TraitName points to the runtime trait ID. Verify the relationship in
# native data instead of guessing from the Curator's display label.
arcana_ids = {
    'The Huntress': ('LowManaDamageBonus', 'LowManaDamageMetaupgrade', 'LowManaDamageBonus'),
    'The Wayward Son': ('HealthRegen', 'DoorHealMetaUpgrade', 'HealthRegen'),
    'Divinity': ('EpicRarityBoost', 'EpicRarityBoostMetaUpgrade', 'EpicRarityBoost'),
}
for display_name, (upgrade_name, trait_id, text_id) in arcana_ids.items():
    block = re.search(rf'(?m)^\s*{re.escape(upgrade_name)}\s*=\s*--[^\n]*\n\s*\{{([\s\S]*?)(?=^\s*[A-Za-z_]\w*\s*=\s*--|\Z)', meta_text)
    assert block and f'TraitName = "{trait_id}"' in block[1], (display_name, upgrade_name, trait_id)
    assert re.search(rf'(?m)^\s*{re.escape(trait_id)}\s*=', trait_meta_text), trait_id
selected = {
    'br2_blades_morrigan_meta_dbc147e065e62721': ('DaggerTripleBuffTrait', 'hammer priority 1'),
    'br2_blades_morrigan_meta_0e7999238013ae66': ('DaggerAttackFinisherTrait', 'hammer alternative 2'),
    'br2_coat_melinoe_intermediate_78929f2a975027d2': ('HestiaWeaponBoon', 'Attack alternatives'),
    'br2_coat_melinoe_intermediate_ef44fbef3991267d': ('ZeusWeaponBoon', 'Attack alternatives'),
    'br2_coat_melinoe_intermediate_093a7c1192f7eb29': ('SuitAttackSizeTrait', 'hammer alternative 3'),
}
assert set(selected) <= {r['recommendationId'] for r in rows}
matrix = []
for row in rows:
    p = profiles[row['canonicalProfileId']]
    m = mechanics[p['mechanicsTemplate']]
    identity = names.get(row['displayName'], [])
    tid = identity[0][0] if len(identity) == 1 else None
    name_evidence = f'TraitText.en.sjson:{identity[0][1]}' if tid else 'Unresolved exact name; no inferred ID'
    if row['category'] == 'Arcana' and row['displayName'] in arcana_ids:
        upgrade_name, trait_id, text_id = arcana_ids[row['displayName']]
        upgrade_line = meta_text.count('\n', 0, meta_text.index(f'\n\t{upgrade_name} =')) + 2
        trait_line = trait_meta_text.count('\n', 0, trait_meta_text.index(f'\n\t{trait_id} =')) + 2
        text_entry = re.search(rf'\bId\s*=\s*"{re.escape(text_id)}"([\s\S]*?)(?=\bId\s*=|\Z)', native_text)
        assert text_entry and f'DisplayName = "{row["displayName"]}"' in text_entry[1], row['displayName']
        display_line = native_text.count('\n', 0, text_entry.start()) + 1
        assert display_line is not None, row['displayName']
        tid = trait_id
        name_evidence = (f'MetaUpgradeData.lua:{upgrade_line} + TraitData_MetaUpgrade.lua:{trait_line}; '
                         f'TraitText.en.sjson:{display_line}')
    baseline = []
    keepsakes = [entry for phase in p.get('keepsakePlan', {}).values() for entry in phase
                 if entry['recommendationId'] == row['recommendationId']]
    if keepsakes:
        assert len(keepsakes) == 1
        entry = keepsakes[0]
        assert entry['documentaryPriority'] == int(row['documentaryPriority'])
        assert entry['classification'] == row['classification'].lower()
        assert entry['conditionText'] == row['conditionText']
        if tid:
            assert tid == entry['traitId'], (row['displayName'], tid, entry['traitId'])
        else:
            tid = entry['traitId']
            name_evidence = 'Existing keepsakePlan recommendationId mapping; documentary alias'
        baseline.append('metadata-only keepsakePlan; no condition execution')
    if tid:
        for slot, policy in p.get('slots', {}).items():
            for role in ('core', 'alternatives', 'preferred', 'discouraged'):
                if tid in policy.get(role, []):
                    baseline.append(f'{slot}.{role}')
            for branch in policy.get('branches', []):
                if tid == branch['traitId']:
                    baseline.append(f'{slot}.branches {branch["classification"]} {branch["priority"]}')
        for hammer in p.get('hammerPlan', []):
            if tid == hammer['traitId']:
                baseline.append(f'hammerPlan {hammer["classification"]} {hammer["priority"]}'
                                + ('; INCOMPLETE: ' + hammer['condition'] if hammer.get('condition') else ''))
        for key in ('aspectInteractions', 'rules', 'traitSemantics', 'hammerRoles'):
            if tid in p.get(key, {}) or tid in m.get(key, {}):
                baseline.append(f'existing {key}; contextual evaluation required')
    if row['recommendationId'] in selected:
        expected, target = selected[row['recommendationId']]
        assert tid == expected, (row['displayName'], tid, expected)
        disposition = 'SELECTED_DELTA: ' + target
    elif keepsakes:
        disposition = 'PRESERVE_METADATA_ONLY'
    elif row['category'] in ('Arcana', 'Familiar', 'Hex', 'Gameplay'):
        disposition = 'DEFER_DOCUMENTARY_GUIDANCE'
    elif baseline:
        disposition = 'PRESERVE_BASELINE; documentary condition/classification is not a new rule'
    else:
        disposition = 'DEFER_NEW_RECOMMENDATION; generic slot coverage may already exist'
    matrix.append({
        'sheetRow': row['sheetRow'], 'recommendationId': row['recommendationId'],
        'profile': row['canonicalProfileId'], 'category': row['category'], 'name': row['displayName'],
        'nativeId': tid, 'identityEvidence': name_evidence,
        'documentaryClassification': row['classification'], 'documentaryPriority': row['documentaryPriority'],
        'documentaryCondition': row['conditionText'], 'sourceFingerprint': row['sourceFingerprint'],
        'mainBaseline': baseline or ['No explicit recommendation entry; not proof of runtime non-coverage'],
        'decision': disposition,
        'sourceRuntimeStatus': row['runtimeImportStatus'],
        'mechanicsStatus': 'See five-delta evidence report' if row['recommendationId'] in selected
                          else 'Not newly attested by name matching; preserve existing evidence limits',
    })
result = {'baselineCommit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
          'nativeTextSha256': hashlib.sha256(text_path.read_bytes()).hexdigest(),
          'nativeMetaUpgradeSha256': hashlib.sha256(meta_path.read_bytes()).hexdigest(),
          'nativeTraitMetaUpgradeSha256': hashlib.sha256(trait_meta_path.read_bytes()).hexdigest(),
          'rows': matrix}
(OUT / 'v02-registry-matrix.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
lines = ['# Registry v0.2: 118-row audit', '',
         'Baseline: `' + result['baselineCommit'] + '`. Source snapshot: `v02-registry-source.json`.', '',
         'Native text matching verifies names only. Conditions and documentary priorities are never executed automatically.',
         'Existing generic slot evaluation is separate from an explicit build recommendation. All source rows remain documentation_only.', '',
         '| Sheet row | Profile | Name / ID | Documentary role / priority | Main baseline | Decision |',
         '| --- | --- | --- | --- | --- | --- |']
def cell(value):
    return str(value).replace('|', '\\|').replace('\n', ' ')
for row in matrix:
    short = row['profile'].replace('sister_blades_', '').replace('black_coat_', 'coat_')
    lines.append('| ' + ' | '.join(map(cell, [row['sheetRow'], short,
        row['name'] + ' / ' + (row['nativeId'] or 'unresolved'),
        row['documentaryClassification'] + ' / ' + row['documentaryPriority'],
        '; '.join(row['mainBaseline']), row['decision']])) + ' |')
(OUT / 'v02-registry-matrix.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(json.dumps({'rows': len(matrix), 'decisions': dict(collections.Counter(r['decision'].split(':')[0].split(';')[0] for r in matrix)),
                  'unresolvedNames': [r['name'] for r in matrix if not r['nativeId']]}))
