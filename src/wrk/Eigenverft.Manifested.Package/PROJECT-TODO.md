# PROJECT TODO

## Priority Legend

- [P0] Blocker
- [P1] Critical
- [P2] High
- [P3] Normal
- [P4] Low
- [P5] Backlog / Nice-to-have
- [P6] Pixelperfect / optional polish

## Open

### [P0] Blocker

### [P1] Critical

#### Team catalog trust

- **Feature issue: sign package definitions from team endpoints.** As a team endpoint owner, I want package JSON to be signed by a trusted publisher key, so a writable share or compromised endpoint cannot silently change install URLs, versions, or package behavior.
  Requester perspective: team catalog maintainer, security reviewer, industrial network operator.
  Outcome: clients can reject unsigned or wrongly signed definitions before any package planning, download, or install happens.

- **Feature issue: strict mode for team catalogs.** As an operator using a shared endpoint, I want a strict trust mode that requires signed definitions and rejects casual unsigned publisher trust, so team use does not depend on every admin remembering the safe flags.
  Requester perspective: IT-friendly team owner, security-conscious developer group, plant-floor operations maintainer.
  Outcome: a team can turn on a clear policy such as "only signed definitions from trusted publishers" and get an understandable failure when a definition does not meet it.

- **Feature issue: require hashes for external downloads in trusted catalogs.** As a catalog reviewer, I want external downloads to carry pinned file hashes when used in a trusted endpoint, so a signed JSON definition cannot still point at mutable unverified binaries.
  Requester perspective: package catalog maintainer, compliance reviewer, offline depot seeder.
  Outcome: validation can warn or fail when a trusted/team package downloads a file without a strong hash policy.

#### Supply chain / release age

- **Feature issue: wait before auto-picking brand-new releases.** As a security-conscious package maintainer, I want automatic updates to wait a little before choosing a release that just appeared upstream, so a bad same-day release is less likely to enter the depot by accident.
  Requester perspective: team endpoint maintainer, release manager, security reviewer.
  Outcome: the engine can explain why it picked or skipped a version; an explicit version pin still works when the operator accepts the risk.

- **Feature issue: record when each package version was released.** As a catalog author, I want each package version to say when the upstream release happened, so release-age policy is based on the real package version rather than when the JSON file was edited.
  Requester perspective: package catalog maintainer, compliance reviewer, agent-generated catalog reviewer.
  Outcome: package state and dry-run output can tell the difference between "this definition changed today" and "this package version was released last week."

### [P2] High

#### Dependency resolution

- **Feature issue: let packages ask for compatible dependency versions.** As a package author, I want a package to say which dependency versions it works with, so installing it does not silently pull a dependency that is too new or too old.
  Requester perspective: package maintainer for CLIs, runtimes, and toolchains with pinned compatibility.
  Outcome: planning shows which dependency versions will be used and fails clearly when no compatible version exists.

- **Feature issue: show the full prerequisite tree before install.** As an operator installing a package with nested prerequisites, I want to see the whole dependency tree before changes start, so install order, cycles, and conflicts are visible early.
  Requester perspective: team endpoint maintainer, CI validation owner, catalog author using generated definitions.
  Outcome: dry-run and package state show a readable tree with each dependency, selected version, and status.

- **Feature issue: stop early when requested packages disagree on dependencies.** As a user installing multiple packages in one command, I want dependency conflicts reported before any install starts, so I can change the package set instead of debugging a half-finished run.
  Requester perspective: package profile author, team onboarding maintainer, release engineer.
  Outcome: batch assignment explains which packages disagree and which dependency version caused the conflict.

- **Feature issue: save the exact package plan for automation.** As an automation user, I want a resolved plan that records package versions, dependency versions, and file hashes, so a CI or agent run can prove what it intended to install.
  Requester perspective: CI operator, security reviewer, agent-driven catalog validator.
  Outcome: a dry-run or assignment result can be archived as a readable install plan without turning the module into a central fleet manager.

#### Catalog validation

- **Feature issue: prove LLM-maintained package JSON stays safe.** As a maintainer scaling the catalog with AI-generated package definitions, I want recurring validation that LLM-created or LLM-updated JSON still follows the schema and product boundaries, so the catalog can grow without turning into unreviewed script sprawl.
  Requester perspective: AI catalog maintainer, package reviewer, endpoint owner scaling beyond the shipped set.
  Outcome: generated definitions can be checked in batches, reviewed by humans, and periodically re-tested against current schema, trust, dependency, and offline rules.

- **Feature issue: check package JSON without installing anything.** As a team endpoint maintainer, I want to validate package JSON before any download, install, PATH change, or inventory write, so agent-generated definitions can be reviewed safely.
  Requester perspective: catalog maintainer, PR reviewer, autonomous package-authoring agent.
  Outcome: validation reports broken fields, old schema names, publisher trust, signature status, platform selection, dependencies, and download/depot plan shape without changing the machine.

- **Feature issue: check a whole package folder at once.** As a maintainer of a growing endpoint folder, I want one report for all package definitions, so broken JSON, unsupported schema versions, duplicate ids, and missing platform targets are found before users hit them.
  Requester perspective: team endpoint owner, release engineer, repo maintainer preparing a shipped module release.
  Outcome: the report works in CI and is readable enough for maintainers who are not package-engine experts.

