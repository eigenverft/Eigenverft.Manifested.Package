<#
    Eigenverft.Manifested.Sandbox.Package.Npm
#>

function Get-PackageNpmGlobalConfigPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $packageRoot = Get-PackageRootFromInventoryPath -PackageAssignmentInventoryFilePath ([string]$PackageResult.PackageConfig.PackageAssignmentInventoryFilePath)
    return ([System.IO.Path]::GetFullPath((Join-Path $packageRoot 'Configuration\External\npm\npmrc')))
}

function New-PackageNpmCacheDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $packageRoot = Get-PackageRootFromInventoryPath -PackageAssignmentInventoryFilePath ([string]$PackageResult.PackageConfig.PackageAssignmentInventoryFilePath)
    $segments = @(
        'Caches'
        'npm'
        [string]$PackageResult.DefinitionId
        [string]$PackageResult.Package.releaseTrack
        [string]$PackageResult.Package.version
        [string]$PackageResult.Package.artifactDistributionVariant
    ) | ForEach-Object {
        ([string]$_).Trim() -replace '[\\/:\*\?"<>\|]', '-'
    }

    $cacheDirectory = [System.IO.Path]::GetFullPath((Join-Path $packageRoot ($segments -join '\')))
    $null = New-Item -ItemType Directory -Path $cacheDirectory -Force
    return $cacheDirectory
}

function Initialize-PackageNpmGlobalConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$GlobalConfigPath
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($GlobalConfigPath)
    $directoryPath = Split-Path -Parent $resolvedPath
    if (-not [string]::IsNullOrWhiteSpace($directoryPath)) {
        $null = New-Item -ItemType Directory -Path $directoryPath -Force
    }

    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        Set-Content -LiteralPath $resolvedPath -Value '' -Encoding UTF8
    }

    return $resolvedPath
}

function Resolve-PackageNpmInstallerCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $install = Get-PackageAssignedInstallOperation -Release $PackageResult.Package
    if (-not $install) {
        throw "Package npm install for '$($PackageResult.PackageId)' requires packageOperations.assigned.install on the selected release."
    }
    if (-not $install.PSObject.Properties['installerCommand'] -or [string]::IsNullOrWhiteSpace([string]$install.installerCommand)) {
        throw "Package npm install for '$($PackageResult.PackageId)' requires packageOperations.assigned.install.installerCommand."
    }

    $installerCommand = [string]$install.installerCommand
    $dependencyInfo = Resolve-PackageDependencyCommandPath -PackageResult $PackageResult -CommandName $installerCommand
    Write-PackageExecutionMessage -Message ("[STATE] Installer command ready: definition='{0}', command='{1}', path='{2}'." -f $dependencyInfo.DefinitionId, $dependencyInfo.Command, $dependencyInfo.CommandPath)

    return $dependencyInfo
}

function Test-PackageNpmMaterializedInstallKind {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [psobject]$Package
    )

    $install = Get-PackageAssignedInstallOperation -Release $Package
    return ($install -and
        $install.PSObject.Properties['kind'] -and
        [string]::Equals([string]$install.kind, 'npmMaterializedInstallGlobalPackage', [System.StringComparison]::OrdinalIgnoreCase))
}

function Get-PackageNpmResolvedPackageSpec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $install = Get-PackageAssignedInstallOperation -Release $PackageResult.Package
    if (-not $install -or -not $install.PSObject.Properties['packageSpec'] -or [string]::IsNullOrWhiteSpace([string]$install.packageSpec)) {
        throw "Package npm materialized install for '$($PackageResult.PackageId)' requires packageOperations.assigned.install.packageSpec."
    }

    return (Resolve-PackageTemplateText -Text ([string]$install.packageSpec) -PackageConfig $PackageResult.PackageConfig -Package $PackageResult.Package)
}

function Get-PackageNpmMaterializationDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    if ([string]::IsNullOrWhiteSpace([string]$PackageResult.PackageFileStagingDirectory)) {
        throw "Package npm materialization for '$($PackageResult.PackageId)' requires a package file staging directory."
    }

    return ([System.IO.Path]::GetFullPath((Join-Path ([string]$PackageResult.PackageFileStagingDirectory) 'npm-materialized')))
}

function Get-PackageNpmPlatform {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig
    )

    switch -Regex ([string]$PackageConfig.Platform) {
        '^(windows|win32)$' { return 'win32' }
        '^(macos|darwin)$' { return 'darwin' }
        '^linux$' { return 'linux' }
        default { return ([string]$PackageConfig.Platform).ToLowerInvariant() }
    }
}

function Get-PackageNpmArchitecture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig
    )

    switch -Regex ([string]$PackageConfig.Architecture) {
        '^(x64|amd64)$' { return 'x64' }
        '^(arm64|aarch64)$' { return 'arm64' }
        '^(x86|ia32)$' { return 'ia32' }
        default { return ([string]$PackageConfig.Architecture).ToLowerInvariant() }
    }
}

function Test-PackageNpmIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Integrity
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    foreach ($token in @(([string]$Integrity) -split '\s+')) {
        if ([string]::IsNullOrWhiteSpace($token) -or $token -notmatch '^(?<algorithm>sha1|sha256|sha384|sha512)-(?<value>.+)$') {
            continue
        }

        $algorithm = $Matches.algorithm.ToUpperInvariant()
        $expected = $Matches.value
        $hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create($algorithm)
        if (-not $hashAlgorithm) {
            continue
        }

        $stream = [System.IO.File]::OpenRead([System.IO.Path]::GetFullPath($Path))
        try {
            $actual = [Convert]::ToBase64String($hashAlgorithm.ComputeHash($stream))
        }
        finally {
            $stream.Dispose()
            $hashAlgorithm.Dispose()
        }

        if ([string]::Equals($actual, $expected, [System.StringComparison]::Ordinal)) {
            return $true
        }
    }

    return $false
}

function ConvertTo-PackageNpmObjectArray {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [System.Array]) {
        return @($Value | Where-Object { $null -ne $_ })
    }

    return @($Value)
}

function ConvertTo-PackageNpmStringArray {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    return @(ConvertTo-PackageNpmObjectArray -Value $Value | ForEach-Object {
            [string]$_
        } | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        })
}

function Get-PackageNpmObjectPropertyValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }
        if ($InputObject.ContainsKey($Name)) {
            return $InputObject[$Name]
        }
        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) {
        return $property.Value
    }

    return $null
}

function ConvertTo-PackageNpmDependencyEntries {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Dependencies,

        [switch]$Optional
    )

    if ($null -eq $Dependencies) {
        return @()
    }

    $entries = New-Object System.Collections.Generic.List[object]
    if ($Dependencies -is [System.Collections.IDictionary]) {
        foreach ($key in @($Dependencies.Keys)) {
            $entries.Add([pscustomobject]@{
                Key      = [string]$key
                Spec     = [string]$Dependencies[$key]
                Optional = [bool]$Optional
            }) | Out-Null
        }
    }
    else {
        foreach ($property in @($Dependencies.PSObject.Properties)) {
            $entries.Add([pscustomobject]@{
                Key      = [string]$property.Name
                Spec     = [string]$property.Value
                Optional = [bool]$Optional
            }) | Out-Null
        }
    }

    return @($entries.ToArray())
}

function Resolve-PackageNpmPackageSpecParts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageSpec
    )

    $spec = ([string]$PackageSpec).Trim()
    if ($spec.StartsWith('@', [System.StringComparison]::Ordinal)) {
        if ($spec -notmatch '^(?<name>@[^/]+/[^@]+)@(?<version>.+)$') {
            throw "npm package spec '$PackageSpec' must include a scoped package name and version."
        }
    }
    elseif ($spec -notmatch '^(?<name>[^@]+)@(?<version>.+)$') {
        throw "npm package spec '$PackageSpec' must include a package name and version."
    }

    return [pscustomobject]@{
        Name    = [string]$Matches.name
        Version = [string]$Matches.version
    }
}

function Resolve-PackageNpmDependencyTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DependencyKey,

        [AllowNull()]
        [string]$DependencySpec
    )

    $spec = ([string]$DependencySpec).Trim()
    if ($spec.StartsWith('npm:', [System.StringComparison]::OrdinalIgnoreCase)) {
        $target = Resolve-PackageNpmPackageSpecParts -PackageSpec $spec.Substring(4)
        return [pscustomobject]@{
            InstallKey    = $DependencyKey
            TargetName    = $target.Name
            TargetVersion = $target.Version
            IsAlias       = $true
        }
    }

    $version = $null
    if ($spec -match '^[0-9][0-9A-Za-z\.\-_]*$') {
        $version = $spec
    }

    return [pscustomobject]@{
        InstallKey    = $DependencyKey
        TargetName    = $DependencyKey
        TargetVersion = $version
        IsAlias       = $false
    }
}

function ConvertTo-PackageNpmFileUriPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return ([System.IO.Path]::GetFullPath($Path) -replace '\\', '/')
}

function New-PackageNpmLocalFileSpec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName,

        [Parameter(Mandatory = $true)]
        [string]$TarballPath
    )

    if ([string]::IsNullOrWhiteSpace($PackageName)) {
        throw 'npm local file spec requires a package name.'
    }

    return ('{0}@file:{1}' -f $PackageName, (ConvertTo-PackageNpmFileUriPath -Path $TarballPath))
}

function Read-PackageNpmTarballPackageJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $json = Read-TarGzipArchiveEntryText -ArchivePath $Path -EntryPath 'package/package.json'
    return ($json | ConvertFrom-Json)
}

function Get-PackageNpmTarballMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $packageJson = Read-PackageNpmTarballPackageJson -Path $resolvedPath
    $name = [string](Get-PackageNpmObjectPropertyValue -InputObject $packageJson -Name 'name')
    $version = [string](Get-PackageNpmObjectPropertyValue -InputObject $packageJson -Name 'version')
    if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($version)) {
        throw "npm tarball '$resolvedPath' package/package.json must include name and version."
    }

    return [pscustomobject]@{
        Path                 = $resolvedPath
        FileName             = Split-Path -Leaf $resolvedPath
        Name                 = $name
        Version              = $version
        OS                   = @(ConvertTo-PackageNpmStringArray -Value (Get-PackageNpmObjectPropertyValue -InputObject $packageJson -Name 'os'))
        CPU                  = @(ConvertTo-PackageNpmStringArray -Value (Get-PackageNpmObjectPropertyValue -InputObject $packageJson -Name 'cpu'))
        Dependencies         = Get-PackageNpmObjectPropertyValue -InputObject $packageJson -Name 'dependencies'
        OptionalDependencies = Get-PackageNpmObjectPropertyValue -InputObject $packageJson -Name 'optionalDependencies'
        PackageJson          = $packageJson
    }
}

function Test-PackageNpmTarballMetadataAllowsPlatform {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Metadata,

        [Parameter(Mandatory = $true)]
        [string]$NpmPlatform,

        [Parameter(Mandatory = $true)]
        [string]$NpmArchitecture
    )

    return ((Test-PackageNpmPlatformListAllows -List $Metadata.OS -Value $NpmPlatform) -and
        (Test-PackageNpmPlatformListAllows -List $Metadata.CPU -Value $NpmArchitecture))
}

function Find-PackageNpmMaterializedTarballMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Metadata,

        [Parameter(Mandatory = $true)]
        [psobject]$Target,

        [Parameter(Mandatory = $true)]
        [string]$NpmPlatform,

        [Parameter(Mandatory = $true)]
        [string]$NpmArchitecture,

        [Parameter(Mandatory = $true)]
        [string]$PackageId,

        [switch]$Optional
    )

    $matches = @($Metadata | Where-Object {
            [string]::Equals([string]$_.Name, [string]$Target.TargetName, [System.StringComparison]::OrdinalIgnoreCase) -and
            ([string]::IsNullOrWhiteSpace([string]$Target.TargetVersion) -or [string]::Equals([string]$_.Version, [string]$Target.TargetVersion, [System.StringComparison]::OrdinalIgnoreCase))
        } | Where-Object {
            Test-PackageNpmTarballMetadataAllowsPlatform -Metadata $_ -NpmPlatform $NpmPlatform -NpmArchitecture $NpmArchitecture
        })

    if ($matches.Count -eq 0) {
        if ($Optional) {
            return $null
        }
        throw "Package npm materialization for '$PackageId' is missing local tarball for dependency '$($Target.InstallKey)' -> '$($Target.TargetName)@$($Target.TargetVersion)'."
    }
    if ($matches.Count -gt 1) {
        throw "Package npm materialization for '$PackageId' has ambiguous local tarballs for dependency '$($Target.InstallKey)' -> '$($Target.TargetName)@$($Target.TargetVersion)'."
    }

    return $matches[0]
}

