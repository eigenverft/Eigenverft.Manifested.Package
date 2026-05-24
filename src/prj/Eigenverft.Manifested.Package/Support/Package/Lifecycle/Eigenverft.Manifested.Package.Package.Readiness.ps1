<#
    Eigenverft.Manifested.Package.Package.Readiness
#>

function Get-PackageReadinessEntryPointDefinition {
<#
.SYNOPSIS
Returns a readiness entry-point definition by name.

.DESCRIPTION
Searches the definition discovery.presence collections and returns the first matching
command or app entry by name.

.PARAMETER Definition
The Package definition object.

.PARAMETER EntryPointName
The entry-point name to resolve.

.EXAMPLE
Get-PackageReadinessEntryPointDefinition -Definition $definition -EntryPointName code
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition,

        [Parameter(Mandatory = $true)]
        [string]$EntryPointName
    )

    foreach ($toolKind in @('commands', 'apps')) {
        $entryPoint = Get-PackageDiscoveryPresenceEntryPoint -Definition $Definition -ToolKind $toolKind -Name $EntryPointName
        if ($entryPoint) {
            return $entryPoint
        }
    }

    return $null
}

function Get-PackageCommandCheckPath {
<#
.SYNOPSIS
Resolves the command path used for a readiness command check.

.DESCRIPTION
Uses an explicit relative path when provided, otherwise resolves the path from
the named Package entry point.

.PARAMETER PackageResult
The current Package result object.

.PARAMETER CommandCheck
The readiness command-check definition.

.EXAMPLE
Get-PackageCommandCheckPath -PackageResult $result -CommandCheck $check
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter(Mandatory = $true)]
        [psobject]$CommandCheck
    )

    if ($CommandCheck.PSObject.Properties['relativePath'] -and -not [string]::IsNullOrWhiteSpace([string]$CommandCheck.relativePath)) {
        return (Join-Path $PackageResult.InstallDirectory (([string]$CommandCheck.relativePath) -replace '/', '\'))
    }

    if ($CommandCheck.PSObject.Properties['entryPoint'] -and -not [string]::IsNullOrWhiteSpace([string]$CommandCheck.entryPoint)) {
        $entryPoint = Get-PackageReadinessEntryPointDefinition -Definition $PackageResult.PackageConfig.Definition -EntryPointName ([string]$CommandCheck.entryPoint)
        if (-not $entryPoint -or -not $entryPoint.PSObject.Properties['relativePath']) {
            throw "Package readiness entry point '$($CommandCheck.entryPoint)' was not found in discovery.presence.commands or discovery.presence.apps."
        }

        return (Join-Path $PackageResult.InstallDirectory (([string]$entryPoint.relativePath) -replace '/', '\'))
    }

    throw 'Package command checks require either relativePath or entryPoint.'
}

function Get-PackageJsonValue {
<#
.SYNOPSIS
Reads a dotted property path from an object.

.DESCRIPTION
Walks a dotted property path such as `version` or `metadata.name` and returns
the current value when every path segment exists.

.PARAMETER InputObject
The object to read from.

.PARAMETER PropertyPath
The dotted property path.

.EXAMPLE
Get-PackageJsonValue -InputObject $document -PropertyPath version
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$PropertyPath
    )

    $current = $InputObject
    foreach ($segment in @($PropertyPath -split '\.')) {
        if ($null -eq $current -or -not $current.PSObject.Properties[$segment]) {
            return $null
        }

        $current = $current.$segment
    }

    return $current
}

function Test-PackageReadinessValueComparison {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [object]$ActualValue,

        [AllowNull()]
        [object]$ExpectedValue,

        [string]$Operator = '=='
    )

    $actualText = [string]$ActualValue
    $expectedText = [string]$ExpectedValue
    $operatorText = if ([string]::IsNullOrWhiteSpace($Operator)) { '==' } else { $Operator }

    if ($operatorText -in @('=', '==')) {
        return [string]::Equals($actualText, $expectedText, [System.StringComparison]::OrdinalIgnoreCase)
    }
    if ($operatorText -eq '!=') {
        return (-not [string]::Equals($actualText, $expectedText, [System.StringComparison]::OrdinalIgnoreCase))
    }

    $actualVersion = ConvertTo-PackageVersion -VersionText $actualText
    $expectedVersion = ConvertTo-PackageVersion -VersionText $expectedText
    switch -Exact ($operatorText) {
        '>' { return $actualVersion -gt $expectedVersion }
        '>=' { return $actualVersion -ge $expectedVersion }
        '<' { return $actualVersion -lt $expectedVersion }
        '<=' { return $actualVersion -le $expectedVersion }
        default { throw "Unsupported Package readiness comparison operator '$operatorText'." }
    }
}

function New-PackageReadinessFailedCheckRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [psobject]$Check
    )

    $actual = switch -Exact ($Kind) {
        'files' { "exists=$($Check.Exists)" }
        'directories' { "exists=$($Check.Exists)" }
        'commands' { "exitCode=$($Check.ExitCode); actual='$($Check.ActualValue)'" }
        'metadataFiles' { "value='$($Check.Value)'" }
        'signatures' { "signatureStatus='$($Check.SignatureStatus)'; signerSubject='$($Check.SignerSubject)'" }
        'fileDetails' { "productName='$($Check.ProductName)'; fileDescription='$($Check.FileDescription)'; fileVersion='$($Check.FileVersion)'; productVersion='$($Check.ProductVersion)'" }
        'registryChecks' { "actual='$($Check.ActualValue)'" }
        'powerShellModules' { "installedVersion='$($Check.InstalledVersion)'; moduleBase='$($Check.ModuleBase)'; nugetProviderAvailable='$($Check.NuGetProviderAvailable)'" }
        default { $null }
    }

    $expected = switch -Exact ($Kind) {
        'files' { 'file exists' }
        'directories' { 'directory exists' }
        'commands' { if ([string]::IsNullOrWhiteSpace([string]$Check.ExpectedValue)) { 'exitCode=0 and non-empty matching output' } else { "expected='$($Check.ExpectedValue)'" } }
        'metadataFiles' { "expected='$($Check.ExpectedValue)'" }
        'signatures' { "requireValid='$($Check.RequireValid)'; subjectContains='$($Check.ExpectedSubjectContains)'" }
        'fileDetails' { "productName='$($Check.ExpectedProductName)'; fileDescription='$($Check.ExpectedFileDescription)'; fileVersion='$($Check.ExpectedFileVersion)'; productVersion='$($Check.ExpectedProductVersion)'" }
        'registryChecks' { if ([string]::IsNullOrWhiteSpace([string]$Check.ExpectedValue)) { 'registry value exists' } else { "expected='$($Check.ExpectedValue)'" } }
        'powerShellModules' { "requiredVersion='$($Check.RequiredVersion)'; scope='$($Check.Scope)'; requireNuGetProvider='$($Check.RequireNuGetProvider)'" }
        default { $null }
    }

    return [pscustomobject]@{
        Kind         = $Kind
        Status       = $Check.Status
        RelativePath = if ($Check.PSObject.Properties['RelativePath']) { $Check.RelativePath } else { $null }
        Path         = if ($Check.PSObject.Properties['Path']) { $Check.Path } else { $null }
        Actual       = $actual
        Expected     = $expected
    }
}

