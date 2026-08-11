# External command collisions can bypass package-owned command selection

**Status:** Open investigation / guardrail design
**Priority:** 4/7 Medium
**Observed:** 2026-08-11 on Windows with `PowerShell7` and VS Code PowerShell extension

## Incident

A machine had the Manifested `PowerShell7` package assigned and healthy. Its generated `pwsh` shim resolved to the package-owned PowerShell 7.6.4 runtime and normal shell command resolution was correct.

The same user profile also contained an older PowerShell 7.5.3 installed independently as a .NET global tool under the user's `.dotnet/tools` directory. That executable was no longer runnable because its required .NET 9 runtime was absent while .NET 10 was installed.

VS Code's PowerShell extension did not rely only on normal `PATH` resolution. Its own PowerShell installation discovery selected the external `.NET Core PowerShell Global Tool` executable directly. Opening the PowerShell extension terminal therefore terminated immediately even though the Manifested `pwsh` shim and package-owned runtime were healthy.

Removing the stale external tool with `dotnet tool uninstall --global powershell` resolved the failure. The Manifested PowerShell installation remained unchanged.

## Why this matters

Package-owned command shims and correct `PATH` ordering are not sufficient to guarantee that another application will select the package-owned runtime. Consumers may enumerate well-known installation locations or use product-specific runtime discovery and choose a competing executable directly.

This creates a class of failures where:

- `Get-Command pwsh` and the Manifested shim are correct;
- the assigned package passes its own readiness checks;
- a second external provider exposes the same logical command/runtime;
- a downstream application bypasses `PATH` and selects that external provider;
- the resulting failure looks like a package/PATH problem even though the package-owned runtime is healthy.

## Current `PowerShell7` definition behavior

The shipped `PowerShell7` definition intentionally does not adopt external installs:

- `discovery.existingInstall.enabled = false`;
- `packageOperations.policy.ownershipPolicy.allowAdoptExternal = false`;
- `requirePackageOwnership = true`.

Therefore the `.dotnet/tools/pwsh.exe` installation from this incident would not be adopted into the Manifested inventory during assignment. This is consistent with the current ownership policy, but it also means assignment does not currently surface that competing provider as an external collision.

## Would `Invoke-Package -DesiredState Removed` have fixed it?

The public command has no `-Remove` switch; removal is requested with `-DesiredState Removed`.

No, not with the current `PowerShell7` definition and removal flow.

`PowerShell7.packageOperations.removed.policy` currently has:

- `whenNotInInventory = "succeed"`;
- `allowedInventoryOwnershipKinds = ["PackageInstalled"]`;
- `allowUntrackedExternalRemoval = false`.

The removal engine resolves the Manifested install slot from package inventory. If no matching inventory record exists and `whenNotInInventory` is `succeed`, it marks removal as skipped and returns without destructive work. If a matching Manifested record exists, removal targets its inventory-owned install directory. It does not remove an unrelated `.NET global tool` installation.

So removing `PowerShell7` through Manifested would either remove the package-owned runtime or skip when it was not tracked; it would not have cleaned up the stale external PowerShell that caused VS Code to fail.

## Existing policy surface that needs review

Schema 2.0 already requires `packageOperations.removed.policy.allowUntrackedExternalRemoval` and describes it as a high-risk opt-in controlling whether removal may delete an external install discovered live without inventory.

However, repository inspection for this incident found the flag in the schema, shipped definitions, validation, and test fixtures, but no consumption of `allowUntrackedExternalRemoval` in the package removal runtime. The current no-inventory path returns before live external discovery/removal can occur.

This should be reconciled before adding another similarly named switch:

1. Confirm whether `allowUntrackedExternalRemoval` is intentionally reserved for future behavior or is an incomplete shipped contract.
2. If intentionally reserved, make that explicit in schema/docs and avoid implying that `true` currently performs live external removal.
3. If intended to work now, implement and test the missing runtime path with strong safety gates.

## Candidate guardrails

### 1. Detect competing command/runtime providers without adopting them

Add a diagnostic/preflight concept separate from ownership adoption. For packages exposing commands such as `pwsh`, discover known competing providers and report them as conflicts even when `allowAdoptExternal=false`.

For PowerShell this could include, where safely identifiable:

- package-owned/generated shim;
- package-owned runtime;
- standard PowerShell installation locations;
- `.dotnet/tools/pwsh.exe` global-tool installation;
- other discovery locations already known by the package definition or package-specific probe logic.

The important distinction is **detect/warn != adopt/remove**.

A useful result should include provider path, detected version/readiness, ownership classification, and whether the provider can shadow or be selected independently of `PATH`.

### 2. Consider a conflict check in assignment planning/state

`Get-PackageAssignmentPlan` or `Get-PackageState` could expose something like competing command providers for package entry points. This would make the condition observable before debugging a downstream application.

Avoid making assignment fail merely because another provider exists. A healthy external installation may be intentional. Prefer warning/status unless the definition authors an explicit exclusivity rule.

### 3. Reconcile untracked external removal with operator consent

If untracked external removal is implemented, definition policy alone may be insufficient for destructive live discovery. Consider requiring both:

- definition opt-in (`allowUntrackedExternalRemoval=true`); and
- explicit operator consent on the invocation, e.g. a dedicated `Invoke-Package` switch or confirmation path.

The engine should never infer that an arbitrary executable sharing a command name is safe to uninstall. Removal needs a definition-specific uninstall operation and strong identity/readiness evidence.

### 4. Prefer native provider uninstall semantics

For this exact incident, the safe repair was provider-native:

```powershell
dotnet tool uninstall --global powershell
```

If a future package definition supports removal of an externally discovered .NET global tool, it should use the provider's uninstall mechanism rather than deleting `.dotnet/tools/pwsh.exe` directly.

## Acceptance / investigation questions

- [ ] Decide whether command-provider collision detection belongs in general package discovery or a package-specific diagnostic layer.
- [ ] Establish how a definition identifies a competing provider without implicitly adopting it.
- [ ] Determine whether collision information belongs in `Get-PackageAssignmentPlan`, `Get-PackageState`, or both.
- [ ] Reconcile the documented `allowUntrackedExternalRemoval` schema contract with the current removal runtime.
- [ ] If untracked external removal is implemented, require enough package identity to invoke a provider-native uninstaller safely.
- [ ] Add a regression scenario where a healthy package-owned `pwsh` coexists with a broken `.dotnet/tools/pwsh.exe`, and diagnostics surface the competing provider without changing ownership automatically.

## Non-goals

- Automatically deleting every duplicate command found on the machine.
- Treating `PATH` precedence as proof that downstream applications will use the same executable.
- Automatically adopting unrelated external installations merely because they expose the same command name.
- Installing an older runtime solely to keep a stale competing provider executable working.
