# AGENT OPERABILITY - Design Issues

Design scratchpad for **agent operability** - persisted execution logs, readable console output, operability guide command, and propose-first failure recovery. Issue ratings and definitions follow [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.8): rating and option-profile tables with short rationales; **Option Kind** in each option heading; **Value Assessment** after Options with **Good Result**; **Stakeholder Success Note** after Recommendation; one **Prefer/Choose Option X** per issue with required author and `YYYY-MM-DD HH:mm`. Facts re-verified against `src/prj/Eigenverft.Manifested.Package` and [PRODUCT-BOUNDARY.md](PRODUCT-BOUNDARY.md) on **2026-06-07**.

Open issues in this file are scheduled here. **No engine, schema, or catalog changes are implied by this file alone** unless an issue and chosen option state otherwise.

**Compose with:** [`PRODUCT-BOUNDARY.md`](PRODUCT-BOUNDARY.md) (local engine; no background mutation). [`IDEA-AGENT-SCALES-PRODUCT.md`](IDEA-AGENT-SCALES-PRODUCT.md) (agent scales diagnosis and repair planning; §4-5). Shipped pattern: [`Get-PackageDefinitionAuthoringGuide`](../../prj/Eigenverft.Manifested.Package/Commands/Module/Eigenverft.Manifested.Package.Cmd.Module.ps1) + `AgentSkills/PackageDefinitionAuthoring.md`. Orthogonal to [ISSUE-ONBOARDING-PROFILES.md](ISSUE-ONBOARDING-PROFILES.md) and [TODO-SUPPLY-CHAIN.md](TODO-SUPPLY-CHAIN.md). Compass: `/agsp` PR-12, SC-08, C-19-C-20.

**Product boundary (read narrowly):** Agents **explain** failures and **propose** repair steps as reviewable artifacts. The engine **executes** only explicit trusted commands (`Invoke-Package`, trust/endpoint/depot cmds). No auto-repair daemon, no fleet log aggregation, no LLM inside the module. Failure recovery is an **agent product feature** (like catalog authoring), not a Manager-only concern.

---

## Open Issues

Sorted by **Priority** (higher urgency first), then higher **Benefit**, then lower **Effort** within the same priority.

**Priority 3/7 - Low**

---
---

## 📌 Assign failures lack persisted execution logs and an agent operability entry command

- 🏷 Rating

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🚦 Priority | 3/7 Low | ▰▰▰▱▱▱▱ | happy path works; gap hits failed assigns |
| 🛠 Effort | 3/4 Substantial | ▰▰▰▱ | log tee, config, cmds, skill, tests |
| 🧠 Complexity | 3/5 Complex | ▰▰▰▱▱ | operation context plus multi-root tagging |
| 🌍 Benefit | 3/4 Team | ▰▰▰▱ | teams and agents recover without source |
| 📦 Shape | 2/4 Composite | ▰▰▱▱ | log plus polish plus guide plus read cmd |
| 🎯 Quality | 📡 Operability | - | diagnostics and recovery path |
| 🚧 Readiness | 🟢 Ready | - | choke point and OperationId exist |

### 📝 Statement

When `Invoke-Package` fails or partially succeeds, operators and agents cannot complete a **round operability loop**. Live tracing goes only to the console via `Write-PackageExecutionMessage`; the step narrative is lost when the terminal closes. `PackageOperationHistory.json` stores one **summary row** per completed definition run (`failedStep`, `failureReason`) but not the ordered `[STEP]` / `[OUTCOME]` / `[ACTION]` story needed to diagnose trust, depot, acquire, or dependency failures.

Unlike package-definition authoring, there is no **`Get-PackageDefinitionAuthoringGuide`-style entry command** that loads a skill, evaluates runtime context, and prints `AgentAction:` lines pointing at the right artifacts to read.

Original design intent (from [IDEA-AGENT-SCALES-PRODUCT.md](IDEA-AGENT-SCALES-PRODUCT.md) and product discussion):

> Agent scales catalog work, validation, trust preparation, onboarding, **and diagnosis**. Persisted execution log by `operationId` → operability guide → agent proposes repair → human runs trusted commands.

The gap is **observability plus agent entry surface** - not a new install engine or auto-repair runtime.

### 🧭 Related Context

