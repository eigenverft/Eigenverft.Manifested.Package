# Implemented decisions

This is a compact index of completed work that still explains the active backlog. Detailed implementation history belongs in Git and tests, not in `src/wrk`.

| Capability | Current contract |
|---|---|
| Package search | `Search-Package` scans enabled local/filesystem endpoints and applies schema and catalog-trust eligibility. |
| Definition trust | Signed definitions, trust inventory, strict/allow-unsigned policy, and explicit unknown-key handling are shipped. |
| Catalog validation | `Test-PackageDefinitionCatalog` validates the schema-2.0 catalog and trust. |
| Dependencies | `Invoke-Package` builds one dependency plan for assigned and materialize-only roots. |
| Assignment preflight | `Get-PackageAssignmentPlan` reuses the execution resolver to preview trust, dependencies, selected releases, artifacts, depot readiness, and existing-install actions without network or persisted mutation. |
| Artifact file sets | Schema 2.0 supports required multi-file distributions and `archiveEntry`-derived files. |
| Durable materialization | `-MaterializeOnly` verifies the complete artifact set, repairs missing/invalid members, and uses the multi-writer-safe filesystem transport for static and npm file sets. The set may be durable in any readable depot; incomplete secondary mirrors remain visible but do not erase success. `searchOrder` selects read preference, while `mirrorTarget` independently selects write targets. |
| Trusted catalog materialize | Public `Invoke-PackageDepotMaterialize -AllTrusted` confirms and materializes deduplicated current-platform definitions only when every planned definition is already `signedTrusted`; it continues after individual package failures by default, supports opt-in `-FailFast`, and does not mutate trust or prune files. |
| Authoring | `Get-PackageDefinitionAuthoringGuide` and `AgentSkills/PackageDefinitionAuthoring.md` provide the LLM-oriented authoring flow. |
| Offline bootstrap | `EigenverftManifestedPackage` is an independently versioned seed that materializes the module, PackageManagement, PowerShellGet, and bootstrap scripts for a clean Windows machine. |
| State and outcome | `Get-PackageState`, operation-history summaries, and `[OUTCOME]` messages are shipped. |
| Browser opening | `Open-UrlInBrowser` opens arbitrary local files or HTTP(S) URLs; `Open-PackageDocumentation` resolves the exact active module version's `Documentation/index.html`. Minimal HTML pages differ only in embedded Markdown, use one stylesheet and one sequential local loader, while neutral `documentation.*` assets build an icon-backed page dropdown plus explicit online project links without fetch or CDN dependencies. `DocTemplate.html` visibly carries the complete portable bootstrap contract and source blueprints without prescribing another project's launch mechanism. |

Remaining work is indexed in [TODO-INDEX.md](TODO-INDEX.md). The accepted local-search design does not imply HTTPS transport or a manifest; those remain separate backlog items.
