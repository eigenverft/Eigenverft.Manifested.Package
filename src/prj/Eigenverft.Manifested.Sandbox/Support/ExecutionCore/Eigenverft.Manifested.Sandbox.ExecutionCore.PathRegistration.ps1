<#
    Eigenverft.Manifested.Sandbox.ExecutionEngine.PathRegistration
#>

function Get-EnvironmentVariableValue {
<#
.SYNOPSIS
Reads an environment variable for one target scope.

.DESCRIPTION
Returns the current environment variable value for the requested Process, User,
or Machine target.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Process', 'User', 'Machine')]
        [string]$Target
    )

    return [Environment]::GetEnvironmentVariable($Name, $Target)
}

function Set-EnvironmentVariableValue {
<#
.SYNOPSIS
Writes an environment variable for one target scope.

.DESCRIPTION
Persists the requested environment variable value to the Process, User, or
Machine target scope.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [AllowNull()]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Process', 'User', 'Machine')]
        [string]$Target
    )

    [Environment]::SetEnvironmentVariable($Name, $Value, $Target)
}

function Get-NormalizedPathEntry {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$PathEntry
    )

    if ([string]::IsNullOrWhiteSpace($PathEntry)) {
        return $null
    }

    $expandedEntry = [Environment]::ExpandEnvironmentVariables($PathEntry.Trim()) -replace '/', '\'
    if ([string]::IsNullOrWhiteSpace($expandedEntry)) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($expandedEntry)) {
        try {
            return [System.IO.Path]::GetFullPath($expandedEntry).TrimEnd('\')
        }
        catch {
            return $expandedEntry.TrimEnd('\')
        }
    }

    return $expandedEntry.TrimEnd('\')
}

function Resolve-PathRegistrationDirectory {
<#
.SYNOPSIS
Resolves the directory that should be added to PATH.

.DESCRIPTION
Turns a raw source path into the concrete directory entry that should be
registered in PATH. Existing files resolve to their parent directory.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [string]$SourceKind
    )

    $resolvedSourcePath = [System.IO.Path]::GetFullPath($SourcePath)
    if ($SourceKind -in @('commandEntryPoint', 'appEntryPoint', 'shim')) {
        return [System.IO.Path]::GetFullPath((Split-Path -Parent $resolvedSourcePath))
    }

    if (Test-Path -LiteralPath $resolvedSourcePath -PathType Leaf) {
        return [System.IO.Path]::GetFullPath((Split-Path -Parent $resolvedSourcePath))
    }

    return [System.IO.Path]::GetFullPath($resolvedSourcePath)
}

function Add-PathEntry {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$CurrentValue,

        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath
    )

    $normalizedTargetDirectory = Get-NormalizedPathEntry -PathEntry $DirectoryPath
    $existingEntries = @()
    foreach ($entry in @(([string]$CurrentValue) -split ';')) {
        if ([string]::IsNullOrWhiteSpace($entry)) {
            continue
        }

        $existingEntries += $entry.Trim()
    }

    foreach ($entry in @($existingEntries)) {
        $normalizedEntry = Get-NormalizedPathEntry -PathEntry $entry
        if ([string]::Equals($normalizedEntry, $normalizedTargetDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject]@{
                Value   = ($existingEntries -join ';')
                Changed = $false
            }
        }
    }

    $updatedEntries = @($existingEntries) + @($DirectoryPath)
    return [pscustomobject]@{
        Value   = ($updatedEntries -join ';')
        Changed = $true
    }
}

function Remove-PathEntries {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$CurrentValue,

        [string[]]$DirectoryPaths
    )

    $normalizedDirectoriesToRemove = @(
        foreach ($directoryPath in @($DirectoryPaths)) {
            $normalizedDirectoryPath = Get-NormalizedPathEntry -PathEntry $directoryPath
            if (-not [string]::IsNullOrWhiteSpace($normalizedDirectoryPath)) {
                $normalizedDirectoryPath
            }
        }
    )

    if (@($normalizedDirectoriesToRemove).Count -eq 0) {
        return [pscustomobject]@{
            Value          = [string]$CurrentValue
            Changed        = $false
            RemovedEntries = @()
        }
    }

    $filteredEntries = New-Object System.Collections.Generic.List[string]
    $removedEntries = New-Object System.Collections.Generic.List[string]
    foreach ($entry in @(([string]$CurrentValue) -split ';')) {
        if ([string]::IsNullOrWhiteSpace($entry)) {
            continue
        }

        $trimmedEntry = $entry.Trim()
        $normalizedEntry = Get-NormalizedPathEntry -PathEntry $trimmedEntry
        if ($normalizedEntry -and $normalizedEntry -in $normalizedDirectoriesToRemove) {
            $removedEntries.Add($trimmedEntry) | Out-Null
            continue
        }

        $filteredEntries.Add($trimmedEntry) | Out-Null
    }

    return [pscustomobject]@{
        Value          = (@($filteredEntries.ToArray()) -join ';')
        Changed        = ($removedEntries.Count -gt 0)
        RemovedEntries = @($removedEntries.ToArray())
    }
}