Related Issues:
- [IDEA-AGENT-SCALES-PRODUCT.md](IDEA-AGENT-SCALES-PRODUCT.md) - `Explain-PackageState` and `Repair-PackageAssignmentPlan` as future names; depend on this issue first.
- [ISSUE-ONBOARDING-PROFILES.md](ISSUE-ONBOARDING-PROFILES.md) - orthogonal; profiles are content bundles, not failure diagnosis.
- [TODO-SUPPLY-CHAIN.md](TODO-SUPPLY-CHAIN.md) - orthogonal; cooling adds new skip reasons operability should explain once shipped.
- [TODO-DOCUMENTATION.md](TODO-DOCUMENTATION.md) - hybrid guide should link troubleshooting to operability commands after ship.
- Shipped authoring path - `Get-PackageDefinitionAuthoringGuide` is the template for guide + `AgentSkills/*.md` packaging.

Affected Areas:
- `Support/Package/Execution/Eigenverft.Manifested.Package.Package.ExecutionMessage.ps1` - single tee choke point.
- `Support/Package/State/Eigenverft.Manifested.Package.Package.OperationHistory.ps1` - complementary summary (unchanged role).
- `Support/Package/Schema/Eigenverft.Manifested.Package.Package.Config.Aggregation.ps1` - new log path in `PackageConfig`.
- `Commands/Module/Eigenverft.Manifested.Package.Cmd.Module.ps1` - new guide command (parallel to authoring).
- New `AgentSkills/PackageAssignmentOperability.md`.
- `Eigenverft.Manifested.Package.psd1` exports and tests.

May Influence:
- README troubleshooting and hybrid docs failure chapter.
- Future **Manifested Manager** drift explanation (reads same logs/state; does not replace them).
- Agent skills repo-wide (operability skill beside authoring skill).

Dependencies:
- `OperationId` and `OperationStartedAtUtc` on `PackageResult` (shipped).
- Choose log path and entry schema in **Open Decisions** before broad test fixtures.

### 🎯 Required Outcome

1. Every `Invoke-Package` and materialize-only path produces a **durable execution log** keyed by `operationId` with structured entries (`category`, `level`, `atUtc`, optional `stepName` / `definitionId`).
2. **Console output is cleaner** - presentation separated from persisted structure; tags parsed into `category` instead of duplicated noise in message bodies.
3. Exported **`Get-PackageAssignmentOperabilityGuide`** loads `AgentSkills/PackageAssignmentOperability.md`, evaluates last/failed operation context, prints `AgentAction:` and artifact paths (mirror authoring guide).
4. Exported **`Get-PackageExecutionLog`** reads logs by `-OperationId`, `-Last`, `-LastFailed`, `-Raw`.
5. Product rule documented: repair stays **propose-first**; execution only via existing trusted commands ([PRODUCT-BOUNDARY.md](PRODUCT-BOUNDARY.md), `/agsp` C-20).
6. Tests: log written on success and failure; multi-root entries tagged; guide emits `AgentAction` on simulated failed run.

### 🔎 Facts

