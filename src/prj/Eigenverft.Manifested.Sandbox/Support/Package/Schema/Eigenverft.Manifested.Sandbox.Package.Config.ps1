<#
    Eigenverft.Manifested.Sandbox.Package.Config
    Loads configuration helpers in dependency order. Split across sibling scripts
    under this folder; dot-source this file only (see Eigenverft.Manifested.Sandbox.psm1).
#>

. "$PSScriptRoot\Eigenverft.Manifested.Sandbox.Package.Config.IOPathsDefaults.ps1"
. "$PSScriptRoot\Eigenverft.Manifested.Sandbox.Package.Config.TemplatesLayout.ps1"
. "$PSScriptRoot\Eigenverft.Manifested.Sandbox.Package.Config.ObjectCopy.ps1"
. "$PSScriptRoot\Eigenverft.Manifested.Sandbox.Package.Config.InventoryAndSchema.ps1"
. "$PSScriptRoot\Eigenverft.Manifested.Sandbox.Package.Config.Aggregation.ps1"