function Remove-PathEnvironmentDirectories {
<#
.SYNOPSIS
Removes directory entries from PATH for the requested scopes without adding a new entry.

.DESCRIPTION
Used by Package removal to drop previously registered directories from Process
and User or Machine PATH.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('user', 'machine')]
        [string]$Mode,

        [AllowEmptyCollection()]
        [string[]]$DirectoryPaths
    )

    $directoriesToRemove = @(
        foreach ($directoryPath in @($DirectoryPaths)) {
            $normalizedDirectoryPath = Get-NormalizedPathEntry -PathEntry $directoryPath
            if (-not [string]::IsNullOrWhiteSpace($normalizedDirectoryPath)) {
                $normalizedDirectoryPath
            }
        }
    )

    $targets = @('Process')
    if ($Mode -eq 'user') {
        $targets += 'User'
    }
    elseif ($Mode -eq 'machine') {
        $targets += 'Machine'
    }

    $updatedTargets = New-Object System.Collections.Generic.List[string]
    $cleanedTargets = New-Object System.Collections.Generic.List[string]
    foreach ($target in @($targets)) {
        $currentValue = Get-EnvironmentVariableValue -Name 'Path' -Target $target
        $cleanupResult = Remove-PathEntries -CurrentValue $currentValue -DirectoryPaths $directoriesToRemove
        if ($cleanupResult.Changed) {
            Set-EnvironmentVariableValue -Name 'Path' -Value $cleanupResult.Value -Target $target
            $updatedTargets.Add($target) | Out-Null
            $cleanedTargets.Add($target) | Out-Null
        }
    }

    return [pscustomobject]@{
        Status             = if ($updatedTargets.Count -gt 0) { 'Unregistered' } else { 'AlreadyAbsent' }
        Mode               = $Mode
        CleanedTargets     = @($cleanedTargets.ToArray())
        UpdatedTargets     = @($updatedTargets.ToArray())
        RemovedDirectories = @($directoriesToRemove)
    }
}

function Register-PathEnvironment {
<#
.SYNOPSIS
Registers a directory in PATH for the requested scopes.

.DESCRIPTION
Updates Process and User PATH for user mode, or Process and Machine PATH for
machine mode. Removes any requested cleanup directories before ensuring the
active directory is present.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('user', 'machine')]
        [string]$Mode,

        [Parameter(Mandatory = $true)]
        [string]$RegisteredPath,

        [string[]]$CleanupDirectories
    )

    if ([string]::IsNullOrWhiteSpace($RegisteredPath)) {
        throw 'PATH registration requires a registered directory path.'
    }

    if (-not (Test-Path -LiteralPath $RegisteredPath)) {
        throw "PATH registration directory '$RegisteredPath' was not found."
    }

    $normalizedRegisteredPath = Resolve-PathRegistrationDirectory -SourcePath $RegisteredPath
    $cleanupDirectoriesToApply = @($CleanupDirectories)
    $targets = @('Process')
    if ($Mode -eq 'user') {
        $targets += 'User'
    }
    elseif ($Mode -eq 'machine') {
        $targets += 'Machine'
    }

    $updatedTargets = New-Object System.Collections.Generic.List[string]
    $cleanedTargets = New-Object System.Collections.Generic.List[string]
    foreach ($target in @($targets)) {
        $currentValue = Get-EnvironmentVariableValue -Name 'Path' -Target $target
        $cleanupResult = Remove-PathEntries -CurrentValue $currentValue -DirectoryPaths $cleanupDirectoriesToApply
        $updateResult = Add-PathEntry -CurrentValue $cleanupResult.Value -DirectoryPath $normalizedRegisteredPath
        if ($cleanupResult.Changed -or $updateResult.Changed) {
            Set-EnvironmentVariableValue -Name 'Path' -Value $updateResult.Value -Target $target
            $updatedTargets.Add($target) | Out-Null
        }
        if ($cleanupResult.Changed) {
            $cleanedTargets.Add($target) | Out-Null
        }
    }

    return [pscustomobject]@{
        Status             = if ($updatedTargets.Count -gt 0) { 'Registered' } else { 'AlreadyRegistered' }
        Mode               = $Mode
        RegisteredPath     = $normalizedRegisteredPath
        CleanupDirectories = @($cleanupDirectoriesToApply)
        CleanedTargets     = @($cleanedTargets.ToArray())
        UpdatedTargets     = @($updatedTargets.ToArray())
    }
}

