# PackageDefinitionAuthoring

## Mandatory Preflight

Before executing any other package-authoring operation, fully read this document from top to bottom and fully read the active package-definition schema. The only actions allowed before this preflight is complete are locating/opening this guide and locating/opening the schema file.

Read the complete schema file for the active `schemaVersion`, currently `Schema/PackageDefinition/eigenverft-module-package-definition-1.9.schema.json`, including root descriptions, `x-eigenverftAgentHint`, nested `description` fields, and `$comment` fields for every object shape you may edit. If either this document or the schema cannot be read fully, stop and ask the user before searching, editing, validating, signing, or writing package JSON.

## What this text is

You are authoring **package-definition JSON** for **Eigenverft.Manifested.Package**, a Windows PowerShell module that catalogs declarative install recipes and applies them later with `Invoke-Package`. Your job here is only the JSON catalog file - not module source code, not running vendor installers, and not `Invoke-Package` while you write JSON.

**How this document is usually delivered**

The user gives you one block of text. Above this heading you should already see, in order when present:

1. **Task** - e.g. `Task: create or update package definition 'TotalCommander'.` That line names the **`definitionId`** unless the user says otherwise.
2. **Authoring mode** (optional) - e.g. `draft-only`: keep the file unsigned and skip signing/trust steps described below.
3. **Runtime endpoint status** - machine paths, `Selection`, `MarkedCandidates`, `AgentAction`, and optional `TroubleshootingKind`.

Everything from this heading downward is the skill. Read the prepended sections first, then follow this document.

**Typical output file path**

When `Selection` shows `Ready` and a folder path, create or edit JSON **under that folder**. The recommended layout from schema and shipped examples is:

`<Selection-path>\<publisherId>\<definitionId>.json`

- **`definitionId`**: from the **Task** line or the user (e.g. `TotalCommander`).
- **`publisherId`**: from the user if they named it; otherwise infer from existing `*.json` under the same catalog root or ask before writing.
- If the existing endpoint uses flat files directly under `Selection`, or the user explicitly asks for that layout, use `<Selection-path>\<definitionId>.json` instead. Runtime identity comes from `definitionPublication`, not from the folder name.

## Start Here

1. Read the **Task**, **Authoring mode** (if any), and **Runtime endpoint status** above this heading.
2. If `Selection` is `(none)` or `TroubleshootingKind` is set, read **Troubleshooting for agents** and explain the situation to the user. Do not edit JSON until there is a writable authoring root or the user picks another target.
3. If `Selection` is `Ready` with a path, complete **Required First Step**, then **Authoring Workflow** (validate; sign and verify trust only when not in draft-only mode).
4. Do not run vendor installers or `Invoke-Package` while writing JSON (**No Installer Execution During Authoring**).

If **Runtime endpoint status** is missing above this text, run `Get-PackageEndpoint` in a shell where the module is installed, report what you find, and ask the user how to proceed. Do not guess the authoring folder.

If **Authoring mode** shows `draft-only`, obey that block for signing and trust even when other sections describe full publication finalization.

## Required First Step

Before making any JSON edit, ground the work in the user's task, the prepended runtime information, and the installed module schema - not in this chat history, the current workspace, or PowerShell module **source code** (`.ps1` implementation trees).

**Read fully (required):**

- The prepended **Task**, **Authoring mode**, and **Runtime endpoint status** (when present), plus this guide from top to bottom.
- `Schema/PackageDefinition/eigenverft-module-package-definition-1.9.schema.json` on the machine where the module is installed. Resolve the folder with `(Get-Module Eigenverft.Manifested.Package).ModuleBase` after import, or `Get-Module -ListAvailable Eigenverft.Manifested.Package` if import fails. Read the complete schema, including the root `description`, `x-eigenverftAgentHint`, and the relevant nested `description` and `$comment` fields for every object shape you edit.
- Any extra instructions the user gave in chat (publisher, scope, installer kind, draft vs signed, and so on)

For normal authoring, these inputs are enough: the skill explains workflow, endpoints, validation, and signing; the schema defines shape, acquisition, dependencies, and materialization. Follow the schema first. Treat schema `description` and `$comment` text as authoring instructions, not decoration.

