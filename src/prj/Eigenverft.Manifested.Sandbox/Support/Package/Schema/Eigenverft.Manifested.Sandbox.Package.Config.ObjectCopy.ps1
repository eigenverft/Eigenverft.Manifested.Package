<#
    Eigenverft.Manifested.Sandbox.Package.Config - deep copy and merge utilities for config objects.
    Loaded by Eigenverft.Manifested.Sandbox.Package.Config.ps1.
#>

function ConvertTo-PackageMergeValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [string] -or
        $InputObject -is [ValueType] -or
        $InputObject -is [datetime] -or
        $InputObject -is [guid]) {
        return $InputObject
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in @($InputObject.Keys)) {
            $result[[string]$key] = ConvertTo-PackageMergeValue -InputObject $InputObject[$key]
        }
        return $result
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [psobject] -and $InputObject.PSObject.Properties.Count -gt 0)) {
        return @($InputObject | ForEach-Object { ConvertTo-PackageMergeValue -InputObject $_ })
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        return @($InputObject | ForEach-Object { ConvertTo-PackageMergeValue -InputObject $_ })
    }

    if ($InputObject.PSObject.Properties.Count -gt 0) {
        $result = [ordered]@{}
        foreach ($property in @($InputObject.PSObject.Properties)) {
            $result[$property.Name] = ConvertTo-PackageMergeValue -InputObject $property.Value
        }
        return $result
    }

    return $InputObject
}

function Merge-PackageValues {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$BaseValue,

        [AllowNull()]
        [object]$OverlayValue
    )

    if ($null -eq $BaseValue) {
        return (ConvertTo-PackageMergeValue -InputObject $OverlayValue)
    }
    if ($null -eq $OverlayValue) {
        return (ConvertTo-PackageMergeValue -InputObject $BaseValue)
    }

    $baseIsObject = ($BaseValue -is [System.Collections.IDictionary])
    $overlayIsObject = ($OverlayValue -is [System.Collections.IDictionary])
    if ($baseIsObject -and $overlayIsObject) {
        $merged = [ordered]@{}
        foreach ($key in @($BaseValue.Keys)) {
            $merged[[string]$key] = ConvertTo-PackageMergeValue -InputObject $BaseValue[$key]
        }
        foreach ($key in @($OverlayValue.Keys)) {
            $keyText = [string]$key
            if ($merged.Contains($keyText)) {
                $merged[$keyText] = Merge-PackageValues -BaseValue $merged[$keyText] -OverlayValue $OverlayValue[$key]
            }
            else {
                $merged[$keyText] = ConvertTo-PackageMergeValue -InputObject $OverlayValue[$key]
            }
        }
        return $merged
    }

    if (($BaseValue -is [System.Collections.IEnumerable] -and -not ($BaseValue -is [string])) -and
        ($OverlayValue -is [System.Collections.IEnumerable] -and -not ($OverlayValue -is [string]))) {
        return @(ConvertTo-PackageMergeValue -InputObject $OverlayValue)
    }

    return (ConvertTo-PackageMergeValue -InputObject $OverlayValue)
}

function ConvertTo-PackageObject {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [string] -or
        $InputObject -is [ValueType] -or
        $InputObject -is [datetime] -or
        $InputObject -is [guid]) {
        return $InputObject
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in @($InputObject.Keys)) {
            $result[[string]$key] = ConvertTo-PackageObject -InputObject $InputObject[$key]
        }
        return [pscustomobject]$result
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and
        -not ($InputObject -is [string]) -and
        -not ($InputObject -is [psobject] -and $InputObject.PSObject.Properties.Count -gt 0)) {
        return @($InputObject | ForEach-Object { ConvertTo-PackageObject -InputObject $_ })
    }

    if ($InputObject.PSObject.Properties.Count -gt 0) {
        $result = [ordered]@{}
        foreach ($property in @($InputObject.PSObject.Properties)) {
            $result[$property.Name] = ConvertTo-PackageObject -InputObject $property.Value
        }
        return [pscustomobject]$result
    }

    return $InputObject
}

function Get-PackageAssignedOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [psobject]$Release
    )

    if ($null -eq $Release) {
        return $null
    }
    if ($Release.PSObject.Properties['assigned'] -and $null -ne $Release.assigned) {
        return $Release.assigned
    }
    return $null
}

function Get-PackageAssignedInstallOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [psobject]$Release
    )

    $assigned = Get-PackageAssignedOperation -Release $Release
    if ($assigned -and $assigned.PSObject.Properties['install'] -and $null -ne $assigned.install) {
        return $assigned.install
    }

    return $null
}

function Get-PackageRemovedOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [psobject]$Release
    )

    if ($null -eq $Release) {
        return $null
    }
    if ($Release.PSObject.Properties['removed'] -and $null -ne $Release.removed) {
        return $Release.removed
    }
    return $null
}