function Resolve-PackageNpmMaterializedInstallInputsFromTarballs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId,

        [Parameter(Mandatory = $true)]
        [string]$PackageSpec,

        [Parameter(Mandatory = $true)]
        [object[]]$TarballPaths,

        [Parameter(Mandatory = $true)]
        [string]$NpmPlatform,

        [Parameter(Mandatory = $true)]
        [string]$NpmArchitecture
    )

    $rootSpec = Resolve-PackageNpmPackageSpecParts -PackageSpec $PackageSpec
    $metadata = @($TarballPaths | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace([string]$_) -or -not (Test-Path -LiteralPath ([string]$_) -PathType Leaf)) {
                throw "Package npm materialization for '$PackageId' is missing local tarball '$($_)'."
            }
            Get-PackageNpmTarballMetadata -Path ([string]$_)
        })

    $rootCandidates = @($metadata | Where-Object {
            [string]::Equals([string]$_.Name, [string]$rootSpec.Name, [System.StringComparison]::OrdinalIgnoreCase) -and
            [string]::Equals([string]$_.Version, [string]$rootSpec.Version, [System.StringComparison]::OrdinalIgnoreCase) -and
            (Test-PackageNpmTarballMetadataAllowsPlatform -Metadata $_ -NpmPlatform $NpmPlatform -NpmArchitecture $NpmArchitecture)
        })
    if ($rootCandidates.Count -eq 0) {
        throw "Package npm materialization for '$PackageId' is missing root tarball '$($rootSpec.Name)@$($rootSpec.Version)'."
    }
    if ($rootCandidates.Count -gt 1) {
        throw "Package npm materialization for '$PackageId' has ambiguous root tarballs for '$($rootSpec.Name)@$($rootSpec.Version)'."
    }

    $installInputs = New-Object System.Collections.Generic.List[object]
    $queue = New-Object System.Collections.Queue
    $seenKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    function Add-MaterializedNpmInstallInput {
        param(
            [Parameter(Mandatory = $true)]
            [psobject]$PackageMetadata,

            [Parameter(Mandatory = $true)]
            [string]$InstallKey,

            [Parameter(Mandatory = $true)]
            [string]$Role
        )

        $dedupeKey = '{0}|{1}|{2}' -f $InstallKey, [string]$PackageMetadata.Name, [string]$PackageMetadata.Version
        if ($seenKeys.Add($dedupeKey)) {
            $input = [pscustomobject]@{
                InstallKey = $InstallKey
                Name       = [string]$PackageMetadata.Name
                Version    = [string]$PackageMetadata.Version
                Path       = [string]$PackageMetadata.Path
                FileSpec   = New-PackageNpmLocalFileSpec -PackageName $InstallKey -TarballPath ([string]$PackageMetadata.Path)
                Role       = $Role
            }
            $installInputs.Add($input) | Out-Null
            $queue.Enqueue($PackageMetadata)
        }
    }

    Add-MaterializedNpmInstallInput -PackageMetadata $rootCandidates[0] -InstallKey ([string]$rootCandidates[0].Name) -Role 'root'

    while ($queue.Count -gt 0) {
        $current = [psobject]$queue.Dequeue()
        $dependencyEntries = @()
        $dependencyEntries += @(ConvertTo-PackageNpmDependencyEntries -Dependencies $current.Dependencies)
        $dependencyEntries += @(ConvertTo-PackageNpmDependencyEntries -Dependencies $current.OptionalDependencies -Optional)

        foreach ($dependency in @($dependencyEntries)) {
            if ([string]::IsNullOrWhiteSpace([string]$dependency.Key) -or [string]::IsNullOrWhiteSpace([string]$dependency.Spec)) {
                continue
            }

            $target = Resolve-PackageNpmDependencyTarget -DependencyKey ([string]$dependency.Key) -DependencySpec ([string]$dependency.Spec)
            $candidate = Find-PackageNpmMaterializedTarballMetadata -Metadata $metadata -Target $target -NpmPlatform $NpmPlatform -NpmArchitecture $NpmArchitecture -PackageId $PackageId -Optional:([bool]$dependency.Optional)
            if ($candidate) {
                Add-MaterializedNpmInstallInput -PackageMetadata $candidate -InstallKey ([string]$target.InstallKey) -Role $(if ([bool]$dependency.Optional) { 'optionalDependency' } else { 'dependency' })
            }
        }
    }

    return @($installInputs.ToArray())
}

function ConvertFrom-PackageNpmJsonOutput {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object[]]$Output,

        [Parameter(Mandatory = $true)]
        [string]$OperationName
    )

    $text = @($Output | Where-Object { $null -ne $_ }) -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "$OperationName did not return JSON output."
    }

    try {
        return @(ConvertTo-PackageNpmObjectArray -Value ($text | ConvertFrom-Json))
    }
    catch {
        $start = $text.IndexOf('[')
        $end = $text.LastIndexOf(']')
        if ($start -ge 0 -and $end -gt $start) {
            try {
                return @(ConvertTo-PackageNpmObjectArray -Value ($text.Substring($start, ($end - $start + 1)) | ConvertFrom-Json))
            }
            catch {
                # Report the original parse failure below; the sliced retry is only a noise guard.
            }
        }
        throw "$OperationName did not return parseable JSON output. $($_.Exception.Message)"
    }
}

function Test-PackageNpmPlatformListAllows {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$List,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $entries = @(ConvertTo-PackageNpmObjectArray -Value $List | ForEach-Object { [string]$_ })
    if ($entries.Count -eq 0) {
        return $true
    }

    $negative = @($entries | Where-Object { $_.StartsWith('!') } | ForEach-Object { $_.Substring(1) })
    if ($negative -contains $Value) {
        return $false
    }

    $positive = @($entries | Where-Object { -not $_.StartsWith('!') })
    return ($positive.Count -eq 0 -or $positive -contains $Value)
}

function Get-PackageNpmNameFromLockKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LockKey
    )

    $parts = $LockKey -split 'node_modules/'
    return ($parts[$parts.Count - 1]).TrimEnd('/')
}

function Get-PackageNpmFileNameFromResolved {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Resolved
    )

    if ([string]::IsNullOrWhiteSpace($Resolved)) {
        return $null
    }

    try {
        $uri = [Uri]$Resolved
        return [Uri]::UnescapeDataString(($uri.AbsolutePath -split '/')[-1])
    }
    catch {
        return $null
    }
}

function Read-PackageNpmLockJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LockFilePath
    )

    $json = Get-Content -LiteralPath $LockFilePath -Raw
    $convertCommand = Get-Command -Name ConvertFrom-Json -ErrorAction Stop
    if ($convertCommand.Parameters.ContainsKey('AsHashTable')) {
        return ($json | ConvertFrom-Json -AsHashTable)
    }

    try {
        if (-not [System.Type]::GetType('System.Web.Script.Serialization.JavaScriptSerializer, System.Web.Extensions', $false)) {
            Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
        }
        $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $serializer.MaxJsonLength = [int]::MaxValue
        return $serializer.DeserializeObject($json)
    }
    catch {
        throw "Unable to parse npm package-lock.json without PowerShell ConvertFrom-Json -AsHashTable support. $($_.Exception.Message)"
    }
}

function Get-PackageNpmMaterializedPackagesFromLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LockFilePath,

        [Parameter(Mandatory = $true)]
        [string]$NpmPlatform,

        [Parameter(Mandatory = $true)]
        [string]$NpmArchitecture
    )

    $lock = Read-PackageNpmLockJson -LockFilePath $LockFilePath
    if (-not $lock) {
        return @()
    }

    $packageEntries = @()
    if ($lock -is [System.Collections.IDictionary]) {
        if (-not $lock.ContainsKey('packages')) {
            return @()
        }
        $packageEntries = @($lock['packages'].GetEnumerator() | ForEach-Object {
                [pscustomobject]@{ Name = [string]$_.Key; Value = $_.Value }
            })
    }
    elseif ($lock.PSObject.Properties['packages']) {
        $packageEntries = @($lock.packages.PSObject.Properties)
    }
    else {
        return @()
    }

    $packages = New-Object System.Collections.Generic.List[object]
    foreach ($property in @($packageEntries)) {
        $lockKey = [string]$property.Name
        $entry = $property.Value
        if ($lockKey -notlike '*node_modules/*' -or -not $entry) {
            continue
        }

        $version = if ($entry -is [System.Collections.IDictionary]) { [string]$entry['version'] } else { [string]$entry.version }
        $resolved = if ($entry -is [System.Collections.IDictionary]) { [string]$entry['resolved'] } else { [string]$entry.resolved }
        $integrity = if ($entry -is [System.Collections.IDictionary]) { [string]$entry['integrity'] } else { [string]$entry.integrity }
        if ([string]::IsNullOrWhiteSpace($version) -or [string]::IsNullOrWhiteSpace($resolved) -or [string]::IsNullOrWhiteSpace($integrity)) {
            continue
        }

        $os = if ($entry -is [System.Collections.IDictionary]) { $entry['os'] } else { $entry.os }
        $cpu = if ($entry -is [System.Collections.IDictionary]) { $entry['cpu'] } else { $entry.cpu }
        if (-not (Test-PackageNpmPlatformListAllows -List $os -Value $NpmPlatform) -or
            -not (Test-PackageNpmPlatformListAllows -List $cpu -Value $NpmArchitecture)) {
            continue
        }

        $lockEntryName = if ($entry -is [System.Collections.IDictionary]) { [string]$entry['name'] } else { [string]$entry.name }
        $packageName = if (-not [string]::IsNullOrWhiteSpace($lockEntryName)) {
            $lockEntryName
        }
        else {
            Get-PackageNpmNameFromLockKey -LockKey $lockKey
        }

        $packages.Add([pscustomobject]@{
            Name      = $packageName
            Version   = $version
            Resolved  = $resolved
            Integrity = $integrity
            FileName  = Get-PackageNpmFileNameFromResolved -Resolved $resolved
            Optional  = if ($entry -is [System.Collections.IDictionary]) { [bool]$entry['optional'] } else { [bool]($entry.PSObject.Properties['optional'] -and $entry.optional) }
        }) | Out-Null
    }

    return @($packages.ToArray())
}

function Test-PackageNpmMaterializationDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        return $null
    }

    $tarballPaths = @(Get-ChildItem -LiteralPath $Directory -Filter '*.tgz' -File -ErrorAction SilentlyContinue | ForEach-Object { [System.IO.Path]::GetFullPath($_.FullName) })
    if ($tarballPaths.Count -eq 0) {
        return $null
    }

    return [pscustomobject]@{
        Directory    = [System.IO.Path]::GetFullPath($Directory)
        TarballPaths = @($tarballPaths)
    }
}

function Copy-PackageNpmMaterializationDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $true)]
        [string]$TargetDirectory,

        [Parameter(Mandatory = $true)]
        [psobject]$Materialization
    )

    $null = New-Item -ItemType Directory -Path $TargetDirectory -Force
    $copiedTarballs = New-Object System.Collections.Generic.List[string]
    foreach ($sourcePath in @($Materialization.TarballPaths)) {
        $targetPath = [System.IO.Path]::GetFullPath((Join-Path $TargetDirectory (Split-Path -Leaf ([string]$sourcePath))))
        $null = Copy-FileToPath -SourcePath ([string]$sourcePath) -TargetPath $targetPath -Overwrite
        $copiedTarballs.Add($targetPath) | Out-Null
    }

    return [pscustomobject]@{
        Directory    = [System.IO.Path]::GetFullPath($TargetDirectory)
        TarballPaths = @($copiedTarballs.ToArray())
    }
}

