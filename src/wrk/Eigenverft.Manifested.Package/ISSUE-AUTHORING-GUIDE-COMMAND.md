# ISSUE AUTHORING GUIDE COMMAND

## Purpose

Define a future module-level authoring guidance command so external agents can discover the package-definition workflow even when the Eigenverft repository is not the current workspace.

Issue ratings and definitions follow [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.6). Facts reviewed against `src/prj/Eigenverft.Manifested.Package` on 2026-06-03.

This issue is documentation and design tracking only. It does not implement the command, endpoint metadata, or authoring-skill updates.

---
---

## 📌 Installed module should expose package-definition authoring guidance and target endpoint discovery

- 🏷 Rating
  - 🚦 Priority: 3/6 Normal ▰▰▰▰▱▱▱
  - 🛠 Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Complexity: 3/5 Complex ▰▰▰▱▱
  - 🌍 Benefit: 1/4 Producer ▰▱▱▱
  - 📦 Shape: 2/4 Composite ▰▰▱▱
  - 🎯 Quality: 🧭 Usability
  - 🚧 Readiness: 🟠 Needs Refinement

### 📝 Statement

External agents can follow `AgentSkills/PackageDefinitionAuthoring.md` when the Eigenverft repository is open because a simple source search finds the file. That discovery path breaks when a different project is open and the agent only has the installed module available. The module should be able to print the canonical authoring instructions and explain where a new or updated package definition should be placed.

Original report:

> What if a other project is open you wont simply find the instruction. so my idea is to instruct the agent to invoke a PS command that is within this module like Package-Autoring that dumps the PackageDefinitionAuthoring.md to console maybe with a command passed Package-Autoring -For 'Totalcommander' that outputs the simple sentence where the for is inserted + the markdown to the console.

The same discussion raised endpoint selection: agents should check configured endpoints marked as authoring-target candidates, choose one by search-order preference when appropriate, and explain troubleshooting when no usable authoring target exists. The endpoint inventory probably does not need `writable` or `ensureExists` flags for this purpose because writability can be probed and directory creation can be attempted. What is missing is an explicit endpoint intent such as `authoringTarget: true`. If a function finds that flag, the endpoint is a candidate by maintainer intent, but the function still needs a write probe before selecting it. If a marked target is not writable or cannot be prepared, the command should emit a warning, report the failed target, and try the next best candidate.

### 🧭 Related Context

Related Issues:
- [ISSUE-CATALOG-AGENT.md](ISSUE-CATALOG-AGENT.md) introduced the `PackageDefinitionAuthoring` skill.

Affected Areas:
- `src/prj/Eigenverft.Manifested.Package/AgentSkills/PackageDefinitionAuthoring.md`
- `src/prj/Eigenverft.Manifested.Package/Commands/Module/Eigenverft.Manifested.Package.Cmd.Module.ps1`
- `src/prj/Eigenverft.Manifested.Package/Commands/Endpoint/Eigenverft.Manifested.Package.Cmd.PackageEndpoint.ps1`
- `src/prj/Eigenverft.Manifested.Package/Support/Package/Schema/Eigenverft.Manifested.Package.Package.EndpointInventory.Management.ps1`
- `src/prj/Eigenverft.Manifested.Package/Configuration/Internal/PackageEndpointInventory.json`

May Influence:
- Future endpoint authoring workflow, team catalog onboarding, and external-agent UI prompts.

Dependencies:
- Maintainer decision on command name and endpoint-selection parameter names.
- Decision on whether `authoringTarget: true` is enough endpoint metadata for v1.

### 🎯 Required Outcome

Agents should be able to run one exported module command from any working directory and receive package-definition authoring guidance, including a task-specific preface when `-For '<definitionId>'` is supplied. The command should surface configured `authoringTarget: true` endpoints, run a write probe against each candidate before selecting it, warn for marked-but-not-writable targets, and pick the next best writable candidate by the configured preference. Endpoint inventory should declare authoring intent explicitly without pretending that intent guarantees current filesystem access.