Known:
- **Live trace only (verified):** `Write-PackageExecutionMessage` in `Package.ExecutionMessage.ps1` writes to `Write-StandardMessage` when present, else `Write-Host ("[{0} {1}] {2}" -f $timestamp, $resolvedLevel, $Message)` with UTC timestamp prefix - console only, no file tee.
- **Message vocabulary (verified):** lifecycle code emits `[STEP]`, `[STATE]`, `[OUTCOME]`, `[ACTION]`, `[DECISION]`, `[FAIL]`, `[WARN]` via `Write-PackageExecutionMessage` (e.g. `Package.CommandFlow.ps1`, `Cmd.InvokePackage.ps1`, `Package.Install.ps1`, `Package.Selection.ps1`).
- **Assigned flow steps (verified):** `Invoke-PackageAssignedFlow` defines named steps `ResolvePackage`, `ResolveDependencies`, `BuildAcquisitionPlan`, `AssignPackage`, etc. (`Package.CommandFlow.ps1`); failures set `CurrentStep` / `failedStep` passed to history.
- **Operation identity (verified):** `OperationId` (`[guid]::NewGuid().ToString('n')`) and `OperationStartedAtUtc` set on `PackageResult` in `Invoke-PackageDefinitionCommandCore` (`Package.CommandFlow.ps1`), dependency plan nodes (`Package.DependencyPlan.ps1`), and early failure paths (e.g. local env init failure).
- **Operation history (verified):** `Get-PackageOperationHistory` / `Add-PackageOperationHistoryRecord` in `Package.OperationHistory.ps1` - **internal** helpers, not exported. Path: `PackageConfig.PackageOperationHistoryFilePath` (default `{applicationRootDirectory}/State/PackageOperationHistory.json` in test helpers). Schema: `schemaVersion: 1`, `records[]` with rich summary (`failedStep`, `failureReason`, `dependencies`, `packageFilePreparation`, etc.) - **one record per completed definition invocation**, appended after flow completes.
- **Public state (verified):** `Get-PackageState` (`Cmd.GetPackageState.ps1`) loads operation history into summary view and `-Raw`; calls `Write-PackageStateFormattedView` for human output. **No execution step log** in state object today.
- **Authoring guide pattern (verified):** `Get-PackageDefinitionAuthoringGuide` loads `AgentSkills/PackageDefinitionAuthoring.md`, runs `Get-PackageAuthoringTargetEvaluation`, emits task preface, `AgentAction:`, `TroubleshootingKind:`, endpoint table (`Cmd.Module.ps1`). Test: `Package.ExportsAndState.Tests.ps1` - "includes task preface and authoring skill header".
- **Agent skills shipped:** only `AgentSkills/PackageDefinitionAuthoring.md` under module project root (resolved relative to `Cmd.Module.ps1`).
- **Exported commands (verified):** **38** functions in `Eigenverft.Manifested.Package.psd1`; **none** named `*Operability*`, `*ExecutionLog*`, `Explain-PackageState`, or `Repair-PackageAssignment*`.
- **PR-03 shipped:** idempotent `Invoke-Package` and `[OUTCOME]` vocabulary exist (`/agsp` 02_FRAME) - rerun is often the repair, but **finding why** still needs better artifacts.
- **Multi-root invoke (verified):** `Invoke-Package` plans dependencies once, iterates roots (`Cmd.InvokePackage.ps1`); operation history is **per definition result**, not one envelope with step stream - execution log design must clarify one log file per top-level `operationId` vs per-root (see Open Decisions).
- **Local environment dirs (verified):** `Initialize-PackageCommandLocalEnvironment` ensures parent of `PackageOperationHistoryFilePath` exists (`Package.LocalEnvironment.ps1`) - pattern for new log directory creation.
- **`PRODUCT-BOUNDARY.md`:** background agents mutating state without explicit `Invoke-Package` are out of scope; clean state primitives for future Manager - operability fits **expose state/logs**, not fleet dashboards.

Unknown:
- Exact log directory name under state root (`Logs/Operations/` vs sibling of `State/`).
- Whether one log envelope covers full multi-root `Invoke-Package` call or one log per root definition.
- Retention policy for log files (prune vs keep all in v1).
- Whether console polish ships in same PR as log persistence or immediately after.

### Codebase reference (evaluation)

| Area | Path / symbol | Today | Option A | Option B | Option C |
| --- | --- | --- | --- | --- | --- |
| Live messages | `Write-PackageExecutionMessage` | Console only | Tee to JSON log + polish console | Unchanged | Unchanged |
| Step names | `Package.CommandFlow.ps1` flows | In-memory `CurrentStep` | Captured in log entries | Not persisted | Read from scrollback only |
| Summary history | `Package.OperationHistory.ps1` | Post-hoc JSON row | Complementary; link by `operationId` | Primary artifact (weak) | Input to aggregators |
| State read | `Get-PackageState -Raw` | History + inventories | Plus log path hints via guide | Guide only | Heavy rollup cmds |
| Agent entry | `Get-PackageDefinitionAuthoringGuide` | Authoring only | Sibling operability guide cmd | New guide, no log cmd | Explain + Repair cmds |
| Log read | (none exported) | N/A | `Get-PackageExecutionLog` | Agent parses console | Embedded in Explain |
| Agent skill | `PackageDefinitionAuthoring.md` | Definitions | `PackageAssignmentOperability.md` | Operability skill only | Extended skill |
| Config | `Package.Config.Aggregation.ps1` | History path only | + execution log root/path | No config change | + aggregator inputs |
| Tests | `Package.ExportsAndState.Tests.ps1` | Authoring guide | + log + operability guide | Skill text tests | Aggregator tests |

**Operability constraints from shipped behavior (must respect in design):**
- Do not replace `PackageOperationHistory.json`; agents read **log for narrative**, **history for summary**, **state for inventories**.
- Propose-first repair must not auto-run `-AcceptUnknownSigningKey` or background `Invoke-Package`.
- Multi-root partial failure: `-FailFast` vs continue affects which roots appear in one session - log must record enough context to explain partial success.

---

