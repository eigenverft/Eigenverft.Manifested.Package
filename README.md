# Eigenverft.Manifested.Package

[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/Eigenverft.Manifested.Package?label=PSGallery&logo=powershell)](https://www.powershellgallery.com/packages/Eigenverft.Manifested.Package) [![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/Eigenverft.Manifested.Package?label=Downloads&logo=powershell)](https://www.powershellgallery.com/packages/Eigenverft.Manifested.Package) [![PowerShell Support](https://img.shields.io/badge/PowerShell-5.1%2B%20Desktop%2FCore-5391FE?logo=powershell&logoColor=white)](#requirements) [![Build Status](https://img.shields.io/github/actions/workflow/status/eigenverft/Eigenverft.Manifested.Package/cicd.yml?branch=main&label=build)](https://github.com/eigenverft/Eigenverft.Manifested.Package/actions/workflows/cicd.yml) [![License](https://img.shields.io/github/license/eigenverft/Eigenverft.Manifested.Package?logo=mit)](LICENSE) [![Windows Sandbox profile](https://img.shields.io/badge/Windows%20Sandbox-profile-0078D4?logo=windows)](https://github.com/eigenverft/Eigenverft.Manifested.Sandbox)

Windows-focused PowerShell package engine for repeatable developer-machine setup. It uses explicit signed package-definition JSON, trusted signing keys, configurable package endpoints, reusable depots, and local inventory so a toolchain can be assigned, rerun, audited, and removed with predictable behavior.

The product sits between public package managers and heavy endpoint-management systems: more governed than ad-hoc installer scripts, more local and team-owned than a public community bucket, and intentionally smaller than a fleet rollout controller.

🚀 **Key Features:**

- Local package assignment through `Invoke-Package`
- Package catalog discovery through `Search-Package`
- Inventory-backed state and operation history through `Get-PackageState`
- Dependency-aware assignment and removal with explicit version selection, offline mode, and materialize-only depot preparation
- Versioned, reviewable package-definition JSON
- Package-definition authoring guidance, catalog validation, signing, re-signing, and trusted signature verification
- Trusted signing-key records for package-definition authority
- File-based depots for reusing installers, archives, npm tarballs, models, and runtime payloads
- Team and file-based package endpoints as the extension model for larger catalogs
- Offline and controlled-network workflows that can be backed by a prepared depot
- Package-backed provisioning for `python`, `pwsh`, `git`, `gh`, `code`, `notepad++`, `node`, `npm`, `npx`, `dotnet` (SDK 10), `7z`, `opencode`, `codex`, Cursor's `agent`, llama.cpp tools, Qwen GGUF model resources, PowerShell bootstrap modules, and VC++ prerequisites
- Package-owned installs with explicit reuse, adoption, repair, assignment, and removal behavior
- Proxy-aware downloads through `Invoke-WebRequestEx` for managed or corporate Windows environments

## 🧭 Motivation

Preparing a Windows development environment should not depend on a long sequence of hand-maintained install notes. Teams need a way to say which signed catalogs are trusted, where package definitions come from, where package payloads are cached, and what happened during the last run.

This project packages that workflow as a local PowerShell engine. A human or agent can maintain package JSON, CI can validate it, a team can publish it through an endpoint, and each machine can explicitly assign the packages it needs without turning the module into central fleet management.

<a id="requirements"></a>

## 🖥️ Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Windows 10/11
- Network access to configured package sources, or a depot that already contains the needed payloads
- Administrator rights only for package definitions that require machine-level installers or prerequisites

## 🚀 Quick Start

Install once, then run exported commands directly (no `Import-Module` needed):

```powershell
Install-Module Eigenverft.Manifested.Package -Scope CurrentUser -Repository PSGallery -Force -AllowClobber

Invoke-Package -DefinitionId SevenZip,DotNetSdk10,NodeRuntime,CodexCli
Search-Package -Query code
Get-PackageState
```

`Search-Package` scans enabled package-definition endpoints by name, definition id, publisher, and entry points such as commands. `Invoke-Package` resolves definitions from enabled endpoints, verifies catalog trust, prepares or reuses payloads, applies dependency order, and records state.

## 📦 Included Definitions

The shipped `moduleDefaults` endpoint currently includes signed Eigenverft definitions for:

| Area | Definition IDs |
| --- | --- |
| Core runtimes and prerequisites | `NodeRuntime`, `PythonRuntime`, `PowerShell7`, `DotNetSdk10`, `VisualCppRedistributable` |
| Developer tools | `GitRuntime`, `GHCli`, `VSCodeRuntime`, `VSCodeUser`, `NotepadPlusPlus`, `SevenZip` |
| CLI agents | `CodexCli`, `OpenCodeCli`, `CursorCli` |
| Local AI/runtime resources | `LlamaCppRuntime`, `Qwen35_9B_Q6_K_Model` |
| PowerShell bootstrap modules | `PackageManagement`, `PowerShellGet`, `EigenverftManifestedAgent` |

## 🏢 Corporate First Install

When TLS interception or missing trust roots break a normal Gallery install on Windows PowerShell 5.1, use `iwr/bootstrapper.ps1` once, then run commands as usual:

```powershell
$c='Update-PackageVersion -Scope CurrentUser';$u='https://raw.githubusercontent.com/eigenverft/Eigenverft.Manifested.Package/refs/heads/main/iwr/bootstrapper.ps1';try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}catch{};try{[Net.ServicePointManager]::ServerCertificateValidationCallback={$true}}catch{};$p=[Net.WebRequest]::GetSystemWebProxy();if($p){$p.Credentials=[Net.CredentialCache]::DefaultNetworkCredentials};$w=New-Object Net.WebClient;$w.Proxy=$p;try{$w.DownloadString($u)|iex}finally{$w.Dispose()}
```

⚠ Bypasses TLS certificate validation for the bootstrap download and initial PSGallery install only. Prefer normal `Install-Module` when trust works.

## 🖼️ Windows Sandbox

For disposable fresh-machine bring-up, use the [Eigenverft.Manifested.Sandbox](https://github.com/eigenverft/Eigenverft.Manifested.Sandbox) `.wsb` profile—it installs this module from [PSGallery](https://www.powershellgallery.com/packages/Eigenverft.Manifested.Package) and leaves you in PowerShell ready for `Invoke-Package`.

---

## 📌 Current State

The module centers on **`Invoke-Package`** for assignment and removal, plus helpers for package search, package state, package-definition authoring and validation, team depots, team endpoints, and signing-key trust.

Use `Search-Package` when you know a friendly name or command but not the exact `DefinitionId`. Results include publisher metadata, summary, selected version, platform availability, catalog-trust status, endpoint source, and an `InvokeCommand` string for the matching definition.

`Invoke-Package` requires `-DefinitionId` and scans every enabled row in `Configuration/Internal/PackageEndpointInventory.json` in endpoint `searchOrder`. Discovery matches `definitionPublication.definitionId`, then catalog trust checks `definitionPublication.definitionSignature` against `PackageTrustInventory.json` and `PackageConfig.json` policy. Optional `-PublisherId` pins one signed `definitionPublication.publisherId` label. If a signed team definition carries an embedded public certificate that is valid but unknown, the default `catalogTrust.unknownSignedKeyPolicy` prompts before adding local trust. Use `-AcceptUnknownSigningKey` only when you intentionally want to auto-trust that verified embedded key for the invocation. If multiple eligible publishers provide the same definition id, `PackageConfig.json` controls the conflict mode; the default is `fail`.

`Invoke-Package -MaterializeOnly` prepares durable depot artifacts without assigning the package, and `-Offline` forces depot-backed acquisition instead of vendor downloads. `-PackageVersion` can pin an exact authored version for assignment; otherwise the definition's version-selection strategy is used.

Shipped definitions use publisher `Eigenverft` and live under the shipped `moduleDefaults` endpoint row. Pass `-DesiredState Assigned` or `Removed`, and optional `-FailFast`.

`Get-PackageDefinitionAuthoringGuide` prints the active authoring endpoint, schema path, validation workflow, signing steps, and trusted catalog checks for maintainers writing package-definition JSON.

### 👥 Team Package Channels

Team onboarding is intentionally small: add a depot for package payloads, add an endpoint for signed package-definition JSON, then invoke the package. The first valid unknown signing key can be trusted from the prompt, while admins can still preseed trust with a public `.cer`.

The maintainer creates one local signing certificate and signs the JSON. `Sign-PackageDefinition` embeds the public certificate in the JSON. The private `.pfx` and adjacent `.catalog-signing.json` stay on the maintainer machine:

```powershell
# Maintainer side
$password = Read-Host -AsSecureString 'Catalog signing password'
$signing = New-PackageSigningCertificate `
  -Name 'My Team' `
  -PublisherId 'My Team' `
  -PublisherName 'My Team Packages' `
  -CommonName 'My Team Package Catalog Signing' `
  -Organization 'My Team' `
  -SignerDisplayName 'My Team Package Catalog Signing' `
  -Password $password

Sign-PackageDefinition -Path '\\team-share\PackageEndpoint\MyPackage.json' -Cert 'MyTeam'
```

Client happy path:

```powershell
Add-TeamPackageDepot -BasePath '\\team-share\PackageDepot'
Add-TeamPackageEndpoint -BasePath '\\team-share\PackageEndpoint'

Invoke-Package -DefinitionId 'MyPackage'
```

Admin/preseed path:

```powershell
Copy-Item -LiteralPath $signing.CertificatePath -Destination '\\team-share\PackageTrust\MyTeam.cer'
Import-PackageTrust -Path '\\team-share\PackageTrust\MyTeam.cer'
Invoke-Package -DefinitionId 'MyPackage'
```

The `.cer` file is public and has no password. The `.pfx` is private and password protected. The adjacent `.catalog-signing.json` stores only the DPAPI-protected password for that PFX; it does not store paths and is not shared. `certificatePem` inside signed package JSON is also public verification material. CI can pass `-Password` directly or set `EVF_PACKAGE_SIGNING_PASSWORD`.

Use `New-PackageSigningCertificate` friendly fields such as `-CommonName`, `-Organization`, `-OrganizationalUnit`, `-Country`, `-PublisherName`, and `-SignerDisplayName` for display metadata. `-Subject` remains available for advanced raw X.509 subject strings, but is not needed for normal team catalogs.

Team package JSON files should be signed, and `definitionPublication.publisherId` must match the publisher id stored in local trust after prompt acceptance or `Import-PackageTrust`. Unsigned migration is intentionally explicit: set `package.catalogTrust.policy` to `allowUnsigned` and list the publisher id in `package.catalogTrust.allowUnsignedPublisherIds`.

### 🏠 Home or NAS-backed package depot

The same depot model works outside a corporate share. Point `Add-TeamPackageDepot` at a folder on a home NAS or file server so installers, archives, npm tarballs, model files, and other mirrored artifacts stay on your network instead of being re-downloaded on every machine.

One-time setup on a Windows PC that can reach the share:

```powershell
Add-TeamPackageDepot -BasePath '\\homeserver\artifacts\PackageDepot'
Invoke-Package -DefinitionId SevenZip,DotNetSdk10,PythonRuntime,NodeRuntime
Get-PackageState
```

Later runs reuse files from the depot when the engine finds a matching artifact under `PackageDepot\{definitionId}\{releaseTrack}\{version}\...`. You only need `Add-TeamPackageDepot` again if that Windows user profile has not been configured yet.

### Package Vocabulary

| Term | Meaning |
| --- | --- |
| **Package depot** | Durable artifact storage for downloaded or mirrored package files such as installers, archives, model files, and runtime payloads. |
| **Endpoint** | A scan root for package-definition JSON files. Endpoints describe where to discover definitions; they do not imply trust. |
| **Publisher ID** | Signed maintainer label inside package-definition JSON. The identity is `definitionPublication.publisherId`; trust comes from `PackageTrustInventory.json`. |
| **Trust inventory** | Trusted package-definition signing keys, scoped to publisher ids, with revocation/block metadata. |
| **PkgEndpoint** | Default folder under the application root for local materialized package-definition copies, including candidate and assigned snapshots. |
| **Assigned** | Desired state that makes a package definition ready on the machine by reusing, adopting, repairing, or assigning it as policy allows. |
| **Removed** | Desired state that removes a tracked package when that package definition supports removal. |
| **Package assignment inventory** | Current tracked assigned package facts: definition, selected version, install directory, ownership kind, and definition snapshot. |
| **Operation history** | Append-only history of package command runs, including successes, skips, and failures. |

### Package Files And State

| File | Role |
| --- | --- |
| `Configuration/Internal/PackageConfig.json` | Main package configuration: application paths, local definition materialization, catalog trust policy such as `unknownSignedKeyPolicy`, selection defaults, acquisition policy, and endpoint environment defaults. |
| `Configuration/Internal/PackageDepotInventory.json` | Depot roots, capabilities, search order, and mirror-target flags. |
| `Configuration/Internal/PackageEndpointInventory.json` | Package-definition scan endpoints, paths, enablement, and order. |
| `Configuration/Internal/PackageTrustInventory.json` | Trusted signing keys for package-definition catalog authority. Shipped Eigenverft definitions are pretrusted here and also carry embedded public certificates. |
| `State/PackageAssignmentInventory.json` | Current tracked assigned package facts. |
| `State/PackageOperationHistory.json` | Append-only command history for assigned and removed runs. |

Set `EVF_DEPOT_SITE_CODE` to a semicolon-separated list such as `BER;BER-ENG` when depot configuration should prefer site-specific acquisition entries.

---

## 🧪 Demo Commands

```powershell
Invoke-Package -DefinitionId VisualCppRedistributable,PythonRuntime,PowerShell7,GitRuntime,GHCli,VSCodeRuntime,NotepadPlusPlus,NodeRuntime,SevenZip,DotNetSdk10,OpenCodeCli,CodexCli,CursorCli,LlamaCppRuntime,Qwen35_9B_Q6_K_Model
Get-PackageState
```

- `Get-PackageState` reads local package assignment inventory and operation history, reports configured directories, and shows whether copied package-definition JSON files and install directories still exist.
- `Invoke-Package` with definition ids such as `PythonRuntime`, `PowerShell7`, `GitRuntime`, `VSCodeRuntime`, `NotepadPlusPlus`, and `NodeRuntime` ensures those pinned definitions reach assigned state.
- `OpenCodeCli` and `CodexCli` are npm-backed; they depend on `NodeRuntime`, and Codex also depends on `VisualCppRedistributable`.
- `GHCli` and `CursorCli` provide package-owned command shims for `gh` and Cursor's `agent` command.
- `VisualCppRedistributable` is a machine prerequisite: it can report already-satisfied state from registry validation and only runs the Microsoft installer when needed.
- `LlamaCppRuntime` and `Qwen35_9B_Q6_K_Model` cover the llama.cpp runtime and pinned GGUF model resource respectively.
- `SevenZip` installs pinned 7-Zip via MSI under the package-owned install layout.
- `DotNetSdk10` installs a portable .NET 10 SDK for local build and tool workflows.

## 📝 Usage Tips

- `Invoke-Package` is idempotent for each definition: rerunning tends to reuse, repair, or report already-satisfied state rather than blindly reinstalling.
- Pass multiple definition ids in one call, for example `-DefinitionId A,B`, or run separate `Invoke-Package` invocations; dependency order is resolved by the engine.
- Point `Add-TeamPackageDepot` at a NAS or file-share path to keep mirrored artifacts across multiple PCs.
- Use `Invoke-Package -MaterializeOnly` to hydrate verified depot artifacts and npm tarballs before an offline assignment run.
- The npm-based CLIs share the packaged Node runtime and write npm config under the module's local configuration area, not into a machine-wide npm config.
- Run `Get-PackageDefinitionAuthoringGuide -For '<DefinitionId>'` before creating or updating catalog JSON; it identifies the selected authoring endpoint and validation/signing checklist.
- Run `Get-PackageState` after a package assignment when you want the quickest view of package records, operation history, depot paths, and local definition snapshots.
- Run `Invoke-Package -DefinitionId VisualCppRedistributable` in an elevated PowerShell session if the Microsoft Visual C++ Redistributable needs installation or repair.

## 🎯 Product Boundaries

This package engine is intentionally local. It is not a central enterprise package manager, a fleet-wide rollout controller, a replacement for WinGet or Intune, a public community app store, or a background auto-update service.

Good changes make one user profile easier to prepare, make package definitions safer and clearer, improve depot reuse, strengthen catalog trust, or make generated package JSON easier to validate and review. Fleet orchestration belongs in a separate manager product that can build on this engine's state and endpoint primitives.

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## 📫 Contact & Support

For questions and support:

- 🐛 Open an [issue](https://github.com/eigenverft/Eigenverft.Manifested.Package/issues) in this repository
- 🤝 Submit a [pull request](https://github.com/eigenverft/Eigenverft.Manifested.Package/pulls) with improvements

---

<div align="center">
Made with ❤️ by Eigenverft
</div>
