# Hades II Boon Advisor

Hades II Boon Advisor is a quality-of-life mod for **Hades II**. It analyzes
Olympian Boon choices during a run and adds build-aware information to the
choice screen. It never changes gameplay, RNG, offered Boons, damage, saves,
or the player's selection.

## Installation

### Recommended: Thunderstore and r2modman

Install **Hades II Boon Advisor** through Thunderstore with r2modman. The mod
manager installs the plugin and its declared dependencies into its profile.

On one tested Epic Games installation, Thunderstore Mod Manager/r2modman
installed the `ReturnOfModding` files inside its profile but did not copy them
into the game's actual `ReturnOfModding` directory. If the mod does not appear
in game, compare the active profile's `ReturnOfModding` directory with:

```text
<Hades-II-root>\Ship\ReturnOfModding\
```

and, if necessary, copy the profile's `ReturnOfModding` contents there
manually while Hades II is closed. This is an observed workaround, not a
universal manager behavior.


### Manual: minimal GitHub ZIP

Download `Hades-II-Boon-Advisor-v<VERSION>.zip` from [GitHub Releases](https://github.com/coyh0/Hades-II-Boon-Advisor/releases), ensure Hell2Modding and the
declared dependencies are already installed, then extract the archive and copy
the single `Local-HadesIIBoonAdvisor` folder into:

```text
<Hades-II-root>\Ship\ReturnOfModding\plugins\
```

No PowerShell is required for this manual workflow.

### Advanced: PowerShell tooling

Repository PowerShell tools provide controlled installation, transactional
updates and compatibility diagnostics for advanced users. See
[installation](docs/INSTALL.md), [updates](docs/UPDATE.md), and
[uninstallation](docs/UNINSTALL.md).

## Supported builds

The current development registry supports these Mobalytics imports:

- **Argent Skull — Aspect of Medea:** [Médée Mobalytics profile](data/canonical/profiles/argent_skull_medea_mobalytics.json)
- **Moonstone Axe — Aspect of Melinoë:** [Moonstone Axe Mobalytics profile](data/canonical/profiles/moonstone_axe_melinoe_mobalytics.json)

Both imports passed offline validation and maintainer-controlled runtime QA.
The published **v0.2.0** release predates these imports and contains three
different historical profiles; those profiles are no longer in the active
registry.

Compact build-status UI, Duos, Hermes and Poms guidance remain future work.

### Build profile selection

`BUILD_PROFILE = "auto"` is the default setting in `config/settings.lua`.

In `auto` mode, the advisor first matches the current weapon and Aspect, then
uses the current run state to resolve the compatible build profile. Owned Boons
are the primary evidence; validated pre-Boon signals may be used when needed at
the start of a run.

The advisor's displayed text follows the in-game language; English labels are
used here by default.

If multiple compatible profiles remain ambiguous, the advisor shows
**SELECT PROFILE** and does not guess or display rankings.

For a weapon/Aspect with no compatible profile, it shows
**UNSUPPORTED PROFILE**.

The active Registry is the source of truth for explicit profile selection.
Selection keys for retired profiles from the v0.2.0 release are not supported
by the current development registry.

### Community sources and validation

The v0.2 Build Registry was assembled from community build guidance, with
[Mobalytics](https://mobalytics.gg/hades-2/community-builds) used for the
intermediate routes and [Lee Reamsnyder](https://www.leereamsnyder.com/) plus
[NeonHades2](https://hades2.guide.neonspace.dev/) used for the meta/Blood Triad
review. Reddit was consulted only for substantive conflicts or unclear
interactions. These are documentary references; the project claims no
affiliation or endorsement and republishes no source text, tables, images or
layout. Recommendations were kept separate from executable rules, then
matched against native Hades II text, scripts and runtime identifiers. The
active profile mappings and the approved v0.2 showcase were reviewed and
validated by the maintainer through controlled DEV gameplay, screenshots and
DEBUG logs. Documentary conditions and rows that could not be mechanically
verified remain non-executable or deferred.

Boons that cannot be evaluated reliably remain **NOT EVALUATED** rather than
receiving a speculative score.

## AI-assisted development

This project was substantially developed with assistance from OpenAI ChatGPT
and Codex, including architecture, code generation, code review,
documentation, and testing support.

Project requirements, design and release decisions, review of generated
changes, and in-game validation are performed or approved by the maintainer.

## Project roadmap

The project roadmap is maintained in `Hades-II-Boon-Advisor-Roadmap.md` and may be published with the project.


## Release material

The Thunderstore definition is in `thunderstore.toml`. The deterministic
manual ZIP contains exactly the runtime plugin files. `CHANGELOG.md` records
the V1 release notes, and this project uses the [MIT License](LICENSE).

## Disclaimer

Unofficial community project; not affiliated with Supergiant Games.
