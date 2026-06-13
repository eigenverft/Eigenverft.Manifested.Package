# 08_REVIEW

## Review Against North Star

```text
Partial
Notes: Core assign/discover/state path supports "minutes to productive." Agent authoring
loop dogfooded (SC-05 / PR-08 core, F-09). Gaps: no cooling on auto-selection (PR-06),
no offline bundled guide (PR-02), ownership opaque for team authors (SC-02).
Stakeholder-lens pass adds missing pre-mutation clarity: no structured assignment
preflight exists yet (SC-09 / PR-13).
```

## Scenario Fit

| Scenario | Fit | Gap |
|----------|-----|-----|
| SC-01 Fresh profile | Partial | Silent latest pick risk until supply chain |
| SC-02 Team share | Partial | Works technically; learnability weak |
| SC-03 Corporate bootstrap | Pass | Documented exception path |
| SC-04 Isolated network | Partial | Intent strong; operator must understand acquire vs selection |
| SC-05 Agent catalog | Partial | Authoring guide + skill dogfooded; workbench deferred (PQ-05) |
| SC-06 Discover → assign | Pass at 18 defs | Scale path open |
| SC-07 Role onboarding | Fail | Issue filed; no example profiles shipped yet |
| SC-08 Failure recovery | Fail | Console-only trace; operation history summary-only; no operability guide |
| SC-09 Review before assign | Fail | No exported read-only assignment plan/preflight surface |

## Review Against Product Requirements

| ID | Status |
|----|--------|
| PR-01–05, PR-07 | Pass (shipped) |
| PR-06, PR-09, PR-10 | Partial |
| PR-08 | Partial (core shipped and dogfooded; workbench not required for v1) |
| PR-11 | Open (wrk issue; Option A chosen, not delivered) |
| PR-12 | Open (wrk issue; execution log + guide cmd not delivered) |
| PR-13 | Open (wrk issue; assignment preflight not delivered) |
| PR-02 | Fail for Gallery-only offline guide |

## Failure Modes (trust destroyers)

```text
- Newest version assigned on next run without operator awareness
- Unexpected public network during expected-offline assign
- Removal of software user did not opt into via inventory
- Depot sync folders full of temp/sidecar clutter
- AI-generated def installed without validation/review
- Engine grows fleet/orchestration features → boundary collapse
- Assign fails with no durable step log → agent/human cannot recover without engine source
- User runs a profile or team endpoint without seeing dependency/trust/depot consequences first
```

## Review Against Guardrails / Constitution

```text
Pass (shipped behavior). Risk: future features (HTTPS, supply chain) must not violate C-09, C-07, GR-05.
```

## Revision Needed

```text
Major for product completeness — not for /agsp archive quality.
Next product judgment: does P5 supply chain close SC-01/PR-06 without hurting S01 first-run story?
Stakeholder-lens judgment: PR-13 assignment preflight is the missing "before mutation"
counterpart to PR-12 operability "after failure"; add it as P4 because it serves every S01-S08 lens.
Profile track (PR-11) should stay artifact-only — guard against C-06 violation via Invoke-PackageProfile in v1.
Operability track (PR-12) should tee logs at Write-PackageExecutionMessage — avoid parallel ad-hoc logging paths.
Agent scale is rounded: semi-manual workflows (C-21, T-11); extend authoring pattern to profiles and operability — not unattended fleet automation.
```