**Read only when needed:**

- Other `*.json` package definitions under the same **Selection** catalog root (same or sibling `publisherId` folders). Use them for structure and convention; they illustrate the schema and do not override it.
- Shipped example definitions under the installed module folder, for example `<ModuleBase>\Endpoint\Defaults\Eigenverft`, when the selected authoring root has no useful examples. Resolve `<ModuleBase>` with `Get-Module`; do not guess a source repository path.
- The target definition file itself when the task is an update, version bump, or review of existing JSON.

**Do not read by default:**

- PowerShell module source, engine implementation, dependency planner, trust model, or installer runtime code. Authoring is declarative JSON work.

Do not skim the required inputs or infer missing rules from example JSON alone. If the user's task, this guide, schema comments/descriptions, and an example disagree - or if this guide or the schema cannot be read fully - stop and ask the user before editing.

Every property you write must be allowed by the JSON Schema for the selected object shape. Do not add "helpful" extra properties because they seem useful to the engine or appear in a guessed installer command. If the schema cannot express the package behavior, stop and report the schema/authoring mismatch instead of forcing JSON through a looser validator.

## Authoring Targets And Endpoints

**Endpoints** are configured catalog roots on disk (or future remote catalogs). The module stores their list in `PackageEndpointInventory.json` (path shown as `InventoryPath` in **Runtime endpoint status**).

- **Authoring** (your job now): write JSON only under endpoints marked `authoringTarget: true` that are `Ready` in **Runtime endpoint status** (`Selection` path).
- **Later install/scan**: other module features read enabled endpoints and may run `Invoke-Package` to apply definitions. That runtime install work is **not** part of composing JSON.

The folder you write to is always whatever **Selection** shows. Do not guess a path from product names or repo layout; use `Selection` or `Get-PackageEndpoint`.

### Status values


