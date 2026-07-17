# Ownership and installer adoption guide

**Status:** Open documentation work; runtime behavior is shipped
**Priority:** 3/7 Low
**Recommendation:** Document the existing policy before adding new engine behavior.

## Shipped foundation

Schema 2.0 and the install/remove engine already support:

- `allowAdoptExternal`;
- `upgradeAdoptedInstall`;
- `requirePackageOwnership`;
- existing-install discovery;
- reuse, adoption, replacement, ignore, and inventory-safe removal decisions;
- `[DECISION]`/`[OUTCOME]` messages and ownership lifecycle tests.

The LLM authoring guide names `ownershipPolicy`, but it does not yet teach the decision matrix or removal consequences.

## Remaining contract

1. Add one author/operator guide mapping the three policy flags to existing-install state, `Assigned.Status`, ownership kind, upgrade behavior, and removal eligibility.
2. Use concrete MSI, NSIS, PowerShell-module, and package-file examples from the shipped catalog where applicable.
3. Explain package-owned versus reused/adopted external installs and when removal must refuse mutation.
4. Align schema descriptions and `PackageDefinitionAuthoring.md` with the guide without duplicating engine logic.
5. Add focused catalog warnings only for combinations proven to be ambiguous; avoid speculative lint rules.

## Open decisions

- Whether this ships first as an authoring-guide section or as part of the hybrid documentation set.
- Which ownership combinations warrant warnings rather than documentation.

## Out of scope

- Rewriting existing-install or installer engines without a demonstrated bug.
- Uninstalling untracked external software.
- Changing dependency planning.

## Acceptance

An author can predict reuse, adoption, replacement, and removal behavior from the definition without reading engine source or tests.
