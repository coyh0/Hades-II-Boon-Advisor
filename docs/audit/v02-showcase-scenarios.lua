-- Audit fixture only: run with BOON_AUDIT_ROOT pointing at the extracted showcase.
local root = assert(BOON_AUDIT_ROOT)
local scorer = assert(loadfile(root .. '/src/ScoringEngine.lua'))()
local function profile(id) return assert(loadfile(root .. '/data/builds/' .. id .. '.lua'))() end
local morrigan = profile('sister_blades_morrigan_meta')
local coat = profile('black_coat_melinoe_intermediate')
local melinoe = profile('sister_blades_melinoe_intermediate')
local function evaluate(p, ids, kind, owned, replacement)
    local offers = {}
    for i, id in ipairs(ids) do
        offers[i] = {originalIndex=i, ItemName=id, Rarity='Common', TraitToReplace=replacement}
    end
    return scorer.scoreOffers({weapon=p.weapon, aspect=p.aspect, offerKind=kind or 'boon',
        godTraits=owned or {}, hammers={}, activeArcana={}, offers=offers}, p)
end
local function mode(p, ids, expected)
    local results = evaluate(p, ids, 'hammer')
    assert(scorer.getRankingDecision(results, true).mode == expected, expected .. ' Hammer ranking failed')
    return results
end
local m = mode(morrigan, {'DaggerTripleBuffTrait','DaggerAttackFinisherTrait'}, 'full')
assert(m[1].score == -1 and m[2].score == -2)
mode(morrigan, {'DaggerTripleBuffTrait','DaggerAttackFinisherTrait','DaggerSpecialJumpTrait'}, 'partial')
mode(morrigan, {'DaggerTripleBuffTrait','DaggerSpecialJumpTrait','DaggerTripleRepeatWomboTrait'}, 'none')
local c = mode(coat, {'SuitDashAttackTrait','SuitAttackSpeedTrait','SuitAttackSizeTrait'}, 'full')
assert(c[1].score == -1 and c[2].score == -2 and c[3].score == -3)
local conditional = mode(coat, {'SuitAttackSizeTrait','SuitAttackSpeedTrait','SuitSpecialAutoTrait'}, 'partial')
assert(not conditional[3].scoreComplete and conditional[3].hammerCondition == 'Special branch')
local a = evaluate(coat, {'PoseidonWeaponBoon','HestiaWeaponBoon','ZeusWeaponBoon'})
assert(a[1].score == 12 and a[2].score == 8 and a[3].score == 8)
for _, id in ipairs({'HestiaWeaponBoon','ZeusWeaponBoon'}) do
    local replacement = evaluate(coat, {id}, 'boon', {{Name='PoseidonWeaponBoon',Slot='Melee'}}, 'PoseidonWeaponBoon')[1]
    assert(not replacement.scoreComplete, 'replacement of core Poseidon must remain unresolved')
    for _, reason in ipairs(replacement.reasons) do
        assert(reason.code ~= 'FILL_EMPTY_PRIMARY_CORE', 'replacement cannot earn empty-slot bonus')
    end
end
local ares = scorer.scoreOffers({weapon=melinoe.weapon,aspect=melinoe.aspect,
    godTraits={},hammers={},activeArcana={},offers={{originalIndex=1,ItemName='AresWeaponBoon',Rarity='Rare'}}}, melinoe)[1]
assert(ares.score == 13 and ares.covered and ares.scoreComplete, 'base Ares regression')