- **Feature issue: make package validation errors easier to fix.** As an agent or human writing package definitions, I want validation errors to explain the package concept, not just the internal field name, so the next edit is obvious.
  Requester perspective: package-definition author, reviewer of generated JSON, new contributor.
  Outcome: validation output points to the bad value, explains why it is wrong, and names the preferred replacement.

#### Depot and offline reliability

- **Feature issue: keep the depot clean for file shares and NAS sync.** As a user syncing a package depot through a file share or NAS, I want the depot to contain only files that are meant to be shared, so sync tools do not copy temp files, sidecar files, or half-built package state.
  Requester perspective: home NAS user, team share maintainer, offline package user.
  Outcome: depot hydration, mirror, and reuse behavior remains predictable when files are copied by external sync tools.

- **Feature issue: show which package types really work offline.** As an offline or low-network operator, I want each package type to say whether it can install fully from the depot, so I can build a package profile that works after the depot is seeded.
  Requester perspective: air-gapped lab user, package power user, team laptop bootstrap owner.
  Outcome: package state or validation can separate fully offline-ready packages from packages that still need live metadata or network fallback.

- **Feature issue: fail closed in isolated networks.** As an industrial or isolated-network operator, I want an offline-only mode that fails when the depot is missing a required file instead of falling back to the internet, so package assignment respects dedicated communication rules.
  Requester perspective: plant-floor workstation maintainer, air-gapped lab operator, regulated network administrator.
  Outcome: planning and install logs clearly say "depot miss, network disabled by policy" rather than trying an unexpected public download.

- **Feature issue: prove a depot is complete before moving it offline.** As a depot seeder, I want a report that says whether all files needed by a selected package set are present in the depot, so I can prepare a plant share or offline lab before users depend on it.
  Requester perspective: offline depot maintainer, team share owner, industrial staging operator.
  Outcome: a package set can be checked on a connected staging machine and then moved into an isolated network with fewer surprises.

### [P3] Normal

#### Package discovery and reporting

- **Feature issue: search packages by name or command.** As a user exploring available tools, I want to find packages by friendly name, command, tag, or publisher without knowing the exact `DefinitionId`, so shipped and team endpoint packages are easier to discover.
  Requester perspective: first-time package user, team member using a shared endpoint, demo operator.
  Outcome: search results show enough identity to run `Invoke-Package` confidently: definition id, publisher, summary, platform availability, and current selected version.

- **Feature issue: show package state without reading JSON.** As a day-to-day package user, I want package state and recent operations shown as readable tables and summaries, so I do not need to inspect inventory files for normal troubleshooting.
  Requester perspective: package user, support helper, team onboarding maintainer.
  Outcome: assigned packages, reused installs, adopted externals, failed operations, and pending restart signals are visible in a concise view.

- **Feature issue: explain what a rerun changed.** As a package user re-running assignment after definitions change, I want the engine to explain whether it reused, repaired, upgraded, downgraded, or refused a version change, so package-owned updates feel intentional.
  Requester perspective: OpenCode/Codex CLI user, package maintainer testing a version bump, release reviewer.
  Outcome: the result and logs make update behavior understandable without reading the implementation.

#### Schema evolution

- **Feature issue: decide if `artifacts` is still the right word.** As a package-definition maintainer preparing for many more package types, I want the current `artifacts` naming reviewed, so the schema does not lock in confusing words before the catalog grows.
  Requester perspective: schema maintainer, package author adding MSI/.NET/npm definitions, future agent author.
  Outcome: the team decides whether `artifacts` is good enough or whether the next breaking schema should use clearer package-file/download wording.

- **Feature issue: explain packages that can live side by side.** As a runtime package maintainer, I want guidance for packages whose major versions can coexist, so definitions like .NET SDK 9 and .NET SDK 10 do not look like accidental duplicates.
  Requester perspective: .NET developer, package catalog maintainer, package profile author.
  Outcome: package identity, install-slot naming, update policy, and removal behavior are understandable for side-by-side runtimes.

- **Feature issue: make installer adoption and removal rules obvious.** As a Windows desktop tool maintainer, I want installer kinds such as MSI to make adoption and removal safety explicit, so already-installed tools can be reused without surprising first-call removals.
  Requester perspective: user with preinstalled 7-Zip/VS Code, team machine maintainer, package author adding desktop software.
  Outcome: package behavior clearly separates safe adoption, package-owned removal, and untracked external uninstall decisions.

#### Product positioning

- **Feature issue: explain the sweet spot clearly.** As a maintainer presenting the project, I want the product story to say where it sits between WinGet/Scoop and enterprise endpoint management, so users understand that it is a governed team package engine rather than a public app store or fleet manager.
  Requester perspective: project maintainer, team platform lead, potential adopter comparing options.
  Outcome: docs and examples consistently describe the base product as a team-owned package channel for Windows dev environments, with fleet orchestration left to a future manager product.