function Find-PackageNpmMaterializationInDepots {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    foreach ($depotSource in @(Get-PackagePackageDepotSources -PackageConfig $PackageResult.PackageConfig)) {
        if ([string]::IsNullOrWhiteSpace([string]$depotSource.basePath)) {
            continue
        }

        $candidateDirectory = [System.IO.Path]::GetFullPath((Join-Path ([string]$depotSource.basePath) ([string]$PackageResult.PackageDepotRelativeDirectory)))
        $materialization = Test-PackageNpmMaterializationDirectory -Directory $candidateDirectory
        if ($materialization) {
            $materialization | Add-Member -MemberType NoteProperty -Name SourceId -Value ([string]$depotSource.id) -Force
            $materialization | Add-Member -MemberType NoteProperty -Name SourceDirectory -Value $candidateDirectory -Force
            return $materialization
        }
    }

    return $null
}

function New-PackageNpmMaterializationFromRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [string]$PackageSpec,

        [Parameter(Mandatory = $true)]
        [string]$NpmPlatform,

        [Parameter(Mandatory = $true)]
        [string]$NpmArchitecture,

        [Parameter(Mandatory = $true)]
        [string]$TargetDirectory
    )

    Write-PackageExecutionMessage -Message ("[STATE] Materializing npm package spec '{0}'." -f $PackageSpec)
    $installerCommandInfo = Resolve-PackageNpmInstallerCommand -PackageResult $PackageResult
    $cacheDirectory = New-PackageNpmCacheDirectory -PackageResult $PackageResult
    $globalConfigPath = Initialize-PackageNpmGlobalConfig -GlobalConfigPath (Get-PackageNpmGlobalConfigPath -PackageResult $PackageResult)
    $targetFullPath = [System.IO.Path]::GetFullPath($TargetDirectory)
    $resolutionDirectory = [System.IO.Path]::GetFullPath((Join-Path $targetFullPath '.npm-resolution'))

    Remove-PathIfExists -Path $resolutionDirectory | Out-Null
    $null = New-Item -ItemType Directory -Path $targetFullPath -Force
    $null = New-Item -ItemType Directory -Path $resolutionDirectory -Force

    $lockArguments = @('install', '--package-lock-only', '--ignore-scripts', '--no-audit', '--no-fund', '--cache', $cacheDirectory)
    $lockArguments += @(Get-NpmGlobalConfigArguments -GlobalConfigPath $globalConfigPath)
    $lockArguments += $PackageSpec

    Push-Location $resolutionDirectory
    try {
        & ([string]$installerCommandInfo.CommandPath) @lockArguments
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) {
            $exitCode = 0
        }
    }
    finally {
        Pop-Location
    }
    if ($exitCode -ne 0) {
        throw "npm metadata resolution for '$PackageSpec' failed with exit code $exitCode."
    }

    $lockFilePath = Join-Path $resolutionDirectory 'package-lock.json'
    if (-not (Test-Path -LiteralPath $lockFilePath -PathType Leaf)) {
        throw "npm metadata resolution for '$PackageSpec' did not produce package-lock.json."
    }

    $packages = @(Get-PackageNpmMaterializedPackagesFromLock -LockFilePath $lockFilePath -NpmPlatform $NpmPlatform -NpmArchitecture $NpmArchitecture)
    if ($packages.Count -eq 0) {
        throw "npm metadata resolution for '$PackageSpec' did not produce any materializable packages."
    }

    foreach ($package in $packages) {
        $packageName = [string]$package.Name
        $packageVersion = [string]$package.Version
        $knownFileName = [string]$package.FileName
        $knownIntegrity = [string]$package.Integrity
        if ([string]::IsNullOrWhiteSpace($packageName) -or [string]::IsNullOrWhiteSpace($packageVersion)) {
            throw "npm materialization package metadata must include name and version."
        }
        if (-not [string]::IsNullOrWhiteSpace($knownFileName) -and -not [string]::IsNullOrWhiteSpace($knownIntegrity)) {
            $knownTargetPath = [System.IO.Path]::GetFullPath((Join-Path $targetFullPath $knownFileName))
            if (Test-PackageNpmIntegrity -Path $knownTargetPath -Integrity $knownIntegrity) {
                continue
            }
        }

        $packageSpecForPack = '{0}@{1}' -f $packageName, $packageVersion
        $packArguments = @('pack', $packageSpecForPack, '--pack-destination', $targetFullPath, '--json', '--cache', $cacheDirectory)
        $packArguments += @(Get-NpmGlobalConfigArguments -GlobalConfigPath $globalConfigPath)

        Write-PackageExecutionMessage -Message ("[STATE] Packing npm materialized package '{0}'." -f $packageSpecForPack)
        Push-Location $targetFullPath
        try {
            $packOutput = & ([string]$installerCommandInfo.CommandPath) @packArguments
            $packExitCode = $LASTEXITCODE
            if ($null -eq $packExitCode) {
                $packExitCode = 0
            }
        }
        finally {
            Pop-Location
        }
        if ($packExitCode -ne 0) {
            throw "npm pack for '$packageSpecForPack' failed with exit code $packExitCode."
        }

        $packItems = @(ConvertFrom-PackageNpmJsonOutput -Output $packOutput -OperationName "npm pack for '$packageSpecForPack'")
        $packItem = @($packItems | Where-Object {
                [string]::Equals([string]$_.name, $packageName, [System.StringComparison]::OrdinalIgnoreCase) -and
                [string]::Equals([string]$_.version, $packageVersion, [System.StringComparison]::OrdinalIgnoreCase)
            } | Select-Object -First 1)
        if ($packItem.Count -eq 0) {
            $packItem = @($packItems | Select-Object -First 1)
        }

        $fileName = [string]$packItem[0].filename
        if ([string]::IsNullOrWhiteSpace($fileName)) {
            $fileName = $knownFileName
        }
        $integrity = [string]$packItem[0].integrity
        if ([string]::IsNullOrWhiteSpace($integrity)) {
            $integrity = $knownIntegrity
        }
        if ([string]::IsNullOrWhiteSpace($fileName) -or [string]::IsNullOrWhiteSpace($integrity)) {
            throw "npm pack for '$packageSpecForPack' did not report tarball filename and integrity metadata."
        }
        $targetPath = [System.IO.Path]::GetFullPath((Join-Path $targetFullPath $fileName))
        if (-not (Test-PackageNpmIntegrity -Path $targetPath -Integrity $integrity)) {
            throw "npm pack output '$fileName' did not satisfy integrity metadata."
        }
    }

    $materialization = Test-PackageNpmMaterializationDirectory -Directory $targetFullPath
    if (-not $materialization) {
        throw "npm materialization for '$PackageSpec' could not be validated after download."
    }

    return $materialization
}

