<#
    Eigenverft.Manifested.Package test import loader
#>

# Mirrors the module psm1 load order for repo-local testing.
$moduleProjectRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'Eigenverft.Manifested.Package'

# Generic ExecutionCore support
. "$moduleProjectRoot\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.StandardMessage.ps1"
. "$moduleProjectRoot\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.Stream.ps1"
. "$moduleProjectRoot\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.Json.ps1"
. "$moduleProjectRoot\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.Tar.ps1"
. "$moduleProjectRoot\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.GZip.ps1"
. "$moduleProjectRoot\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.Archive.ps1"
. "$moduleProjectRoot\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.CommandResolution.ps1"
. "$moduleProjectRoot\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.FileSystem.ps1"
. "$moduleProjectRoot\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.PathTemplate.ps1"
. "$moduleProjectRoot\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.Registry.ps1"
. "$moduleProjectRoot\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.SystemResources.ps1"
. "$moduleProjectRoot\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.Elevation.ps1"
. "$moduleProjectRoot\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.PathRegistration.ps1"
. "$moduleProjectRoot\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.Npm.ps1"
. "$moduleProjectRoot\Support\ExecutionCore\Eigenverft.Manifested.Package.ExecutionCore.InitializeProxyAccessProfile.ps1"

# Package support
. "$moduleProjectRoot\Support\ExecutionCore\Upstream\Eigenverft.Manifested.Package.ExecutionCore.Upstream.GitHubRelease.ps1"
. "$moduleProjectRoot\Support\Package\Execution\Eigenverft.Manifested.Package.Package.ExecutionMessage.ps1"
. "$moduleProjectRoot\Support\Package\Execution\Eigenverft.Manifested.Package.Package.Bootstrap.ps1"
. "$moduleProjectRoot\Support\Package\Execution\Eigenverft.Manifested.Package.Package.VersionSelection.ps1"
. "$moduleProjectRoot\Support\Package\Schema\Eigenverft.Manifested.Package.Package.Config.ps1"
. "$moduleProjectRoot\Support\Package\Schema\Eigenverft.Manifested.Package.Package.DepotInventory.Management.ps1"
. "$moduleProjectRoot\Support\Package\Schema\Eigenverft.Manifested.Package.Package.EndpointInventory.Management.ps1"
. "$moduleProjectRoot\Support\Package\Schema\Eigenverft.Manifested.Package.Package.PublisherInventory.Management.ps1"
. "$moduleProjectRoot\Support\Package\Schema\Eigenverft.Manifested.Package.Package.Trust.ps1"
. "$moduleProjectRoot\Support\Package\Schema\Eigenverft.Manifested.Package.Package.DefinitionReference.ps1"
. "$moduleProjectRoot\Support\Package\Schema\Eigenverft.Manifested.Package.Package.DefinitionSchema.Wire1_9.ps1"
. "$moduleProjectRoot\Support\Package\Schema\Eigenverft.Manifested.Package.Package.DefinitionSchema.ps1"
. "$moduleProjectRoot\Support\Package\Schema\Eigenverft.Manifested.Package.Package.DefinitionCatalogValidation.ps1"
. "$moduleProjectRoot\Support\Package\Execution\Eigenverft.Manifested.Package.Package.LocalEnvironment.ps1"
. "$moduleProjectRoot\Support\Package\Schema\Eigenverft.Manifested.Package.Package.Selection.ps1"
. "$moduleProjectRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Package.Package.Dependencies.ps1"
. "$moduleProjectRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Package.Package.DependencyPlan.ps1"
. "$moduleProjectRoot\Support\Package\Schema\Eigenverft.Manifested.Package.Package.Source.ps1"
. "$moduleProjectRoot\Support\Package\State\Eigenverft.Manifested.Package.Package.Ownership.ps1"
. "$moduleProjectRoot\Support\Package\State\Eigenverft.Manifested.Package.Package.OperationHistory.ps1"
. "$moduleProjectRoot\Support\Package\State\Eigenverft.Manifested.Package.Package.State.ps1"
. "$moduleProjectRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Package.Package.Readiness.ps1"
. "$moduleProjectRoot\Support\Package\Execution\Eigenverft.Manifested.Package.Package.Npm.ps1"
. "$moduleProjectRoot\Support\Package\Execution\Eigenverft.Manifested.Package.Package.PowerShellModule.ps1"
# Package install fragments (order-sensitive); orchestrator last - keep in sync with psm1
. "$moduleProjectRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Package.Package.Install.Existing.ps1"
. "$moduleProjectRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Package.Package.Install.Preparation.ps1"
. "$moduleProjectRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Package.Package.Install.Artifact.ps1"
. "$moduleProjectRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Package.Package.Install.InstallerEngine.ps1"
. "$moduleProjectRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Package.Package.Install.ps1"
. "$moduleProjectRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Package.Package.EntryPoints.ps1"
. "$moduleProjectRoot\Support\Package\Execution\Eigenverft.Manifested.Package.Package.Shims.ps1"
. "$moduleProjectRoot\Support\Package\Execution\Eigenverft.Manifested.Package.Package.PathRegistration.ps1"
. "$moduleProjectRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Package.Package.CommandFlow.ps1"
. "$moduleProjectRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Package.Package.Remove.ps1"

# Public commands
. "$moduleProjectRoot\Commands\Package\Eigenverft.Manifested.Package.Cmd.GetPackageState.ps1"
. "$moduleProjectRoot\Commands\Package\Eigenverft.Manifested.Package.Cmd.InvokePackage.ps1"
. "$moduleProjectRoot\Commands\Package\Eigenverft.Manifested.Package.Cmd.SearchPackage.ps1"
. "$moduleProjectRoot\Commands\Depot\Eigenverft.Manifested.Package.Cmd.PackageDepot.ps1"
. "$moduleProjectRoot\Commands\Endpoint\Eigenverft.Manifested.Package.Cmd.PackageEndpoint.ps1"
. "$moduleProjectRoot\Commands\Publisher\Eigenverft.Manifested.Package.Cmd.PackagePublisher.ps1"
. "$moduleProjectRoot\Commands\Trust\Eigenverft.Manifested.Package.Cmd.PackageTrust.ps1"
. "$moduleProjectRoot\Commands\Trust\Eigenverft.Manifested.Package.Cmd.PackageCatalogValidation.ps1"
. "$moduleProjectRoot\Commands\Web\Eigenverft.Manifested.Package.Cmd.InvokeWebRequestEx.ps1"
. "$moduleProjectRoot\Commands\Module\Eigenverft.Manifested.Package.Cmd.Module.ps1"

# Package definitions
# Package definitions are JSON-only.

