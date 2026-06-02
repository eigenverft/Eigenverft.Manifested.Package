# Decision — Keep `artifacts` / `targetArtifacts` on wire 1.8

**Status:** Draft — not product sign-off (see [TODO-INDEX.md](TODO-INDEX.md))  
**Date:** 2026-05-30  
**Recorded from:** closed wrk issue (Choose Option A) — see [DECISIONS.md](DECISIONS.md)

## Decision

Keep top-level **`artifacts`** and per-release **`targetArtifacts`** on wire **1.8** until a future breaking schema version. Do not rename in the shipped catalog or runtime without a planned schema break.

## Rationale

- All **18** shipped definitions already use this vocabulary successfully.
- Rename would touch schema, wire asserts, acquisition helpers, every definition, and tests — high cost for speculative benefit.
- `artifactsByTarget` remains rejected at validation time; authors must use `targetArtifacts`.

## Reopen when

- A new package kind cannot be modeled clearly under `artifacts` / `targetArtifacts`, or
- A schema break (1.9+) is scheduled and rename migration is in scope.

## Out of scope

- Implementing rename or migration tooling in this decision.
