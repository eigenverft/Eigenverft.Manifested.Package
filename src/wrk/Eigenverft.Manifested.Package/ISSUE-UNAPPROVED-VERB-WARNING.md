# Coding-agent task — remove unapproved-verb import warnings

## Goal

Make a normal import of `Eigenverft.Manifested.Package` complete without PowerShell's warning that some exported commands use unapproved verbs, while preserving compatibility and without suppressing unrelated warnings.

## Current context

The module explicitly exports functions from:

`src/prj/Eigenverft.Manifested.Package/Eigenverft.Manifested.Package.psd1`

Potential candidates must be determined from the actual `FunctionsToExport` list with `Get-Verb` on both Windows PowerShell 5.1 and PowerShell 7. Do not assume that every custom-looking verb is invalid. Current names that require verification include examples such as:

- `Open-PackageDocumentation`
- `Open-UrlInBrowser`
- `Search-Package`
- `Resign-PackageDefinition`
- `Sign-PackageDefinition`
- `Trust-PackageSigningCertificate`
- `Untrust-PackageSigningCertificate`
- `Verify-PackageDefinitionCatalog`
- `Verify-PackageDefinitionSignature`

This list is only an investigation seed; the manifest is the source of truth.

## Required approach

1. Reproduce the warning with a clean normal import, without `-DisableNameChecking`.
2. Enumerate every exported function whose verb is absent from `Get-Verb` for the supported PowerShell versions.
3. Propose approved canonical names that preserve the existing command semantics.
4. Preserve backwards compatibility where practical through aliases or thin compatibility wrappers.
5. Verify experimentally whether exported compatibility aliases themselves trigger the unapproved-verb warning.
6. Update the module manifest, exported command surface, help, README, packaged HTML documentation, tests, and examples consistently.
7. Add release notes and a migration table from old names to new names.

## Prohibited shortcuts

Do not treat any of the following as the final solution:

- changing global or caller `WarningPreference`;
- importing the module internally with `-DisableNameChecking` only;
- adding `-WarningAction SilentlyContinue` to examples;
- filtering all warnings by message text;
- hiding warnings that are unrelated to command naming.

The user should be able to run:

```powershell
Import-Module Eigenverft.Manifested.Package -Force
```

without the unapproved-verb warning and without losing other legitimate warnings.

## Compatibility requirements

- Existing automation using old public command names must either continue to work or receive an explicit, documented breaking-change decision.
- Parameter names, pipeline behavior, output types, error behavior, `WhatIf`, and `Confirm` semantics must remain unchanged unless a change is justified separately.
- `Get-Command -Module Eigenverft.Manifested.Package` must show the intended canonical functions and compatibility aliases clearly.
- Do not create duplicate implementations for renamed commands; one implementation should remain authoritative.

## Tests

Add focused tests that:

- import the module normally and capture warnings;
- assert that no warning mentions unapproved verbs;
- prove that an unrelated deliberate warning is still observable;
- verify every new canonical command is exported;
- verify every retained old name resolves and behaves compatibly;
- verify manifest `FunctionsToExport` and `AliasesToExport` match the implementation;
- run on Windows PowerShell 5.1 and PowerShell 7;
- validate packaged documentation and README examples after renaming.

## Deliverables

Produce a reviewable implementation with:

1. investigation results and exact offending verbs;
2. approved-name mapping and compatibility decision;
3. code and manifest changes;
4. updated help and documentation;
5. regression tests for clean import and compatibility;
6. a concise work-history entry;
7. separate logical commits where useful.

Before changing command names, present the proposed mapping and evidence from `Get-Verb`. Do not solve the warning by broadly suppressing PowerShell warnings.
