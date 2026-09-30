# Public release rules

This is the active release procedure for future GitHub and Thunderstore
releases of Hades II Boon Advisor. `AGENTS.md` defines approval authority and
project boundaries. A completed development task, DEV deployment, or QA report
does not authorize a public release.

## Candidate and validation gate

1. Agree with the maintainer on the release candidate, version, supported
   builds, and scope. Distinguish the published version from the current
   development registry in public text.
2. Review the exact candidate source and the relevant offline validation:
   canonical generation and import contracts, Lua behavior, localization,
   staging and package inventories, dependencies, compatibility, and
   installation/update/uninstallation where affected. Record the results and
   any exceptions.
3. Require maintainer-controlled in-game validation for the approved release
   scope. Preserve the QA evidence and report untested scenarios explicitly.
4. Align `manifest.json`, `thunderstore.toml`, `CHANGELOG.md`, README content,
   release notes, and package contents with the approved version and supported
   build set. Keep public release text in English and preserve the project's
   AI-assistance disclosure.
5. Rebuild the final artifacts after any source or metadata change. Inspect
   their exact inventories, verify SHA-256 digests, and exclude development-only
   files from public packages. A prior package check does not validate a later
   rebuild.

## GitHub release gate

- Build the deterministic manual ZIP from the reviewed candidate. Verify that
  it contains the intended `Local-HadesIIBoonAdvisor` runtime plugin, with no
  unrelated development files. Verify its `.sha256` asset against the ZIP.
- Review the English release notes, supported-build scope, installation
  instructions, version, and links before publishing.
- Keep published release tags immutable. Do not move or rewrite an existing
  tag or release to represent a different source state.
- Follow the distinct approval gates in `AGENTS.md` for Git checkpoints, tags,
  pushes, and GitHub release actions. After publication, verify the public
  assets and their digests against the approved artifacts.

## Thunderstore release gate

- Check `thunderstore.toml` against `manifest.json`: version, package identity,
  dependencies, description, website, category, and copied files. Inspect the
  final package for the intended runtime inventory, README, changelog,
  license, and icon.
- Verify the AI-assistance disclosure in the Thunderstore-facing description
  and packaged README. For the next public update, resolve the AI-related tag
  requested in the project's recorded Thunderstore issue #8. Check the exact
  tags available at release preparation time rather than relying on an older
  category inventory. If no suitable tag is available, record that finding
  and ask the maintainer how to proceed before publication or moderator
  contact.
- Rebuild and inspect the package after disclosure, tag, or other metadata
  changes. Run the relevant package checks against that final artifact.
- Obtain explicit approval before upload. After publication, verify the live
  listing, version, disclosure, tag, and package against the approved release.

## Release report

Present the candidate source revision, approved scope, validation and QA
evidence, artifact names and SHA-256 digests, metadata review, remaining
limitations, and the exact publication actions proposed. Stop at each
applicable Human Gate in `AGENTS.md`.
