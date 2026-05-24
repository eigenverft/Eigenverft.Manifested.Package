<#
    Eigenverft.Manifested.Package.Package.Config
    Loads configuration helpers in dependency order. Split across sibling scripts
    under this folder; dot-source this file only (see Eigenverft.Manifested.Package.psm1).
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Package.Config.IOPathsDefaults.ps1"
. "$PSScriptRoot\Eigenverft.Manifested.Package.Package.Config.TemplatesLayout.ps1"
. "$PSScriptRoot\Eigenverft.Manifested.Package.Package.Config.ObjectCopy.ps1"
. "$PSScriptRoot\Eigenverft.Manifested.Package.Package.Config.InventoryAndSchema.ps1"
. "$PSScriptRoot\Eigenverft.Manifested.Package.Package.Config.Aggregation.ps1"
