# Agent operability

**Status:** Open
**Priority:** 3/7 Low
**Recommendation:** Persist structured execution logs, then expose log and guide commands.

## Gap

`Write-PackageExecutionMessage` provides the ordered step narrative only on the console. `PackageOperationHistory.json` preserves useful per-definition summaries, including failures, but not the complete `[STEP]`, `[STATE]`, `[ACTION]`, and `[OUTCOME]` sequence after the terminal closes.

## Reuse the shipped engine

- `OperationId` and operation timestamps on results;
- the execution-message choke point;
- operation-history summaries and `Get-PackageState`;
- the packaged authoring-guide command/skill pattern.

Operation history remains the summary source; execution logs add the narrative rather than replace it.

## Remaining contract

1. Persist structured entries keyed by operation ID with timestamp, level, category, message, and optional step/definition context.
2. Cover success, failure, materialize-only, dependencies, multi-root continuation, and `-FailFast`.
3. Export `Get-PackageExecutionLog` with operation-ID, last, last-failed, formatted, and raw access.
4. Export `Get-PackageAssignmentOperabilityGuide` backed by `AgentSkills/PackageAssignmentOperability.md` and resolved paths/context.
5. Keep repair propose-first: the guide may recommend existing trusted commands but never execute them.
6. Separate structured categories from console decoration so persisted data does not contain presentation noise.

## Open decisions

- One log for the top-level multi-root call or one per root with a correlation ID.
- Log directory and JSON document versus JSON-lines format.
- Retention policy; keeping all is acceptable for the first version if documented.
- Whether console formatting ships in the same change.

## Deferred until logs are proven

- `Explain-PackageState` aggregation.
- `Repair-PackageAssignmentPlan` rule-based proposals.
- Log pruning and `Invoke-Package -Quiet`.

## Out of scope

- Fleet log collection or dashboards.
- Automatic repair, background retry, or automatic trust.
- An LLM embedded in the module.
- Changes to install, trust, or dependency semantics.

## Acceptance

A failed invocation remains diagnosable after the console closes using the persisted log, operation history, state, and a single operability-guide entry command.
