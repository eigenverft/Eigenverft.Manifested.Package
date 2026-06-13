# 06_DECISIONS

Product constitution — durable rules for what this product is and is not.
Issue-specific implementation choices → wrk/ (e.g. TODO-SUPPLY-CHAIN Option A).

| ID | Decision | Status |
|----|----------|--------|
| C-01 | Local deterministic engine; one profile, one inventory | Accepted |
| C-02 | Agent creates reviewable artifacts; engine executes trusted artifacts only | Accepted |
| C-03 | Declarative package JSON; install logic in engine, not per-def scripts | Accepted |
| C-04 | Schema-bound install kinds; no generic pre/post-install hooks | Accepted |
| C-05 | Extension via endpoints + depots; module ships useful core, not full catalog | Accepted |
| C-06 | Fleet orchestration → future Manager product, not this engine | Accepted |
| C-07 | No background auto-update or hidden machine mutation | Accepted |
| C-08 | Catalog trust via signing + inventory; not silent latest-upstream | Accepted |
| C-09 | Selection from signed authored catalog; no live upstream at selection | Accepted |
| C-10 | Release-age clock = vendor time on release row (not publication time) | Accepted — see wrk |
| C-11 | Explicit pin bypasses age policy | Accepted — see wrk |
| C-12 | Fail closed when no version passes cooling | Accepted — see wrk |
| C-13 | Small-catalog discovery = live scan (Search-Package shipped) | Shipped |
| C-14 | Large-catalog discovery = manifest before HTTPS-at-scale | Proposed — DECISION-ENDPOINT-DISCOVERY-V1 |
| C-15 | Keep artifacts/targetArtifacts vocabulary on wire until planned schema break | Proposed — DECISION-SCHEMA-ARTIFACTS-VOCABULARY |
| C-16 | Profile content (DefinitionId bundles) in catalog/docs layer; profile policy in Manager | Accepted — ISSUE-ONBOARDING-PROFILES |
| C-17 | Profile v1: no separate profile trust; inherits per-definition catalog trust at invoke | Accepted — ISSUE-ONBOARDING-PROFILES Option A |
| C-18 | Profile v1 execution stays explicit Invoke-Package; no Invoke-PackageProfile | Accepted — ISSUE-ONBOARDING-PROFILES Option A |
| C-19 | Agent operability reads persisted execution logs + state; not console scrollback | Accepted — ISSUE-AGENT-OPERABILITY Option A |
| C-20 | Failure recovery stays propose-first; repair executes only via trusted existing cmds | Accepted — ISSUE-AGENT-OPERABILITY Option A |
| C-21 | Default agent scale = semi-manual/manual workflows with human review gate; unattended only via explicit preseed (trust inventory, documented bootstrap exception) | Accepted — authoring dogfooded |
| C-22 | Assignment preflight is a first-class read-only product surface before mutation; it must reuse the effective resolver/planner and stay local, explicit, and non-mutating | Proposed — ISSUE-ASSIGNMENT-PREFLIGHT Option A |

## Process (minimal)

| ID | Decision | Status |
|----|----------|--------|
| P-01 | wrk/ = issue source of truth; /agsp = product compass | Accepted |
| P-02 | Compact /agsp structure (01–09) | Accepted |