### 🧩 Options

#### Option A - Persisted execution log, console polish, operability guide, and log read command (Implementation Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🟢 Full | ▰▰▰▰▰ | closes SC-08 / PR-12 for v1 |
| 🛠 Option Effort | 3/4 Substantial | ▰▰▰▱ | log schema, tee, two cmds, skill |
| 🧠 Option Complexity | 3/5 Complex | ▰▰▰▱▱ | operation scope threading at tee point |
| 🔮 Future Impact | 🟢 -1 Improves | ▰▰▱▱▱ | base for Explain/Repair later |
| ↩️ Reversibility | 🟡 Moderate | ▰▰▱▱ | new files on disk; public cmds |
| 🧬 Integration | 🟢 Compatible | - | mirrors authoring guide pattern |
| 🤖 Agent Difficulty | 2/4 Guided | ▰▰▱▱ | bounded cmds plus skill doc |
| 🧾 Agent Work | 💻 Local Code | - | engine tee plus agent skill |

Description:
Extend `Write-PackageExecutionMessage` to append structured entries to a per-`operationId` JSON log under package state. Polish console formatting (timestamp/level as fields, not embedded in message text). Ship `Get-PackageAssignmentOperabilityGuide` + `AgentSkills/PackageAssignmentOperability.md` and `Get-PackageExecutionLog`. Defer `Explain-PackageState` / `Repair-PackageAssignmentPlan` until dogfood proves need.

Current State:
Agents and operators depend on terminal scrollback or reading engine source. `Get-PackageState -Raw` helps but lacks step narrative.

Resulting State:
Failed assign produces a durable, agent-readable log. Agent runs operability guide, reads log and state, proposes trusted next commands.

Solves:
- SC-08 failure recovery without engine source.
- Agent diagnosis axis from IDEA §4-5.
- Ugly console output improved for humans.

Leaves Open:
- Optional aggregators (`Explain-PackageState`, `Repair-PackageAssignmentPlan`).
- Log retention and rotation policy.
- Fleet-wide log collection (Manager).

Risks:
- Tee overhead on every message (mitigate: append JSON lines or buffered write).
- Operation context must be available inside `Write-PackageExecutionMessage` (may need scoped context object).

Later Cost:
- Low if Explain/Repair reuse same log schema.

---

#### Option B - Operability guide and skill only without persisted log (Reframed Implementation Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🟡 Partial | ▰▰▰▱▱ | skill without durable trace |
| 🛠 Option Effort | 1/4 Trivial | ▰▱▱▱ | skill plus thin guide cmd only |
| 🧠 Option Complexity | 2/5 Normal | ▰▰▱▱▱ | no tee or schema work |
| 🔮 Future Impact | 🟠 +1 Adds Debt | ▰▰▰▱▱ | scrollback dependency remains |
| ↩️ Reversibility | 🟢 Easy | ▰▱▱▱ | docs and cmd only |
| 🧬 Integration | 🟡 Temporary | - | incomplete operability loop |
| 🤖 Agent Difficulty | 1/4 Routine | ▰▱▱▱ | mostly writing |
| 🧾 Agent Work | 📝 Writing / Docs | - | skill without log artifact |

Description:
Ship `PackageAssignmentOperability.md` and `Get-PackageAssignmentOperabilityGuide` that instruct agents to read `Get-PackageState -Raw`, operation history, and **saved console output**. No log persistence, no `Get-PackageExecutionLog`, no console polish.

Current State:
Same as issue statement.

Resulting State:
Documented workflow exists but still fails when terminal output is lost.

Solves:
- Fast documentation win.
- Establishes `AgentAction:` pattern for failures.

Leaves Open:
- Durable diagnosis (C-19 violated in practice).
- Reliable CI/agent pipeline recovery.

Risks:
- Appears shipped while core gap remains.
- Agents hallucinate steps without log facts.

Later Cost:
- Must add Option A anyway; throwaway skill sections referencing scrollback.

---

#### Option C - Ship Explain-PackageState and Repair-PackageAssignmentPlan in v1 (Implementation Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🟢 Full | ▰▰▰▰▰ | rich diagnosis surface |
| 🛠 Option Effort | 4/4 Major | ▰▰▰▰ | aggregators plus log plus rules engine |
| 🧠 Option Complexity | 4/5 Hard | ▰▰▰▰▱ | repair rules across trust/depot/acquire |
| 🔮 Future Impact | 🟠 +1 Adds Debt | ▰▰▰▱▱ | rules drift without log dogfood |
| ↩️ Reversibility | 🟠 Hard | ▰▰▰▱ | public repair contract |
| 🧬 Integration | 🟡 Temporary | - | risks duplicating skill logic in code |
| 🤖 Agent Difficulty | 3/4 Strong | ▰▰▰▱ | rule matrix needs careful review |
| 🧾 Agent Work | 🔌 Integration | - | large cmd surface in one release |

