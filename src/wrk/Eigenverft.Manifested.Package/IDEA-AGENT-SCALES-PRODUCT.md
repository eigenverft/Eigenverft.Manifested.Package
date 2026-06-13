# IDEA: Agent Scales The Product By Scaling The Catalog

Source: external AI conversation reviewed on 2026-06-03.
Status: idea note. Onboarding → [ISSUE-ONBOARDING-PROFILES.md](ISSUE-ONBOARDING-PROFILES.md). Operability → [ISSUE-AGENT-OPERABILITY.md](ISSUE-AGENT-OPERABILITY.md).

## Take

I agree with the core thesis:

> The agent should scale catalog work, validation, trust preparation, onboarding, and diagnosis. The local engine should stay small, deterministic, and trust-bound.

This fits the current product boundary better than an "agent daemon" or fleet autopilot. Eigenverft.Manifested.Package should remain the local execution and trust layer. Agents should produce reviewable artifacts around it.

Short formula:

> Local deterministic engine + agentic catalog operations = scalable team provisioning.

## Why It Fits

- `PRODUCT-BOUNDARY.md` already says package JSON should be maintainable by agents, then validated and reviewed before it becomes trusted catalog content.
- The module already centers reviewable package-definition JSON, signed definitions, trust inventory, endpoints, depots, local state, and operation history.
- `Test-PackageDefinitionCatalog` now gives agents a deterministic pre-install validation command.
- Shipped `Get-PackageDefinitionAuthoringGuide` and `PackageDefinitionAuthoring.md` capture the first concrete slice for external package-definition agents.

## Useful Product Principle

Agent creates reviewable artifacts. Engine executes trusted artifacts.

Good agent outputs:

- package-definition JSON drafts
- package-definition review notes
- validation reports
- signing requests
- update PRs
- onboarding profile recommendations
- state and drift explanations

Bad fit:

- a central always-on agent that mutates many machines
- automatic trust of unknown signing keys
- automatic signing of semantic JSON changes without review
- generic pre-install or post-install script hooks

## Ideas Worth Keeping

### 1. Package Definition Authoring

This immediate task has shipped:

- `Get-PackageDefinitionAuthoringGuide`
- `PackageDefinitionAuthoring.md`

The agent skill guides unsigned draft -> validate -> sign -> verify -> human review -> publish.

### 2. Catalog Maintenance Workbench

Future maintainer-facing tools could help agents generate update PRs without changing install semantics.

Candidate capabilities:

- compare a shipped package definition against a new upstream version
- update hashes and artifact metadata
- produce a review markdown summary
- run `Test-PackageDefinitionCatalog`
- request signing, but not silently trust or sign

Possible future command names, not commitments:

- `New-PackageDefinitionDraft`
- `Compare-PackageDefinitionVersion`
- `New-PackageDefinitionReview`

### 3. Onboarding Profiles

Agents can turn team roles into explicit `DefinitionId` sets.

Examples:

- `.NET backend dev`
- PowerShell maintainer
- local AI runtime
- frontend dev

This should probably produce a reviewable profile document or command recommendation first, not a new runtime manager.

Possible future command name, not a commitment:

- `New-PackageOnboardingProfile`

### 4. State And Drift Explanation

**Scheduled:** [ISSUE-AGENT-OPERABILITY.md](ISSUE-AGENT-OPERABILITY.md) — persisted execution log + `Get-PackageAssignmentOperabilityGuide` / `Get-PackageExecutionLog` before optional `Explain-PackageState`.

The module already has local state and operation history. An agent can explain that state without changing it. Today the **step narrative** lives only on the console (`Write-PackageExecutionMessage`); operation history is a **summary row** per run — not enough for reliable agent diagnosis.

Useful questions:

- What is assigned?
- What is missing?
- What was repaired or reused?
- Which dependency caused this install?
- Which package owns this PATH entry or install slot?

Possible future command name, not a commitment:

- `Explain-PackageState`

### 5. Repair Planning

**Depends on** execution log + operability guide (feature track above). Repair planning without a durable log forces console scrollback or engine source — not product-grade.

The agent can propose a repair plan from state, validation, endpoint facts, and **execution log entries**.

Important boundary:

- propose first
- make the plan reviewable
- execute only through existing trusted commands such as `Invoke-Package`

Possible future command name, not a commitment:

- `Repair-PackageAssignmentPlan`

## What I Would Not Do

- Do not make this product a fleet orchestrator.
- Do not add a background update daemon.
- Do not let agents automatically accept unknown signing keys.
- Do not make live upstream metadata part of deterministic install selection unless a future issue explicitly decides that boundary.
- Do not hide agent decisions inside opaque generated scripts.

## Suggested Next Step

Keep the first implementation small:

1. Keep dogfooding `PackageDefinitionAuthoring.md` with real package-definition changes.
2. Capture recurring agent-catalog maintenance pain as concrete TODOs.
3. Only then decide whether "Catalog Maintenance Workbench" deserves a formal issue.
