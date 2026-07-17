# PRODUCT BOUNDARY

## Purpose

Eigenverft.Manifested.Package is a Windows-focused package-assignment engine for one machine or one user profile.

Its job is to make developer-tool setup repeatable through trusted package definitions, local state, reusable depots, configurable endpoints, and explicit package assignment.

The product should feel like a small, reliable package engine, not like a central fleet manager.

The market position is between public package managers such as WinGet/Scoop and heavy enterprise endpoint management. The product should be easier for teams to own than enterprise configuration management, but more governed and repeatable than ad-hoc install scripts or public community buckets.

AI-scalable catalog growth is a main product feature: package JSON should be maintainable by LLMs and agents, then validated and reviewed before it becomes trusted catalog content.

## Primary Users

- A developer who wants a fresh Windows user profile to become useful in minutes.
- A maintainer who wants shipped package definitions for common development tools.
- A team endpoint owner who wants to share package definitions and depots through a file share.
- A security-conscious operator who wants explicit signing-key trust, hashes, local inventory, and predictable package ownership.
- An agent or human package author who wants a schema that is strict enough to avoid ambiguous live releases.
- An Eigenverft catalog maintainer who wants an online endpoint to carry the growing package catalog outside the module.
- An industrial or isolated-network operator who needs packages to come from a controlled internal endpoint and depot.

## Product Shape

- Package definitions are explicit, versioned, and reviewable JSON.
- Package assignment is local and inventory-backed.
- Package depots are file-based and sync-friendly.
- Team endpoints and depots are first-class distribution channels.
- Online package endpoints are the main extension point for large catalogs, including an Eigenverft endpoint and team-owned endpoints.
- The module should ship a useful core set, not every possible package definition.
- Package installs should be repeatable, explainable, and safe to rerun.
- Package-owned installs should be easy to remove when they are tracked in inventory.
- External installs may be discovered and adopted only when the package definition clearly allows it.
- Offline or depot-backed behavior is a core strength, not an afterthought.
- Network-isolated use cases should be able to fail closed instead of unexpectedly reaching for public internet sources.
- Schema changes are allowed while the product is still shaping itself, but the schema should become simpler and clearer over time.

## What This Is Not

- Not a central enterprise package manager.
- Not a fleet-wide rollout controller.
- Not a replacement for WinGet, Scoop, Chocolatey, Intune, or ConfigMgr.
- Not a public community app store.
- Not a background auto-update service.
- Not a hidden global machine mutator.
- Not a generic installer wrapper where every installer behavior is accepted without ownership and removal rules.
- Not a package catalog that silently trusts latest upstream releases.
- Not a manifest format that allows arbitrary pre-install or post-install scripts for convenience.

## Important Boundaries

- Keep the default mental model local: one user profile, one package assignment inventory.
- Keep package ownership explicit: installed, reused, adopted, removed, or skipped should be understandable.
- Keep removal safe: do not uninstall arbitrary external software unless the user and definition clearly opted into that behavior.
- Keep depots clean: avoid temp files, sidecars, lock clutter, and partial materialization state in synced depot folders.
- Keep schema wording user-readable: names should describe product concepts, not implementation accidents.
- Keep package definitions declarative: install logic belongs in the engine, not hidden inside each JSON file.
- Keep install actions schema-bound: do not add generic pre-install or post-install hooks as a shortcut.
- Keep package JSON agent-friendly: LLMs should be able to generate and update definitions, but validation and review must remain part of the flow.
- Keep team catalog trust stronger than naming alone: publisher identity binds to signed definitions and explicit local trust policy, not only self-declared JSON fields.
- Keep runtime flows separated by installer kind when behavior is materially different.
- Keep release selection explainable: latest, previous, pinned, skipped, and replaced versions should be clear in results and logs.
- Keep agent-generated definitions reviewable by humans before install.

## Good Product Decisions

A change is likely in-bounds when it:

- Makes a user profile more repeatable.
- Makes package assignment safer, clearer, or more offline-capable.
- Improves package definition validation before install.
- Reduces hidden network or installer behavior.
- Makes package state and logs easier to understand.
- Helps team endpoints and depots scale without becoming fleet orchestration.
- Helps online endpoints, especially an Eigenverft endpoint, carry catalog growth outside the module package.
- Makes LLM-maintained package definitions easier to validate, review, and publish safely.
- Helps isolated networks use an internal endpoint and depot without public internet dependency.
- Preserves safe removal and ownership tracking.

## Risky Product Decisions

A change needs extra scrutiny when it:

- Adds central control over many machines.
- Adds automatic background updates.
- Makes package definitions execute imperative setup logic.
- Stores unnecessary generated files in the depot.
- Makes removal hunt for untracked external software.
- Uses live upstream metadata during an install that was expected to be offline.
- Treats unsigned JSON on a writable share as production-grade trust.
- Adds generic script hooks because one package type is inconvenient to model.
- Turns the module package itself into the place where all generated catalog definitions must ship.
- Lets AI-generated package definitions bypass validation or human review.
- Makes schema names more abstract or harder for package authors to understand.
- Hides version or dependency decisions from the result object.

## Out Of Scope For This Product

These may become a separate manager or orchestration product, but should not define the package engine:

- Fleet-wide pin, hold, rollout, and rollback policy.
- Central outdated reporting across many hosts.
- Cross-machine assignment enforcement.
- Organization-wide compliance dashboards.
- Background agents that mutate package state without an explicit `Invoke-Package` style action.

Those orchestration concerns belong to a separate **Eigenverft Manifested Manager** style product. The package engine should expose clean state, endpoint, and catalog primitives that such a manager can use, without becoming the manager itself.

## Positioning

This product should be presented as a governed Windows package channel for teams:

- More structured than ad-hoc WinGet/Scoop scripts.
- More local and team-owned than a central public catalog.
- Lighter than enterprise endpoint management.
- Strong for team dev machines, internal package shares, reusable depots, and isolated networks.
- Designed so agents and LLMs can maintain package definitions at scale, while humans and CI can validate and review them before install.
- Extended primarily through online or team package endpoints, not by bloating the shipped module with every possible definition.

Security should support the product story without becoming the whole sales pitch: users should see "one command, known toolchain, works from our depot" first, and "signed, schema-bound, hash-checked catalog" as the reason the approach is acceptable for teams.

## Decision Test

Before adding a feature, ask:

- Does this make one user profile easier to prepare?
- Can a human understand what will be installed before it happens?
- Can the package be rerun safely?
- Can removal stay inventory-safe?
- Can depot reuse stay clean and predictable?
- Can a catalog definition be generated or updated by an LLM and still be validated by deterministic tooling?
- Does this strengthen endpoints as the extension model instead of adding packages directly to the module?
- Can the package run from a controlled endpoint and depot when the network is isolated?
- Are install actions still limited to reviewed schema kinds rather than arbitrary hooks?
- Does this belong in the package engine, or is it really a future manager product?

If the answer points toward local, explicit, inventory-backed package assignment, it probably fits.

If the answer points toward central policy, hidden automation, or fleet orchestration, it probably belongs elsewhere.
