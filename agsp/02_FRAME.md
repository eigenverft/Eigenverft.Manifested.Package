# 02_FRAME

## North Star

```text
A Windows user profile becomes useful in minutes through one governed command —
repeatable, explainable, signable, local, and depot-capable — without becoming
a fleet controller or a silent auto-updater.

Positioning (from PRODUCT-BOUNDARY): more structured than ad-hoc WinGet/Scoop scripts;
more local and team-owned than a public catalog; lighter than enterprise endpoint management.
Lead with "one command, known toolchain, works from our depot"; security is the reason
teams accept it, not the headline.

Agent scaling (not fleet automation): semi-manual or fully manual agent-assisted work
produces reviewable artifacts; humans gate trust, sign, and Invoke-Package. Shipped and
dogfooded: Get-PackageDefinitionAuthoringGuide + PackageDefinitionAuthoring.md.
Same pattern planned for profiles and assign operability (wrk issues).
```

## Canonical User Scenarios

| ID | Scenario | Primary user | Happy path today | Product gap |
|----|----------|--------------|------------------|-------------|
| SC-01 | Fresh Windows dev profile | Developer | Install-Module → Invoke-Package -DefinitionId … | Auto-selection has no cooling window (trust risk) |
| SC-02 | Team file-share channel | Team endpoint owner | Add-TeamPackageDepot/Endpoint → Invoke-Package | Ownership rules hard to learn; no bundled offline guide |
| SC-03 | Corporate TLS / Gallery block | Developer | iwr/bootstrapper.ps1 once → normal commands | Bootstrap bypasses TLS — acceptable only as exception |
| SC-04 | Isolated / factory network | Operator | Internal endpoint + depot; fail closed to public | Selection must stay catalog-local; acquire per source kind |
| SC-05 | Agent-maintained catalog | Maintainer + agent | Guide → skill → draft → validate → sign → publish | Authoring loop dogfooded; workbench deferred (PQ-05) |
| SC-06 | Discover then assign | Developer | Search-Package -Query … → InvokeCommand | Fine at 18 defs; large-catalog path not built |
| SC-07 | Role-based team onboarding | Team lead / agent | Long comma lists in README or wiki | No named profile artifacts; issue filed (Option A) |
| SC-08 | Assign failed — diagnose and recover | Developer / agent | Rerun Invoke-Package; scrollback if saved | No persisted step log; no operability guide cmd |
| SC-09 | Review before assign | Developer / operator / agent | Read docs, Search-Package, inspect state manually | No structured read-only assignment preflight |

## Current Design Frame (runtime snapshot)

```text
Local PowerShell package-assignment engine: signed JSON defs (schema 1.9), trust inventory,
file depots, endpoints, assignment inventory + operation history.
Invoke-Package assigns/removes; Search-Package discovers; Get-PackageState explains.
Extension model: endpoints + depots grow the catalog outside the module (18 shipped core defs).
Separate future product: Eigenverft Manifested Manager (fleet/orchestration) — out of scope here.
```

## Intention

```text
Every feature and backlog item must be judgeable against scenarios, anti-goals, and
the decision test — not only against technical completeness.
```

## Product Requirements (durable)

| ID | Requirement (outcome) | Status | Success signal |
|----|------------------------|--------|----------------|
| PR-01 | One profile, one inventory — local mental model | Shipped | State files per user, no cross-machine policy |
| PR-02 | Human understands what installs before it runs | Partial | Trust + logs exist; bundled guide missing |
| PR-03 | Rerun is safe and predictable (reuse/repair/skip) | Shipped | Idempotent Invoke-Package; [OUTCOME] vocabulary |
| PR-04 | Removal is inventory-safe only | Shipped | No hunt for untracked external software |
| PR-05 | Catalog trust is explicit, not naming-only | Shipped | catalogTrust + signed defs + trust inventory |
| PR-06 | Version choice is explainable (pin/latest/previous/skipped) | Partial | Pin/latest/previous exist; no "skipped: too new" yet |
| PR-07 | Offline/depot path is first-class | Shipped | packageDepot sources; isolated fail-closed intent |
| PR-08 | Agent drafts; engine executes only reviewed artifacts | Partial | Authoring guide dogfooded; human gates sign/trust/invoke; workbench optional |
| PR-09 | Endpoints scale catalog; module stays a useful core | Partial | 18 defs shipped; httpsCatalog/manifest backlog |
| PR-10 | Depot folders stay sync-clean | Partial | Mirror exists; hygiene validation backlog |
| PR-11 | Role onboarding via named, reviewable DefinitionId bundles | Open | profileId + examples; invoke stays explicit |
| PR-12 | Failure is explainable; recovery path explicit and safe to rerun | Open | persisted execution log + operability guide; propose-first repair |
| PR-13 | Assignment intent is reviewable before mutation | Open | read-only plan shows deps, versions, trust, state, depot/offline feasibility, next Invoke-Package |