- **Feature issue: present web endpoints as the main extension point.** As a package catalog maintainer, I want online endpoints such as an Eigenverft package endpoint to be the normal way to expand beyond shipped definitions, so teams and agents can add packages without bloating the module itself.
  Requester perspective: Eigenverft catalog maintainer, team endpoint owner, AI-generated catalog pipeline owner.
  Outcome: docs and product language explain that the module ships a core set, while web/team endpoints carry the scalable catalog.

### [P4] Low

#### Maintenance polish

- **Feature issue: clean up old words in code and messages.** As a contributor reading package engine code, I want helper names, comments, and user-facing errors to use current package words, so old terms do not create false migration questions.
  Requester perspective: new maintainer, schema reviewer, contributor debugging package lifecycle behavior.
  Outcome: retired terms remain only where they are intentionally rejected or documented as migration guidance.

### [P6] Pixelperfect / optional polish

#### Presentation polish

- **Feature issue: make package lists easier to scan.** As a first-time reader, I want package lists and examples to be visually scannable, so the growing catalog does not make documentation or command output feel noisy.
  Requester perspective: README reader, demo audience, new contributor.
  Outcome: polish improves readability without changing package behavior or schema semantics.

## Out Of Scope / Manager Product Candidates

These are useful stories, but they belong to a separate manager or orchestration product rather than the base package engine:

- **Manager story: hold a version across many machines.** As an enterprise operator, I want to hold or skip package versions across many machines, so central rollout policy is enforced consistently.
- **Manager story: share package sets across machines.** As an environment administrator, I want portable package profiles across clients, so workstation groups can be assigned consistently.
- **Manager story: save and reuse named package profiles.** As a team or enterprise operator, I want to export and reapply named package sets, so repeated workstation setup does not depend on hand-maintained command strings.
- **Manager story: show upgrade availability across assignments.** As a fleet or profile owner, I want to compare assigned package versions against endpoint catalog versions, so upgrade decisions belong to the orchestration layer instead of the base assignment engine.
- **Manager story: upgrade many machines from one place.** As a fleet owner, I want to see and drive upgrades across many hosts, so local package assignment is coordinated centrally.

The package engine already covers per-machine **Assigned** state, endpoint-driven definitions, `versionUpdatePolicy` on re-invoke, and flexible **team/web endpoint / depot / publisher** layout. Catalog growth at scale is expected to be driven by LLM-maintained JSON on endpoints, including an Eigenverft online endpoint and team endpoints, not by turning the package module into a fleet manager.

## Review / Questions

- Should the wait-before-release-pick rule be global, package-specific, publisher-specific, or only enabled for sensitive packages?
- Should explicit `-PackageVersion` always bypass the wait period, or should bypass require a separate accept-risk signal?
- Should dependencies use exact versions, version ranges, inherited release tracks, or a small set of simple policy names?
- Should dry-run be a definition/catalog validation command, an `Invoke-Package` planning mode, or both?
- Should package search scan endpoints live, use a maintained index file, or support both for different catalog sizes?
- What minimum recurring validation should LLM-maintained catalog definitions pass before they are published to an endpoint?
- Should the Eigenverft online endpoint have an index or manifest so clients can discover packages without scanning every JSON file?
- Should the next breaking schema revisit `artifacts` naming now, or wait until more package kinds prove where the wording hurts?
- Which package type should be the next confidence test for fully offline depot reuse after npm, MSI, archive, PowerShell module, and portable SDK packages?
- Which signature format should package definitions use: embedded signature, sidecar file, signed catalog manifest, or a combination?
- Should strict team mode require both signed definitions and hashes on all external downloads, or should those be separate policy switches?
- Should offline-only behavior be global, endpoint-specific, package-set-specific, or a command override?

## Closed

- [P3] Rename - 2026-05-24: Completed repository and module surface rename to **Eigenverft.Manifested.Package**, including public command names, module metadata, local root default `Evf.Package`, and removal of obsolete launch-profile artifacts.
- [P3] Tooling - 2026-05-23: Bumped package-definition schema to 1.6 for shipped definitions including SevenZip and DotNetSdk10.
- [P3] Tooling - 2026-05-23: Added managed **SevenZip** and **DotNetSdk10** package definitions.
- [P2] Tooling - 2026-05-22: Added package version selection, refreshed shipped definition versions, and resolved npm installs from materialized local tarballs.
- [P2] Architecture - 2026-05-16: Retired legacy package-definition schemas and completed endpoint naming cleanup.
- [P1] Trust - 2026-05-16: Added package publisher trust commands and inventory management.
- [P2] Architecture - 2026-05-14: Replaced package repository inventory with endpoint inventory; definitions are discovered by endpoint scan order.
- [P2] Tooling - 2026-05-11: Added package depot management, mirror reconcile, package assignment inventory, and operation history.
- [P2] Tooling - 2026-05-02: Established generic package command surface, depot support, readiness checks, and removal groundwork.
- [P3] Tooling - 2026-03-19: Added managed CLI runtimes and explicit managed npm proxy ownership.
- [P3] Tooling - 2026-03-13: Added managed Git, PowerShell, Node, Python, editor, CLI, and prerequisite package paths.
