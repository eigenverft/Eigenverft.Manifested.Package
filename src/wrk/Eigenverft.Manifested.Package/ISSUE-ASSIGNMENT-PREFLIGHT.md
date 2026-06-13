# ASSIGNMENT PREFLIGHT - Design Issues

Design scratchpad for **assignment preflight** - a read-only way to inspect what `Invoke-Package` would resolve before it downloads, trusts, installs, removes, or mutates local state. Issue ratings and definitions follow [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.8). Facts re-verified against `src/prj/Eigenverft.Manifested.Package` and [PRODUCT-BOUNDARY.md](PRODUCT-BOUNDARY.md) on **2026-06-07**.

Open issues in this file are scheduled here. **No engine, schema, or catalog changes are implied by this file alone** unless an issue and chosen option state otherwise.

**Compose with:** [PRODUCT-BOUNDARY.md](PRODUCT-BOUNDARY.md) (explicit local assignment), [ISSUE-ONBOARDING-PROFILES.md](ISSUE-ONBOARDING-PROFILES.md) (profile bundles need validation before publish), [ISSUE-AGENT-OPERABILITY.md](ISSUE-AGENT-OPERABILITY.md) (post-failure diagnosis), [TODO-SUPPLY-CHAIN.md](TODO-SUPPLY-CHAIN.md) (age-aware selection), and [TODO-DEPOTS-HYGIENE.md](TODO-DEPOTS-HYGIENE.md) (depot readiness).

**Product boundary (read narrowly):** Preflight explains and validates the next explicit local action. It does not install, remove, download, trust unknown keys, mutate endpoint/depot inventories, or become fleet policy. It is the product's "show me the plan" surface before `Invoke-Package`.

---

## Open Issues

Sorted by **Priority** (higher urgency first), then higher **Benefit**, then lower **Effort** within the same priority.

**Priority 4/7 - Normal**

---

## Assignment intent is not reviewable before mutation

- Rating

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| Priority | 4/7 Normal | ▰▰▰▰▱▱▱ | many stakeholders need pre-run confidence |
| Effort | 3/4 Substantial | ▰▰▰▱ | public cmd, object model, tests, docs |
| Complexity | 3/5 Complex | ▰▰▰▱▱ | selection, trust, depots, state intersect |
| Benefit | 4/4 Product | ▰▰▰▰ | improves trust before every assign |
| Shape | 2/4 Composite | ▰▰▱▱ | plan object plus formatting plus tests |
| Quality | Operability / UX | - | preview reduces surprise and recovery cost |
| Readiness | Ready | - | internal dependency planner already exists |

### Statement

The product asks users to trust `Invoke-Package` as the explicit action boundary, but there is no exported command that shows the resolved assignment plan before that boundary is crossed.

Stakeholders currently infer the plan from a mixture of README command lists, `Search-Package` single-definition rows, trust prompts during invoke, endpoint/depot config, and source code knowledge. That is good enough for a small happy path, but weak for team profiles, isolated networks, signed catalogs, depot-backed setup, and agent-produced artifacts.

The missing product move is not "auto-repair" and not "fleet policy." It is a read-only **assignment preflight**:

```text
DefinitionIds in
-> dependency plan
-> selected versions / skipped candidates
-> publisher and trust status
-> source/depot/offline feasibility
-> existing/adopted/package-owned state
-> elevation/removal risk hints
-> exact Invoke-Package line
```

### Stakeholder Lens

| Stakeholder | What preflight gives them |
| --- | --- |
| S01 Windows developer | A quick answer to "what will this install and why?" before first mutation |
| S02 Isolated-network operator | Evidence that selection is local and acquisition will not unexpectedly reach public sources |
| S03 Security / compliance | Trust, signature, cooling, hash, and pin explanations before execution |
| S04 Team endpoint / depot owner | A way to verify a shared endpoint/depot/profile before telling a second machine to run it |
| S05 Package-definition maintainer | A real assignment-plan check after catalog validation but before signing/publishing examples |
| S06 Agent / LLM author | A deterministic artifact to cite instead of guessing dependency and trust effects |
| S07 Eigenverft catalog maintainer | A scalable preview path for larger endpoint catalogs without bloating the module |
| S08 Future maintainer | One public read-only plan surface instead of ad-hoc preview logic spread across docs and commands |

### Required Outcome

1. Exported read-only command, working name **`Get-PackageAssignmentPlan`**, accepts the same core selection inputs as `Invoke-Package` (`DefinitionId`, optional `PublisherId`, `PackageVersion`, `Offline`, maybe `MaterializeOnly` / `DesiredState` where meaningful).
2. It reuses the effective resolver and dependency planner rather than creating a second planning model.
3. Output includes root definitions, dependency nodes/edges, selected versions, trust status, endpoint/source summary, existing assignment/adoption status, depot/offline feasibility, warnings, blockers, and exact next command.
4. It does not write trust, package state, operation history, depot files, staged package files, endpoint inventory, or install directories.
5. It gives agents and humans a stable object shape for profile validation, isolated-network checks, and review comments.

