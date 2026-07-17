# Assignment preflight

**Status:** Shipped
**Priority:** 4/7 Normal
**Delivered:** Exported the read-only `Get-PackageAssignmentPlan` surface.

## Gap

`Invoke-Package` plans dependencies before assignment or materialization, but users cannot inspect that effective plan through a public read-only command. `Search-Package` describes individual definitions; it is not a multi-root execution preview.

## Reuse the shipped engine

- definition winner, schema, trust, target, release, and version resolution;
- `New-PackageDependencyPlan` and its conflict/version-range checks;
- artifact-file acquisition plans and depot configuration;
- assignment inventory and existing-install decisions.

Do not build a parallel resolver.

## Delivered contract

`Get-PackageAssignmentPlan`:

1. Accept the core selection inputs from `Invoke-Package` (`DefinitionId`, optional `PublisherId`, `PackageVersion`, `Offline`, and an assignment/materialization mode).
2. Return roots, dependency nodes/edges, selected versions/targets, definition trust, source/depot feasibility, existing assignment/adoption state, warnings, blockers, and the exact next command.
3. Perform no downloads and write no trust, state, history, depot, endpoint, staging, or installation data.
4. Use a stable structured result suitable for humans, onboarding-profile validation, and agent review.
5. Prove planning parity with the plan consumed by `Invoke-Package`.

## Resolved decisions

- The command is `Get-PackageAssignmentPlan`.
- Online planning checks presence by default and hashes depot content with `-VerifyDepotContent`; offline planning always verifies.
- Assignment and materialize-only planning are shipped; removal remains out of scope.
- One multi-root envelope contains root summaries and a shared deduplicated graph.

## Out of scope

- Executing the returned plan.
- Trusting unknown signing keys.
- Downloading during preflight.
- Fleet policy, automatic repair, or compliance enforcement.
- Treating `Invoke-Package -WhatIf` text as the structured plan contract.

## Acceptance

- The command is demonstrably mutation-free.
- The same inputs produce the same selections and dependency verdict as `Invoke-Package`.
- Offline blockers and trust decisions are visible before invocation.
