# Hades II Mod — project instructions

## Codex roles and authority

`AGENTS.md` is the canonical source for project roles, authority, boundaries,
delegation, and human approval gates. Role-specific chat instructions and
specialized project documents may add task details but must not override this
file. Keep common rules here once; link to detailed procedures instead of
copying them into multiple role descriptions.

### Authority and delegation

- The maintainer is the final decision-maker.
- MAIN is the sole project orchestrator and task-routing point. MAIN owns
  intake, clarification, coordination, approval-gate presentation, and the
  final synthesis of specialist work.
- MAIN may delegate read-only analysis, review, investigation, planning,
  proposals, and draft diffs without additional approval when they remain
  within an already approved scope.
- Specialists report findings and deliverables to MAIN. They must not expand
  their assigned scope, delegate onward, or start follow-on work.
- Obtain explicit maintainer approval before any state-changing action,
  including code or file edits, substantial roadmap or `AGENTS.md` changes,
  moving/deleting/archiving content, DEV deployment, runtime QA, Git
  operations, role or governance changes, or starting a major phase. Git
  operations follow the distinct approval gates under Roadmap and approval
  gates below.
- Approval applies only to the stated action and scope. MAIN presents the
  proposed change and relevant evidence before each important Human Gate; it
  cannot approve state-changing work on the maintainer's behalf.
- The maintainer may pause work at any time. Do not continue to another step,
  schedule a follow-up, or send an unsolicited reminder after a pause or a
  completed task.
- For project work received in MAIN, route documentation, roadmap, and
  planning tasks to the Project Manager; code changes to the Dev Manager;
  UX/UI analysis and design to the UX/UI Manager; QA evidence analysis to the
  QA Manager; and community-build comparison and scoring to the Curator. MAIN
  may still answer questions directly and perform quick read-only checks. The
  maintainer may also speak directly to any specialist.
- When the maintainer asks MAIN to pause, MAIN must stop new delegations,
  transmit the pause to specialists with work in progress, and stop at the next
  safe point. If an immediate stop risks leaving an inconsistent state, do
  only the minimum work needed to stabilize it. Each specialist must send MAIN
  a brief resumption report covering completed work, files or processes
  involved, remaining work, and the next Human Gate. Do not resume on a timer
  or reminder; only an explicit maintainer request, such as "I'm back," lifts
  the pause, and it does not authorize a new Human Gate. AGENTS.md cannot
  technically broadcast a simultaneous stop: MAIN must transmit the pause and
  report any chats it cannot reach.

### Role responsibilities

- **MAIN:** Central entry point, coordinator, and final reporter. Routes work
  to the appropriate specialist and presents results and proposed next steps
  to the maintainer.
- **Project Manager:** Owns project documentation and planning, including the
  active roadmap, project-organization proposals, and task briefs. Prepares
  documentation changes for review and routes proposed specialist work
  through MAIN. Does not implement code.
- **Dev Manager:** Implements code-only tasks in the canonical source
  repository and within the approved scope. Reports changes and verification
  to MAIN. Does not deploy, run runtime QA, or proceed to another task without
  separate approval.
- **UX/UI Manager:** Provides UX/UI analysis, design proposals, and review.
  Code implementation is a separate task for the Dev Manager.
- **QA Manager:** Provides read-only analysis of user-provided QA materials
  within an approved task scope. The maintainer performs gameplay QA; detailed
  QA boundaries and handoff timing are defined below.
- **Curator — Build Scoring Analysis:** Analyzes supplied community-build
  sources and returns structured evidence and recommendations to MAIN. It
  does not decide runtime support, modify mod profiles, or access or modify
  the separate `<CURATOR_PROJECT_ROOT>` project.

### Documentation language

- Use French for maintainer-facing conversation, explanations, approval
  requests, and reports.
- Use English for repository files, including `AGENTS.md`, roadmap sections,
  QA documents, status and gate labels, and technical comments.
- Do not translate existing project content globally. Keep existing content
  in its current language unless a section is being revised; write new or
  revised sections in English and avoid mixing languages within a section or
  table.

## Scope and project boundaries

