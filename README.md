# Eigenverft.Manifested.Sandbox

[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/Eigenverft.Manifested.Sandbox?label=PSGallery&logo=powershell)](https://www.powershellgallery.com/packages/Eigenverft.Manifested.Sandbox) [![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/Eigenverft.Manifested.Sandbox?label=Downloads&logo=powershell)](https://www.powershellgallery.com/packages/Eigenverft.Manifested.Sandbox) [![PowerShell Support](https://img.shields.io/badge/PowerShell-5.1%2B%20Desktop%2FCore-5391FE?logo=powershell&logoColor=white)](src/prj/Eigenverft.Manifested.Sandbox/Eigenverft.Manifested.Sandbox.psd1) [![Build Status](https://img.shields.io/github/actions/workflow/status/eigenverft/Eigenverft.Manifested.Sandbox/cicd.yml?branch=main&label=build)](https://github.com/eigenverft/Eigenverft.Manifested.Sandbox/actions/workflows/cicd.yml) [![License](https://img.shields.io/github/license/eigenverft/Eigenverft.Manifested.Sandbox?logo=mit)](LICENSE)

Windows-focused PowerShell module and repository-shipped Windows Sandbox profile for quickly turning a fresh Windows Sandbox session into a usable development environment. The primary user entrypoint is the downloadable `.wsb` file in this repo, backed by a PowerShell module that can provision managed Python, PowerShell 7, Node.js, .NET SDK 10, 7-Zip, OpenCode CLI, Gemini CLI, Qwen CLI, Codex CLI, GitHub CLI, MinGit, VS Code, Notepad++, and Microsoft Visual C++ runtime prerequisites when you want them.

The primary intent is fast, repeatable setup inside Windows Sandbox. The same module can also run on a normal Windows machine, but that is a secondary use case rather than the main focus of this repo.

🚀 **Key Features:**
- Ready-to-download Windows Sandbox profile in the repo for repeatable bring-up
- Package-backed provisioning for `python`, `pwsh`, `git`, `gh`, `code`, `notepad++`, `node`, `npm`, `dotnet` (SDK 10), `7z`, `opencode`, `gemini`, `qwen`, `codex`, Qwen GGUF model resources, llama.cpp, and VC++ prerequisites
- Package state tracking through local package assignment inventory and operation history under `%LOCALAPPDATA%\Programs\Evf.Sandbox`
- Package depot plus endpoint definition layout that can reuse local artifacts and resolve package definitions from configured endpoints
- Managed npm ownership under the sandbox Node runtime, including proxy-aware npm configuration when Windows resolves the npm registry through a proxy
- Proxy-aware startup and download handling for managed or corporate Windows environments
- Compacted embedded startup helpers so the `.wsb` `LogonCommand` fits within the practical 8 KB command-line limit
- PowerShell 5.1-first sandbox startup path with normal Windows machine support as a secondary workflow

## 🧭 Motivation

Windows Sandbox is ideal for disposable setup checks: bootstrap a repo, validate installer behavior, and test fresh-machine assumptions without touching your main workstation.

The problem is that a blank `.wsb` session still takes manual work to become useful, and in many corporate environments the first outbound connection is the hard part. Proxy discovery, proxy authentication, certificate friction, and Windows PowerShell bootstrap work often show up before the real task starts. This project packages that repeated startup story into a versioned `.wsb` profile plus a supporting PowerShell module so the environment is quick to reuse instead of tedious to rebuild.

## 🖥️ Host Requirements

Windows Sandbox on the host requires Windows 10/11 `1903+`, Pro/Enterprise/Education/Pro Education/SE, virtualization enabled, 4 GB RAM, 1 GB free disk, 2 CPU cores, and the `Windows Sandbox` feature enabled.

## 🖼️ Preview

![Windows Sandbox preview showing the repo-provided sandbox profile opening PowerShell and a follow-up runtime command](resources/screenshots/windows-sandbox-bootstrap-preview.png)

Example Windows Sandbox session after the repository's `.wsb` profile opens PowerShell and the follow-up runtime commands are available.

---

## 🚀 Quick Start

1. Download the sandbox profile: [Eigenverft.Manifested.Sandbox.wsb](src/wrk/Eigenverft.Manifested.Sandbox/Eigenverft.Manifested.Sandbox.wsb) or [raw .wsb download](https://raw.githubusercontent.com/eigenverft/Eigenverft.Manifested.Sandbox/refs/heads/main/src/wrk/Eigenverft.Manifested.Sandbox/Eigenverft.Manifested.Sandbox.wsb)
2. Before first launch, edit the file for your environment, especially the integration/security toggles, optional mapped folders, and startup defaults shown below.
3. Launch the `.wsb` file from Windows.
4. When the sandbox opens PowerShell, run the follow-up runtime commands you want.

### 🔧 Customize the `.wsb`

This is the main pre-launch customization point. Most users only need to review the integration toggles, decide whether they want any host folder mapping, and edit the four startup defaults inside `LogonCommand`.

```powershell
$dprx='http://test.corp.com:8080'
$duprx=''
$c='Get-SandboxVersion'
$i='PackageManagement','PowerShellGet','Eigenverft.Manifested.Sandbox'
```

| Setting | Default | What it controls |
| --- | --- | --- |
| `$dprx` | `http://test.corp.com:8080` | Default manual proxy address shown if startup resolves to a manual-proxy-required path. |
| `$duprx` | `''` | Prefills the proxy user field so a manual proxy prompt can require less typing. |
| `$c` | `Get-SandboxVersion` | Post-bootstrap command or semicolon-separated command chain executed in the fresh PowerShell window. |
| `$i` | `PackageManagement`, `PowerShellGet`, `Eigenverft.Manifested.Sandbox` | Module list requested by the embedded bootstrap step. It currently matches the built-in default inside `Initialize-Bootstrap`, so most users can leave it unchanged. |

### 🔐 Security Notes for the `.wsb`

This shipped `.wsb` is a convenience and testing profile first, not a hardened security-analysis profile.

A useful sandbox always needs some transfer path for content to come in and results to go back out. In practice that usually means `Networking`, `MappedFolders`, `ClipboardRedirection`, or some combination of them. This profile keeps `Networking` enabled because bootstrap, proxy resolution, and package download are the main use case.

`MappedFolders` is commented out by default. If you enable it, prefer a dedicated staging folder and keep `<ReadOnly>true</ReadOnly>` unless sandbox write-back is actually required. Writable mappings expose real host files to whatever runs inside the sandbox.

`ClipboardRedirection`, `PrinterRedirection`, `AudioInput`, `VideoInput`, and `VGpu` are convenience features. Turn off anything you do not need for the current run. `ProtectedClient` is enabled as an extra hardening layer, but it can restrict some host interaction flows.

If startup falls back to a manual proxy prompt, the resolved proxy profile is stored at `%LOCALAPPDATA%\Programs\ProxyAccessProfile\ProxyAccessProfile.clixml`. It is written with `Export-Clixml`, so on Windows the `PSCredential` stays bound to that sandbox user and sandbox instance. This is useful across in-sandbox restarts, but the whole sandbox is discarded when it is closed.

⚠ **Important:** If you entered manual proxy credentials and then want to continue with suspicious or unknown payload testing in the same sandbox, delete `%LOCALAPPDATA%\Programs\ProxyAccessProfile\ProxyAccessProfile.clixml` first. If the later test phase no longer needs the stored proxy/bootstrap state, an even tighter option is to run that phase in a fresh sandbox instance.

For most users, these are the only startup values worth touching. Leave the embedded helper payload alone unless you are intentionally maintaining the startup chain itself.

### 💡 Common `$c` Recipes

Use `$c` when you want startup to do more than just show the module version.

```powershell
# Simple sanity check after bootstrap
$c='Get-SandboxVersion'

# Bootstrap, then prepare a fuller sandbox toolset (default endpoint is moduleDefaults; definitions under Endpoint/Defaults/Eigenverft)
$c='Get-SandboxVersion; Invoke-Package -DefinitionId VisualCppRedistributable,PythonRuntime,PowerShell7,GitRuntime,VSCodeRuntime,NotepadPlusPlus,NodeRuntime,SevenZip,DotNetSdk10,OpenCodeCli,CodexCli,LlamaCppRuntime,Qwen35_9B_Q6_K_Model; Get-PackageState'

# Lean dev baseline: archives, .NET SDK, Node/npm CLIs
$c='Get-SandboxVersion; Invoke-Package -DefinitionId SevenZip,DotNetSdk10,NodeRuntime,CodexCli; Get-PackageState'

# Bootstrap, then download and run another script
$c='Invoke-WebRequestEx -Uri ''https://example.org/setup.ps1'' -OutFile ""$env:TEMP\setup.ps1""; powershell -ExecutionPolicy Bypass -File ""$env:TEMP\setup.ps1""'
```

### 🧠 Why the Startup Logic Is Embedded

The original bootstrapper approach was useful groundwork, but the more practical onboarding artifact in this repository is now the ready `.wsb` file.

The embedded startup chain exists because many managed corporate environments do not have a reliable first outbound connection. Proxy discovery, proxy authentication, certificate friction, and resilient download behavior are the real hurdles before any runtime install work begins.

`Initialize-ProxyCompact` in the `.wsb` is a highly compacted form of nearly the same proxy-resolution logic as `Initialize-ProxyAccessProfile`, and `Invoke-WebRequestEx` is the readable download-side reference in the module. `Initialize-Bootstrap` is still part of the embedded startup chain, but it is background implementation rather than the recommended public entrypoint.

When manual proxy entry is required, that resolved proxy profile stays inside the current sandbox instance and can survive in-sandbox restarts, but it is still discarded when the sandbox is closed.

The startup helpers are compacted and compressed so the Windows Sandbox `LogonCommand` stays within the practical 8 KB command-line limit. The tracked `.wsb` file in this repository is the authoritative version to download and edit, so the README intentionally does not reproduce the full embedded command blob.

---

## 📌 Current State

The module exports a single package dispatcher, **`Invoke-Package`**, plus helpers such as **`Get-PackageState`**, **`Get-SandboxVersion`**, **`Sandbox`**, and **`Invoke-WebRequestEx`**.

`Invoke-Package` requires `-DefinitionId` and scans every **enabled** row in `Configuration/Internal/PackageEndpointInventory.json` in endpoint `searchOrder`. Discovery matches `definitionPublication.definitionId`, then filters to publishers trusted in `PackagePublisherInventory.json`. Optional `-PublisherId` pins one publisher. If multiple trusted publishers provide the same definition id, `PackageConfig.json` controls the conflict mode; the default is `fail`. Shipped definitions use publisher `Eigenverft` and live under `Endpoint\Defaults\Eigenverft` behind the shipped `moduleDefaults` endpoint row. Pass `-DesiredState Assigned` or `Removed`, and optional `-FailFast`.

Team onboarding is intentionally short: add a depot for package payloads, add an endpoint for package definition JSON, then trust the team publisher identity used inside those JSON files.

```powershell
Add-TeamPackageDepot -BasePath '\\team-share\PackageDepot'
Add-TeamPackageEndpoint -BasePath '\\team-share\PackageEndpoint'
Add-TeamPackagePublisher -PublisherId 'My Team'
Invoke-Package -DefinitionId 'OtherTextEditorFromTeamRepos'
```

Team package JSON files must set `definitionPublication.publisherId` to the same value, for example `My Team`.

### Home or NAS-backed package depot

The same depot model works outside a corporate share. Point `Add-TeamPackageDepot` at a folder on a home NAS or file server so installers, archives, npm tarballs, and other mirrored artifacts stay on your network instead of being re-downloaded on every fresh machine or sandbox run.

One-time setup on a Windows PC that can reach the share (your daily workstation is fine):

```powershell
Import-Module Eigenverft.Manifested.Sandbox

# UNC path to a dedicated folder on the NAS, e.g. \\homeserver\artifacts\PackageDepot
Add-TeamPackageDepot -BasePath '\\homeserver\artifacts\PackageDepot'

# First run: downloads into the local sandbox layout and mirrors into the NAS depot
Invoke-Package -DefinitionId SevenZip,DotNetSdk10,PythonRuntime,NodeRuntime

Get-PackageState
```

Later runs (same PC, another profile, or Windows Sandbox after bootstrap) reuse files from the depot when the engine finds a matching artifact under `PackageDepot\{definitionId}\{releaseTrack}\{version}\…`. You only need `Add-TeamPackageDepot` again if that Windows user profile has not been configured yet; the depot path is stored under `%LOCALAPPDATA%\Programs\Evf.Sandbox\Configuration\Internal\PackageDepotInventory.json`.

For sandbox-only use, run `Add-TeamPackageDepot` inside the sandbox session as well (sandbox state is discarded when the VM closes, but the NAS depot content remains).

`Get-SandboxVersion` prints the module version, example `Invoke-Package` lines for each shipped definition discovered on disk, and the remaining exported commands.

### Package Vocabulary

| Term | Meaning |
| --- | --- |
| **Package depot** | Durable artifact storage for downloaded or mirrored package files such as installers, archives, model files, and runtime payloads. The default local depot folder is `PkgDepot`. |
| **Endpoint** | A scan root for package definition JSON files. Endpoints describe where to discover definitions; they do not imply trust. |
| **Publisher** | Trusted package-definition authority from `PackagePublisherInventory.json`. The identity is `definitionPublication.publisherId`. |
| **PkgEndpoint** | Default folder under the application root for **local** materialized package-definition copies (Candidate and Assigned snapshots). This is not a remote discovery endpoint. Renamed from `PkgRepos`; migrate files manually if you relied on the old path. |
| **Assigned** | Desired state that makes a package definition ready on the machine by reusing, adopting, repairing, or assigning it as policy allows. |
| **Removed** | Desired state that removes a tracked package when that package definition supports removal. |
| **Package assignment inventory** | Current tracked **Assigned** package facts: definition, selected version, install directory, ownership kind, and definition snapshot. |
| **Operation history** | Append-only history of package command runs, including successes, skips, and failures. |

### Package Files And State

| File | Role |
| --- | --- |
| `Configuration/Internal/PackageConfig.json` | Main package configuration: application paths, `localEndpointRoot` (local definition materialization), selection defaults, acquisition policy, and `endpointEnvironment` defaults. |
| `Configuration/Internal/PackageDepotInventory.json` | Depot roots, capabilities, search order, and mirror-target flags. |
| `Configuration/Internal/PackageEndpointInventory.json` | Package definition scan endpoints (paths, enablement, order). |
| `Configuration/Internal/PackagePublisherInventory.json` | Package definition publisher trust policy. |
| `Configuration/External/PackageSourceInventory.json` | Optional external/site acquisition overlays; can be overridden with `EIGENVERFT_MANIFESTED_PACKAGE_SOURCE_INVENTORY_PATH`. |
| `State/PackageAssignmentInventory.json` | Current tracked **Assigned** package facts. |
| `State/PackageOperationHistory.json` | Append-only command history for **Assigned** and **Removed** runs. |

---

## 🧪 Demo Commands

After the repository's `.wsb` profile opens the new console, run:

```powershell
Get-SandboxVersion
Invoke-Package -DefinitionId VisualCppRedistributable,PythonRuntime,PowerShell7,GitRuntime,VSCodeRuntime,NotepadPlusPlus,NodeRuntime,SevenZip,DotNetSdk10,OpenCodeCli,CodexCli,LlamaCppRuntime,Qwen35_9B_Q6_K_Model
Get-PackageState
```

- `Get-SandboxVersion` shows the module version, example `Invoke-Package -DefinitionId '…'` lines for shipped definitions, and other exported commands.
- `Get-PackageState` reads local package assignment inventory and operation history, reports configured directories, and shows whether copied package definition JSON files and install directories still exist.
- `Invoke-Package` with definition ids such as `PythonRuntime`, `PowerShell7`, `GitRuntime`, `VSCodeRuntime`, `NotepadPlusPlus`, and `NodeRuntime` ensures those pinned definitions reach **Assigned** (reuse, repair, adoption, or assignment per each definition’s policy).
- `OpenCodeCli` and `CodexCli` are npm-backed; they depend on `NodeRuntime`, and Codex’s definition also depends on `VisualCppRedistributable`.
- `VisualCppRedistributable` is a machine prerequisite: it can report already-satisfied state from registry validation and only runs the Microsoft installer when needed.
- `LlamaCppRuntime` and `Qwen35_9B_Q6_K_Model` cover the llama.cpp runtime and pinned GGUF model resource respectively.
- `SevenZip` installs pinned 7-Zip (`7z`, `7zFM`, `7zG`) via MSI under the package-owned install layout.
- `DotNetSdk10` installs a portable .NET 10 SDK (`dotnet` on PATH) for local build and tool workflows (for example Codex-assisted repo tasks).

## 📦 Direct Module Usage

If you prefer installing the module directly instead of using the `.wsb` profile:

This path assumes working access to `PSGallery` and the `NuGet` package provider. If first-connection proxy, authentication, or trust-chain setup is still the main hurdle, prefer the `.wsb` path above.

```powershell
Install-Module Eigenverft.Manifested.Sandbox -Scope CurrentUser -Repository PSGallery
Import-Module Eigenverft.Manifested.Sandbox
```

## 📝 Usage Tips

- `Invoke-Package` is idempotent for each definition: rerunning tends to reuse, repair, or report already-satisfied state rather than blindly reinstalling.
- Pass multiple definition ids in one call (e.g. `-DefinitionId A,B`) or run separate `Invoke-Package` invocations; dependency order is resolved by the engine.
- OpenCode, Qwen, and Codex are opt-in in the example chains; add or drop `-DefinitionId` values for the sandbox profile you want.
- `SevenZip` and `DotNetSdk10` are optional in the large demo chain; use them when you need archive tooling or a managed `dotnet` SDK without a separate installer run.
- Point `Add-TeamPackageDepot` at a NAS UNC path to keep mirrored artifacts across sandbox resets and multiple PCs (see **Home or NAS-backed package depot** above).
- The npm-based CLIs share the packaged Node runtime and write npm config under the module's local configuration area, not into a machine-wide npm config.
- To test another branch, swap `main` in the raw `.wsb` download URL before launching the sandbox.
- If you are working from a local checkout instead of the raw download, edit the tracked `.wsb` file directly and launch that local copy.
- Keep `.wsb` files small and let versioned PowerShell own the real startup logic whenever you want a more maintainable sandbox launch path.
- Run `Get-PackageState` after a bootstrap chain when you want the quickest view of package records, operation history, depot/repository paths, and local definition snapshots.
- Run `Invoke-Package -DefinitionId VisualCppRedistributable` in an elevated PowerShell session if the Microsoft Visual C++ Redistributable needs installation or repair.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📫 Contact & Support

For questions and support:
- 🐛 Open an [issue](https://github.com/eigenverft/Eigenverft.Manifested.Sandbox/issues) in this repository
- 🤝 Submit a [pull request](https://github.com/eigenverft/Eigenverft.Manifested.Sandbox/pulls) with improvements

---

<div align="center">
Made with ❤️ by Eigenverft
</div>