Smart target selection should use three separate concepts:

1. Candidate intent: `authoringTarget: true` means the maintainer says this endpoint may be used for authoring.
2. Current usability: runtime checks resolve the absolute target path, probe write/preparation ability, and report enabled/effective status.
3. Selection: the command chooses the best usable candidate, warns for skipped candidates, and explains what to fix when no usable candidate exists.
4. Agent instruction: when no `authoringTarget: true` endpoint exists, or when one or more are found but none are writable/preparable, the command output must instruct the agent to explain the endpoint situation to the user instead of silently continuing. If no target is marked, the explanation should name the endpoint inventory, summarize the configured endpoints, explain that no endpoint is marked for authoring, and describe how to add or mark one. If targets are marked but blocked, the explanation should name the marked endpoints, their resolved paths, why they were skipped, and practical next actions such as fixing filesystem permissions, creating the folder/share, enabling or repairing the endpoint, or choosing another explicit endpoint.

Suggested status model:

- `Ready`: marked as `authoringTarget`, writable/preparable, and enabled/effective for normal scans.
- `DraftOnly`: marked as `authoringTarget` and writable/preparable, but disabled or not effective; usable for test/prerelease/draft storage, with a warning that package commands will not scan it until enabled/effective.
- `Blocked`: marked as `authoringTarget`, but not writable, unreachable, or cannot be prepared; warn and try the next best candidate.
- `Unsupported`: marked as `authoringTarget`, but the endpoint kind has no implemented authoring check, such as future HTTPS create/update before authorization exists.

Default selection should skip `Blocked` and `Unsupported`, prefer `Ready`, then fall back to `DraftOnly` with a clear warning. Explicit endpoint selection can request a specific marked target, but it must still fail or warn if the write probe does not pass. If no endpoint is marked, or if all marked endpoints are blocked, the command should produce a troubleshooting-oriented guide section that the agent can relay directly to the user.

### 🔎 Facts

Known:
- `AgentSkills/PackageDefinitionAuthoring.md` exists under the module project and contains the package-definition authoring workflow.
- `Get-PackageVersion` is exported and prints general module/version/examples, but it does not emit the authoring skill body.
- `Get-PackageEndpoint` is exported and returns endpoint summaries with `EndpointName`, `Kind`, `Enabled`, `Effective`, `SearchOrder`, `ResolvedRootPath`, and `InventoryPath`.
- Endpoint inventory currently defines scan locations with `endpointName`, `kind`, `enabled`, `searchOrder`, and kind-specific path fields.
- The shipped `PackageEndpointInventory.json` currently has `moduleDefaults` as an enabled `moduleLocal` endpoint and `corpPackageEndpoint` as a disabled `filesystem` endpoint.
- Endpoint validation currently checks required fields and retired trust fields; it does not model authoring intent.
- Depot inventory already has writable-style metadata such as `writable`, `mirrorTarget`, and `ensureExists`, but endpoint inventory does not.
- Search order is sorted ascending in runtime endpoint selection; lower numeric `searchOrder` is the first searched endpoint.
- Filesystem writability can be checked at runtime, and directory creation can be attempted when needed.
- `moduleLocal` endpoints can resolve to an absolute module folder and can be useful as a local test/prerelease authoring store when explicitly marked, if the resolved folder passes the write probe.
- `filesystem` endpoints already carry a configured path; the authoring guide command should display the full resolved location and whether the endpoint is disabled, writable, reachable, or skipped.

Unknown:
- Final command name: `Get-PackageDefinitionAuthoringGuide` is a likely approved-verb candidate, but naming is not decided.
- Whether the command should output plain text only, a structured object plus text, or both via parameter sets.
- Whether endpoint inventory should bump `inventoryVersion` when `authoringTarget` is introduced.
- Exact default selection behavior when multiple `authoringTarget: true` endpoints are configured, especially when one is disabled.

---

### 🧩 Options

