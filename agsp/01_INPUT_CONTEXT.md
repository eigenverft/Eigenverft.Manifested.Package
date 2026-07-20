# 01_INPUT_CONTEXT

## Current Trigger

```text
Stakeholder-lens AGS-P pass: inspect product through S01-S08, not only archive quality.
Blindspot found: no read-only assignment preflight before Invoke-Package mutation.
Add ISSUE-ASSIGNMENT-PREFLIGHT and sync compass with SC-09/PR-13/C-22/T-12.
```

## Operating Mode

```text
Revision Mode — stakeholder pass changed product frame and backlog
```

## Available Context

```text
Canonical product scope: src/wrk/.../PRODUCT-BOUNDARY.md
Issue detail & delivery: src/wrk/.../TODO-*.md, PROJECT-ISSUE-FRAMEWORK V1.8
Shipped runtime: src/prj/... (schema 1.9, 18 defs, Search-Package, trust, depots, state)
Agent model: PRODUCT-BOUNDARY — agents/LLMs maintain package JSON; deterministic validation and review before trusted install
New issue: ISSUE-ASSIGNMENT-PREFLIGHT — plan before mutation
```

## Explicit Instructions

```text
Use AGS-P to support product judgment from every stakeholder lens.
Change any AGS-P point if the product needs a more important next step.
```

## Implied Work

```text
- Review S01-S08 one by one for missing product capabilities
- Add read-only assignment preflight as cross-stakeholder need
- Keep preflight local/explicit so it does not become Manager/fleet policy
- Connect preflight to profiles, isolated operation, security review, agent artifacts, and future maintainer clarity
```

## Ambiguities

```text
- Profile artifact format (JSON vs markdown) — open in wrk issue, not blocking compass
- Whether 7-day release-age cooling is acceptable to primary users (unchanged)
- When ~200-definition manifest trigger will matter in production (unchanged)
- Preflight command name and depth of depot/offline checks
```