function Invoke-PackageNpmMaterializationDepotDistribution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [psobject]$Materialization
    )

    $mode = if ($PackageResult.PackageConfig.PSObject.Properties['DepotDistributionMode'] -and
        -not [string]::IsNullOrWhiteSpace([string]$PackageResult.PackageConfig.DepotDistributionMode)) {
        [string]$PackageResult.PackageConfig.DepotDistributionMode
    }
    else {
        'packageFocused'
    }

    $files = New-Object System.Collections.Generic.List[object]
    foreach ($tarballPath in @($Materialization.TarballPaths)) {
        if ([string]::IsNullOrWhiteSpace([string]$tarballPath) -or -not (Test-Path -LiteralPath ([string]$tarballPath) -PathType Leaf)) {
            continue
        }
        $files.Add([pscustomobject]@{
            FileName   = Split-Path -Leaf ([string]$tarballPath)
            SourcePath = [System.IO.Path]::GetFullPath([string]$tarballPath)
        }) | Out-Null
    }

    $actions = New-Object System.Collections.Generic.List[object]
    if ([string]::Equals($mode, 'disabled', [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ Mode = $mode; Status = 'Skipped'; Reason = 'DisabledByPolicy'; Actions = @(); CopiedCount = 0; FailedCount = 0; SkippedCount = 0 }
    }

    foreach ($mirrorSource in @(Get-PackageDepotDistributionTargets -PackageConfig $PackageResult.PackageConfig)) {
        foreach ($file in @($files.ToArray())) {
            if (-not [string]::Equals([string]$mirrorSource.kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
                $actions.Add([pscustomobject]@{ DepotId = [string]$mirrorSource.id; FileName = [string]$file.FileName; Action = 'Skip'; Status = 'Skipped'; Reason = 'UnsupportedDepotKind'; SourcePath = [string]$file.SourcePath; TargetPath = $null; EnsureExists = [bool]$mirrorSource.ensureExists; ErrorMessage = $null }) | Out-Null
                continue
            }
            if ([string]::IsNullOrWhiteSpace([string]$mirrorSource.basePath)) {
                $actions.Add([pscustomobject]@{ DepotId = [string]$mirrorSource.id; FileName = [string]$file.FileName; Action = 'Skip'; Status = 'Skipped'; Reason = 'MissingBasePath'; SourcePath = [string]$file.SourcePath; TargetPath = $null; EnsureExists = [bool]$mirrorSource.ensureExists; ErrorMessage = $null }) | Out-Null
                continue
            }

            $targetDirectory = [System.IO.Path]::GetFullPath((Join-Path ([string]$mirrorSource.basePath) ([string]$PackageResult.PackageDepotRelativeDirectory)))
            $targetPath = [System.IO.Path]::GetFullPath((Join-Path $targetDirectory ([string]$file.FileName)))
            $sourceFullPath = [System.IO.Path]::GetFullPath([string]$file.SourcePath)
            if ([string]::Equals($sourceFullPath, $targetPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                $actions.Add([pscustomobject]@{ DepotId = [string]$mirrorSource.id; FileName = [string]$file.FileName; Action = 'Skip'; Status = 'Skipped'; Reason = 'SourceIsTarget'; SourcePath = $sourceFullPath; TargetPath = $targetPath; EnsureExists = [bool]$mirrorSource.ensureExists; ErrorMessage = $null }) | Out-Null
                continue
            }

            $match = Test-PackageDepotDistributionFileMatches -SourcePath $sourceFullPath -TargetPath $targetPath
            if ($match.Matches) {
                $actions.Add([pscustomobject]@{ DepotId = [string]$mirrorSource.id; FileName = [string]$file.FileName; Action = 'Skip'; Status = 'Skipped'; Reason = [string]$match.Reason; SourcePath = $sourceFullPath; TargetPath = $targetPath; EnsureExists = [bool]$mirrorSource.ensureExists; ErrorMessage = $null }) | Out-Null
                continue
            }
            if ([string]::Equals($mode, 'packageFocused', [System.StringComparison]::OrdinalIgnoreCase) -and
                -not [string]::Equals([string]$match.Reason, 'Missing', [System.StringComparison]::OrdinalIgnoreCase)) {
                $actions.Add([pscustomobject]@{ DepotId = [string]$mirrorSource.id; FileName = [string]$file.FileName; Action = 'Skip'; Status = 'Skipped'; Reason = 'DifferentTargetPreservedByPackageFocusedPolicy'; SourcePath = $sourceFullPath; TargetPath = $targetPath; EnsureExists = [bool]$mirrorSource.ensureExists; ErrorMessage = [string]$match.Reason }) | Out-Null
                continue
            }

            try {
                if ($mirrorSource.ensureExists) {
                    $null = New-Item -ItemType Directory -Path $targetDirectory -Force
                }
                $null = Copy-FileToPath -SourcePath $sourceFullPath -TargetPath $targetPath -Overwrite
                $actions.Add([pscustomobject]@{ DepotId = [string]$mirrorSource.id; FileName = [string]$file.FileName; Action = 'Copy'; Status = 'Copied'; Reason = [string]$match.Reason; SourcePath = $sourceFullPath; TargetPath = $targetPath; EnsureExists = [bool]$mirrorSource.ensureExists; ErrorMessage = $null }) | Out-Null
            }
            catch {
                $actions.Add([pscustomobject]@{ DepotId = [string]$mirrorSource.id; FileName = [string]$file.FileName; Action = 'Copy'; Status = 'Failed'; Reason = [string]$match.Reason; SourcePath = $sourceFullPath; TargetPath = $targetPath; EnsureExists = [bool]$mirrorSource.ensureExists; ErrorMessage = $_.Exception.Message }) | Out-Null
            }
        }
    }

    $copiedCount = @($actions.ToArray() | Where-Object { [string]::Equals([string]$_.Status, 'Copied', [System.StringComparison]::OrdinalIgnoreCase) }).Count
    $failedCount = @($actions.ToArray() | Where-Object { [string]::Equals([string]$_.Status, 'Failed', [System.StringComparison]::OrdinalIgnoreCase) }).Count
    $skippedCount = @($actions.ToArray() | Where-Object { [string]::Equals([string]$_.Status, 'Skipped', [System.StringComparison]::OrdinalIgnoreCase) }).Count

    return [pscustomobject]@{
        Mode         = $mode
        Status       = if ($actions.Count -eq 0) { 'Skipped' } else { 'Planned' }
        Reason       = if ($actions.Count -eq 0) { 'NoDepotTargets' } else { $null }
        Actions      = @($actions.ToArray())
        CopiedCount  = $copiedCount
        FailedCount  = $failedCount
        SkippedCount = $skippedCount
    }
}

function Invoke-PackageNpmMaterialization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    if (-not (Test-PackageNpmMaterializedInstallKind -Package $PackageResult.Package)) {
        return $PackageResult
    }

    $packageSpec = Get-PackageNpmResolvedPackageSpec -PackageResult $PackageResult
    $npmPlatform = Get-PackageNpmPlatform -PackageConfig $PackageResult.PackageConfig
    $npmArchitecture = Get-PackageNpmArchitecture -PackageConfig $PackageResult.PackageConfig
    $stageDirectory = Get-PackageNpmMaterializationDirectory -PackageResult $PackageResult
    Remove-PathIfExists -Path $stageDirectory | Out-Null

    $depotMaterialization = Find-PackageNpmMaterializationInDepots -PackageResult $PackageResult
    if ($depotMaterialization) {
        $copied = Copy-PackageNpmMaterializationDirectory -SourceDirectory ([string]$depotMaterialization.SourceDirectory) -TargetDirectory $stageDirectory -Materialization $depotMaterialization
        $PackageResult | Add-Member -MemberType NoteProperty -Name NpmMaterialization -Value ([pscustomobject]@{
            Success         = $true
            Status          = 'HydratedFromDepot'
            PackageSpec     = $packageSpec
            NpmPlatform     = $npmPlatform
            NpmArchitecture = $npmArchitecture
            SourceId        = [string]$depotMaterialization.SourceId
            TarballPaths    = @($copied.TarballPaths)
            DepotDistribution = $null
        }) -Force
        Write-PackageExecutionMessage -Message ("[ACTION] Hydrated npm materialization from depot '{0}'." -f [string]$depotMaterialization.SourceId)
    }
    else {
        $materialization = New-PackageNpmMaterializationFromRegistry -PackageResult $PackageResult -PackageSpec $packageSpec -NpmPlatform $npmPlatform -NpmArchitecture $npmArchitecture -TargetDirectory $stageDirectory
        $PackageResult | Add-Member -MemberType NoteProperty -Name NpmMaterialization -Value ([pscustomobject]@{
            Success         = $true
            Status          = 'MaterializedFromRegistry'
            PackageSpec     = $packageSpec
            NpmPlatform     = $npmPlatform
            NpmArchitecture = $npmArchitecture
            SourceId        = 'npmRegistry'
            TarballPaths    = @($materialization.TarballPaths)
            DepotDistribution = $null
        }) -Force
        Write-PackageExecutionMessage -Message ("[ACTION] Materialized npm package spec '{0}' with {1} tarball(s)." -f $packageSpec, @($materialization.TarballPaths).Count)
    }

    $installInputs = @(Resolve-PackageNpmMaterializedInstallInputsFromTarballs -PackageId ([string]$PackageResult.PackageId) -PackageSpec $packageSpec -TarballPaths @($PackageResult.NpmMaterialization.TarballPaths) -NpmPlatform $npmPlatform -NpmArchitecture $npmArchitecture)
    $PackageResult.NpmMaterialization | Add-Member -MemberType NoteProperty -Name InstallInputs -Value @($installInputs) -Force
    Write-PackageExecutionMessage -Message ("[STATE] npm materialized install inputs: {0}" -f (@($installInputs | ForEach-Object { [string]$_.FileSpec }) -join ', '))

    $distribution = Invoke-PackageNpmMaterializationDepotDistribution -PackageResult $PackageResult -Materialization $PackageResult.NpmMaterialization
    $PackageResult.NpmMaterialization.DepotDistribution = $distribution
    Write-PackageExecutionMessage -Message ("[STATE] npm materialization depot distribution completed: mode='{0}', copied={1}, skipped={2}, failed={3}." -f [string]$distribution.Mode, [int]$distribution.CopiedCount, [int]$distribution.SkippedCount, [int]$distribution.FailedCount)

    return $PackageResult
}

function Install-PackageNpmMaterializedInstallGlobalPackage {
<#
.SYNOPSIS
Installs a materialized npm package spec from local tarballs into a staged Package-owned prefix.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $install = Get-PackageAssignedInstallOperation -Release $PackageResult.Package
    if (-not $install) {
        throw "Package npm materialized install for '$($PackageResult.PackageId)' requires packageOperations.assigned.install on the selected release."
    }
    if (-not $PackageResult.PSObject.Properties['NpmMaterialization'] -or -not $PackageResult.NpmMaterialization -or -not $PackageResult.NpmMaterialization.Success) {
        throw "Package npm materialized install for '$($PackageResult.PackageId)' requires prepared npm materialization."
    }

    $packageSpec = Get-PackageNpmResolvedPackageSpec -PackageResult $PackageResult
    $tarballPaths = @($PackageResult.NpmMaterialization.TarballPaths)
    if ($tarballPaths.Count -eq 0) {
        throw "Package npm materialized install for '$($PackageResult.PackageId)' has no local materialized tarballs."
    }
    foreach ($tarballPath in $tarballPaths) {
        if ([string]::IsNullOrWhiteSpace([string]$tarballPath) -or -not (Test-Path -LiteralPath ([string]$tarballPath) -PathType Leaf)) {
            throw "Package npm materialized install for '$($PackageResult.PackageId)' is missing materialized tarball '$tarballPath'."
        }
    }
    $installInputs = @()
    if ($PackageResult.NpmMaterialization.PSObject.Properties['InstallInputs']) {
        $installInputs = @($PackageResult.NpmMaterialization.InstallInputs)
    }
    if ($installInputs.Count -eq 0) {
        $npmPlatform = if ($PackageResult.NpmMaterialization.PSObject.Properties['NpmPlatform'] -and -not [string]::IsNullOrWhiteSpace([string]$PackageResult.NpmMaterialization.NpmPlatform)) {
            [string]$PackageResult.NpmMaterialization.NpmPlatform
        }
        else {
            Get-PackageNpmPlatform -PackageConfig $PackageResult.PackageConfig
        }
        $npmArchitecture = if ($PackageResult.NpmMaterialization.PSObject.Properties['NpmArchitecture'] -and -not [string]::IsNullOrWhiteSpace([string]$PackageResult.NpmMaterialization.NpmArchitecture)) {
            [string]$PackageResult.NpmMaterialization.NpmArchitecture
        }
        else {
            Get-PackageNpmArchitecture -PackageConfig $PackageResult.PackageConfig
        }
        $installInputs = @(Resolve-PackageNpmMaterializedInstallInputsFromTarballs -PackageId ([string]$PackageResult.PackageId) -PackageSpec $packageSpec -TarballPaths $tarballPaths -NpmPlatform $npmPlatform -NpmArchitecture $npmArchitecture)
    }
    if ($installInputs.Count -eq 0) {
        throw "Package npm materialized install for '$($PackageResult.PackageId)' has no resolved local install inputs."
    }

    $installerCommandInfo = Resolve-PackageNpmInstallerCommand -PackageResult $PackageResult
    $cacheDirectory = New-PackageNpmCacheDirectory -PackageResult $PackageResult
    $globalConfigPath = Initialize-PackageNpmGlobalConfig -GlobalConfigPath (Get-PackageNpmGlobalConfigPath -PackageResult $PackageResult)
    if ([string]::IsNullOrWhiteSpace([string]$PackageResult.PackageInstallStageDirectory)) {
        throw "Package npm materialized install for '$($PackageResult.PackageId)' requires a package install stage directory."
    }

    $stagePath = [System.IO.Path]::GetFullPath([string]$PackageResult.PackageInstallStageDirectory)
    Remove-PathIfExists -Path $stagePath | Out-Null
    $null = New-Item -ItemType Directory -Path $stagePath -Force
    $stagePromoted = $false

    $cacheAddArguments = @('cache', 'add')
    $cacheAddArguments += @($tarballPaths)
    $cacheAddArguments += @('--cache', $cacheDirectory)
    $cacheAddArguments += @(Get-NpmGlobalConfigArguments -GlobalConfigPath $globalConfigPath)

    $commandArguments = @('install', '-g', '--prefix', $stagePath, '--cache', $cacheDirectory, '--offline')
    $commandArguments += @(Get-NpmGlobalConfigArguments -GlobalConfigPath $globalConfigPath)
    $commandArguments += @($installInputs | ForEach-Object { [string]$_.FileSpec })

    Write-PackageExecutionMessage -Message ("[STATE] npm materialized package install:")
    Write-PackageExecutionMessage -Message ("[PATH] npm command: {0}" -f $installerCommandInfo.CommandPath)
    Write-PackageExecutionMessage -Message ("[PATH] npm stage: {0}" -f $stagePath)
    Write-PackageExecutionMessage -Message ("[PATH] npm cache: {0}" -f $cacheDirectory)
    Write-PackageExecutionMessage -Message ("[STATE] npm materialized tarballs: {0}" -f ($tarballPaths -join ', '))
    Write-PackageExecutionMessage -Message ("[STATE] npm materialized install inputs: {0}" -f (@($installInputs | ForEach-Object { [string]$_.FileSpec }) -join ', '))
    Write-PackageExecutionMessage -Message ("[STATE] npm package spec: {0}" -f $packageSpec)

    try {
        & ([string]$installerCommandInfo.CommandPath) @cacheAddArguments
        $cacheAddExitCode = $LASTEXITCODE
        if ($null -eq $cacheAddExitCode) {
            $cacheAddExitCode = 0
        }
        if ($cacheAddExitCode -ne 0) {
            throw "npm cache add for materialized package '$($PackageResult.PackageId)' failed with exit code $cacheAddExitCode."
        }

        Push-Location $stagePath
        try {
            & ([string]$installerCommandInfo.CommandPath) @commandArguments
            $exitCode = $LASTEXITCODE
            if ($null -eq $exitCode) {
                $exitCode = 0
            }
        }
        finally {
            Pop-Location
        }

        if ($exitCode -ne 0) {
            throw "Package npm materialized install for '$($PackageResult.PackageId)' failed with exit code $exitCode."
        }

        $installParent = Split-Path -Parent $PackageResult.InstallDirectory
        if (-not [string]::IsNullOrWhiteSpace($installParent)) {
            $null = New-Item -ItemType Directory -Path $installParent -Force
        }
        Remove-PathIfExists -Path $PackageResult.InstallDirectory | Out-Null
        Move-Item -LiteralPath $stagePath -Destination $PackageResult.InstallDirectory -Force
        $stagePromoted = $true
    }
    finally {
        if (-not $stagePromoted) {
            Write-PackageExecutionMessage -Level 'WRN' -Message ("[WARN] Preserving failed npm materialized install stage '{0}' for inspection." -f $stagePath)
        }
    }

    return [pscustomobject]@{
        Status           = Get-PackageOwnedInstallStatus -PackageResult $PackageResult
        InstallKind      = 'npmMaterializedInstallGlobalPackage'
        InstallDirectory = $PackageResult.InstallDirectory
        ReusedExisting   = $false
        InstallerCommand = $installerCommandInfo.Command
        InstallerCommandPath = $installerCommandInfo.CommandPath
        PackageSpec      = $packageSpec
        MaterializedTarballPaths = @($tarballPaths)
        MaterializedInstallInputs = @($installInputs)
        CacheAddArguments = @($cacheAddArguments)
        CommandArguments = @($commandArguments)
        CacheDirectory   = $cacheDirectory
        GlobalConfigPath = $globalConfigPath
        StagePath        = $stagePath
        ExitCode         = $exitCode
    }
}
