# 04_ASSUMPTIONS

## Verified facts (codebase — refresh on schema/catalog change)

| ID | Fact | Source |
|----|------|--------|
| F-01 | 18 shipped defs, schema 1.9, moduleLocal endpoint enabled | Endpoint/Defaults, inventory |
| F-02 | Selection is local to authored releases; no network in VersionSelection | Package.VersionSelection.ps1 |
| F-03 | latestByVersion picks highest compatible version immediately today | Runtime + TODO-SUPPLY-CHAIN |
| F-04 | Search-Package shipped 2026-06-01; live scan on enabled endpoints | DECISIONS.md |
| F-05 | httpsCatalog in inventory but Resolve throws — not effective | TODO-ENDPOINTS-HTTPS facts |
| F-06 | Only filesystem depot kind exists | TODO-DEPOTS-HTTP facts |
| F-07 | Trust/signing shipped; catalogTrust strict | PackageConfig.json |
| F-08 | 7/18 defs allow external adoption; ownership policies vary | TODO-OWNERSHIP facts |
| F-09 | PackageDefinitionAuthoring.md + Get-PackageDefinitionAuthoringGuide dogfooded with live agent (2026-06) | Product validation |
| F-10 | No exported assignment preflight/plan command; internal New-PackageDependencyPlan exists and is used by Invoke-Package | psd1 exports, Cmd.InvokePackage.ps1, DependencyPlan tests |

## Product hypotheses (may be wrong — test explicitly)

| ID | Hypothesis | Confidence | Risk if wrong | How to test |
|----|------------|------------|---------------|-------------|
| H-01 | Primary adopters are solo/small-team devs before enterprise fleet | Medium | Over-build Manager features in engine | User interviews, issue traffic |
| H-02 | 7-day cooling is acceptable if pin override is documented | Medium | Power users frustrated | Supply-chain UX + docs |
| H-03 | Teams adopt file-share endpoints before httpsCatalog | Medium | Wrong P2 sequencing | First production endpoint kind |
| H-04 | Gallery-only users need offline bundled docs more than repo README | High | P4 docs low ROI | Support questions post-install |
| H-05 | Agent catalog velocity will exceed human review bandwidth | Medium | Bad defs slip through | Validation catch rate, review time; mitigated by authoring skill + Test-PackageDefinitionCatalog (F-09) |
| H-06 | Manifest trigger ~200 defs is right before pain appears | Low | Too early or too late | Measure Search-Package latency on real catalogs |
| H-07 | "One command" story matters more than exposing all 38 exports | Medium | API surface confusion | Onboarding funnel |
| H-08 | Users will trust one-command assignment more if a read-only plan exists first | Medium | Extra command feels like friction | Compare onboarding with and without preflight |
