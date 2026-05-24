<#
    Eigenverft.Manifested.Sandbox.ExecutionEngine.PathTemplate
#>

function Get-StableShortHash {
<#
.SYNOPSIS
Creates a deterministic short hash from text.

.DESCRIPTION
Hashes UTF-8 text with SHA256 and returns the requested number of lowercase
hex characters. This is intended for stable local identifiers, not security
decisions.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$InputText,

        [ValidateRange(1, 64)]
        [int]$Length = 8
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    $bytes = $encoding.GetBytes($InputText)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = (($sha256.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
        return $hash.Substring(0, $Length)
    }
    finally {
        $sha256.Dispose()
    }
}

function Resolve-TemplateText {
<#
.SYNOPSIS
Replaces {tokenName} placeholders in a string.

.DESCRIPTION
Performs case-sensitive string replacement for the provided token keys. Unknown
tokens remain unchanged, and tokens with null values are skipped.
#>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Text,

        [AllowNull()]
        [System.Collections.IDictionary]$Tokens
    )

    if ($null -eq $Text) {
        return $null
    }

    $resolvedText = [string]$Text
    if ($null -eq $Tokens) {
        return $resolvedText
    }

    foreach ($key in @($Tokens.Keys)) {
        if ($null -eq $Tokens[$key]) {
            continue
        }

        $resolvedText = $resolvedText.Replace(('{' + [string]$key + '}'), [string]$Tokens[$key])
    }

    return $resolvedText
}

function Resolve-ConfiguredPath {
<#
.SYNOPSIS
Resolves a configured filesystem path.

.DESCRIPTION
Expands environment variables, replaces template tokens, normalizes separators,
and resolves relative paths under the supplied base directory. This helper does
not create files or directories.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue,

        [AllowNull()]
        [string]$BaseDirectory,

        [AllowNull()]
        [System.Collections.IDictionary]$Tokens
    )

    $expandedPath = [Environment]::ExpandEnvironmentVariables($PathValue)
    $templatedPath = Resolve-TemplateText -Text $expandedPath -Tokens $Tokens
    $normalizedPath = ([string]$templatedPath).Trim() -replace '/', '\'
    if ([string]::IsNullOrWhiteSpace($normalizedPath)) {
        throw 'Configured path values must not be empty.'
    }

    if ([System.IO.Path]::IsPathRooted($normalizedPath)) {
        return [System.IO.Path]::GetFullPath($normalizedPath)
    }

    if ([string]::IsNullOrWhiteSpace($BaseDirectory)) {
        throw "Configured path '$PathValue' is relative, but no base directory was provided."
    }

    $expandedBase = [Environment]::ExpandEnvironmentVariables($BaseDirectory)
    $templatedBase = Resolve-TemplateText -Text $expandedBase -Tokens $Tokens
    $normalizedBase = ([string]$templatedBase).Trim() -replace '/', '\'
    if ([string]::IsNullOrWhiteSpace($normalizedBase)) {
        throw 'Configured path base directory must not be empty.'
    }

    return [System.IO.Path]::GetFullPath((Join-Path $normalizedBase $normalizedPath))
}
