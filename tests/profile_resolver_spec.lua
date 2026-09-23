local Resolver = assert(loadfile("src/ProfileResolver.lua"))()
local registry = assert(loadfile("data/builds/registry.lua"))()
local loadedProfiles = {}
for _, descriptor in pairs(registry) do loadedProfiles[descriptor.module] = assert(loadfile(descriptor.module))() end
local function check(value, message) assert(value, message) end
local function owned(...) local t = {}; for i = 1, select("#", ...) do t[i] = { Name = select(i, ...) } end; return t end

local profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerBackstabAspect", "intermediate")
check(profile.id == "sister_blades_melinoe_intermediate" and reason == "preferred", "Intermediate was not preferred")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerBackstabAspect", "starter")
check(profile.id == "sister_blades_melinoe_starter" and reason == "preferred", "Starter was not preferred")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerTripleAspect", "intermediate")
check(profile.id == "sister_blades_morrigan_meta" and reason == "only_candidate", "Morrigan did not auto-resolve")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerTripleAspect", "starter")
check(profile.id == "sister_blades_morrigan_meta" and reason == "only_candidate", "Morrigan did not ignore incompatible preference")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerTripleAspect", nil)
check(profile.id == "sister_blades_morrigan_meta" and reason == "only_candidate", "Morrigan auto mode did not resolve")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerBackstabAspect", nil, owned("AresWeaponBoon"), loadedProfiles)
check(profile.id == "sister_blades_melinoe_intermediate" and reason == "affinity", "Ares core did not select Intermediate")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerBackstabAspect", nil, owned("ForceAresBoonKeepsake"), loadedProfiles)
check(profile.id == "sister_blades_melinoe_intermediate" and reason == "auto_signal", "Ares keepsake did not select Intermediate")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerBackstabAspect", nil, owned("DemeterCastBoon"), loadedProfiles)
check(profile.id == "sister_blades_melinoe_intermediate" and reason == "affinity", "Demeter core did not select Intermediate")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerBackstabAspect", nil, owned("AphroditeWeaponBoon", "ForceAresBoonKeepsake"), loadedProfiles)
check(profile.id == "sister_blades_melinoe_starter" and reason == "affinity", "Starter core did not outrank Intermediate alternative")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerBackstabAspect", nil, owned("ZeusSpecialBoon", "ForceAresBoonKeepsake"), loadedProfiles)
check(profile.id == "sister_blades_melinoe_intermediate" and reason == "auto_signal", "Shared Zeus evidence did not fall back to the signal")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerBackstabAspect", nil, {}, loadedProfiles)
check(profile == nil and reason == "ambiguous", "No distinguishing evidence incorrectly selected a profile")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerBlockAspect", "intermediate")
check(profile == nil and reason == "unsupported", "Artemis was not unsupported")
profile, reason = Resolver.resolve(registry, "UnknownWeapon", "DaggerTripleAspect", "intermediate")
check(profile == nil and reason == "unsupported", "Unknown weapon was not unsupported")
local ambiguousRegistry = {
    one = { weapon = "WeaponDagger", aspect = "AspectX", module = "one" },
    two = { weapon = "WeaponDagger", aspect = "AspectX", module = "two" },
}
profile, reason = Resolver.resolve(ambiguousRegistry, "WeaponDagger", "AspectX", "starter")
check(profile == nil and reason == "ambiguous", "Incompatible preference guessed through ambiguity")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerBackstabAspect", "not-a-profile")
check(profile == nil and reason == "ambiguous", "Unknown preference guessed among compatible profiles")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerTripleAspect", "not-a-profile")
check(profile.id == "sister_blades_morrigan_meta" and reason == "only_candidate",
    "Unknown preference incorrectly rejected the sole Morrigan candidate")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerBackstabAspect", "intermediate", owned("AphroditeWeaponBoon"), loadedProfiles)
check(profile.id == "sister_blades_melinoe_intermediate" and reason == "preferred", "Explicit Intermediate was not a hard preference")
profile, reason = Resolver.resolve(registry, "WeaponDagger", "DaggerBackstabAspect", "starter", owned("AresWeaponBoon"), loadedProfiles)
check(profile.id == "sister_blades_melinoe_starter" and reason == "preferred", "Explicit Starter was not a hard preference")
print("PASS: profile resolver exact matching, preference, automatic singleton selection, and ambiguity fail-safe")
