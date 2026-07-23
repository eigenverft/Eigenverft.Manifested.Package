[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$SourcePath,

    [Parameter(Mandatory)]
    [string]$DestinationPath,

    [switch]$TestExclusiveClaim
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LineEndingState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes -contains [byte]0) {
        return [pscustomobject]@{
            Style            = 'BinaryOrUnknown'
            CrLfCount        = $null
            LfCount          = $null
            CrCount          = $null
            NormalizedSha256 = $null
        }
    }

    $crLfCount = 0
    $lfCount = 0
    $crCount = 0
    $normalized = New-Object System.IO.MemoryStream
    try {
        for ($index = 0; $index -lt $bytes.Length; $index++) {
            $value = $bytes[$index]
            if ($value -eq 13) {
                if (($index + 1) -lt $bytes.Length -and $bytes[$index + 1] -eq 10) {
                    $crLfCount++
                    $index++
                }
                else {
                    $crCount++
                }
                $normalized.WriteByte(10)
                continue
            }

            if ($value -eq 10) {
                $lfCount++
            }
            $normalized.WriteByte($value)
        }

        $style = if ($crLfCount -eq 0 -and $lfCount -eq 0 -and $crCount -eq 0) {
            'None'
        }
        elseif ($crLfCount -gt 0 -and $lfCount -eq 0 -and $crCount -eq 0) {
            'CRLF'
        }
        elseif ($lfCount -gt 0 -and $crLfCount -eq 0 -and $crCount -eq 0) {
            'LF'
        }
        elseif ($crCount -gt 0 -and $crLfCount -eq 0 -and $lfCount -eq 0) {
            'CR'
        }
        else {
            'Mixed'
        }

        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $normalized.Position = 0
            $normalizedHashBytes = $sha.ComputeHash($normalized)
            $normalizedHash = -join ($normalizedHashBytes | ForEach-Object { $_.ToString('x2') })
        }
        finally {
            $sha.Dispose()
        }

        return [pscustomobject]@{
            Style            = $style
            CrLfCount        = $crLfCount
            LfCount          = $lfCount
            CrCount          = $crCount
            NormalizedSha256 = $normalizedHash
        }
    }
    finally {
        $normalized.Dispose()
    }
}

function Get-ArtifactState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Role,

        [string]$ExpectedHash,

        [string]$ExpectedNormalizedHash,

        [switch]$TestExclusiveClaim
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{
            Role                       = $Role
            Path                       = $Path
            Exists                     = $false
            Length                     = $null
            LastWriteTimeUtc           = $null
            Sha256                     = $null
            MatchesExpected            = $false
            LineEndingStyle            = $null
            NormalizedLineEndingSha256 = $null
            MatchesExpectedNormalized  = $false
            ExclusiveClaim             = $null
            ExclusiveClaimError        = $null
        }
    }

    $item = Get-Item -LiteralPath $Path -Force
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    $lineEndingState = Get-LineEndingState -Path $Path
    $exclusiveClaim = $null
    $exclusiveClaimError = $null

    if ($TestExclusiveClaim) {
        $stream = $null
        try {
            $stream = [System.IO.FileStream]::new(
                $item.FullName,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::ReadWrite,
                [System.IO.FileShare]::None
            )
            $exclusiveClaim = $true
        }
        catch {
            $exclusiveClaim = $false
            $exclusiveClaimError = '{0}: {1}' -f $_.Exception.GetType().FullName, $_.Exception.Message
        }
        finally {
            if ($stream) {
                $stream.Dispose()
            }
        }
    }

    [pscustomobject]@{
        Role                       = $Role
        Path                       = $item.FullName
        Exists                     = $true
        Length                     = [long]$item.Length
        LastWriteTimeUtc           = $item.LastWriteTimeUtc
        Sha256                     = $hash
        MatchesExpected            = if ([string]::IsNullOrWhiteSpace($ExpectedHash)) { $null } else { $hash -eq $ExpectedHash }
        LineEndingStyle            = $lineEndingState.Style
        NormalizedLineEndingSha256 = $lineEndingState.NormalizedSha256
        MatchesExpectedNormalized  = if ([string]::IsNullOrWhiteSpace($ExpectedNormalizedHash) -or [string]::IsNullOrWhiteSpace($lineEndingState.NormalizedSha256)) { $null } else { $lineEndingState.NormalizedSha256 -eq $ExpectedNormalizedHash }
        ExclusiveClaim             = $exclusiveClaim
        ExclusiveClaimError        = $exclusiveClaimError
    }
}

