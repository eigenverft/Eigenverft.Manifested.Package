# 05_OPEN_QUESTIONS

Product-strategic only. Implementation syntax, phases, and code paths → wrk/ issues.

| ID | Question | Blocking? | Affects | Proposed default |
|----|----------|-----------|---------|------------------|
| PQ-01 | Is default ~7d cooling acceptable for dev velocity (SC-01)? | Yes* | Supply chain adoption | Yes if pin is prominent in docs and errors |
| PQ-02 | For first-time trust, docs (P4) or ownership guide (P3) first? | No | SC-02 onboarding | P4 hybrid docs — broader audience |
| PQ-03 | When does catalog growth force manifest (H-06)? | No | P2 sequencing | Reopen at measured scan latency or ~200 defs |
| PQ-04 | Should bundled guide duplicate PRODUCT-BOUNDARY or only link? | No | Doc trust | Summarize + link; boundary stays canonical in wrk |
| PQ-05 | Is Catalog Maintenance Workbench (IDEA) worth a formal issue now? | No | Agent scale | No — authoring loop dogfooded (F-09); open issue only if maintainer pain recurs |
| PQ-06 | Sign off draft decisions (endpoint discovery, artifacts vocab)? | No | P2 design confidence | Yes before httpsCatalog implementation |
| PQ-07 | Profile artifact: JSON vs markdown; explicit deps in list? | No | SC-07 / PR-11 | Top-level definitionIds; planner handles transitive — see wrk issue |
| PQ-08 | Read-only Get-PackageProfile in v1 or docs-only first? | No | Option B timing | Docs + examples first (Option A); cmd after format stable |
| PQ-09 | Execution log retention: keep all vs prune last N / age? | No | PR-12 operability | v1 append-only; prune later if disk matters |
| PQ-10 | Operability command family name (`Assignment` vs `Execution`)? | No | Agent discoverability | `Get-PackageAssignmentOperabilityGuide` + `Get-PackageExecutionLog` — see wrk feature |
| PQ-11 | Preflight command name and depth: `Get-PackageAssignmentPlan` vs `Test-*`; depot/offline shallow vs deep? | No | PR-13 / SC-09 | `Get-PackageAssignmentPlan`; start read-only with resolver/dependency/trust/depot feasibility |

*Blocking product acceptance of release-age policy, not blocking code start (defaults in wrk).