Description:
Deliver Option A plus deterministic `Explain-PackageState` and `Repair-PackageAssignmentPlan` commands that encode troubleshooting rules in PowerShell instead of primarily in the agent skill.

Current State:
No aggregators; IDEA names only.

Resulting State:
Module emits repair plans without agent LLM for common failures.

Solves:
- Deterministic repair suggestions for known failure kinds.

Leaves Open:
- Long tail of novel failures still need agent reasoning.

Risks:
- Duplicates agent skill maintenance in code.
- Repair cmd tempted to auto-execute (boundary violation).
- Ships before log format is proven.

Later Cost:
- High rework when log schema or supply-chain skip reasons change.

---

#### Option D - Defer operability to Manifested Manager only (Reject Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🔴 Reject | ▱▱▱▱▱ | no local failure recovery product |
| 🛠 Option Effort | 0/4 N/A | ▱▱▱▱ | no delivery in engine |
| 🧠 Option Complexity | 1/5 Simple | ▰▱▱▱▱ | wait for separate product |
| 🔮 Future Impact | 🟠 +1 Adds Debt | ▰▰▰▰▱ | solo devs stuck until Manager |
| ↩️ Reversibility | 🟢 Easy | ▰▱▱▱ | can reopen later |
| 🧬 Integration | 🔴 Conflicting | - | Manager not shipped |
| 🤖 Agent Difficulty | 1/4 Routine | ▰▱▱▱ | no work now |
| 🧾 Agent Work | 🧩 Planning / Structuring | - | defer only |

Description:
Do not add execution logs or operability commands to the package engine. Assume future **Manifested Manager** will collect logs and explain drift across hosts.

Current State:
Local operators lack diagnosis artifacts.

Resulting State:
Unchanged until Manager ships.

Solves:
- Avoids engine scope debate short term.

Leaves Open:
- Every local failed assign without Manager deployment.
- Agent operability axis from IDEA unfinished.
- PRODUCT-BOUNDARY asks for understandable state/logs on the engine.

Risks:
- Manager inherits undefined log primitives.
- Agent product story is "author definitions" only, not "recover assigns."

Later Cost:
- Manager must retrofit log format under pressure.

---

### 💶 Value Assessment

- 💎 Value Type: 🧭 User Experience Improved · 📡 Operability Improved · 🔁 Rework Avoided
- 🧭 Value Direction: 🚀 Opportunity / Improvement
- 🧾 Value Mechanism: Gives agents and operators the same **artifact loop** catalog authoring already has: deterministic runtime facts → guide command → skill → propose next trusted action. Removes scrollback and engine-source dependency for failure recovery without fleet features or auto-repair.
- ⚖️ Option Value Summary:
  - Option A - Persisted execution log, console polish, operability guide, and log read command (Implementation Option)
    - 🧭 Resolution: 🟢 Full ▰▰▰▰▰
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
    - 🔮 Future Impact: 🟢 -1 Improves ▰▰▱▱▱
    - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
    - 🧾 Decision Note: Complete v1 operability loop; mirrors shipped authoring pattern.
  - Option B - Operability guide and skill only without persisted log (Reframed Implementation Option)
    - 🧭 Resolution: 🟡 Partial ▰▰▰▱▱
    - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt ▰▰▰▱▱
    - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
    - 🧾 Decision Note: Too thin; violates C-19 intent (no scrollback dependency).
  - Option C - Ship Explain-PackageState and Repair-PackageAssignmentPlan in v1 (Implementation Option)
    - 🧭 Resolution: 🟢 Full ▰▰▰▰▰
    - 🛠 Option Effort: 4/4 Major ▰▰▰▰
    - 🧠 Option Complexity: 4/5 Hard ▰▰▰▰▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt ▰▰▰▱▱
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧾 Decision Note: Premature; build log + skill first, aggregators after dogfood.
  - Option D - Defer operability to Manifested Manager only (Reject Option)
    - 🧭 Resolution: 🔴 Reject ▱▱▱▱▱
    - 🛠 Option Effort: 0/4 N/A ▱▱▱▱
    - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt ▰▰▰▰▱
    - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
    - 🧾 Decision Note: Manager needs engine log primitives; local users cannot wait.