$resolvedSource = (Resolve-Path -LiteralPath $SourcePath).Path
$sourceState = Get-ArtifactState -Path $resolvedSource -Role 'Source' -TestExclusiveClaim:$false
$expectedHash = $sourceState.Sha256
$expectedNormalizedHash = $sourceState.NormalizedLineEndingSha256

$destinationDirectory = Split-Path -Path $DestinationPath -Parent
$destinationLeaf = [System.IO.Path]::GetFileName($DestinationPath)
$partialPattern = $destinationLeaf + '.partial.*'

$states = New-Object System.Collections.Generic.List[object]
$states.Add($sourceState)
$states.Add((Get-ArtifactState -Path $DestinationPath -Role 'Final' -ExpectedHash $expectedHash -ExpectedNormalizedHash $expectedNormalizedHash -TestExclusiveClaim:$TestExclusiveClaim))

if (Test-Path -LiteralPath $destinationDirectory -PathType Container) {
    foreach ($partial in @(Get-ChildItem -LiteralPath $destinationDirectory -File -Filter $partialPattern -Force -ErrorAction Stop | Sort-Object LastWriteTimeUtc)) {
        $state = Get-ArtifactState -Path $partial.FullName -Role 'Partial' -ExpectedHash $expectedHash -ExpectedNormalizedHash $expectedNormalizedHash -TestExclusiveClaim:$TestExclusiveClaim
        $nameParts = $partial.Name -split '\.partial\.', 2
        $suffixParts = if ($nameParts.Count -eq 2) { $nameParts[1] -split '\.', 2 } else { @() }
        $state | Add-Member -NotePropertyName ContentIdentity -NotePropertyValue $(if ($suffixParts.Count -ge 1) { $suffixParts[0] } else { $null })
        $state | Add-Member -NotePropertyName WriterToken -NotePropertyValue $(if ($suffixParts.Count -ge 2) { $suffixParts[1] } else { $null })
        $states.Add($state)
    }
}

$states.ToArray()

$final = @($states | Where-Object Role -eq 'Final') | Select-Object -First 1
$partials = @($states | Where-Object Role -eq 'Partial')

[pscustomobject]@{
    Analysis                                 = 'Summary'
    SourceSha256                             = $expectedHash
    SourceLineEndingStyle                    = $sourceState.LineEndingStyle
    SourceNormalizedLineEndingSha256         = $expectedNormalizedHash
    FinalExists                              = [bool]$final.Exists
    FinalMatchesSource                       = [bool]$final.MatchesExpected
    FinalMatchesAfterLineEndingNormalization = [bool]$final.MatchesExpectedNormalized
    FinalDifferenceIsLineEndingOnly          = [bool]($final.Exists -and -not $final.MatchesExpected -and $final.MatchesExpectedNormalized)
    PartialCount                             = $partials.Count
    MatchingPartialCount                     = @($partials | Where-Object MatchesExpected).Count
    LockedOrUnclaimableCount                 = @($partials | Where-Object { $_.ExclusiveClaim -eq $false }).Count
    Interpretation                           = if (-not $final.Exists) {
        'The final destination is missing.'
    }
    elseif (-not $final.MatchesExpected -and $final.MatchesExpectedNormalized) {
        'The final destination differs from the verified source only by CR/LF byte representation. A Windows checkout or text-normalizing copy path likely published non-canonical bytes.'
    }
    elseif (-not $final.MatchesExpected) {
        'The final destination differs from the verified source. A no-clobber promotion will retain a verified partial.'
    }
    elseif ($partials.Count -gt 0) {
        'The final destination matches the source. Remaining partials are cleanup residue; inspect timestamps, writer tokens and exclusive-claim results.'
    }
    else {
        'The final destination matches the source and no partial residue remains.'
    }
}