### Facts

Known:
- `Invoke-Package` does not use `SupportsShouldProcess` and has no `-WhatIf` surface (`Cmd.InvokePackage.ps1`).
- Exported command names include `Invoke-Package`, `Search-Package`, and `Get-PackageState`, but no `*Plan*`, `*Preflight*`, `*Preview*`, or `*AssignmentPlan*`.
- `Invoke-Package` already calls internal `New-PackageDependencyPlan` before assignment/materialization and returns failure results when the dependency plan is rejected.
- Tests already exercise `New-PackageDependencyPlan` for `CodexCli`, `Qwen35_9B_Q6_K_Model`, and `VSCodeRuntime`/`VSCodeUser` conflict cases.
- `Search-Package` returns invoke-ready rows for single definitions, not a multi-root assignment plan.
- `Get-PackageState` explains current state after prior operations; it does not preview a future assignment.
- `Test-PackageDefinitionCatalog` validates package-definition JSON and catalog trust shape; it does not validate a user's concrete endpoint/depot/offline assignment intent.

Unknown:
- Whether v1 should inspect depot file existence/hash deeply or only report acquisition candidate kinds.
- Whether removal preflight belongs in v1 or should start with assigned/materialize-only paths.
- Whether preflight should produce one envelope for multi-root invocations or one plan per root plus a shared graph.

### Options

#### Option A - Export `Get-PackageAssignmentPlan` as a read-only preflight surface (Implementation Option)

Description:
Expose a read-only command that resolves definitions, dependency graph, selected versions, trust status, endpoint/source/depot feasibility, and next command. It shares resolver/planner code with `Invoke-Package` and becomes the validation target for profile examples and agent reviews.

Solves:
- Plan-before-mutation gap across all stakeholder lenses.
- Profile artifact validation before publication.
- Isolated/offline confidence before an operator starts an assign.
- Agent review traceability without engine-source reading.

Risks:
- If it forks invoke logic, it becomes misleading. Mitigation: reuse core resolver/planner and test parity with `Invoke-Package` planning.

#### Option B - Add `-WhatIf` to `Invoke-Package` only (Implementation Option)

Description:
Make `Invoke-Package` support PowerShell `ShouldProcess` and rely on `-WhatIf` output as the preview path.

Solves:
- Familiar PowerShell surface.

Leaves Open:
- `-WhatIf` text alone is too weak for agents, profiles, trust review, depot/offline checks, and structured comparison.

Risk:
- False confidence if `-WhatIf` only suppresses late mutation while still performing partial planning/acquisition side effects.

#### Option C - Document manual preflight checklist only (Defer Option)

Description:
Use docs to tell users to run `Search-Package`, inspect state, validate catalogs, and then run `Invoke-Package`.

Solves:
- Fastest documentation path.

Leaves Open:
- No stable object for agents or team profile validation.
- Same cognitive load remains for isolated/security stakeholders.

#### Option D - Defer to operability logs after failure (Reject Option)

Description:
Treat post-failure logs and guide commands as enough; users run first, then diagnose if needed.

Solves:
- Avoids new command surface.

Leaves Open:
- Violates "understand before install" for the most cautious stakeholders.
- Turns preventable setup mistakes into failed installs.

### Recommendation

- [2026-06-07 22:55 | Author: Codex | Recommendation: Choose Option A | Support: 3/3 Well Supported]

Reasoning:
Option A is the only path that satisfies all stakeholder lenses without crossing the Manager boundary. It turns existing internal planning into a product surface and gives profiles, agents, isolated operators, and security reviewers a common artifact before mutation. Option B may still be useful later, but `-WhatIf` is not enough as the primary product answer.

### Resolved Decisions

- Preflight is **read-only** and does not mutate trust, state, depots, endpoints, staged files, or installs.
- Preflight belongs in this package engine because it explains one local explicit assignment, not fleet policy.
- The command must reuse the effective assignment resolver/planner rather than maintain a parallel model.

### Open Decisions

- Command name: `Get-PackageAssignmentPlan` vs `Test-PackageAssignmentPlan` vs `Test-PackageAssignmentPreflight`.
- Depth of depot/offline checks in v1.
- Whether removal preflight ships with assigned preflight or follows after assignment plan shape stabilizes.
- Exact output object shape for agent/profile validation.

### Out of Scope

- Automatically executing the returned plan.
- Fleet-wide policy, drift compliance, or mandatory profile enforcement.
- Trusting unknown keys or downloading packages during preflight.
- Replacing post-failure execution logs and operability guide.

### Extracted Work

Optional follow-ups:
- Add `Invoke-Package -WhatIf` once the structured plan object exists.
- Include preflight examples in hybrid docs and onboarding profile examples.
- Let future Manager read assignment plans for policy explanation without owning the engine resolver.

---
