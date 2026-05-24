<#
    Eigenverft.Manifested.Sandbox root module
#>

# Generic ExecutionCore support
. "$PSScriptRoot\Support\ExecutionCore\Eigenverft.Manifested.Sandbox.ExecutionCore.StandardMessage.ps1"
. "$PSScriptRoot\Support\ExecutionCore\Eigenverft.Manifested.Sandbox.ExecutionCore.Stream.ps1"
. "$PSScriptRoot\Support\ExecutionCore\Eigenverft.Manifested.Sandbox.ExecutionCore.Tar.ps1"
. "$PSScriptRoot\Support\ExecutionCore\Eigenverft.Manifested.Sandbox.ExecutionCore.GZip.ps1"
. "$PSScriptRoot\Support\ExecutionCore\Eigenverft.Manifested.Sandbox.ExecutionCore.Archive.ps1"
. "$PSScriptRoot\Support\ExecutionCore\Eigenverft.Manifested.Sandbox.ExecutionCore.CommandResolution.ps1"
. "$PSScriptRoot\Support\ExecutionCore\Eigenverft.Manifested.Sandbox.ExecutionCore.FileSystem.ps1"
. "$PSScriptRoot\Support\ExecutionCore\Eigenverft.Manifested.Sandbox.ExecutionCore.PathTemplate.ps1"
. "$PSScriptRoot\Support\ExecutionCore\Eigenverft.Manifested.Sandbox.ExecutionCore.Registry.ps1"
. "$PSScriptRoot\Support\ExecutionCore\Eigenverft.Manifested.Sandbox.ExecutionCore.SystemResources.ps1"
. "$PSScriptRoot\Support\ExecutionCore\Eigenverft.Manifested.Sandbox.ExecutionCore.Elevation.ps1"
. "$PSScriptRoot\Support\ExecutionCore\Eigenverft.Manifested.Sandbox.ExecutionCore.PathRegistration.ps1"
. "$PSScriptRoot\Support\ExecutionCore\Eigenverft.Manifested.Sandbox.ExecutionCore.Npm.ps1"
. "$PSScriptRoot\Support\ExecutionCore\Eigenverft.Manifested.Sandbox.ExecutionCore.InitializeProxyAccessProfile.ps1"

# Package support
. "$PSScriptRoot\Support\ExecutionCore\Upstream\Eigenverft.Manifested.Sandbox.ExecutionCore.Upstream.GitHubRelease.ps1"
. "$PSScriptRoot\Support\Package\Execution\Eigenverft.Manifested.Sandbox.Package.ExecutionMessage.ps1"
. "$PSScriptRoot\Support\Package\Execution\Eigenverft.Manifested.Sandbox.Package.Bootstrap.ps1"
. "$PSScriptRoot\Support\Package\Execution\Eigenverft.Manifested.Sandbox.Package.VersionSelection.ps1"
. "$PSScriptRoot\Support\Package\Schema\Eigenverft.Manifested.Sandbox.Package.Config.ps1"
. "$PSScriptRoot\Support\Package\Schema\Eigenverft.Manifested.Sandbox.Package.DepotInventory.Management.ps1"
. "$PSScriptRoot\Support\Package\Schema\Eigenverft.Manifested.Sandbox.Package.EndpointInventory.Management.ps1"
. "$PSScriptRoot\Support\Package\Schema\Eigenverft.Manifested.Sandbox.Package.PublisherInventory.Management.ps1"
. "$PSScriptRoot\Support\Package\Schema\Eigenverft.Manifested.Sandbox.Package.DefinitionReference.ps1"
. "$PSScriptRoot\Support\Package\Schema\Eigenverft.Manifested.Sandbox.Package.DefinitionSchema.Wire1_6.ps1"
. "$PSScriptRoot\Support\Package\Schema\Eigenverft.Manifested.Sandbox.Package.DefinitionSchema.ps1"
. "$PSScriptRoot\Support\Package\Execution\Eigenverft.Manifested.Sandbox.Package.LocalEnvironment.ps1"
. "$PSScriptRoot\Support\Package\Schema\Eigenverft.Manifested.Sandbox.Package.Selection.ps1"
. "$PSScriptRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Sandbox.Package.Dependencies.ps1"
. "$PSScriptRoot\Support\Package\Schema\Eigenverft.Manifested.Sandbox.Package.Source.ps1"
. "$PSScriptRoot\Support\Package\State\Eigenverft.Manifested.Sandbox.Package.Ownership.ps1"
. "$PSScriptRoot\Support\Package\State\Eigenverft.Manifested.Sandbox.Package.OperationHistory.ps1"
. "$PSScriptRoot\Support\Package\State\Eigenverft.Manifested.Sandbox.Package.State.ps1"
. "$PSScriptRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Sandbox.Package.Readiness.ps1"
. "$PSScriptRoot\Support\Package\Execution\Eigenverft.Manifested.Sandbox.Package.Npm.ps1"
. "$PSScriptRoot\Support\Package\Execution\Eigenverft.Manifested.Sandbox.Package.PowerShellModule.ps1"
# Package install fragments (order-sensitive); orchestrator last - mirror in TestImports.ps1
. "$PSScriptRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Sandbox.Package.Install.Existing.ps1"
. "$PSScriptRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Sandbox.Package.Install.Preparation.ps1"
. "$PSScriptRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Sandbox.Package.Install.Artifact.ps1"
. "$PSScriptRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Sandbox.Package.Install.InstallerEngine.ps1"
. "$PSScriptRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Sandbox.Package.Install.ps1"
. "$PSScriptRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Sandbox.Package.EntryPoints.ps1"
. "$PSScriptRoot\Support\Package\Execution\Eigenverft.Manifested.Sandbox.Package.Shims.ps1"
. "$PSScriptRoot\Support\Package\Execution\Eigenverft.Manifested.Sandbox.Package.PathRegistration.ps1"
. "$PSScriptRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Sandbox.Package.CommandFlow.ps1"
. "$PSScriptRoot\Support\Package\Lifecycle\Eigenverft.Manifested.Sandbox.Package.Remove.ps1"

# Public commands
. "$PSScriptRoot\Commands\Package\Eigenverft.Manifested.Sandbox.Cmd.GetPackageState.ps1"
. "$PSScriptRoot\Commands\Package\Eigenverft.Manifested.Sandbox.Cmd.InvokePackage.ps1"
. "$PSScriptRoot\Commands\Depot\Eigenverft.Manifested.Sandbox.Cmd.PackageDepot.ps1"
. "$PSScriptRoot\Commands\Endpoint\Eigenverft.Manifested.Sandbox.Cmd.PackageEndpoint.ps1"
. "$PSScriptRoot\Commands\Publisher\Eigenverft.Manifested.Sandbox.Cmd.PackagePublisher.ps1"
. "$PSScriptRoot\Commands\Web\Eigenverft.Manifested.Sandbox.Cmd.InvokeWebRequestEx.ps1"
. "$PSScriptRoot\Commands\Module\Eigenverft.Manifested.Sandbox.Cmd.Module.ps1"

# Package definitions
# Package definitions are JSON-only.

