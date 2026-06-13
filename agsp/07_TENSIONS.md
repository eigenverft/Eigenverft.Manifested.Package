# 07_TENSIONS

| ID | Tension | Legitimate A | Legitimate B | Alignment (who wins) | Product rule |
|----|---------|--------------|--------------|----------------------|--------------|
| T-01 | First impression vs security depth | Fast quick start (S01) | Cooling, trust prompts (S03) | Security with visible escape hatch | Pin documented; logs explain skips; README leads with happy path |
| T-02 | Auto-update convenience vs supply-chain safety | Newest version immediately | Cooling before auto-pick | Safety for auto-path only | Implement P5; pins override |
| T-03 | Agent speed vs review capacity | More defs faster (S06) | Human/signing gate (S05) | Review gate never removed | Test-PackageDefinitionCatalog mandatory pre-trust |
| T-04 | Module simplicity vs catalog growth | Ship more in module (S07) | Small engine (S08) | Extension model wins | Endpoints/httpsCatalog, not module bloat |
| T-05 | Search simplicity vs catalog scale | Live scan (shipped) | Manifest/index (P2) | Simplicity until ~200 defs / latency pain | DECISION-ENDPOINT-DISCOVERY-V1 trigger |
| T-06 | Authoring ease vs schema strictness | Loose schema | Agent-safe strict wire | Strictness with guide + validation | No script hooks shortcut |
| T-07 | Offline story vs GitHub acquire | No network ever (S02 ideal) | githubRelease at acquire (3 defs) | Step-separated clarity | Selection offline; acquire per source kind |
| T-08 | Docs in repo vs bundled offline | Git readers | Gallery-only installs (H-04) | Parity via hybrid docs (P4) | Same content, two surfaces |
| T-09 | Profile as team recipe vs Manager org mandate | Curated role bundles now (S04) | Fleet policy later (Manager) | Content now; enforcement in Manager | profileId in artifacts; no engine fleet invoke |
| T-10 | Profile convenience vs second trust system | One named install surface | Definition-level trust only | Definition trust wins in v1 | No PackageProfileTrustInventory until proven need |
| T-11 | Unattended automation vs governed trust | Headless CI, scripts (implicit) | Prompts, review, semi-manual agent (S06) | Semi-manual agent + human gate | C-21; authoring skill dogfooded; preseed/bootstrap = exception only |
| T-12 | One-command simplicity vs plan-before-mutation | Fast direct Invoke-Package | Read-only preflight artifact first | Clarity wins when risk/context exists | Keep Invoke-Package direct, but expose Get-PackageAssignmentPlan for review |