function Test-PackageAssignedReadiness {
<#
.SYNOPSIS
Validates assigned package state against its Package rules.

.DESCRIPTION
Runs file, directory, command, metadata, signature, file-details, and registry
checks for the current install directory and attaches the readiness result to
the Package result object.

.PARAMETER PackageResult
The Package result object to validate.

.PARAMETER FailedCheckLogLevel
Severity for per-check messages when readiness is not accepted. Use 'INF' for
expected-not-ready probes (for example machine-prerequisite pre-assignment or
absence verification) so missing registry keys or files do not look like faults.

.EXAMPLE
Test-PackageAssignedReadiness -PackageResult $result
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [Parameter()]
        [string]$FailedCheckLogLevel = 'WRN'
    )

    $package = $PackageResult.Package
    if (-not $package -or -not $package.PSObject.Properties['readiness'] -or $null -eq $package.readiness) {
        $PackageResult.Readiness = [pscustomobject]@{
            Status       = 'Ready'
            Accepted     = $true
            InstallDirectory = $PackageResult.InstallDirectory
            Files        = @()
            Directories  = @()
            Commands     = @()
            MetadataFiles = @()
            Signatures   = @()
            FileDetails  = @()
            Registry     = @()
            PowerShellModules = @()
        }
        return $PackageResult
    }

    $installDirectory = $PackageResult.InstallDirectory
    $readiness = $package.readiness
    $requiresInstallDirectory = (@($readiness.files).Count -gt 0) -or
        (@($readiness.directories).Count -gt 0) -or
        (@($readiness.commandChecks).Count -gt 0) -or
        (@($readiness.metadataFiles).Count -gt 0) -or
        (@($readiness.signatures).Count -gt 0) -or
        (@($readiness.fileDetails).Count -gt 0)
    if ($requiresInstallDirectory -and ([string]::IsNullOrWhiteSpace($installDirectory) -or -not (Test-Path -LiteralPath $installDirectory))) {
        $PackageResult.Readiness = [pscustomobject]@{
            Status           = 'Failed'
            Accepted         = $false
            FailureReason    = 'InstallDirectoryMissing'
            InstallDirectory = $installDirectory
            Files            = @()
            Directories      = @()
            Commands         = @()
            MetadataFiles    = @()
            Signatures       = @()
            FileDetails      = @()
            Registry         = @()
            PowerShellModules = @()
        }
        return $PackageResult
    }

    $fileResults = New-Object System.Collections.Generic.List[object]
    foreach ($relativePath in @($readiness.files)) {
        if ($null -eq $relativePath) {
            continue
        }
        $path = Join-Path $installDirectory (([string]$relativePath) -replace '/', '\')
        $fileResults.Add([pscustomobject]@{
            RelativePath = $relativePath
            Path         = $path
            Exists       = (Test-Path -LiteralPath $path -PathType Leaf)
            Status       = if (Test-Path -LiteralPath $path -PathType Leaf) { 'Ready' } else { 'Missing' }
        }) | Out-Null
    }

    $directoryResults = New-Object System.Collections.Generic.List[object]
    foreach ($relativePath in @($readiness.directories)) {
        if ($null -eq $relativePath) {
            continue
        }
        $path = Join-Path $installDirectory (([string]$relativePath) -replace '/', '\')
        $directoryResults.Add([pscustomobject]@{
            RelativePath = $relativePath
            Path         = $path
            Exists       = (Test-Path -LiteralPath $path -PathType Container)
            Status       = if (Test-Path -LiteralPath $path -PathType Container) { 'Ready' } else { 'Missing' }
        }) | Out-Null
    }

    $commandResults = New-Object System.Collections.Generic.List[object]
    foreach ($commandCheck in @($readiness.commandChecks)) {
        if ($null -eq $commandCheck) {
            continue
        }
        $commandPath = Get-PackageCommandCheckPath -PackageResult $PackageResult -CommandCheck $commandCheck
        $arguments = @()
        foreach ($argument in @($commandCheck.arguments)) {
            $arguments += (Resolve-PackageTemplateText -Text ([string]$argument) -PackageConfig $PackageResult.PackageConfig -Package $package)
        }

        $outputLines = @()
        $exitCode = $null
        try {
            $outputLines = @(& $commandPath @arguments 2>&1)
            $exitCode = $LASTEXITCODE
            if ($null -eq $exitCode) {
                $exitCode = 0
            }
        }
        catch {
            $outputLines = @($_.Exception.Message)
            $exitCode = 1
        }

        $combinedOutput = (($outputLines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
        $pattern = if ($commandCheck.PSObject.Properties['outputPattern']) { [string]$commandCheck.outputPattern } else { '(?m)^(?<value>.+)$' }
        $match = [regex]::Match($combinedOutput, $pattern)
        $actualValue = if ($match.Success) {
            if ($match.Groups['value'] -and $match.Groups['value'].Success) {
                $match.Groups['value'].Value.Trim()
            }
            else {
                $match.Value.Trim()
            }
        }
        else {
            $null
        }

        $expectedValue = if ($commandCheck.PSObject.Properties['expectedValue'] -and -not [string]::IsNullOrWhiteSpace([string]$commandCheck.expectedValue)) {
            Resolve-PackageTemplateText -Text ([string]$commandCheck.expectedValue) -PackageConfig $PackageResult.PackageConfig -Package $package
        }
        else {
            $null
        }

        $isReady = ($exitCode -eq 0) -and ($null -ne $actualValue) -and (([string]::IsNullOrWhiteSpace($expectedValue)) -or ([string]::Equals([string]$actualValue, [string]$expectedValue, [System.StringComparison]::OrdinalIgnoreCase)))
        $commandResults.Add([pscustomobject]@{
            EntryPoint    = if ($commandCheck.PSObject.Properties['entryPoint']) { $commandCheck.entryPoint } else { $null }
            Path          = $commandPath
            ExitCode      = $exitCode
            ActualValue   = $actualValue
            ExpectedValue = $expectedValue
            Status        = if ($isReady) { 'Ready' } else { 'Failed' }
            Output        = $combinedOutput
        }) | Out-Null
    }

    $metadataResults = New-Object System.Collections.Generic.List[object]
    foreach ($metadataCheck in @($readiness.metadataFiles)) {
        if ($null -eq $metadataCheck) {
            continue
        }
        $path = Join-Path $installDirectory (([string]$metadataCheck.relativePath) -replace '/', '\')
        $exists = Test-Path -LiteralPath $path -PathType Leaf
        $value = $null
        $status = 'Missing'

        if ($exists) {
            try {
                $document = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                $value = Get-PackageJsonValue -InputObject $document -PropertyPath ([string]$metadataCheck.jsonPath)
                $expectedValue = Resolve-PackageTemplateText -Text ([string]$metadataCheck.expectedValue) -PackageConfig $PackageResult.PackageConfig -Package $package
                $status = if ([string]::Equals([string]$value, [string]$expectedValue, [System.StringComparison]::OrdinalIgnoreCase)) { 'Ready' } else { 'Failed' }
            }
            catch {
                $status = 'Failed'
            }
        }
        else {
            $expectedValue = Resolve-PackageTemplateText -Text ([string]$metadataCheck.expectedValue) -PackageConfig $PackageResult.PackageConfig -Package $package
        }

        $metadataResults.Add([pscustomobject]@{
            RelativePath = $metadataCheck.relativePath
            Path         = $path
            Exists       = $exists
            JsonPath     = $metadataCheck.jsonPath
            Value        = $value
            ExpectedValue = $expectedValue
            Status       = $status
        }) | Out-Null
    }

    $signatureResults = New-Object System.Collections.Generic.List[object]
    foreach ($signatureCheck in @($readiness.signatures)) {
        if ($null -eq $signatureCheck) {
            continue
        }
        $path = Join-Path $installDirectory (([string]$signatureCheck.relativePath) -replace '/', '\')
        $status = 'Missing'
        $signatureStatus = $null
        $signerSubject = $null
        $requiresValid = $true
        if ($signatureCheck.PSObject.Properties['requireValid']) {
            $requiresValid = [bool]$signatureCheck.requireValid
        }
        $expectedSubjectContains = if ($signatureCheck.PSObject.Properties['subjectContains']) { [string]$signatureCheck.subjectContains } else { $null }

        if (Test-Path -LiteralPath $path -PathType Leaf) {
            try {
                $signature = Get-AuthenticodeSignature -FilePath $path
                $signatureStatus = $signature.Status.ToString()
                $signerSubject = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null }
                $status = 'Ready'
                if ($requiresValid -and $signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
                    $status = 'Failed'
                }
                if ($status -eq 'Ready' -and $signatureCheck.PSObject.Properties['subjectContains'] -and
                    -not [string]::IsNullOrWhiteSpace([string]$signatureCheck.subjectContains) -and
                    ($null -eq $signerSubject -or $signerSubject -notmatch [regex]::Escape([string]$signatureCheck.subjectContains))) {
                    $status = 'Failed'
                }
            }
            catch {
                $status = 'Failed'
            }
        }

        $signatureResults.Add([pscustomobject]@{
            RelativePath     = $signatureCheck.relativePath
            Path             = $path
            SignatureStatus  = $signatureStatus
            SignerSubject    = $signerSubject
            RequireValid     = $requiresValid
            ExpectedSubjectContains = $expectedSubjectContains
            Status           = $status
        }) | Out-Null
    }

    $fileDetailResults = New-Object System.Collections.Generic.List[object]
    foreach ($detailCheck in @($readiness.fileDetails)) {
        if ($null -eq $detailCheck) {
            continue
        }
        $path = Join-Path $installDirectory (([string]$detailCheck.relativePath) -replace '/', '\')
        $productName = $null
        $fileDescription = $null
        $fileVersion = $null
        $productVersion = $null
        $status = 'Missing'
        $expectedProductName = if ($detailCheck.PSObject.Properties['productName']) { [string]$detailCheck.productName } else { $null }
        $expectedFileDescription = if ($detailCheck.PSObject.Properties['fileDescription']) { [string]$detailCheck.fileDescription } else { $null }
        $expectedFileVersion = if ($detailCheck.PSObject.Properties['fileVersion']) { Resolve-PackageTemplateText -Text ([string]$detailCheck.fileVersion) -PackageConfig $PackageResult.PackageConfig -Package $package } else { $null }
        $expectedProductVersion = if ($detailCheck.PSObject.Properties['productVersion']) { Resolve-PackageTemplateText -Text ([string]$detailCheck.productVersion) -PackageConfig $PackageResult.PackageConfig -Package $package } else { $null }

        if (Test-Path -LiteralPath $path -PathType Leaf) {
            try {
                $item = Get-Item -LiteralPath $path -ErrorAction Stop
                $productName = if ($item.PSObject.Properties['VersionInfo'] -and $item.VersionInfo) { $item.VersionInfo.ProductName } else { $null }
                $fileDescription = if ($item.PSObject.Properties['VersionInfo'] -and $item.VersionInfo) { $item.VersionInfo.FileDescription } else { $null }
                $fileVersion = if ($item.PSObject.Properties['VersionInfo'] -and $item.VersionInfo) { $item.VersionInfo.FileVersion } else { $null }
                $productVersion = if ($item.PSObject.Properties['VersionInfo'] -and $item.VersionInfo) { $item.VersionInfo.ProductVersion } else { $null }
                $status = 'Ready'
                if ($detailCheck.PSObject.Properties['productName'] -and
                    -not [string]::IsNullOrWhiteSpace([string]$detailCheck.productName) -and
                    -not [string]::Equals([string]$productName, [string]$detailCheck.productName, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $status = 'Failed'
                }
                if ($status -eq 'Ready' -and $detailCheck.PSObject.Properties['fileDescription'] -and
                    -not [string]::IsNullOrWhiteSpace([string]$detailCheck.fileDescription) -and
                    -not [string]::Equals([string]$fileDescription, [string]$detailCheck.fileDescription, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $status = 'Failed'
                }
                if ($status -eq 'Ready' -and $detailCheck.PSObject.Properties['fileVersion'] -and
                    -not [string]::IsNullOrWhiteSpace($expectedFileVersion) -and
                    -not [string]::Equals([string]$fileVersion, $expectedFileVersion, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $status = 'Failed'
                }
                if ($status -eq 'Ready' -and $detailCheck.PSObject.Properties['productVersion'] -and
                    -not [string]::IsNullOrWhiteSpace($expectedProductVersion) -and
                    -not [string]::Equals([string]$productVersion, $expectedProductVersion, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $status = 'Failed'
                }
            }
            catch {
                $status = 'Failed'
            }
        }

        $fileDetailResults.Add([pscustomobject]@{
            RelativePath    = $detailCheck.relativePath
            Path            = $path
            ProductName     = $productName
            FileDescription = $fileDescription
            FileVersion     = $fileVersion
            ProductVersion  = $productVersion
            ExpectedProductName = $expectedProductName
            ExpectedFileDescription = $expectedFileDescription
            ExpectedFileVersion = $expectedFileVersion
            ExpectedProductVersion = $expectedProductVersion
            Status          = $status
        }) | Out-Null
    }

    $registryResults = New-Object System.Collections.Generic.List[object]
    foreach ($registryCheck in @($readiness.registryChecks)) {
        if ($null -eq $registryCheck) {
            continue
        }
        $registryPaths = if ($registryCheck.PSObject.Properties['paths'] -and @($registryCheck.paths).Count -gt 0) {
            @($registryCheck.paths | ForEach-Object { [string]$_ })
        }
        elseif ($registryCheck.PSObject.Properties['path'] -and -not [string]::IsNullOrWhiteSpace([string]$registryCheck.path)) {
            @([string]$registryCheck.path)
        }
        else {
            @()
        }
        $valueName = if ($registryCheck.PSObject.Properties['valueName'] -and -not [string]::IsNullOrWhiteSpace([string]$registryCheck.valueName)) {
            [string]$registryCheck.valueName
        }
        else {
            $null
        }
        $expectedValue = if ($registryCheck.PSObject.Properties['expectedValue']) {
            Resolve-PackageTemplateText -Text ([string]$registryCheck.expectedValue) -PackageConfig $PackageResult.PackageConfig -Package $package
        }
        else {
            $null
        }
        $operator = if ($registryCheck.PSObject.Properties['operator'] -and -not [string]::IsNullOrWhiteSpace([string]$registryCheck.operator)) {
            [string]$registryCheck.operator
        }
        else {
            '=='
        }
        $registryResolution = Resolve-RegistryValueFromPaths -Paths $registryPaths -ValueName $valueName
        $status = [string]$registryResolution.Status
        if ($status -eq 'Ready' -and $registryCheck.PSObject.Properties['expectedValue']) {
            $status = if (Test-PackageReadinessValueComparison -ActualValue $registryResolution.ActualValue -ExpectedValue $expectedValue -Operator $operator) { 'Ready' } else { 'Failed' }
        }

        $registryResults.Add([pscustomobject]@{
            Path          = $registryResolution.Path
            Paths         = @($registryPaths)
            ValueName     = $valueName
            ActualValue   = $registryResolution.ActualValue
            ExpectedValue = $expectedValue
            Operator      = if ($registryCheck.PSObject.Properties['expectedValue']) { $operator } else { $null }
            Status        = $status
        }) | Out-Null
    }

    $powerShellModuleResults = New-Object System.Collections.Generic.List[object]
    foreach ($moduleCheck in @($readiness.powerShellModules)) {
        if ($null -eq $moduleCheck) {
            continue
        }

        $moduleName = if ($moduleCheck.PSObject.Properties['name']) { [string]$moduleCheck.name } elseif ($moduleCheck.PSObject.Properties['moduleName']) { [string]$moduleCheck.moduleName } else { $null }
        $requiredVersion = if ($moduleCheck.PSObject.Properties['requiredVersion']) {
            Resolve-PackageTemplateText -Text ([string]$moduleCheck.requiredVersion) -PackageConfig $PackageResult.PackageConfig -Package $package
        }
        else {
            $null
        }
        $scope = if ($moduleCheck.PSObject.Properties['scope'] -and -not [string]::IsNullOrWhiteSpace([string]$moduleCheck.scope)) {
            [string]$moduleCheck.scope
        }
        else {
            'CurrentUser'
        }
        $requireNuGetProvider = if ($moduleCheck.PSObject.Properties['requireNuGetProvider']) { [bool]$moduleCheck.requireNuGetProvider } else { $false }

        $moduleStatus = $null
        $status = 'Failed'
        $errorMessage = $null
        try {
            if ([string]::IsNullOrWhiteSpace($moduleName) -or [string]::IsNullOrWhiteSpace($requiredVersion)) {
                throw 'PowerShell module readiness requires name and requiredVersion.'
            }
            $moduleStatus = Test-PackagePowerShellModulePresence -PackageResult $PackageResult -Name $moduleName -RequiredVersion $requiredVersion -Scope $scope -RequireNuGetProvider $requireNuGetProvider
            $status = if ($moduleStatus -and $moduleStatus.PSObject.Properties['installed'] -and [bool]$moduleStatus.installed) {
                'Ready'
            }
            elseif ($moduleStatus -and $moduleStatus.PSObject.Properties['status']) {
                [string]$moduleStatus.status
            }
            else {
                'Missing'
            }
        }
        catch {
            $status = 'Failed'
            $errorMessage = $_.Exception.Message
        }

        $powerShellModuleResults.Add([pscustomobject]@{
            Name                   = $moduleName
            RequiredVersion        = $requiredVersion
            Scope                  = $scope
            RequireNuGetProvider   = $requireNuGetProvider
            Installed              = if ($moduleStatus -and $moduleStatus.PSObject.Properties['installed']) { [bool]$moduleStatus.installed } else { $false }
            ModuleInstalled        = if ($moduleStatus -and $moduleStatus.PSObject.Properties['moduleInstalled']) { [bool]$moduleStatus.moduleInstalled } else { $null }
            InstalledVersion       = if ($moduleStatus -and $moduleStatus.PSObject.Properties['installedVersion']) { [string]$moduleStatus.installedVersion } else { $null }
            ModuleBase             = if ($moduleStatus -and $moduleStatus.PSObject.Properties['moduleBase']) { [string]$moduleStatus.moduleBase } else { $null }
            NuGetProviderAvailable = if ($moduleStatus -and $moduleStatus.PSObject.Properties['nugetProviderAvailable']) { [bool]$moduleStatus.nugetProviderAvailable } else { $null }
            Status                 = $status
            ErrorMessage           = $errorMessage
        }) | Out-Null
    }

    $allResults = @($fileResults.ToArray()) + @($directoryResults.ToArray()) + @($commandResults.ToArray()) + @($metadataResults.ToArray()) + @($signatureResults.ToArray()) + @($fileDetailResults.ToArray()) + @($registryResults.ToArray()) + @($powerShellModuleResults.ToArray())
    $accepted = (@($allResults | Where-Object { $_.Status -ne 'Ready' }).Count -eq 0)
    $failedChecks = @(
        foreach ($item in @($fileResults.ToArray() | Where-Object { $_.Status -ne 'Ready' })) { New-PackageReadinessFailedCheckRecord -Kind 'files' -Check $item }
        foreach ($item in @($directoryResults.ToArray() | Where-Object { $_.Status -ne 'Ready' })) { New-PackageReadinessFailedCheckRecord -Kind 'directories' -Check $item }
        foreach ($item in @($commandResults.ToArray() | Where-Object { $_.Status -ne 'Ready' })) { New-PackageReadinessFailedCheckRecord -Kind 'commands' -Check $item }
        foreach ($item in @($metadataResults.ToArray() | Where-Object { $_.Status -ne 'Ready' })) { New-PackageReadinessFailedCheckRecord -Kind 'metadataFiles' -Check $item }
        foreach ($item in @($signatureResults.ToArray() | Where-Object { $_.Status -ne 'Ready' })) { New-PackageReadinessFailedCheckRecord -Kind 'signatures' -Check $item }
        foreach ($item in @($fileDetailResults.ToArray() | Where-Object { $_.Status -ne 'Ready' })) { New-PackageReadinessFailedCheckRecord -Kind 'fileDetails' -Check $item }
        foreach ($item in @($registryResults.ToArray() | Where-Object { $_.Status -ne 'Ready' })) { New-PackageReadinessFailedCheckRecord -Kind 'registryChecks' -Check $item }
        foreach ($item in @($powerShellModuleResults.ToArray() | Where-Object { $_.Status -ne 'Ready' })) { New-PackageReadinessFailedCheckRecord -Kind 'powerShellModules' -Check $item }
    )

    $PackageResult.Readiness = [pscustomobject]@{
        Status           = if ($accepted) { 'Ready' } else { 'Failed' }
        Accepted         = $accepted
        FailureReason    = if ($accepted) { $null } else { 'AssignedPackageReadinessFailed' }
        InstallDirectory = $installDirectory
        Files            = @($fileResults.ToArray())
        Directories      = @($directoryResults.ToArray())
        Commands         = @($commandResults.ToArray())
        MetadataFiles    = @($metadataResults.ToArray())
        Signatures       = @($signatureResults.ToArray())
        FileDetails      = @($fileDetailResults.ToArray())
        Registry         = @($registryResults.ToArray())
        PowerShellModules = @($powerShellModuleResults.ToArray())
        FailedChecks     = @($failedChecks)
    }

    $failedCount = @($allResults | Where-Object { $_.Status -ne 'Ready' }).Count
    Write-PackageExecutionMessage -Message ("[STATE] Readiness completed for '{0}' with accepted='{1}', failedChecks={2}." -f $installDirectory, $accepted, $failedCount)
    $perCheckLevel = if ([string]::IsNullOrWhiteSpace($FailedCheckLogLevel)) { 'WRN' } else { $FailedCheckLogLevel }
    foreach ($failedCheck in @($failedChecks)) {
        $targetText = if (-not [string]::IsNullOrWhiteSpace([string]$failedCheck.RelativePath)) {
            [string]$failedCheck.RelativePath
        }
        elseif (-not [string]::IsNullOrWhiteSpace([string]$failedCheck.Path)) {
            [string]$failedCheck.Path
        }
        else {
            '<none>'
        }
        Write-PackageExecutionMessage -Level $perCheckLevel -Message ('[READINESS] {0} failed for ''{1}'' with status=''{2}'', actual="{3}", expected="{4}".' -f $failedCheck.Kind, $targetText, $failedCheck.Status, $failedCheck.Actual, $failedCheck.Expected)
    }

    return $PackageResult
}

function Test-PackageRemovedAbsence {
<#
.SYNOPSIS
Verifies post-removal absence using packageOperations.removed.absenceVerification.

.DESCRIPTION
Builds a synthetic readiness model from absenceVerification.require and
discovery.presence, reuses Test-PackageAssignedReadiness evaluation, then
requires that substantive checks do not report full readiness success.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    $definition = $PackageResult.PackageConfig.Definition
    $removed = $definition.packageOperations.removed
    $absence = $removed.absenceVerification
    $fakeAssigned = [pscustomobject]@{
        readyStateCheck = [pscustomobject]@{
            require = $absence.require
        }
    }

    $readinessModel = New-PackageReadinessFromDiscoveryPresence -Definition $definition -Assigned $fakeAssigned
    $hadChecks = (@($readinessModel.files).Count -gt 0) -or (@($readinessModel.directories).Count -gt 0) -or
        (@($readinessModel.commandChecks).Count -gt 0) -or (@($readinessModel.metadataFiles).Count -gt 0) -or
        (@($readinessModel.signatures).Count -gt 0) -or (@($readinessModel.fileDetails).Count -gt 0) -or
        (@($readinessModel.registryChecks).Count -gt 0) -or (@($readinessModel.powerShellModules).Count -gt 0)

    $package = $PackageResult.Package
    $oldReadiness = $null
    if ($package.PSObject.Properties['readiness']) {
        $oldReadiness = $package.readiness
    }

    $null = $package | Add-Member -Force -MemberType NoteProperty -Name 'readiness' -Value $readinessModel
    try {
        $null = Test-PackageAssignedReadiness -PackageResult $PackageResult -FailedCheckLogLevel 'INF'
    }
    finally {
        if ($null -ne $oldReadiness) {
            $null = $package | Add-Member -Force -MemberType NoteProperty -Name 'readiness' -Value $oldReadiness
        }
        else {
            $null = $package.PSObject.Properties.Remove('readiness')
        }
    }

    $assignAccepted = $PackageResult.Readiness.Accepted
    $absenceAccepted = if (-not $hadChecks) { $true } else { -not $assignAccepted }

    $PackageResult.Removed = [pscustomobject]@{
        Accepted = $absenceAccepted
        HadChecks = $hadChecks
        ReadinessProbeAccepted = $assignAccepted
    }

    if (-not $absenceAccepted) {
        throw "Package absence verification failed: discovery.presence still reports readiness for removed definition '$($PackageResult.DefinitionId)'."
    }

    $PackageResult.Readiness = $null

    Write-PackageExecutionMessage -Message ("[STATE] Absence verification completed for '{0}' with accepted='{1}'." -f $PackageResult.InstallDirectory, $absenceAccepted)

    return $PackageResult
}