| Status        | Meaning                                                                                                                                                                                               |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Ready`       | Marked, **enabled**, writable, and a supported kind (`moduleLocal` or `filesystem`). This is the only status selected for authoring. For these kinds, enabled also means effective for package scans. |
| `Blocked`     | Marked but not usable: disabled, path missing/unreachable, not writable, or otherwise not ready. Disabled endpoints are listed but not filesystem-probed. Skipped for selection.                      |
| `Unsupported` | Marked but kind is not `moduleLocal` or `filesystem` (for example `httpsCatalog` in v1). Skipped for selection.                                                                                       |


Selection uses only `Ready` targets, then applies `searchOrder` (`First` = lowest order, `Last` = highest). `authoringTarget` is not inferred from writability alone.

### Managing authoring intent

```powershell
Get-PackageEndpoint
Add-PackageEndpoint -EndpointName 'teamCatalog' -BasePath '\\share\PackageEndpoint' -AuthoringTarget
Set-PackageEndpoint -EndpointName 'teamCatalog' -AuthoringTarget
Set-PackageEndpoint -EndpointName 'teamCatalog' -NoAuthoringTarget
```

Or set `"authoringTarget": true` on an endpoint object in `PackageEndpointInventory.json`.

### Troubleshooting for agents

Explain endpoint configuration to the user when runtime status shows:

- **NoMarkedTarget** - No endpoint has `authoringTarget: true`. Name the inventory file, summarize configured endpoints from `Get-PackageEndpoint`, and describe how to mark or add an authoring target.
- **AllMarkedBlocked** - Targets are marked but none are writable or supported. List each skipped endpoint with resolved path (if any) and skip reason; suggest fixing permissions, creating the folder or share, enabling the endpoint, or choosing another marked endpoint.

Do not silently continue as if a usable authoring root exists.

### Definition layout under a target root

Place the JSON under the resolved authoring root from **Runtime endpoint status** or `Get-PackageEndpoint`.

Recommended convention: `<publisherId>/<definitionId>.json`.

Flat files directly under the endpoint root can also be valid when that is the endpoint's existing convention or the user requests it. Keep the file name clear and make `definitionPublication.publisherId` and `definitionPublication.definitionId` authoritative.

### Publication finalization

Skip this subsection when **Authoring mode** is `draft-only` (unsigned JSON and non-trusted validation only).

A package definition is a trusted-catalog or shipped-catalog change when the user asks for a publishable definition, the selected endpoint is an enabled scan endpoint, or **Selection** points at the module's shipped defaults such as `Endpoint/Defaults/Eigenverft` under the installed module folder. These are not disposable drafts. Do not leave a new or changed definition unsigned unless **Authoring mode** is `draft-only` or the user explicitly requested unsigned draft work.

The selected path from **Runtime endpoint status** is authoritative. Do not guess a repository path or edit a different copy of `Endpoint/Defaults/Eigenverft`. If **Selection** points into an installed module folder and the path is not writable, stop and explain the endpoint/write-access problem to the user instead of editing another file.

Before final handoff for definitions intended for trusted or shipped catalog use:

1. Finish all JSON edits under the selected authoring root using the layout above.
2. Run `Test-PackageDefinitionCatalog` on the changed file.
3. Sign or re-sign with the profile the user approved or that `Get-PackageSigningProfile` selected, commonly:

```powershell
Resign-PackageDefinition -Path '<definition.json>' -Cert Eigenverft -KeepSchemaVersion
```

4. Run `Test-PackageDefinitionCatalog -RequireTrusted` on the changed file or endpoint folder.
5. Run `Verify-PackageDefinitionSignature -RequireTrusted` for the file, or `Verify-PackageDefinitionCatalog -RequireTrusted` for the folder.
6. If the selected authoring root is inside a local Git working tree, check repository tracking/status so new JSON files are not forgotten. For remote endpoints or non-repository paths, skip repository commands and mark the repository-status check `Not applicable`.
7. In the handoff, include **Required handoff check result** so executed validation, signing, trust verification, source research, and blockers are explicit.

### Required handoff check result

Before the final user handoff, include a section named `Check Result`. This is mandatory for every package-definition authoring or update task, including draft-only work.

Use a compact table or bullet list with one row per relevant check:

- `Definition path`
- `Vendor installer kind evidence`
- `Generic installer kind corroboration`
- `Vendor installer switch evidence`
- `Generic installer switch corroboration`
- `Artifact hash verification`
- `Publisher signature verification`
- `Raw JSON schema validation`
- `Test-PackageDefinitionCatalog`
- `Signing or re-signing`
- `Trusted signature/catalog verification`
- `Repository status` (local Git working tree only)

Each row must include `Status`, `Evidence`, and `Command/source`. Valid statuses are `Passed`, `Failed`, `Not run`, and `Not applicable`.

For installer-backed definitions, the installer evidence rows are required and must cite the exact JSON behavior they justify: `packageOperations.assigned.install.kind`, any `installerKind`, `commandArguments`, target-directory argument/property behavior, force/update semantics, shortcut or registry side effects when relevant, and elevation assumptions. Use `Not applicable` only for definitions with no installer command surface to validate, such as pure archive extraction, file placement, or PowerShell module installs.

Use `Passed` only when the command was actually executed or the source was actually opened/read during the current task. Do not mark a check as passed because it is planned, recommended, inferred from prior conversation, or expected to pass. If a required check is `Failed` or `Not run`, do not call the package complete; report the blocker or explain why the task is draft-only/incomplete. If no vendor installer documentation or no generic corroborating source was found for installer kind or switches, mark the relevant row `Failed` and stop instead of guessing.

## Product Boundary

Package definitions are declarative JSON: where to download software, how to verify it, and how the module should install it later. They are not scripts you run during authoring.

When **Selection** is `Ready`, finish the catalog work on that path (JSON plus validation; signing and trust when not draft-only). Do not stop after drafting if the user expected a signed catalog file and **Authoring mode** is not `draft-only`.

Do not change the module's PowerShell implementation, invent fleet/orchestration features, or expand scope beyond one definition file (plus validation/signing commands). If the product cannot be described in schema 1.9 JSON, tell the user and stop.

Do not run upstream installers or `Invoke-Package` while constructing JSON. See **No Installer Execution During Authoring**.

## No Installer Execution During Authoring

Package-definition authoring is **declarative JSON work**. Discover acquisition URLs, installer kind, silent switches, scopes, and materialization from the schema, this guide, example definitions, and official or reputable web sources - not by executing the vendor installer on the agent machine.

**Forbidden while drafting or updating definition JSON** (including one-off "tests" or "figuring out switches"):

- Running `setup.exe`, `install.exe`, `.msi`, or any vendor bootstrapper
- **Administrative or machine-wide installs** (`ALLUSERS`, elevated `/quiet`, `msiexec /i` with admin scope, or any install that requires elevation) unless the user explicitly ordered a separate install test outside authoring
- User-scoped trial installs used only to learn behavior - also forbidden during authoring
- `Invoke-Package`, hand-running materialization blocks from the JSON, or ad-hoc copies of install commands from the definition
- Repair, modify, or uninstall runs whose only purpose is to probe installer behavior

Authoring must not mutate the host with installed products, services, drivers, or registry state from exploratory installs.

**Allowed while authoring:**

- Catalog commands on the JSON artifact: `Test-PackageDefinitionCatalog`, signing, `Verify-PackageDefinitionSignature`, and related trust checks
- Downloading release binaries **only** when a version-update workflow needs `contentHash` or `publisherSignature` verification - do not execute the downloaded installer afterward

**When installer behavior is unclear:**

1. Re-read schema 1.9 (`x-eigenverftAgentHint`, acquisition and materialization sections) and **Installer Kind Discovery** below.
2. Align with an existing trusted `*.json` definition for the same artifact kind (portable vs user installer vs admin installer).
3. Search the web: official silent-install docs, release notes, package-manager manifests, and vendor KB articles.
4. If still unclear, stop and ask the user. Do **not** install the product to discover switches, scope, or paths.

## Inputs To Read First

After **Required First Step**, use these when the task still needs location or command detail:

- `Selection` path from **Runtime endpoint status**, or `Get-PackageEndpoint` when the runtime block is absent
- Example `*.json` under the **Selection** root - only when structure or convention is unclear from the schema alone
- Command help for validation, signing, or trust when usage is unclear

Do not expand scope into module source unless **Required First Step** says that is warranted.

## PowerShell Host Check

Do not assume the current shell can import the module. Some agents run commands in PowerShell 7 (`pwsh`) while the module may be installed only for Windows PowerShell 5.1 (`powershell.exe`), or the reverse. Check both hosts before running validation, signing, or trust commands.

Check the current host:

```powershell
$PSVersionTable.PSEdition
$PSVersionTable.PSVersion
Get-Module -ListAvailable Eigenverft.Manifested.Package | Select-Object Name, Version, ModuleBase
```

Check Windows PowerShell 5.1 from an agent shell:

```powershell
powershell.exe -NoProfile -Command "$PSVersionTable.PSEdition; $PSVersionTable.PSVersion; Get-Module -ListAvailable Eigenverft.Manifested.Package | Select-Object Name,Version,ModuleBase"
```

Check PowerShell 7 from Windows PowerShell:

```powershell
pwsh -NoProfile -Command "$PSVersionTable.PSEdition; $PSVersionTable.PSVersion; Get-Module -ListAvailable Eigenverft.Manifested.Package | Select-Object Name,Version,ModuleBase"
```

Run `Test-PackageDefinitionCatalog`, signing, and trust commands in the host where `Eigenverft.Manifested.Package` is installed. If the module is available in only Windows PowerShell 5.1, call `powershell.exe`. If it is available in only PowerShell 7, call `pwsh`. If neither host can see the module, tell the user the module must be installed or imported before validation can run.

## Authoring Workflow

1. Use **Start Here** and the sections above this document when present; otherwise obtain paths with `Get-PackageEndpoint`.
2. Start from schema 1.9 and a nearby example under the resolved authoring target. If the target is empty, use shipped examples under the installed module's `<ModuleBase>\Endpoint\Defaults\Eigenverft` as examples only.
3. Author drafts as unsigned: `definitionPublication.definitionSignature.kind = unsigned`.
4. Never fabricate, copy, or hand-edit `signatureValue`.
5. Write under **Selection**. Prefer `<publisherId>/<definitionId>.json` unless the endpoint already uses flat files or the user requested a flat layout.
6. Bump `definitionRevision` for every definition content change.
7. Keep scripts and acquisition behavior minimal, declarative, and reviewable; do not run upstream installers or `Invoke-Package` during construction (**No Installer Execution During Authoring**).
8. Run `Test-PackageDefinitionCatalog` before signing or publishing.
9. Sign or re-sign only after content is stable.
10. Verify signature or catalog trust.
11. Check repository tracking/status before handoff only when the selected authoring root is inside a local Git working tree. For remote endpoints or non-repository paths, do not run repository commands.
12. When `Selection` is `Ready`, write the JSON under that path and run **Publication finalization** (or draft-only validation only when **Authoring mode** requires it).

## Installer Kind Discovery

When the installer kind, silent arguments, extraction behavior, or package format is unclear, **search the web and read documentation first**. Prefer official vendor documentation, release notes, package manager manifests, installer docs, and existing trusted package definitions.

For installer kind and installer switches, do a vendor-focused web search first and identify the vendor-documented installer technology, package format, silent-mode syntax, target-directory syntax, update/force behavior, shortcut creation, registry/uninstall behavior, and elevation expectations. Then confirm the installer kind and switch usage against at least one broader generic source, such as a reputable package-manager manifest, deployment guide, enterprise software catalog, or community packaging recipe. Treat generic results as corroboration only; if they disagree with the vendor documentation, if they omit a risky detail such as installer kind or target-directory force/update semantics, or if the vendor documentation is not found, stop and report the ambiguity instead of guessing.

Carry the discovered installer evidence into the final `Check Result`; the handoff must show the vendor source and generic corroborating source that justify the exact installer kind and switches written into JSON.

**Never run the installer to discover this information.** That includes administrative installs, quiet `msiexec` trials, or any "test install" while editing JSON. Those steps are forbidden under **No Installer Execution During Authoring**.

Discover whether the vendor ships multiple artifact kinds for the same product, such as portable archives, user installers, machine/admin installers, MSI packages, app-store packages, or architecture-specific builds. Prefer a vendor-published portable archive when it fits the package intent. Otherwise prefer a user-scoped installer over a machine/admin installer. Use admin or machine-wide installers only when the user's intent and documentation explicitly require that scope - not because an elevated trial install was run.

Choose the install operation shape from the schema, not from a guessed product-specific label. Prefer the dedicated schema adapters when they fit (`nsisInstaller`, `innoSetupInstaller`, `msiInstaller`, `powershellModuleInstaller`, `expandArchive`, and so on). Use generic `runInstaller` only when the schema's `assignRunInstaller` shape exactly fits the package. `runInstaller.installerKind` is descriptive metadata for logging; it does not create a new adapter and it does not permit extra properties outside the schema. If a custom installer needs a target-directory property that the selected schema shape does not allow, stop and ask for a schema/runtime decision instead of adding an unsupported property.

Do not mix artifact kinds by accident. If the existing definition is for a user installer, update from the user-installer source. If it is for a portable/runtime package, update from the matching portable/runtime source. If intent is unclear, stop and ask the user before switching installer kind.

Non-executing inspection of a downloaded file (for example format identification from headers or static metadata) is a last resort after documentation and examples, and must not launch or install the payload. If the installer format or silent switches still cannot be established confidently, stop and ask the user instead of guessing or installing.

## Existing Definition Latest Version Update

Use this workflow when asked to check or update an existing package definition to the latest upstream version. This is an authoring/update task and is independent of the definition's install-time `versionSelection` policy.

1. Read the full existing definition before changing it.
2. Identify every target artifact that belongs to the definition's release, for example x64 and arm64 entries.
3. Search official vendor release channels, update services, release notes, download pages, package metadata, and package-manager manifests for the latest stable version. Some vendors expose multiple official "latest" sources, and they can disagree temporarily.
4. Compare all discovered official sources. Record which source matches the package's artifact kind and whether any other official source disagrees. Do not use unofficial mirrors as the source of truth.
5. If official sources disagree, verify the concrete artifact endpoint, version text, hash, and publisher signature for the intended artifact kind before editing. If the newest valid artifact cannot be proven, stop and report the ambiguity.
6. If the definition already contains the latest stable version and all hashes still match the upstream artifacts, do not edit or re-sign the JSON. Report that it is current.
7. If a newer stable version exists, update the release entry or add a new release following the existing file's retention pattern. If retention is unclear, add the new release and leave older releases unchanged.
8. Refresh every target artifact for that release together. Do not update only one architecture when the definition contains multiple stable targets.
9. Download each upstream artifact through the source model declared in the definition, compute the declared `contentHash`, and verify any declared `publisherSignature`. Do not run or install the downloaded artifact; see **No Installer Execution During Authoring**.
10. Bump `definitionRevision`, refresh `publishedAtUtc`, then sign or re-sign after all semantic JSON edits are finished.
11. Run **Publication finalization** before handoff.

Stop if the latest version cannot be proven from official sources, an artifact for any required target is missing, a hash cannot be verified, or an expected publisher signature no longer matches.

## Self-Check Checklist

- `publisherId`, `definitionId`, display metadata, and revision match the requested package.
- `schemaVersion` is `1.9`.
- Deprecated top-level `dependencies` and `dependencyPolicy` are not used.
- Dependencies use `dependency.requires[]`.
- Coexistence policy uses `dependency.policy.conflictsWith[]` or `dependency.policy.requiresAbsent[]` only when the user's intent is explicit.
- Download URLs, checksums, installer arguments, and materialization paths are reviewable.
- `packageOperations.assigned.install` uses one exact schema-defined operation shape; no extra fields are added to make a custom installer work.
- No credentials, tokens, local private paths, or machine-specific secrets are embedded.
- `definitionSignature.kind` is `unsigned` only while drafting or when explicitly requested.

## Catalog Validation

Validate a single draft file while authoring:

```powershell
Test-PackageDefinitionCatalog -Path '<definition.json>'
```

Validate an endpoint folder before publication:

```powershell
Test-PackageDefinitionCatalog -Path '<endpoint-root>' -RequireTrusted -ErrorOnFailure
```

Treat validation issues as blockers until the user says otherwise. Do not use `Verify-PackageDefinitionCatalog` as a replacement for schema and reference validation; it checks signature and trust summary, while `Test-PackageDefinitionCatalog` checks parse, schema, signature/trust status, duplicate identities, and static dependency references.

Also run raw JSON Schema validation when the current host supports `Test-Json`; PowerShell 7 usually does. This catches schema-shape errors before signing:

```powershell
$moduleBase = (Get-Module Eigenverft.Manifested.Package).ModuleBase
$schemaPath = Join-Path $moduleBase 'Schema\PackageDefinition\eigenverft-module-package-definition-1.9.schema.json'
Test-Json -Json (Get-Content -Raw -LiteralPath '<definition.json>') -Schema (Get-Content -Raw -LiteralPath $schemaPath) -ErrorAction Stop
```

If `Test-Json` is unavailable in the current shell, try the other PowerShell host described in **PowerShell Host Check**. If raw schema validation cannot be run, say so in the handoff; do not claim that schema-file validation passed. If `Test-PackageDefinitionCatalog` passes but raw schema validation fails, treat the raw schema failure as a blocker and fix the JSON or ask for a schema/runtime decision.

## Signing And Signing-Profile Discovery

Use `Sign-PackageDefinition` for first signing and `Resign-PackageDefinition` for changed signed definitions. Use `-KeepSchemaVersion` when re-signing a stable schema version.

If signing is required and the user did not name a certificate or profile, discover existing signing profiles first:

```powershell
Get-PackageSigningProfile -PublisherId '<publisherId>'
```

Selection rules:

- Zero matching profiles: stop and ask the user to create a profile with `New-PackageSigningCertificate` or to supply a signing certificate/profile path.
- Exactly one matching profile: use `SigningDescriptorPath` when present; otherwise use `PfxPath`.
- Multiple matching profiles: stop and ask the user which profile or certificate to use.
- Public `.cer` and `.pem` files are trust/verification material, not signing certificates. Do not pass them as signing certs.

Example re-sign after one unambiguous profile was selected:

```powershell
Resign-PackageDefinition -Path '<definition.json>' -Cert '<SigningDescriptorPath-or-PfxPath>' -KeepSchemaVersion
```

Do not fabricate signatures, edit `signatureValue` by hand, auto-trust unknown keys, or use runtime trust bypasses as a publication workflow.

## Signature And Catalog Verification

Verify one signed file:

```powershell
Verify-PackageDefinitionSignature -Path '<definition.json>' -RequireTrusted -ErrorOnFailure
```

Verify a signed endpoint catalog:

```powershell
Verify-PackageDefinitionCatalog -Path '<endpoint-root>' -RequireTrusted
```

If trust verification fails, stop and explain to the user. They may need `Import-PackageTrust`, `Trust-PackageSigningCertificate`, or another trust command before verification can pass.

## Agent Completion At A Valid Endpoint

When **Runtime endpoint status** shows `Selection` with status `Ready`:

1. Write the JSON under the **Selection** path (`definitionId` usually from the **Task** line). Prefer `<publisherId>\<definitionId>.json`; use `<definitionId>.json` directly under **Selection** when that matches the endpoint convention or user instruction.
2. Run `Test-PackageDefinitionCatalog` on that file.
3. Run raw JSON Schema validation with `Test-Json` when available, or state clearly that raw schema validation could not be run.
4. Unless **Authoring mode** is `draft-only`, complete **Publication finalization** (sign with an approved profile when appropriate, then verify signature and trust).

Success means the JSON exists on the catalog root with catalog validation, raw schema validation when available, signing/trust when required, and a final `Check Result` that records the executed evidence. Proof is validation/signature/source output - not installing the product.

**Draft-only:** when **Authoring mode** shows `draft-only`, stop after unsigned JSON and schema validation; skip signing and `-RequireTrusted` steps.

**Do not confuse catalog work with runtime install:**


| Your authoring job                                               | Out of scope while authoring                     |
| ---------------------------------------------------------------- | ------------------------------------------------ |
| JSON under **Selection**, validated (signed when not draft-only) | `Invoke-Package` or running the vendor installer |
| Document results for the user                                    | Trial installs to discover silent switches       |


## Common Mistakes

- Using retired top-level `dependencies` instead of `dependency.requires`.
- Using retired top-level `dependencyPolicy` instead of `dependency.policy`.
- Forgetting to bump `definitionRevision`.
- Hand-editing `signatureValue`.
- Treating `.cer` or `.pem` files as signing certificates.
- Authoring under a folder that does not match **Selection** in **Runtime endpoint status**.
- Leaving a definition unsigned when it is meant for a trusted, enabled scan endpoint.
- Skipping `Test-PackageDefinitionCatalog` or trust verification.
- Inventing `conflictsWith` pairs without clear user intent.
- Trusting unknown signing keys as a shortcut.
- Embedding secrets or local machine paths in package JSON.
- Reporting work as done without the required final `Check Result`, validation, signing status, and repository-status check when the selected authoring root is inside a local Git working tree.
- Reading module or engine source when the schema, this guide, and example definitions were sufficient.
- Running vendor installers (including administrative or quiet "test" installs) to discover silent switches or install paths.
- Calling `Invoke-Package` during authoring instead of using catalog validation and documentation.
- Choosing an admin/machine-wide installer artifact because a trial elevated install "worked" when user or portable artifacts fit the intent.

## Out Of Scope

- Package engine changes.
- Schema changes.
- Dependency planner or resolver architecture changes.
- Fleet management or orchestration.
- Lockfile models inside materialized packages.
- New signing or trust commands.
- Editing built-in sample catalog JSON shipped inside the module install unless the user explicitly asked for that and **Selection** points there.
- Executing upstream installers or `Invoke-Package` on the authoring machine to probe behavior; use documentation, examples, and **No Installer Execution During Authoring** instead.
