# Hades II Boon Advisor

Hades II Boon Advisor is a quality-of-life mod for **Hades II**. It analyzes
Olympian Boon choices during a run and adds build-aware information to the
choice screen. It never changes gameplay, RNG, offered Boons, damage, saves,
or the player's selection.

## Installation

### Recommended: Thunderstore and r2modman

Install **Hades II Boon Advisor** through Thunderstore with r2modman. The mod
manager installs the plugin and its declared dependencies in the appropriate
ReturnOfModding plugin location.


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

- Sister Blades — Aspect of Melinoë: Starter and Intermediate
- Sister Blades — Aspect of Morrigan: Meta / Blood Triad

### Build profile selection

`BUILD_PROFILE = "auto"` is the default setting in `config/settings.lua`.

In `auto` mode, the advisor first matches the current weapon and Aspect, then
uses the current run state to resolve the compatible build profile. Owned Boons
are the primary evidence; validated pre-Boon signals may be used when needed at
the start of a run.

If multiple compatible profiles remain ambiguous, the advisor shows
**PROFIL À CHOISIR** and does not guess or display rankings.

Compatible profiles can also be selected explicitly with:

- `starter`
- `intermediate`
- `morrigan_meta`

Boons that cannot be evaluated reliably remain **NON ÉVALUÉ** rather than
receiving a speculative score.

## AI-assisted development

This project was substantially developed with assistance from OpenAI ChatGPT
and Codex, including architecture, code generation, code review,
documentation, and testing support.

Project requirements, design and release decisions, review of generated
changes, and in-game validation are performed or approved by the maintainer.

## Project roadmap

Current development status and planned work are tracked in [ROADMAP.md](ROADMAP.md). The roadmap is updated only after maintainer confirmation.

## Release material

The Thunderstore definition is in `thunderstore.toml`. The deterministic
manual ZIP contains exactly the runtime plugin files. `CHANGELOG.md` records
the V1 release notes, and this project uses the [MIT License](LICENSE).

## Disclaimer

Unofficial community project; not affiliated with Supergiant Games.
