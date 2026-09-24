local Resolver = assert(loadfile("src/ProfileResolver.lua"))()
local registry = assert(loadfile("data/builds/registry.lua"))()
local loadedProfiles = {}
for _, descriptor in pairs(registry) do loadedProfiles[descriptor.module] = assert(loadfile(descriptor.module))() end
local function check(value, message) assert(value, message) end
local function owned(...) local t = {}; for i = 1, select("#", ...) do t[i] = { Name = select(i, ...) } end; return t end

check(registry.starter == nil, "retired Starter remains selectable")
for _, names in ipairs({ {}, { "ZeusSpecialBoon" }, { "ForceZeusBoonKeepsake" },
    { "AphroditeWeaponBoon" }, { "AresWeaponBoon" }, { "ForceAresBoonKeepsake" },
    { "AphroditeWeaponBoon", "ForceAresBoonKeepsake" } }) do
    local profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerBackstabAspect", nil,
        owned(table.unpack(names)), loadedProfiles)
    check(profile == registry.intermediate and reason == "only_candidate",
        "Melinoe singleton depended on shared boon or keepsake evidence")
end
local profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerBackstabAspect", "intermediate",
    owned("AresWeaponBoon"), loadedProfiles)
check(profile == registry.intermediate and reason == "preferred", "explicit Intermediate preference changed")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerBackstabAspect", "starter", {}, loadedProfiles)
check(profile == registry.intermediate and reason == "only_candidate", "retired preference blocked singleton auto")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerTripleAspect", nil, {}, loadedProfiles)
check(profile == registry.morrigan_meta and reason == "only_candidate", "Morrigan singleton changed")
profile, reason = Resolver.resolve(registry, "WeaponSuit", "BaseSuitAspect", nil, {}, loadedProfiles)
check(profile == registry.coat_melinoe_intermediate and reason == "only_candidate", "Black Coat singleton changed")
for _, pair in ipairs({ { "WeaponDagger", "DaggerBlockAspect" }, { "WeaponSuit", "UnknownAspect" },
    { "UnknownWeapon", "DaggerBackstabAspect" } }) do
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
print("PASS: active singleton profiles, retired preference fallback, and legacy multi-candidate fail-safe")