- ✅ Good Result: After a failed `Invoke-Package`, an agent runs `Get-PackageAssignmentOperabilityGuide`, reads `Get-PackageExecutionLog -LastFailed`, explains what failed and why using structured entries, and proposes numbered repair commands (trust import, depot fix, rerun) without reading engine source or saved terminal scrollback.

---

### 🏁 Recommendation

- [2026-06-07 20:00 | Author: Composer | Recommendation: Choose Option A | Support: 3/3 Well Supported ▰▰▰]

Reasoning:
Option A delivers the full operability loop the product compass already committed to (PR-12, C-19-C-20) using the proven authoring-guide pattern. Option B is fast but leaves the durable log gap - agents cannot reliably diagnose without scrollback. Option C front-loads repair aggregators before the log format and skill are dogfooded. Option D correctly avoids fleet creep but wrongly delays **local** diagnosis primitives the Manager will need anyway.

Required Checks:
- Force a failed `Invoke-Package` (e.g. unknown definition or blocked trust) and confirm a log file appears under the configured execution-log path with `operationId` matching the operation-history record.
- Confirm log entries include `category` parsed from `[STEP]` / `[FAIL]` prefixes and optional `stepName` on failure paths exercised in tests.
- Run `Get-PackageAssignmentOperabilityGuide -AfterFailedInvoke` (or equivalent switch) and assert output contains `AgentAction:` and path to last failed log (mirror authoring guide tests).
- Run `Get-PackageExecutionLog -LastFailed` and assert formatted output is readable without raw `[yy-MM-dd HH:mm:ss INF]` prefixes inside message bodies.
- Multi-root invoke with `-FailFast`: log shows which root failed; without `-FailFast`, log reflects partial success across roots.
- New exports appear in `Eigenverft.Manifested.Package.psd1`; no `Explain-PackageState` / `Repair-PackageAssignmentPlan` in v1 unless explicitly reopened.

### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: 🧑‍💼 Product Management · 🔧 Engineering · 👥 Customer / User Representative
- 🗣 Communication Lens: 🧑‍💼 Product Summary
- 📬 Success Note: When package assignment fails, users and agents get a clear persisted trace and a single guide command - the same way definition authoring already works. Recovery stays explicit and safe: review the log, follow proposed trusted commands, rerun assign. No silent auto-fix and no fleet product required.

### ✅ Resolved Decisions

- **Product type** - operability / failure recovery is an **agent product feature**, filed as this issue (not a separate FEATURE doc).
- **Diagnosis input** - agents read **persisted execution logs** plus state/history; not console scrollback (`/agsp` C-19).
- **Repair execution** - propose-first only; trusted existing commands (`/agsp` C-20).
- **Authoring parallel** - `Get-PackageAssignmentOperabilityGuide` + `AgentSkills/PackageAssignmentOperability.md` mirror `Get-PackageDefinitionAuthoringGuide` pattern.

### ❓ Open Decisions

- Log directory path under package state root?
- One log envelope per top-level `Invoke-Package` call vs per-root definition log?
- Log retention: keep all in v1 vs prune last N?
- Exact parameter names on guide (`-AfterFailedInvoke` vs `-LastFailed`)?
- Ship console polish in same phase as log tee or immediately after?

### 🚫 Out of Scope

- Fleet-wide log aggregation, Manager dashboards, cross-machine drift reporting.
- Automatic repair execution, background retry, or agent-driven `Invoke-Package` without human/CI approval.
- LLM or external AI inside the module.
- Replacing `PackageOperationHistory.json` summary role.
- `Explain-PackageState` / `Repair-PackageAssignmentPlan` in v1 (Option C - extracted work).
- Changing install semantics, trust policy, or dependency planner behavior.

### 🌱 Extracted Work

Optional:
- [ ] **`Explain-PackageState` deterministic aggregator** (IDEA §4)
  Reason: After log + guide dogfood; rolls up state + last log + history for agents.
- [ ] **`Repair-PackageAssignmentPlan` rule-based proposals** (IDEA §5)
  Reason: After common failure kinds are observed in persisted logs.
- [ ] **Log retention / prune command**
  Reason: If disk usage matters on long-lived dev machines.
- [ ] **`Invoke-Package -Quiet` console verbosity**
  Reason: Separate UX polish once structured log is primary diagnostic surface.

---
