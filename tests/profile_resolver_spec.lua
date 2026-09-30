local Resolver = assert(loadfile("src/ProfileResolver.lua"))()
local registry = assert(loadfile("data/builds/registry.lua"))()
local loadedProfiles = {}
for _, descriptor in pairs(registry) do loadedProfiles[descriptor.module] = assert(loadfile(descriptor.module))() end
local function check(value, message) assert(value, message) end
local function owned(...) local t = {}; for i = 1, select("#", ...) do t[i] = { Name = select(i, ...) } end; return t end

for _, key in ipairs({ "intermediate", "morrigan_meta", "coat_melinoe_intermediate", "starter" }) do
    check(registry[key] == nil, "retired profile remains selectable: " .. key)
end
for _, names in ipairs({ {}, { "ZeusSpecialBoon" }, { "ForceZeusBoonKeepsake" },
    { "AphroditeWeaponBoon" }, { "AresWeaponBoon" }, { "ForceAresBoonKeepsake" },
    { "AphroditeWeaponBoon", "ForceAresBoonKeepsake" } }) do
    local profile, reason = Resolver.resolve(registry, "WeaponLob", "LobCloseAttackAspect", nil,
        owned(table.unpack(names)), loadedProfiles)
    check(profile == registry.argent_skull_medea_mobalytics and reason == "only_candidate",
        "Medea singleton depended on unrelated boon or keepsake evidence")
end
local profile, reason = Resolver.resolve(registry, "WeaponLob", "LobCloseAttackAspect", "argent_skull_medea_mobalytics",
    owned("AresWeaponBoon"), loadedProfiles)
check(profile == registry.argent_skull_medea_mobalytics and reason == "preferred", "explicit Medea preference changed")
profile, reason = Resolver.resolve(registry, "WeaponLob", "LobCloseAttackAspect", "intermediate", {}, loadedProfiles)
check(profile == registry.argent_skull_medea_mobalytics and reason == "only_candidate",
    "retired preference blocked singleton auto")
profile, reason = Resolver.resolve(registry, "WeaponAxe", "AxeRecoveryAspect", nil, {}, loadedProfiles)
check(profile == registry.moonstone_axe_melinoe_mobalytics and reason == "only_candidate",
    "Moonstone Axe identity did not select its own Mobalytics profile")
for _, pair in ipairs({ { "WeaponDagger", "DaggerBackstabAspect" }, { "WeaponDagger", "DaggerTripleAspect" },
    { "WeaponSuit", "BaseSuitAspect" }, { "WeaponSuit", "UnknownAspect" }, { "UnknownWeapon", "LobCloseAttackAspect" } }) do
    profile, reason = Resolver.resolve(registry, pair[1], pair[2], nil, {}, loadedProfiles)
    check(profile == nil and reason == "unsupported", "unsupported weapon/aspect selected a profile")
end

-- Unmigrated multi-candidate behavior remains conservative.
local ambiguousRegistry = {
    one = { weapon = "WeaponDagger", aspect = "AspectX", module = "one" },
    two = { weapon = "WeaponDagger", aspect = "AspectX", module = "two" },
}
local syntheticProfiles = {
    one = { slots = { Attack = { core = { "CoreOne" }, alternatives = { "AltOne" } } },
        autoSignals = { KeepsakeOne = true } },
    two = { slots = { Attack = { core = { "CoreTwo" }, alternatives = { "AltTwo" } } },
        autoSignals = { KeepsakeTwo = true } },
}
profile, reason = Resolver.resolve(ambiguousRegistry, "WeaponDagger", "AspectX", nil, {}, syntheticProfiles)
check(profile == nil and reason == "ambiguous", "empty evidence selected a profile")
profile, reason = Resolver.resolve(ambiguousRegistry, "WeaponDagger", "AspectX", nil,
    owned("CoreOne", "KeepsakeTwo"), syntheticProfiles)
check(profile == ambiguousRegistry.one and reason == "affinity", "owned core lost to contrary keepsake")
profile, reason = Resolver.resolve(ambiguousRegistry, "WeaponDagger", "AspectX", nil,
    owned("CoreOne", "CoreTwo", "KeepsakeOne", "KeepsakeTwo"), syntheticProfiles)
check(profile == nil and reason == "ambiguous", "tied owned cores used a keepsake to guess")
profile, reason = Resolver.resolve(ambiguousRegistry, "WeaponDagger", "AspectX", nil,
    owned("KeepsakeTwo"), syntheticProfiles)
check(profile == ambiguousRegistry.two and reason == "auto_signal", "legacy autoSignal fallback changed")
profile, reason = Resolver.resolve(ambiguousRegistry, "WeaponDagger", "AspectX", nil,
    owned("KeepsakeOne", "KeepsakeTwo"), syntheticProfiles)
check(profile == nil and reason == "ambiguous", "tied signals selected a profile")
profile, reason = Resolver.resolve(ambiguousRegistry, "WeaponDagger", "AspectX", "two",
    owned("CoreOne"), syntheticProfiles)
check(profile == ambiguousRegistry.two and reason == "preferred", "explicit compatible preference changed")
profile, reason = Resolver.resolve(ambiguousRegistry, "WeaponDagger", "AspectX", "starter", {}, syntheticProfiles)
check(profile == nil and reason == "ambiguous", "incompatible preference selected a profile")
print("PASS: active Mobalytics singleton profiles, retired preference fallback, and generic multi-candidate fail-safe")