#### Option A — Authoring guide command with `authoringTarget` endpoint intent (Combined Path Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
  - 🧾 Agent Work: 🧭 Code + Tests + Docs

Description:
Add an exported command, likely `Get-PackageDefinitionAuthoringGuide`, that prints a generated task preface and then the module-local `PackageDefinitionAuthoring.md` content. Add `authoringTarget: true` as endpoint inventory metadata to mark endpoints intended for package-definition authoring. The command discovers endpoints with `authoringTarget: true`, treats the flag as the candidate-intent signal, resolves their paths, probes or creates the target directory only when appropriate, and selects only a currently writable/preparable candidate. For `moduleLocal`, output the absolute resolved definition root; for `filesystem`, output the full resolved location. If a candidate fails the write probe, emit a warning and continue to the next best candidate. If no endpoint is marked for authoring, print a troubleshooting section that explains endpoint inventory, lists current endpoint candidates, and tells the user how to mark or add an authoring target. If marked targets exist but no writable authoring target is available, print a troubleshooting section that explains what was checked, which targets were blocked, and how the user can configure or repair one.

Current State:
Agents must discover the authoring markdown by searching the current repository. If another project is open, an agent can import the module but has no obvious command that explains the package-definition authoring workflow or where to place a draft definition. Endpoint inventory has scan locations, but it does not distinguish read/scan endpoints from intended authoring destinations.

Resulting State:
An agent can run one command from any workspace, for example `Get-PackageDefinitionAuthoringGuide -For 'TotalCommander'`, and receive a task-specific instruction header, endpoint target guidance, troubleshooting text, and the full authoring guide. Endpoint inventory declares authoring intent separately from real filesystem access, and the command verifies and displays filesystem access at runtime. The shipped inventory starts with `authoringTarget: true` on both `moduleDefaults` and the disabled `corpPackageEndpoint`, so local test/prerelease authoring and future share-backed authoring are both visible. A disabled or unreachable share can be reported as an intended target but skipped for selection until the write probe passes.

Solves:
- Makes authoring guidance discoverable outside the Eigenverft source workspace.
- Gives agents an explicit path for no-marked-target and no-writable-target troubleshooting.
- Avoids duplicating filesystem truth in inventory by using `authoringTarget` for intent and runtime probing for selection.
- Prevents selecting marked targets that are not currently writable.
- Gives agents ready wording to explain endpoint configuration and permission problems to users when marked targets are blocked.
- Lets maintainers mark local, test, prerelease, or disabled future-share endpoints as authoring targets without requiring endpoint enablement first.

Leaves Open:
- Exact command output shape.
- Exact selection parameter name and default, such as `-EndpointPreference First|Last`.
- Whether a helper should physically create missing authoring directories or only report the command/user action needed.

Risks:
- If the command returns only plain text, future tools may need to scrape output.
- If the command creates directories too eagerly, a read-only or policy-controlled path may produce surprising side effects.
- If both shipped endpoints are marked as authoring targets, the command must make disabled and non-writable status obvious, warn for skipped candidates, and select the next best writable target.

Later Cost:
- Endpoint management commands need small follow-up support so maintainers can set or clear `authoringTarget` cleanly.

---

#### Option B — Update the authoring markdown only (Partial Documentation Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
  - 🔮 Future Impact: ⚪ 0 Neutral
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🔵 Local
  - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
  - 🧾 Agent Work: 📝 Writing / Docs

Description:
Add a troubleshooting section to `PackageDefinitionAuthoring.md` that tells agents what to do if they cannot find an authoring endpoint or are working outside the Eigenverft repository. The text can explain that authors should ask the maintainer to configure an endpoint intended for authoring. This is the smallest improvement and does not require new command surface or endpoint metadata.

Current State:
The authoring markdown exists but is only easy to discover from the source repository. Agents that do not find the file cannot benefit from its troubleshooting text.

Resulting State:
Agents that already discover the markdown receive better endpoint troubleshooting guidance. Agents in unrelated workspaces still need to know the file exists or receive it through some other channel.

