<#
    Eigenverft.Manifested.Package.Package.VersionSelection

    Version ordering policy for authored package releases:
    - normalVersion: full [version] values such as 1.15.7, 24.15.0, 1.4.8.1.
    - plainInteger: single integer build versions such as 9094.
    - dateHash: date-like dotted numeric prefix with a suffix, such as 2026.05.09-0afadcc.
    - numericPrefix: fallback for other values that contain a numeric dotted prefix.

    Selection is intentionally local to authored, compatible release candidates; no strategy in
    this file performs a network "latest" lookup.
#>

function ConvertTo-PackageVersion {
<#
.SYNOPSIS
Converts package version text to a comparable Version object.

.DESCRIPTION
Keeps existing semantic-like version comparisons while also supporting single
integer package versions as Major.0 and suffix-bearing versions by their first
numeric dotted prefix.
#>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$VersionText
    )

    if ([string]::IsNullOrWhiteSpace($VersionText)) {
        return [version]'0.0.0'
    }

    $text = ([string]$VersionText).Trim()
    if ($text -match '^\d+$') {
        return [version]('{0}.0' -f $text)
    }

    try {
        return [version]$text
    }
    catch {
        $match = [regex]::Match($text, '\d+(?:\.\d+){0,3}')
        if ($match.Success) {
            try {
                $numericText = $match.Value
                if ($numericText -match '^\d+$') {
                    $numericText = '{0}.0' -f $numericText
                }
                return [version]$numericText
            }
            catch {
            }
        }
    }

    return [version]'0.0.0'
}

function Get-PackageVersionOrderingInfo {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$VersionText,

        [int]$AuthorIndex = 0,

        [int]$CandidateIndex = 0
    )

    $text = if ([string]::IsNullOrWhiteSpace($VersionText)) { '' } else { ([string]$VersionText).Trim() }
    $orderingKind = 'numericPrefix'
    if ([string]::IsNullOrWhiteSpace($text)) {
        $orderingKind = 'empty'
    }
    elseif ($text -match '^\d+$') {
        $orderingKind = 'plainInteger'
    }
    else {
        try {
            $null = [version]$text
            $orderingKind = 'normalVersion'
        }
        catch {
            if ($text -match '^\d{4}\.\d{1,2}\.\d{1,2}(?:\.\d+)?[-+_].+$') {
                $orderingKind = 'dateHash'
            }
        }
    }

    return [pscustomobject]@{
        VersionText    = $text
        OrderingKind   = $orderingKind
        SortVersion    = ConvertTo-PackageVersion -VersionText $text
        AuthorIndex    = $AuthorIndex
        CandidateIndex = $CandidateIndex
    }
}

function Sort-PackageVersionCandidates {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object[]]$Candidates
    )

    return @($Candidates) | Sort-Object `
        @{ Expression = { $_.VersionOrdering.SortVersion }; Descending = $true },
        @{ Expression = { $_.VersionOrdering.AuthorIndex }; Descending = $false },
        @{ Expression = { $_.VersionOrdering.CandidateIndex }; Descending = $false }
}

function Resolve-PackageVersionCandidateSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Candidates,

        [AllowNull()]
        [string]$CommandSelector = $null,

        [Parameter(Mandatory = $true)]
        [string]$DefinitionId,

        [Parameter(Mandatory = $true)]
        [string]$Platform,

        [Parameter(Mandatory = $true)]
        [string]$Architecture,

        [Parameter(Mandatory = $true)]
        [string]$ReleaseTrack,

        [AllowNull()]
        [object[]]$AllVersionEntries
    )

    if (@($Candidates).Count -eq 0) {
        throw "No Package target/release entry matched platform '$Platform', architecture '$Architecture', and releaseTrack '$ReleaseTrack'."
    }

    $selector = if ([string]::IsNullOrWhiteSpace($CommandSelector)) { $null } else { ([string]$CommandSelector).Trim() }
    $selectionSource = if ([string]::IsNullOrWhiteSpace($selector)) { 'definition' } else { 'command' }
    if ([string]::IsNullOrWhiteSpace($selector)) {
        $firstTarget = @($Candidates)[0].ArtifactTarget
        $selector = if ($firstTarget -and $firstTarget.PSObject.Properties['versionSelection'] -and
            $firstTarget.versionSelection -and $firstTarget.versionSelection.PSObject.Properties['strategy'] -and
            -not [string]::IsNullOrWhiteSpace([string]$firstTarget.versionSelection.strategy)) {
            [string]$firstTarget.versionSelection.strategy
        }
        else {
            'latestByVersion'
        }
    }

    $orderedCandidates = @(Sort-PackageVersionCandidates -Candidates $Candidates)
    $selected = $null
    $requestedVersion = $null
    $selectionKind = $selector

    if ([string]::Equals($selector, 'latestByVersion', [System.StringComparison]::OrdinalIgnoreCase)) {
        $selected = $orderedCandidates | Select-Object -First 1
        $selectionKind = 'latestByVersion'
    }
    elseif ([string]::Equals($selector, 'previousByVersion', [System.StringComparison]::OrdinalIgnoreCase)) {
        $selected = if ($orderedCandidates.Count -gt 1) { $orderedCandidates[1] } else { $orderedCandidates[0] }
        $selectionKind = 'previousByVersion'
    }
    else {
        $requestedVersion = $selector
        $matches = @(
            foreach ($candidate in @($Candidates)) {
                if ([string]::Equals([string]$candidate.VersionEntry.version, $requestedVersion, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $candidate
                }
            }
        )

        if ($matches.Count -eq 0) {
            $versionIsAuthored = $false
            foreach ($versionEntry in @($AllVersionEntries)) {
                if ([string]::Equals([string]$versionEntry.version, $requestedVersion, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $versionIsAuthored = $true
                    break
                }
            }

            if ($versionIsAuthored) {
                throw "Package version '$requestedVersion' is not available for definition '$DefinitionId' on platform '$Platform', architecture '$Architecture', and releaseTrack '$ReleaseTrack'."
            }

            throw "Package version '$requestedVersion' is not authored for definition '$DefinitionId'."
        }

        $selected = @(Sort-PackageVersionCandidates -Candidates $matches) | Select-Object -First 1
        $selectionKind = 'exact'
    }

    return [pscustomobject]@{
        Candidate        = $selected
        Selector         = $selector
        Source           = $selectionSource
        SelectionKind    = $selectionKind
        OrderingKind     = [string]$selected.VersionOrdering.OrderingKind
        RequestedVersion = $requestedVersion
    }
}