## Anti-Goals (from PRODUCT-BOUNDARY)

```text
Not: fleet manager, background auto-update, public app store, WinGet/Intune replacement,
hidden machine mutator, silent latest-upstream trust, arbitrary pre/post-install script hooks,
AI defs bypassing validation, live upstream metadata at selection time.
```

## Decision Test (apply before every feature)

```text
1. Easier to prepare one user profile?
2. Understandable before install?
3. Safe to rerun?
4. Inventory-safe removal?
5. Clean depot reuse?
6. LLM-generatable yet deterministically validatable?
7. Strengthens endpoints as extension model?
8. Works from controlled endpoint + depot when isolated?
9. Install actions still schema-bound kinds?
10. Engine — or future Manager product?
```

## Form Conditions

| ID | Condition | Type | Strength |
|----|-----------|------|----------|
| FC-01 | Declarative package JSON; logic in engine | Semantic | Invariant |
| FC-02 | Schema-bound install kinds only | Semantic | Invariant |
| FC-03 | Selection from signed authored catalog | Semantic | Hard |
| FC-04 | Explicit Invoke-Package style actions only | Process | Invariant |
| FC-05 | Security story supports UX, does not replace it | Normative | Soft |

## Guardrails

| ID | Guardrail | Strength |
|----|-----------|----------|
| GR-01 | No fleet / cross-machine orchestration in engine | Invariant |
| GR-02 | No background state mutation | Invariant |
| GR-03 | No generic script hooks in schema | Invariant |
| GR-04 | Agent output = reviewable artifact | Strong |
| GR-05 | Network at selection time = rejected | Strong |
| GR-06 | PRODUCT-BOUNDARY is normative; /agsp does not fork it | Strong |

## Alignment (priority when stakeholders conflict)

```text
1. Safety / harm prevention (no silent trust, inventory-safe removal)
2. Primary user clarity (developer happy path, explainable logs)
3. Isolated-network predictability (fail closed)
4. Maintainer/agent reviewability (signed catalog facts)
5. Team scale (endpoints/depots) without fleet creep
6. Convenience and performance (search latency, doc access)
```

## Active Delivery Tracks (link only — detail in wrk/)

| P | Track | Product why | wrk |
|---|-------|-------------|-----|
| 5 | Release-age cooling | PR-06, SC-01/04/05 — governed auto-selection | TODO-SUPPLY-CHAIN.md |
| 4 | Hybrid offline docs | PR-02, SC-02 — Gallery-only users need guide | TODO-DOCUMENTATION.md |
| 4 | Assignment preflight | PR-02/07/11/13, SC-01/04/07/09 — plan before mutation | ISSUE-ASSIGNMENT-PREFLIGHT.md |
| 3 | Ownership guide | PR-02/04, SC-02 — adoption rules opaque today | TODO-OWNERSHIP.md |
| 3 | Onboarding profiles | PR-11, SC-07 — role bundles without fleet invoke | ISSUE-ONBOARDING-PROFILES.md |
| 3 | Agent operability | PR-12, SC-08 — execution log + guide cmd; agent diagnoses failures | ISSUE-AGENT-OPERABILITY.md |
| 2 | Manifest → httpsCatalog → HTTP depots → depot hygiene | PR-09/10, SC-06 — scale without bloat | TODO-ENDPOINTS-*, TODO-DEPOTS-* |

## Success Signals (product-level)

| When track lands | Good looks like |
|------------------|-----------------|
| Supply chain | Operator sees skipped-for-age; pin overrides; fail-closed when all too new |
| Hybrid docs | Install-Module user opens bundled guide offline; same content as repo |
| Assignment preflight | User sees dependency graph, trust state, selected versions, depot/offline blockers, and exact next command before install |
| Ownership guide | Author picks ownershipPolicy without reading tests; logs map to guide |
| Onboarding profiles | Team picks "backend-dev" profile; documented Invoke-Package line after review |
| Agent operability | Failed assign → operability guide → execution log → clear next Invoke-Package step |
| Manifest + HTTPS | 200+ def catalog searchable without multi-second scan storm |
| Depot hygiene | Stray sidecars flagged before ambiguous acquire failure |

## Freedom Degrees

```text
Delegated to implementers (within constitution): schema field naming within 1.9 additive
bounds, log wording, doc renderer choice, optional Option C GitHub date helper,
assignment preflight object formatting.

Requires product owner: cooling duration acceptance, manifest trigger confirmation,
httpsCatalog auth model, preflight command naming if public API taste matters,
any Manager-boundary crossing.
```

## Frame Status

```text
Stable as product compass. Delivery detail and open implementation choices remain in wrk/.
```