Solves:
- Clarifies no-authoring-target behavior for agents that already found the skill.
- Avoids command and inventory changes.

Leaves Open:
- Does not solve installed-module discoverability.
- Does not let the module select or report an authoring endpoint.

Risks:
- Gives a false sense that the discovery problem is solved when only the markdown reader path improved.

Later Cost:
- A future command still needs to be added if agents should self-orient from any workspace.

---

#### Option C — Command without endpoint authoring metadata (Reframed Implementation Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟡 Acceptable
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 🧭 Code + Tests

Description:
Add the exported authoring guide command, but avoid endpoint inventory changes. The command would infer candidate authoring targets from enabled filesystem endpoints, resolved path accessibility, and search order. It could also accept an explicit endpoint name when the maintainer wants to override inference.

Current State:
Endpoint summaries expose scan roots but not authoring intent. Inference would treat all enabled filesystem scan endpoints as possible authoring endpoints unless filtered by probing.

Resulting State:
Agents can obtain the authoring guide from the installed module, but endpoint selection remains heuristic. A filesystem endpoint could be readable and writable yet not intended for agent-authored drafts.

Solves:
- Fixes installed-module guidance discoverability.
- Avoids endpoint inventory changes in the first slice.

Leaves Open:
- No durable way to distinguish scan-only endpoints from authoring destinations.
- Troubleshooting is weaker because the command cannot tell whether no target exists or only no target was inferable.

Risks:
- Heuristics may select the wrong endpoint.
- Future work may need to unwind inference after `authoringTarget` is added.

Later Cost:
- Adds likely cleanup work when explicit authoring intent is introduced later.

---

### 💶 Value Assessment

