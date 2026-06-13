# 03_STAKEHOLDERS

| ID | Stakeholder | Tier | Viewpoint | Interest | Wins when conflict? |
|----|-------------|------|-----------|----------|---------------------|
| S01 | Windows developer | **Primary** | End user | Minutes-to-productive profile; clear commands | First-run clarity beats feature count |
| S02 | Isolated-network operator | **Primary** | Deployment | Controlled endpoint+depot; no surprise public reach | Predictability beats convenience |
| S03 | Security / compliance | **Secondary** | Trust | Signed catalog, cooling, hashes, audit trail | When pin bypass exists and logs explain skips |
| S04 | Team endpoint / depot owner | **Secondary** | Distribution | Share defs+artifacts on share or HTTPS | When team path needs no fleet product |
| S05 | Package-definition maintainer | **Enabler** | Catalog authoring | Correct JSON, validation, signing workflow | When validation catches errors pre-publish |
| S06 | Agent / LLM author | **Enabler** | Scale | Semi-manual artifact workflows (authoring skill) | Never over human review gate |
| S07 | Eigenverft catalog maintainer | **Enabler** | Growth | Online endpoint carries catalog outside module | When extension model holds; module not bloated |
| S08 | Future maintainer | **Enabler** | Architecture | Traceable policy, one effective selection resolver | When decisions live in wrk + constitution here |

## Agent model (S05, S06)

```text
Scale through semi-manual or fully manual agent-assisted artifact work — not unattended
fleet mutation. Agent reads guide + skill + schema; human reviews, signs, trusts, invokes.
Authoring path shipped and dogfooded (PackageDefinitionAuthoring.md). Profiles and assign
operability extend the same pattern (wrk issues). Unattended CI is edge case only: explicit
trust preseed, not default product path (see T-11, C-21).
```

## Success signals by stakeholder

| ID | Success signal |
|----|----------------|
| S01 | README quick start → preflight plan → Invoke-Package → Get-PackageState tells a coherent story |
| S02 | Preflight proves endpoint/depot/offline feasibility before assign; acquire failures are explicit |
| S03 | No silent jump to newest authored version; preflight shows trust/cooling/pin effects before execution |
| S04 | Team endpoint + depot + profile artifact → preflight on second machine matches without fleet product |
| S05 | Test-PackageDefinitionCatalog clean before sign; assignment preflight validates example DefinitionId bundles |
| S06 | Guide + skill + preflight artifact → JSON/profile draft without reading engine source |
| S07 | New definitions ship via endpoint; preflight works for larger catalogs; module export count stays a useful core |
| S08 | Policy choices in wrk + constitution; one resolver feeds invoke and preflight |

## Stakeholder Lens Pass (2026-06-07)

```text
Cross-stakeholder blindspot: the product explains discovery and post-run state, and now
plans post-failure operability, but it lacks a structured read-only assignment preflight.
Every stakeholder benefits from "show the plan before mutation":
S01 clarity, S02 offline confidence, S03 trust preview, S04 team repeatability,
S05 catalog/example validation, S06 agent grounding, S07 endpoint growth, S08 resolver coherence.
This creates ISSUE-ASSIGNMENT-PREFLIGHT and PR-13.
```