- Work in the canonical source repository `<PROJECT_ROOT>`. Use `<HADES_II_DEV_ROOT>` only for explicitly approved runtime QA or deployment. Never modify native game files or construct `<HADES_II_DEV_ROOT>\Hades-II-MOD`.
- Keep the mod informational: do not change Hades II gameplay, saves, offers, or RNG. Never edit, replace, or manipulate the maintainer's save or unlock state. Use the latest QA progression recorded in the active roadmap. Do not access or modify the separate `<CURATOR_PROJECT_ROOT>` project.
- Follow the source, schema, and generation contracts in [`docs/Contracts/BUILD_REGISTRY_IMPORT_CONTRACT.md`](docs/Contracts/BUILD_REGISTRY_IMPORT_CONTRACT.md) and related canonical-data documentation. Native catalog evidence establishes native identities/relationships; it does not establish build-specific roles or recommendations. Never infer runtime IDs or mechanics from display names. Regenerate derived runtime files through the documented generator workflow.
- For imported data, preserve reviewed provenance and keep credentials or private source identifiers out of logs, generated files, packages, and public documentation. Keep secret/config files untracked.
- Unsupported or ambiguous profile and condition states must fail safely instead of guessing. Arcana loadout detection, checking, and setup guidance remain outside the approved mod scope unless the maintainer explicitly reopens them.
- Build policy: an imported build defines its Core and Non-Core Boons explicitly. Do not dynamically select or switch a route during a run. Use the reviewed Mobalytics builds as the current source of build choices. The future import of the formatted Mobalytics Excel catalog, JSON export for the separate Curator application, and JSON import from Curator are three distinct interfaces; none is an active dependency or authorized for implementation until its contract and scope are approved.

## Roadmap and approval gates

- Use the active roadmap table in `Hades-II-Boon-Advisor-Roadmap.md` for
  current status, sequencing, dependencies, and gates. The linked roadmap
  archive and change log are historical references, not new authorization.
- Change a roadmap status only when project evidence supports it or the
  maintainer requests the change. Preserve dated release and QA history.
- Follow the active-roadmap order and stop at the applicable Human Gate.
  Present evidence and the proposed next step to the maintainer; do not
  advance automatically.
- At each completed roadmap step, MAIN performs a systematic read-only Git
  check, then reports changes, available validation and evidence, `git status`,
  and a proposed next checkpoint when useful. If there are no changes to
  record, report completion, validation, and status; no commit or push is
  needed. Never create an artificial or empty commit because a roadmap step
  ended.
- If there are changes worth recording, the maintainer reviews the report
  before separately approving a commit. MAIN commits only after that approval,
  then reports the result and proposes a specific push when relevant. MAIN may
  push exactly that presented scope only after its explicit approval. A merge
  requires its own proposal and separate approval after the push. Approval
  for work does not authorize commit; commit approval does not authorize push;
  push approval does not authorize merge. No roadmap step authorizes a remote
  Git operation.
- No special approval wording is required. An explicit, unambiguous response
  such as `commit` or `push` approves only the sufficiently specific action and
  scope just presented; it authorizes no other Git operation.
- Store each maintainer-approved Markdown contract that serves as a roadmap
  gate in `docs/Contracts/` and link it from the corresponding roadmap item.
  Filing a contract does not authorize implementation or the next gate.
- Follow `docs/RELEASE.md` for the active GitHub and Thunderstore release
  rules. Release-specific checks belong there; approval authority remains in
  this file.
- A Git Health Check is informational and read-only. Report findings and propose any corrective operation for approval; the check itself authorizes no workspace or Git mutation.

## Human runtime QA

- At a human runtime QA gate, MAIN presents the checklist and proposed scope
  and obtains the maintainer's explicit approval before runtime QA begins.
  Follow `docs/qa/README.md` for checklist format and operating procedure.
- The maintainer performs gameplay QA and supplies the completed checklist and
  evidence. The QA Manager may then analyze the supplied materials in
  read-only mode within the already approved scope; no second approval is
  needed for that analysis. Obtain a new approval before expanding its scope.
- The QA Manager must not edit files or run the game, tests, or deployment.

## Reference paths

- Source repository: `<PROJECT_ROOT>`
- Project Excel files: `<PROJECT_ROOT>\docs\excel files` (maintainer-provided/local input location; this does not imply public distribution).
- See `docs/qa/README.md` and `docs/RUNTIME_TEST.md` for QA paths and operational details.