- 💎 Value Type: 🧲 Adoption / Retention Improved · 🛟 Support Effort Reduced · 🔎 Better Decision
- 🧭 Value Direction: 🚀 Opportunity / Improvement
- 🧾 Value Mechanism: A module command gives agents a reliable self-orientation path independent of the current workspace, while endpoint authoring intent plus write probing makes local, test, prerelease, and team-share authoring stores explicit without selecting unusable locations.
- ⚖️ Option Value Summary:
  - Option A — Authoring guide command with `authoringTarget` endpoint intent (Combined Path Option)
    - 🧭 Resolution: 🟢 Full
    - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
    - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧾 Decision Note: Best balance; solves discovery and target intent while requiring live write probing before selection.
  - Option B — Update the authoring markdown only (Partial Documentation Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
    - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
    - 🔮 Future Impact: ⚪ 0 Neutral
    - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
    - 🧾 Decision Note: Useful small text improvement but does not solve the installed-module discovery gap.
  - Option C — Command without endpoint authoring metadata (Reframed Implementation Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 2/4 Moderate ▰▰▱▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧾 Decision Note: Solves guide discovery but relies on endpoint heuristics that may become product debt.
- ✅ Good Result: Agents can ask the installed module for package-definition authoring instructions and receive honest endpoint guidance, including absolute target paths, write-probe status, skipped-target warnings, and user-facing endpoint troubleshooting text when no authoring target is marked or no marked target is writable.

---

### 🏁 Recommendation

- [2026-06-03 20:16 | Author: Codex | Recommendation: Prefer Option A | Support: 2/3 Reasoned ▰▰▱]

Reasoning:
The installed-module command solves the real UI/agent problem: the authoring instructions must be discoverable when the Eigenverft repository is not open. `authoringTarget: true` is the right minimal endpoint metadata because it records maintainer intent, but it is not enough to select an endpoint for writing. Live writability or preparability must be checked before selection; failed candidates should warn and selection should continue to the next best marked endpoint.

Required Checks:
- Confirm command name and exported command surface.
- Confirm whether endpoint inventory version should be bumped when `authoringTarget` is introduced.
- Confirm whether authoring target selection should default to lowest numeric `searchOrder` (`First`) or require an explicit switch when multiple targets exist.
- Ensure the shipped `PackageEndpointInventory.json` starts with `authoringTarget: true` on both `moduleDefaults` and `corpPackageEndpoint`; `corpPackageEndpoint` remains disabled unless explicitly enabled later.
- Define the write probe contract, including whether it creates and removes a temporary marker file, checks parent creation, or only tests an existing directory.
- Define the no-marked-target and no-writable-target message contracts so agents consistently explain endpoint inventory, configured endpoints, marked targets, skipped reasons, and next user actions.

### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: Package-definition maintainers and external-agent operators
- 🗣 Communication Lens: Product Summary
- 📬 Success Note: Agents can now ask the installed module how to author package definitions instead of depending on repository search. The workflow can point them to a configured authoring endpoint or explain exactly what is missing. This reduces malformed drafts and wrong-location edits while keeping human review and signing as the publication gate.

### ✅ Resolved Decisions

- Decision: Endpoint authoring intent should not be inferred only from filesystem writability.
  Reason: A path can be writable but still not be intended for agent-authored package definitions.
  Consequence: The preferred path includes explicit `authoringTarget: true` metadata.

- Decision: `authoringTarget: true` is sufficient for a function to treat an endpoint as an authoring-target candidate, but not sufficient to select it for writing.
  Reason: The flag records maintainer intent; current writability is operational state and can fail due to ACLs, network availability, disabled shares, or missing directories.
  Consequence: Marked but non-writable targets are reported with warnings and skipped while the command tries the next best candidate.

- Decision: When no marked endpoint is writable/preparable, the authoring guide command should instruct the agent to explain the endpoint problem to the user.
  Reason: This is an environment/configuration issue, not a package-definition authoring task the agent can solve silently.
  Consequence: The command output should include user-facing troubleshooting, not only machine-readable status.

- Decision: When no endpoint is marked with `authoringTarget: true`, the authoring guide command should instruct the agent to explain the missing authoring-target configuration to the user.
  Reason: Without an explicit authoring target, the agent does not know where package-definition drafts are intended to be written.
  Consequence: The command output should summarize configured endpoints and give user-facing guidance for adding or marking an authoring target.

- Decision: `writable` and `ensureExists` are not required endpoint metadata for the first issue shape.
  Reason: Actual filesystem access can be probed, and directory creation can be attempted by the command when policy allows.
  Consequence: The issue focuses on `authoringTarget` plus runtime checks rather than copying the full depot writable model.

- Decision: The first implementation should add `authoringTarget: true` to both shipped endpoint entries.
  Reason: `moduleDefaults` can serve local test/prerelease authoring when explicitly marked, and the disabled share entry can show the intended future/team authoring store without enabling it for normal scans.
  Consequence: The authoring guide command must report absolute paths and status clearly so agents understand which target is local, disabled, writable, or active.

### ❓ Open Decisions

- Should the command output a plain string, structured object, or both?
- Should the command be named `Get-PackageDefinitionAuthoringGuide`, or is another approved-verb name better?
- Should multiple authoring targets select the lowest numeric `searchOrder` by default, the highest numeric `searchOrder`, or require explicit selection?
- Should endpoint commands add `-AuthoringTarget` / `-NoAuthoringTarget` switches, or should the first implementation only read the metadata?
- Should disabled authoring targets be selectable by default, or listed as valid targets that require explicit selection?
- What exact write probe should be used for `moduleLocal` and `filesystem` paths?
- What exact user-facing troubleshooting text should `Get-PackageDefinitionAuthoringGuide` emit when no target is marked?
- What exact user-facing troubleshooting text should `Get-PackageDefinitionAuthoringGuide` emit when every marked target is blocked?

### 🚫 Out of Scope

- Changing package-definition schema 1.9.
- Changing package install or dependency planner behavior.
- Automatically signing or publishing package definitions.
- Trusting new signing keys.
- Writing package-definition JSON from the guide command itself.

### 🌱 Extracted Work

None.
