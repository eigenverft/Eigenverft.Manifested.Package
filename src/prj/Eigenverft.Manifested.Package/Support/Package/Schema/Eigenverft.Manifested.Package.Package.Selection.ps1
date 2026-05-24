<#
    Eigenverft.Manifested.Package.Package.Selection
#>

function Test-PackageConstraintSetMatch {
<#
.SYNOPSIS
Checks whether a constraint set matches an actual value.

.DESCRIPTION
Treats empty constraint sets as unrestricted and otherwise performs a
case-insensitive comparison against each configured value.

.PARAMETER Values
The configured constraint values.

.PARAMETER ActualValue
The effective value to test.

.EXAMPLE
Test-PackageConstraintSetMatch -Values @('windows') -ActualValue 'windows'
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [object[]]$Values,

        [AllowNull()]
        [string]$ActualValue
    )

    if ($null -eq $Values -or $Values.Count -eq 0) {
        return $true
    }

    foreach ($value in $Values) {
        if ([string]::Equals([string]$value, [string]$ActualValue, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Test-PackageCompatibilityAllowedBlockedMatch {
<#
.SYNOPSIS
Checks allowed/blocked compatibility lists against one actual value.

.DESCRIPTION
Treats empty allowed/blocked lists as unrestricted and otherwise enforces
case-insensitive allow and block matching for one actual value.

.PARAMETER Allowed
The optional allowed values.

.PARAMETER Blocked
The optional blocked values.

.PARAMETER ActualValue
The value to test.
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [object[]]$Allowed,

        [AllowNull()]
        [object[]]$Blocked,

        [AllowNull()]
        [string]$ActualValue
    )

    if ($Blocked -and $Blocked.Count -gt 0) {
        foreach ($value in @($Blocked)) {
            if ([string]::Equals([string]$value, [string]$ActualValue, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $false
            }
        }
    }

    if ($Allowed -and $Allowed.Count -gt 0) {
        foreach ($value in @($Allowed)) {
            if ([string]::Equals([string]$value, [string]$ActualValue, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }

        return $false
    }

    return $true
}

function Test-PackageCompatibilityChecks {
<#
.SYNOPSIS
Evaluates typed Package compatibility checks for one selected release.

.DESCRIPTION
Runs the current compatibility kinds against the resolved runtime context and
returns the normalized compatibility results and acceptance state.

.PARAMETER PackageConfig
The resolved Package config object.

.PARAMETER Compatibility
The effective release compatibility object.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig,

        [AllowNull()]
        [psobject]$Compatibility
    )

    $results = New-Object System.Collections.Generic.List[object]
    $allAccepted = $true
    $blockingAccepted = $true
    $checks = if ($Compatibility -and $Compatibility.PSObject.Properties['checks']) { @($Compatibility.checks) } else { @() }

    foreach ($check in @($checks)) {
        if ($null -eq $check) {
            continue
        }

        $kind = [string]$check.kind
        $onFail = if ($check.PSObject.Properties['onFail'] -and -not [string]::IsNullOrWhiteSpace([string]$check.onFail)) {
            ([string]$check.onFail).ToLowerInvariant()
        }
        else {
            'fail'
        }
        $accepted = $false
        $actualValue = $null
        $expectedSummary = $null
        $testNumericValue = {
            param(
                [AllowNull()]
                [object]$ActualNumericValue,

                [Parameter(Mandatory = $true)]
                [string]$Operator,

                [Parameter(Mandatory = $true)]
                [double]$ExpectedNumericValue
            )

            if ($null -eq $ActualNumericValue) {
                return $false
            }

            $actualNumericComparisonValue = [double]$ActualNumericValue

            switch -Exact ($Operator) {
                '=' { return $actualNumericComparisonValue -eq $ExpectedNumericValue }
                '==' { return $actualNumericComparisonValue -eq $ExpectedNumericValue }
                '!=' { return $actualNumericComparisonValue -ne $ExpectedNumericValue }
                '>' { return $actualNumericComparisonValue -gt $ExpectedNumericValue }
                '>=' { return $actualNumericComparisonValue -ge $ExpectedNumericValue }
                '<' { return $actualNumericComparisonValue -lt $ExpectedNumericValue }
                '<=' { return $actualNumericComparisonValue -le $ExpectedNumericValue }
                default { throw "Unsupported numeric compatibility operator '$Operator'." }
            }
        }
        $formatMemoryValue = {
            param([AllowNull()][object]$MemoryGiB)

            if ($null -eq $MemoryGiB) {
                return 'unknown'
            }

            return ('{0:N2} GiB' -f ([double]$MemoryGiB))
        }

        switch -Exact ($kind) {
            'osFamily' {
                $actualValue = [string]$PackageConfig.Platform
                $allowedValues = if ($check.PSObject.Properties['allowed']) { @($check.allowed) } else { @() }
                $blockedValues = if ($check.PSObject.Properties['blocked']) { @($check.blocked) } else { @() }
                $accepted = Test-PackageCompatibilityAllowedBlockedMatch -Allowed $allowedValues -Blocked $blockedValues -ActualValue $actualValue
                $expectedSummary = @(
                    if ($allowedValues.Count -gt 0) { 'allowed=' + (($allowedValues | ForEach-Object { [string]$_ }) -join ',') }
                    if ($blockedValues.Count -gt 0) { 'blocked=' + (($blockedValues | ForEach-Object { [string]$_ }) -join ',') }
                ) -join '; '
            }
            'cpuArchitecture' {
                $actualValue = [string]$PackageConfig.Architecture
                $allowedValues = if ($check.PSObject.Properties['allowed']) { @($check.allowed) } else { @() }
                $blockedValues = if ($check.PSObject.Properties['blocked']) { @($check.blocked) } else { @() }
                $accepted = Test-PackageCompatibilityAllowedBlockedMatch -Allowed $allowedValues -Blocked $blockedValues -ActualValue $actualValue
                $expectedSummary = @(
                    if ($allowedValues.Count -gt 0) { 'allowed=' + (($allowedValues | ForEach-Object { [string]$_ }) -join ',') }
                    if ($blockedValues.Count -gt 0) { 'blocked=' + (($blockedValues | ForEach-Object { [string]$_ }) -join ',') }
                ) -join '; '
            }
            'osVersion' {
                $actualValue = [string]$PackageConfig.OSVersion
                $expectedVersion = ConvertTo-PackageVersion -VersionText ([string]$check.value)
                $actualVersion = ConvertTo-PackageVersion -VersionText $actualValue
                $operator = [string]$check.operator
                $accepted = switch -Exact ($operator) {
                    '=' { $actualVersion -eq $expectedVersion }
                    '==' { $actualVersion -eq $expectedVersion }
                    '!=' { $actualVersion -ne $expectedVersion }
                    '>' { $actualVersion -gt $expectedVersion }
                    '>=' { $actualVersion -ge $expectedVersion }
                    '<' { $actualVersion -lt $expectedVersion }
                    '<=' { $actualVersion -le $expectedVersion }
                    default { throw "Unsupported Package osVersion compatibility operator '$operator'." }
                }
                $expectedSummary = '{0} {1}' -f $operator, [string]$check.value
            }
            'physicalMemoryGiB' {
                $operator = [string]$check.operator
                $expectedNumericValue = [double]([string]$check.value)
                $observedMemoryGiB = Get-PhysicalMemoryGiB
                $accepted = & $testNumericValue -ActualNumericValue $observedMemoryGiB -Operator $operator -ExpectedNumericValue $expectedNumericValue
                $actualValue = & $formatMemoryValue $observedMemoryGiB
                $expectedSummary = '{0} {1} GiB' -f $operator, [string]$check.value
            }
            'videoMemoryGiB' {
                $operator = [string]$check.operator
                $expectedNumericValue = [double]([string]$check.value)
                $observedMemoryGiB = Get-VideoMemoryGiB
                $accepted = & $testNumericValue -ActualNumericValue $observedMemoryGiB -Operator $operator -ExpectedNumericValue $expectedNumericValue
                $actualValue = & $formatMemoryValue $observedMemoryGiB
                $expectedSummary = '{0} {1} GiB' -f $operator, [string]$check.value
            }
            'physicalOrVideoMemoryGiB' {
                $operator = [string]$check.operator
                $expectedNumericValue = [double]([string]$check.value)
                $memoryRequirementResult = Test-PhysicalOrVideoMemoryRequirement -Operator $operator -ValueGiB $expectedNumericValue
                $accepted = [bool]$memoryRequirementResult.Accepted
                $actualValue = 'physical={0}; video={1}' -f (& $formatMemoryValue $memoryRequirementResult.PhysicalMemoryGiB), (& $formatMemoryValue $memoryRequirementResult.VideoMemoryGiB)
                $expectedSummary = '{0} {1} GiB' -f $operator, [string]$check.value
            }
            default {
                throw "Unsupported Package compatibility kind '$kind'."
            }
        }

        if (-not $accepted) {
            $allAccepted = $false
            if ([string]::Equals($onFail, 'fail', [System.StringComparison]::OrdinalIgnoreCase)) {
                $blockingAccepted = $false
            }
        }

        $results.Add([pscustomobject]@{
            Kind     = $kind
            OnFail   = $onFail
            Accepted = $accepted
            Actual   = $actualValue
            Expected = $expectedSummary
        }) | Out-Null
    }

    return [pscustomobject]@{
        Accepted         = $allAccepted
        BlockingAccepted = $blockingAccepted
        Checks           = @($results.ToArray())
    }
}

function Resolve-PackagePackage {
<#
.SYNOPSIS
Attaches the selected release to a Package result.

.DESCRIPTION
Selects a schemaVersion 1.6 artifact target and release entry for the
resolved Package config, projects that artifact target/release into the runtime
assigned package object, and attaches it to the result.

.PARAMETER PackageResult
The Package result object to enrich.

.EXAMPLE
Resolve-PackagePackage -PackageResult $result
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $packageConfig = $PackageResult.PackageConfig
    $effectiveReleaseTrack = if ([string]::IsNullOrWhiteSpace($packageConfig.ReleaseTrack)) { 'none' } else { [string]$packageConfig.ReleaseTrack }

    if (-not [string]::Equals([string]$packageConfig.SelectionStrategy, 'latestByVersion', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsupported Package selection strategy '$($packageConfig.SelectionStrategy)'."
    }

    $packageVersionOverride = if ($PackageResult.PSObject.Properties['PackageVersionOverrideSpecified'] -and [bool]$PackageResult.PackageVersionOverrideSpecified -and
        $PackageResult.PSObject.Properties['PackageVersionSelector'] -and
        -not [string]::IsNullOrWhiteSpace([string]$PackageResult.PackageVersionSelector)) {
        [string]$PackageResult.PackageVersionSelector
    }
    else {
        $null
    }

    $selectedPackage = Resolve-PackageEffectivePackage_1_6 -PackageConfig $packageConfig -PackageVersionOverride $packageVersionOverride

    $PackageResult.Package = $selectedPackage
    $PackageResult.EffectiveRelease = $selectedPackage
    $PackageResult.PackageId = [string]$selectedPackage.id
    $PackageResult.PackageVersion = [string]$selectedPackage.version
    if ($selectedPackage.PSObject.Properties['versionSelection'] -and $selectedPackage.versionSelection) {
        $PackageResult.PackageVersionSelectionSource = [string]$selectedPackage.versionSelection.source
        $PackageResult.PackageVersionSelector = [string]$selectedPackage.versionSelection.selector
        $PackageResult.PackageVersionOrderingKind = [string]$selectedPackage.versionSelection.orderingKind
        $PackageResult.RequestedPackageVersion = if ($selectedPackage.versionSelection.PSObject.Properties['requestedVersion'] -and
            -not [string]::IsNullOrWhiteSpace([string]$selectedPackage.versionSelection.requestedVersion)) { [string]$selectedPackage.versionSelection.requestedVersion } else { $null }
    }
    $compatibilityEvaluation = Test-PackageCompatibilityChecks -PackageConfig $packageConfig -Compatibility $selectedPackage.compatibility
    $PackageResult.Compatibility = @($compatibilityEvaluation.Checks)
    if (-not $compatibilityEvaluation.BlockingAccepted) {
        $failedCompatibilityText = @(
            foreach ($checkResult in @($compatibilityEvaluation.Checks)) {
                if (-not $checkResult.Accepted -and [string]::Equals([string]$checkResult.OnFail, 'fail', [System.StringComparison]::OrdinalIgnoreCase)) {
                    "{0} actual='{1}' expected='{2}' onFail='{3}'" -f $checkResult.Kind, [string]$checkResult.Actual, [string]$checkResult.Expected, [string]$checkResult.OnFail
                }
            }
        ) -join '; '
        throw "Package release '$($selectedPackage.id)' does not satisfy compatibility.checks. $failedCompatibilityText"
    }

    $selectedArtifactDistributionVariant = if ($selectedPackage.PSObject.Properties['artifactDistributionVariant']) { [string]$selectedPackage.artifactDistributionVariant } else { 'default' }
    Write-PackageExecutionMessage -Message ("[STATE] Selected package artifact target '{0}' release '{1}' version '{2}' for platform '{3}', architecture '{4}', releaseTrack '{5}', artifactDistributionVariant '{6}'." -f [string]$selectedPackage.artifactTargetId, $PackageResult.PackageId, $PackageResult.PackageVersion, $packageConfig.Platform, $packageConfig.Architecture, $effectiveReleaseTrack, $selectedArtifactDistributionVariant)
    if (@($compatibilityEvaluation.Checks).Count -gt 0) {
        $compatibilitySummary = @(
            foreach ($checkResult in @($compatibilityEvaluation.Checks)) {
                "{0}={1}({2})" -f $checkResult.Kind, $(if ($checkResult.Accepted) { 'accepted' } else { 'rejected' }), [string]$checkResult.OnFail
            }
        ) -join ', '
        Write-PackageExecutionMessage -Message ("[STATE] Compatibility checks: {0}." -f $compatibilitySummary)
    }

    $compatibilityWarnings = @(
        foreach ($checkResult in @($compatibilityEvaluation.Checks)) {
            if (-not $checkResult.Accepted -and [string]::Equals([string]$checkResult.OnFail, 'warn', [System.StringComparison]::OrdinalIgnoreCase)) {
                "{0} actual='{1}' expected='{2}'" -f $checkResult.Kind, [string]$checkResult.Actual, [string]$checkResult.Expected
            }
        }
    )
    if ($compatibilityWarnings.Count -gt 0) {
        Write-PackageExecutionMessage -Message ("[WARN] Compatibility warnings: {0}." -f ($compatibilityWarnings -join '; '))
    }

    return $PackageResult
}

