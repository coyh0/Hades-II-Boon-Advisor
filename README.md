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

The first Thunderstore publication is pending confirmation of the publishing
team namespace and a required 256x256 PNG icon.

### Manual: minimal GitHub ZIP

Download `Hades-II-Boon-Advisor-v<VERSION>.zip` from [GitHub Releases](https://github.com/coyh0/Hades-II-Boon-Advisor-Public/releases), ensure Hell2Modding and the
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

Boons that cannot be evaluated reliably remain **NON ÉVALUÉ** rather than
receiving a speculative score.

## Release material

The Thunderstore definition is in `thunderstore.toml`. The deterministic
manual ZIP contains exactly the runtime plugin files. `CHANGELOG.md` records
the V1 release notes, and this project uses the [MIT License](LICENSE).

## Disclaimer

Unofficial community project; not affiliated with Supergiant Games.
