# Eigenverft.Manifested.Package

[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/Eigenverft.Manifested.Package?label=PSGallery&logo=powershell)](https://www.powershellgallery.com/packages/Eigenverft.Manifested.Package) [![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/Eigenverft.Manifested.Package?label=Downloads&logo=powershell)](https://www.powershellgallery.com/packages/Eigenverft.Manifested.Package) [![PowerShell Support](https://img.shields.io/badge/PowerShell-5.1%2B%20Desktop%2FCore-5391FE?logo=powershell&logoColor=white)](#requirements) [![Build Status](https://img.shields.io/github/actions/workflow/status/eigenverft/Eigenverft.Manifested.Package/cicd.yml?branch=main&label=build)](https://github.com/eigenverft/Eigenverft.Manifested.Package/actions/workflows/cicd.yml) [![License](https://img.shields.io/github/license/eigenverft/Eigenverft.Manifested.Package?logo=mit)](LICENSE) [![Windows Sandbox profile](https://img.shields.io/badge/Windows%20Sandbox-profile-0078D4?logo=windows)](https://github.com/eigenverft/Eigenverft.Manifested.Sandbox)

Windows-focused PowerShell package engine for repeatable developer-machine setup. It uses explicit package-definition JSON, trusted publishers, configurable package endpoints, reusable depots, and local inventory so a toolchain can be assigned, rerun, audited, and removed with predictable behavior.

The product sits between public package managers and heavy endpoint-management systems: more governed than ad-hoc installer scripts, more local and team-owned than a public community bucket, and intentionally smaller than a fleet rollout controller.

🚀 **Key Features:**

- Local package assignment through `Invoke-Package`
- Inventory-backed state and operation history through `Get-PackageState`
- Versioned, reviewable package-definition JSON
- Trusted publisher records for package-definition authority
- File-based depots for reusing installers, archives, npm tarballs, models, and runtime payloads
- Team and web package endpoints as the extension model for larger catalogs
- Offline and controlled-network workflows that can be backed by a prepared depot
- Package-backed provisioning for `python`, `pwsh`, `git`, `gh`, `code`, `notepad++`, `node`, `npm`, `dotnet` (SDK 10), `7z`, `opencode`, `gemini`, `qwen`, `codex`, Qwen GGUF model resources, llama.cpp, and VC++ prerequisites
- Package-owned installs with explicit reuse, adoption, repair, assignment, and removal behavior
- Proxy-aware downloads through `Invoke-WebRequestEx` for managed or corporate Windows environments

## 🧭 Motivation

Preparing a Windows development environment should not depend on a long sequence of hand-maintained install notes. Teams need a way to say which tools are trusted, where package definitions come from, where package payloads are cached, and what happened during the last run.

This project packages that workflow as a local PowerShell engine. A human or agent can maintain package JSON, CI can validate it, a team can publish it through an endpoint, and each machine can explicitly assign the packages it needs without turning the module into central fleet management.

<a id="requirements"></a>

## 🖥️ Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Windows 10/11
- Network access to configured package sources, or a depot that already contains the needed payloads
- Administrator rights only for package definitions that require machine-level installers or prerequisites

## 🚀 Quick Start

Install or import the module, then assign one or more package definitions:

```powershell
Install-Module Eigenverft.Manifested.Package -Scope CurrentUser -Repository PSGallery
Import-Module Eigenverft.Manifested.Package

Invoke-Package -DefinitionId SevenZip,DotNetSdk10,NodeRuntime,CodexCli
Get-PackageState
```

`Invoke-Package` resolves the selected package definitions from enabled endpoints, checks publisher trust, prepares or reuses package payloads, applies dependency ordering, and records the resulting package state.

## 🏢 Corporate First Install

On a locked-down Windows PowerShell 5.1 machine where TLS interception or missing trust roots break the first Gallery install, use the skip-certificate bootstrapper only long enough to install the package module and open a fresh console that runs `Package -Update`:

```powershell
$c='Package -Update -Scope CurrentUser';$u='https://raw.githubusercontent.com/eigenverft/Eigenverft.Manifested.Package/refs/heads/main/iwr/bootstrapper.package.generic.skipcert.ps1';try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}catch{};try{[Net.ServicePointManager]::ServerCertificateValidationCallback={$true}}catch{};$p=[Net.WebRequest]::GetSystemWebProxy();if(-not $p.IsBypassed($u)){iwr $u -Proxy ($p.GetProxy($u).AbsoluteUri) -ProxyUseDefaultCredentials -UseBasicParsing|iex}else{iwr $u -UseBasicParsing|iex}
```

⚠ **Important:** This path intentionally bypasses TLS certificate validation for the bootstrap download and initial PSGallery install. Prefer normal `Install-Module` when the machine trust chain works.

## 🖼️ Windows Sandbox

For disposable fresh-machine bring-up, use the [Eigenverft.Manifested.Sandbox](https://github.com/eigenverft/Eigenverft.Manifested.Sandbox) `.wsb` profile—it installs this module from [PSGallery](https://www.powershellgallery.com/packages/Eigenverft.Manifested.Package) and leaves you in PowerShell ready for `Invoke-Package`.

---

## 📌 Current State

The module centers on **`Invoke-Package`** for assignment and removal, plus helpers for package state, team depots, team endpoints, and publisher trust.

`Invoke-Package` requires `-DefinitionId` and scans every enabled row in `Configuration/Internal/PackageEndpointInventory.json` in endpoint `searchOrder`. Discovery matches `definitionPublication.definitionId`, then filters to publishers trusted in `PackagePublisherInventory.json`. Optional `-PublisherId` pins one publisher. If multiple trusted publishers provide the same definition id, `PackageConfig.json` controls the conflict mode; the default is `fail`.

Shipped definitions use publisher `Eigenverft` and live under the shipped `moduleDefaults` endpoint row. Pass `-DesiredState Assigned` or `Removed`, and optional `-FailFast`.

### 👥 Team Package Channels

Team onboarding is intentionally small: add a depot for package payloads, add an endpoint for package-definition JSON, then trust the team publisher identity used inside those JSON files.

```powershell
Add-TeamPackageDepot -BasePath '\\team-share\PackageDepot'
Add-TeamPackageEndpoint -BasePath '\\team-share\PackageEndpoint'
Add-TeamPackagePublisher -PublisherId 'My Team'

Invoke-Package -DefinitionId 'OtherTextEditorFromTeamRepos'
```

Team package JSON files must set `definitionPublication.publisherId` to the same value, for example `My Team`.

### 🏠 Home or NAS-backed package depot

The same depot model works outside a corporate share. Point `Add-TeamPackageDepot` at a folder on a home NAS or file server so installers, archives, npm tarballs, model files, and other mirrored artifacts stay on your network instead of being re-downloaded on every machine.

One-time setup on a Windows PC that can reach the share:

```powershell
Import-Module Eigenverft.Manifested.Package

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
| **Publisher** | Trusted package-definition authority from `PackagePublisherInventory.json`. The identity is `definitionPublication.publisherId`. |
| **PkgEndpoint** | Default folder under the application root for local materialized package-definition copies, including candidate and assigned snapshots. |
| **Assigned** | Desired state that makes a package definition ready on the machine by reusing, adopting, repairing, or assigning it as policy allows. |
| **Removed** | Desired state that removes a tracked package when that package definition supports removal. |
| **Package assignment inventory** | Current tracked assigned package facts: definition, selected version, install directory, ownership kind, and definition snapshot. |
| **Operation history** | Append-only history of package command runs, including successes, skips, and failures. |

### Package Files And State

| File | Role |
| --- | --- |
| `Configuration/Internal/PackageConfig.json` | Main package configuration: application paths, local definition materialization, selection defaults, acquisition policy, and endpoint environment defaults. |
| `Configuration/Internal/PackageDepotInventory.json` | Depot roots, capabilities, search order, and mirror-target flags. |
| `Configuration/Internal/PackageEndpointInventory.json` | Package-definition scan endpoints, paths, enablement, and order. |
| `Configuration/Internal/PackagePublisherInventory.json` | Package-definition publisher trust policy. |
| `State/PackageAssignmentInventory.json` | Current tracked assigned package facts. |
| `State/PackageOperationHistory.json` | Append-only command history for assigned and removed runs. |

Set `EVF_DEPOT_SITE_CODE` to a semicolon-separated list such as `BER;BER-ENG` when depot configuration should prefer site-specific acquisition entries.

---

## 🧪 Demo Commands

```powershell
Invoke-Package -DefinitionId VisualCppRedistributable,PythonRuntime,PowerShell7,GitRuntime,VSCodeRuntime,NotepadPlusPlus,NodeRuntime,SevenZip,DotNetSdk10,OpenCodeCli,CodexCli,LlamaCppRuntime,Qwen35_9B_Q6_K_Model
Get-PackageState
```

- `Get-PackageState` reads local package assignment inventory and operation history, reports configured directories, and shows whether copied package-definition JSON files and install directories still exist.
- `Invoke-Package` with definition ids such as `PythonRuntime`, `PowerShell7`, `GitRuntime`, `VSCodeRuntime`, `NotepadPlusPlus`, and `NodeRuntime` ensures those pinned definitions reach assigned state.
- `OpenCodeCli` and `CodexCli` are npm-backed; they depend on `NodeRuntime`, and Codex also depends on `VisualCppRedistributable`.
- `VisualCppRedistributable` is a machine prerequisite: it can report already-satisfied state from registry validation and only runs the Microsoft installer when needed.
- `LlamaCppRuntime` and `Qwen35_9B_Q6_K_Model` cover the llama.cpp runtime and pinned GGUF model resource respectively.
- `SevenZip` installs pinned 7-Zip via MSI under the package-owned install layout.
- `DotNetSdk10` installs a portable .NET 10 SDK for local build and tool workflows.

## 📝 Usage Tips

- `Invoke-Package` is idempotent for each definition: rerunning tends to reuse, repair, or report already-satisfied state rather than blindly reinstalling.
- Pass multiple definition ids in one call, for example `-DefinitionId A,B`, or run separate `Invoke-Package` invocations; dependency order is resolved by the engine.
- Point `Add-TeamPackageDepot` at a NAS or file-share path to keep mirrored artifacts across multiple PCs.
- The npm-based CLIs share the packaged Node runtime and write npm config under the module's local configuration area, not into a machine-wide npm config.
- Run `Get-PackageState` after a package assignment when you want the quickest view of package records, operation history, depot paths, and local definition snapshots.
- Run `Invoke-Package -DefinitionId VisualCppRedistributable` in an elevated PowerShell session if the Microsoft Visual C++ Redistributable needs installation or repair.

## 🎯 Product Boundaries

This package engine is intentionally local. It is not a central enterprise package manager, a fleet-wide rollout controller, a replacement for WinGet or Intune, a public community app store, or a background auto-update service.

Good changes make one user profile easier to prepare, make package definitions safer and clearer, improve depot reuse, strengthen endpoint trust, or make generated package JSON easier to validate and review. Fleet orchestration belongs in a separate manager product that can build on this engine's state and endpoint primitives.

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
