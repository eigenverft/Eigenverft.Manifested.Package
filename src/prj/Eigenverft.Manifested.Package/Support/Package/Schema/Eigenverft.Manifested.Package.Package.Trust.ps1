<#
    Eigenverft.Manifested.Package.Package.Trust
    Catalog-signature canonicalization, certificate, and PackageTrustInventory.json helpers.
#>

$script:PackageDefinitionSignatureFormat = 'embedded-json-rsa-sha256-v1'
$script:PackageDefinitionSignedContentKind = 'canonicalDefinitionExcludingSignatureValue'

function ConvertFrom-PackageSecureString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [securestring]$SecureString
    )

    $ptr = [IntPtr]::Zero
    try {
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        if ($ptr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }
    }
}

function ConvertTo-PackageCanonicalJson {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return 'null'
    }
    if ($Value -is [bool]) {
        if ($Value) {
            return 'true'
        }
        return 'false'
    }
    if ($Value -is [string] -and $Value -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$') {
        try {
            $dateOffset = [DateTimeOffset]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
            return ConvertTo-PackageJsonEscapedString -Value ($dateOffset.UtcDateTime.ToString('o', [Globalization.CultureInfo]::InvariantCulture))
        }
        catch {
        }
    }
    if ($Value -is [string] -or $Value -is [char] -or $Value -is [guid]) {
        return ConvertTo-PackageJsonEscapedString -Value ([string]$Value)
    }
    if ($Value -is [datetime]) {
        $dateText = ([datetime]$Value).ToUniversalTime().ToString('o', [Globalization.CultureInfo]::InvariantCulture)
        return ConvertTo-PackageJsonEscapedString -Value $dateText
    }
    if ($Value -is [byte] -or $Value -is [sbyte] -or
        $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int] -or $Value -is [uint32] -or
        $Value -is [long] -or $Value -is [uint64] -or
        $Value -is [decimal]) {
        return ([System.Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture))
    }
    if ($Value -is [single] -or $Value -is [double]) {
        $doubleValue = [double]$Value
        if ([double]::IsNaN($doubleValue) -or [double]::IsInfinity($doubleValue)) {
            throw 'Canonical JSON cannot represent NaN or Infinity.'
        }
        return $doubleValue.ToString('R', [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $properties = @(
            foreach ($key in @($Value.Keys)) {
                [pscustomobject]@{
                    Name  = [string]$key
                    Value = $Value[$key]
                }
            }
        ) | Sort-Object -Property Name

        $parts = @(
            foreach ($property in @($properties)) {
                '{0}:{1}' -f (ConvertTo-PackageJsonEscapedString -Value $property.Name), (ConvertTo-PackageCanonicalJson -Value $property.Value)
            }
        )
        return '{' + ($parts -join ',') + '}'
    }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = @(
            foreach ($item in $Value) {
                ConvertTo-PackageCanonicalJson -Value $item
            }
        )
        return '[' + ($items -join ',') + ']'
    }

    $objectProperties = @(
        foreach ($property in @($Value.PSObject.Properties)) {
            if ($property.MemberType -notin @('NoteProperty', 'Property', 'AliasProperty')) {
                continue
            }
            [pscustomobject]@{
                Name  = [string]$property.Name
                Value = $property.Value
            }
        }
    ) | Sort-Object -Property Name

    $objectParts = @(
        foreach ($property in @($objectProperties)) {
            '{0}:{1}' -f (ConvertTo-PackageJsonEscapedString -Value $property.Name), (ConvertTo-PackageCanonicalJson -Value $property.Value)
        }
    )
    return '{' + ($objectParts -join ',') + '}'
}

function ConvertTo-PackageUtf8Bytes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $encoding = [System.Text.UTF8Encoding]::new($false)
    return $encoding.GetBytes($Text)
}

function Get-PackageBytesSha256Text {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return (($sha256.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    }
    finally {
        $sha256.Dispose()
    }
}

function Copy-PackageObjectViaJson {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    return (($InputObject | ConvertTo-Json -Depth 80) | ConvertFrom-Json)
}

function Remove-PackageDefinitionSignatureValueFromObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition
    )

    if ($Definition.PSObject.Properties['definitionPublication'] -and
        $Definition.definitionPublication -and
        $Definition.definitionPublication.PSObject.Properties['definitionSignature'] -and
        $Definition.definitionPublication.definitionSignature -and
        $Definition.definitionPublication.definitionSignature.PSObject.Properties['signatureValue']) {
        $Definition.definitionPublication.definitionSignature.PSObject.Properties.Remove('signatureValue')
    }
}

function Get-PackageDefinitionSignableContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition
    )

    $clone = Copy-PackageObjectViaJson -InputObject $Definition
    Remove-PackageDefinitionSignatureValueFromObject -Definition $clone
    $canonicalJson = ConvertTo-PackageCanonicalJson -Value $clone
    $bytes = ConvertTo-PackageUtf8Bytes -Text $canonicalJson

    return [pscustomobject]@{
        CanonicalJson = $canonicalJson
        Bytes         = $bytes
        Sha256        = Get-PackageBytesSha256Text -Bytes $bytes
    }
}

function Set-PackageObjectProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [AllowNull()]
        [object]$Value
    )

    if ($InputObject.PSObject.Properties[$Name]) {
        $InputObject.PSObject.Properties[$Name].Value = $Value
        return
    }

    $InputObject | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
}

function ConvertTo-PackageSafeFileName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $trimmed = $Value.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return 'PackageSigning'
    }

    $safe = ($trimmed -replace '[\\/:*?"<>|]+', '-' -replace '\s+', '-').Trim('-')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return 'PackageSigning'
    }

    return $safe
}

function ConvertTo-PackageX500NameValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $trimmed = $Value.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        throw 'Certificate subject values must not be empty.'
    }

    return ($trimmed -replace '\\', '\\' -replace '([,+"<>;=])', '\$1')
}

function New-PackageCertificateSubject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommonName,

        [AllowNull()]
        [string]$Organization = $null,

        [AllowNull()]
        [string]$OrganizationalUnit = $null,

        [AllowNull()]
        [string]$Country = $null
    )

    if ([string]::IsNullOrWhiteSpace($CommonName)) {
        throw 'CommonName must not be empty.'
    }
    if (-not [string]::IsNullOrWhiteSpace($Country) -and $Country.Trim() -notmatch '^[A-Za-z]{2}$') {
        throw "Country '$Country' is invalid. Use a two-letter ISO country code such as 'DE' or 'US'."
    }

    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add(('CN={0}' -f (ConvertTo-PackageX500NameValue -Value $CommonName))) | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($Organization)) {
        $parts.Add(('O={0}' -f (ConvertTo-PackageX500NameValue -Value $Organization))) | Out-Null
    }
    if (-not [string]::IsNullOrWhiteSpace($OrganizationalUnit)) {
        $parts.Add(('OU={0}' -f (ConvertTo-PackageX500NameValue -Value $OrganizationalUnit))) | Out-Null
    }
    if (-not [string]::IsNullOrWhiteSpace($Country)) {
        $parts.Add(('C={0}' -f $Country.Trim().ToUpperInvariant())) | Out-Null
    }

    return ($parts.ToArray() -join ', ')
}

function Get-PackageDefaultSigningDirectory {
    [CmdletBinding()]
    param()

    $documentsPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
    if ([string]::IsNullOrWhiteSpace($documentsPath)) {
        $documentsPath = Join-Path $HOME 'Documents'
    }

    return [System.IO.Path]::GetFullPath((Join-Path $documentsPath 'Eigenverft.Package\Signing'))
}

function Get-PackageSigningPasswordEnvironmentVariableName {
    [CmdletBinding()]
    param()

    return 'EVF_PACKAGE_SIGNING_PASSWORD'
}

function Get-PackageSigningPasswordDescriptorPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PfxPath
    )

    return [System.IO.Path]::GetFullPath([System.IO.Path]::ChangeExtension($PfxPath, '.json'))
}

function New-PackageSigningPasswordDescriptorDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [securestring]$Password
    )

    $now = [DateTime]::UtcNow.ToString('o')
    return [pscustomobject][ordered]@{
        schemaVersion         = 1
        kind                  = 'catalogSigningPassword'
        protectedPasswordKind = 'dpapi-current-user-securestring'
        protectedPassword     = Protect-PackageSigningProfilePassword -Password $Password
        createdAtUtc          = $now
        updatedAtUtc          = $now
    }
}

function Assert-PackageSigningPasswordDescriptorSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DescriptorInfo
    )

    $document = $DescriptorInfo.Document
    foreach ($requiredProperty in @('schemaVersion', 'kind', 'protectedPasswordKind', 'protectedPassword')) {
        if (-not $document.PSObject.Properties[$requiredProperty] -or [string]::IsNullOrWhiteSpace([string]$document.$requiredProperty)) {
            throw "Package signing password descriptor '$($DescriptorInfo.Path)' is missing '$requiredProperty'."
        }
    }
    if (-not [string]::Equals([string]$document.kind, 'catalogSigningPassword', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Package signing password descriptor '$($DescriptorInfo.Path)' has unsupported kind '$($document.kind)'."
    }
    if (-not [string]::Equals([string]$document.protectedPasswordKind, 'dpapi-current-user-securestring', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Package signing password descriptor '$($DescriptorInfo.Path)' has unsupported protectedPasswordKind '$($document.protectedPasswordKind)'."
    }
    foreach ($forbiddenProperty in @('pfxPath', 'certificatePath', 'trustExportPath')) {
        if ($document.PSObject.Properties[$forbiddenProperty]) {
            throw "Package signing password descriptor '$($DescriptorInfo.Path)' must not contain '$forbiddenProperty'. The PFX is resolved from the adjacent file name."
        }
    }
}

function Save-PackageSigningPasswordDescriptor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [securestring]$Password
    )

    Save-PackageJsonDocument -Path $Path -Document (New-PackageSigningPasswordDescriptorDocument -Password $Password)
}

function Get-PackageSigningPasswordFromDescriptor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $descriptorInfo = Read-PackageJsonDocument -Path $Path
    Assert-PackageSigningPasswordDescriptorSchema -DescriptorInfo $descriptorInfo
    return Unprotect-PackageSigningProfilePassword -ProtectedPassword ([string]$descriptorInfo.Document.protectedPassword)
}

function Get-PackageSigningPasswordFromEnvironment {
    [CmdletBinding()]
    param()

    $variableName = Get-PackageSigningPasswordEnvironmentVariableName
    $passwordText = [Environment]::GetEnvironmentVariable($variableName, 'Process')
    if ([string]::IsNullOrEmpty($passwordText)) {
        return $null
    }

    return ConvertTo-SecureString -String $passwordText -AsPlainText -Force
}

function ConvertTo-PackageSigningSelectorKey {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    return (([string]$Value).ToLowerInvariant() -replace '[^a-z0-9]', '')
}

function Get-PackageSigningPfxPathByName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $signingDirectory = Get-PackageDefaultSigningDirectory
    if (-not (Test-Path -LiteralPath $signingDirectory -PathType Container)) {
        throw "Package signing directory '$signingDirectory' does not exist. Create a signing certificate with New-PackageSigningCertificate -Name '$Name' first."
    }

    $selectorKey = ConvertTo-PackageSigningSelectorKey -Value $Name
    $matchingPfxFiles = @(
        Get-ChildItem -LiteralPath $signingDirectory -Filter '*.catalog-signing.pfx' -File -Recurse | Where-Object {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            $friendlyName = ($baseName -replace '\.catalog-signing$', '')
            $folderName = Split-Path -Leaf $_.DirectoryName
            $selectorKey -in @(
                ConvertTo-PackageSigningSelectorKey -Value $baseName
                ConvertTo-PackageSigningSelectorKey -Value $friendlyName
                ConvertTo-PackageSigningSelectorKey -Value $folderName
            )
        }
    )

    if ($matchingPfxFiles.Count -eq 0) {
        throw "No package signing certificate named '$Name' was found under '$signingDirectory'. Use -Cert with a PFX path or create one with New-PackageSigningCertificate -Name '$Name'."
    }
    if ($matchingPfxFiles.Count -gt 1) {
        throw "Package signing certificate name '$Name' is ambiguous under '$signingDirectory'. Use -Cert with the full PFX path."
    }

    return [System.IO.Path]::GetFullPath($matchingPfxFiles[0].FullName)
}

function Resolve-PackageSigningCertificateReference {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Cert = $null,

        [AllowNull()]
        [securestring]$Password = $null
    )

    if ([string]::IsNullOrWhiteSpace($Cert)) {
        throw "Sign-PackageDefinition requires -Cert. Use a friendly name, a .pfx path, or an adjacent .catalog-signing.json descriptor."
    }

    $reference = $Cert.Trim()
    $resolvedReference = $null
    if (Test-Path -LiteralPath $reference -PathType Leaf) {
        $resolvedReference = (Resolve-Path -LiteralPath $reference -ErrorAction Stop).Path
    }
    elseif ([System.IO.Path]::IsPathRooted($reference) -or $reference -match '[\\/]') {
        throw "Package signing certificate reference '$reference' does not exist."
    }
    else {
        $resolvedReference = Get-PackageSigningPfxPathByName -Name $reference
    }

    $extension = [System.IO.Path]::GetExtension($resolvedReference)
    $pfxPath = $null
    $descriptorPath = $null
    if ([string]::Equals($extension, '.json', [System.StringComparison]::OrdinalIgnoreCase)) {
        $descriptorPath = [System.IO.Path]::GetFullPath($resolvedReference)
        $pfxPath = [System.IO.Path]::GetFullPath([System.IO.Path]::ChangeExtension($descriptorPath, '.pfx'))
        if (-not (Test-Path -LiteralPath $pfxPath -PathType Leaf)) {
            throw "Package signing descriptor '$descriptorPath' requires adjacent PFX '$pfxPath'."
        }
    }
    elseif ([string]::Equals($extension, '.pfx', [System.StringComparison]::OrdinalIgnoreCase) -or
        [string]::Equals($extension, '.p12', [System.StringComparison]::OrdinalIgnoreCase)) {
        $pfxPath = [System.IO.Path]::GetFullPath($resolvedReference)
        $candidateDescriptorPath = Get-PackageSigningPasswordDescriptorPath -PfxPath $pfxPath
        if (Test-Path -LiteralPath $candidateDescriptorPath -PathType Leaf) {
            $descriptorPath = $candidateDescriptorPath
        }
    }
    elseif ($extension -in @('.cer', '.crt', '.pem')) {
        throw "Package signing certificate reference '$resolvedReference' is public-only. Use the private .pfx or adjacent .catalog-signing.json descriptor for signing."
    }
    else {
        throw "Package signing certificate reference '$resolvedReference' must be a .pfx, .p12, or .json file."
    }

    $passwordSource = 'parameter'
    if ($null -eq $Password) {
        if (-not [string]::IsNullOrWhiteSpace($descriptorPath)) {
            $Password = Get-PackageSigningPasswordFromDescriptor -Path $descriptorPath
            $passwordSource = 'descriptor'
        }
        else {
            $Password = Get-PackageSigningPasswordFromEnvironment
            if ($Password) {
                $passwordSource = 'environment'
            }
        }
    }

    if ($null -eq $Password) {
        $environmentVariableName = Get-PackageSigningPasswordEnvironmentVariableName
        throw "Password is required for signing certificate '$pfxPath'. Use -Password, create adjacent descriptor '$(Get-PackageSigningPasswordDescriptorPath -PfxPath $pfxPath)', or set environment variable '$environmentVariableName'."
    }

    return [pscustomobject]@{
        PfxPath        = $pfxPath
        DescriptorPath = $descriptorPath
        Password       = $Password
        PasswordSource = $passwordSource
    }
}

function Protect-PackageSigningProfilePassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [securestring]$Password
    )

    return ConvertFrom-SecureString -SecureString $Password
}

function Unprotect-PackageSigningProfilePassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProtectedPassword
    )

    return ConvertTo-SecureString -String $ProtectedPassword -ErrorAction Stop
}

function Get-PackageSigningProfileSummaries {
    [CmdletBinding()]
    param()

    $signingDirectory = Get-PackageDefaultSigningDirectory
    if (-not (Test-Path -LiteralPath $signingDirectory -PathType Container)) {
        return
    }

    foreach ($pfxFile in @(Get-ChildItem -LiteralPath $signingDirectory -Filter '*.catalog-signing.pfx' -File -Recurse)) {
        $pfxPath = [System.IO.Path]::GetFullPath($pfxFile.FullName)
        $descriptorPath = Get-PackageSigningPasswordDescriptorPath -PfxPath $pfxPath
        $certificatePath = [System.IO.Path]::ChangeExtension($pfxPath, '.cer')
        if (-not (Test-Path -LiteralPath $certificatePath -PathType Leaf)) {
            $certificatePath = [System.IO.Path]::ChangeExtension($pfxPath, '.pem')
        }

        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($pfxFile.Name)
        $name = ($baseName -replace '\.catalog-signing$', '')
        $publisherId = $name
        $publisherName = $name
        $keyThumbprint = $null
        $certificateSubject = $null
        if (Test-Path -LiteralPath $certificatePath -PathType Leaf) {
            $certificate = Import-PackageCertificate -Path $certificatePath
            try {
                $resolvedPublisherId = Resolve-PackagePublisherIdFromCertificate -Certificate $certificate
                if (-not [string]::IsNullOrWhiteSpace($resolvedPublisherId)) {
                    $publisherId = $resolvedPublisherId
                    $publisherName = $resolvedPublisherId
                }
                $keyThumbprint = (($certificate.Thumbprint -replace '\s', '').ToUpperInvariant())
                $certificateSubject = [string]$certificate.Subject
            }
            finally {
                $certificate.Dispose()
            }
        }

        $passwordStorage = $null
        if (Test-Path -LiteralPath $descriptorPath -PathType Leaf) {
            try {
                $descriptorInfo = Read-PackageJsonDocument -Path $descriptorPath
                Assert-PackageSigningPasswordDescriptorSchema -DescriptorInfo $descriptorInfo
                $passwordStorage = [string]$descriptorInfo.Document.protectedPasswordKind
            }
            catch {
                $passwordStorage = 'invalid'
            }
        }

        [pscustomobject]@{
            Name                  = $name
            PublisherId           = $publisherId
            PublisherName         = $publisherName
            PfxPath               = $pfxPath
            CertificatePath       = if (Test-Path -LiteralPath $certificatePath -PathType Leaf) { [System.IO.Path]::GetFullPath($certificatePath) } else { $null }
            SigningDescriptorPath = if (Test-Path -LiteralPath $descriptorPath -PathType Leaf) { $descriptorPath } else { $null }
            KeyThumbprint         = $keyThumbprint
            CertificateSubject    = $certificateSubject
            PasswordStored        = Test-Path -LiteralPath $descriptorPath -PathType Leaf
            PasswordStorage       = $passwordStorage
        }
    }
}

function Get-PackageCertificateCommonName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    $simpleName = $Certificate.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
    if (-not [string]::IsNullOrWhiteSpace($simpleName)) {
        return $simpleName.Trim()
    }

    $subject = [string]$Certificate.Subject
    if ($subject -match '(?i)(^|,\s*)CN=([^,]+)') {
        return $matches[2].Trim()
    }

    return $null
}

function Get-PackageCertificateDisplayName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    if (-not [string]::IsNullOrWhiteSpace($Certificate.FriendlyName)) {
        return [string]$Certificate.FriendlyName
    }

    $commonName = Get-PackageCertificateCommonName -Certificate $Certificate
    if (-not [string]::IsNullOrWhiteSpace($commonName)) {
        return $commonName
    }

    return [string]$Certificate.Subject
}

function Resolve-PackagePublisherIdFromCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    $commonName = Get-PackageCertificateCommonName -Certificate $Certificate
    if ([string]::IsNullOrWhiteSpace($commonName)) {
        return $null
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    $catalogSigningSuffix = ' Package Catalog Signing'
    if ($commonName.EndsWith($catalogSigningSuffix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $candidates.Add($commonName.Substring(0, $commonName.Length - $catalogSigningSuffix.Length).Trim()) | Out-Null
    }
    $candidates.Add($commonName.Trim()) | Out-Null

    foreach ($candidate in @($candidates.ToArray())) {
        try {
            Assert-PackagePublisherId -PublisherId $candidate
            return $candidate
        }
        catch {
            continue
        }
    }

    return $null
}

function New-PackageTrustExportDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Entry
    )

    return [pscustomobject][ordered]@{
        inventoryVersion = 1
        keys             = @($Entry)
        revokedKeys      = @()
    }
}

function ConvertTo-PackageCertificatePem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    $base64 = [Convert]::ToBase64String($Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('-----BEGIN CERTIFICATE-----') | Out-Null
    for ($i = 0; $i -lt $base64.Length; $i += 64) {
        $length = [Math]::Min(64, $base64.Length - $i)
        $lines.Add($base64.Substring($i, $length)) | Out-Null
    }
    $lines.Add('-----END CERTIFICATE-----') | Out-Null
    return ($lines.ToArray() -join [Environment]::NewLine)
}

function ConvertFrom-PackageCertificatePem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CertificatePem
    )

    $base64 = ($CertificatePem -replace '-----BEGIN CERTIFICATE-----', '' -replace '-----END CERTIFICATE-----', '') -replace '\s', ''
    if ([string]::IsNullOrWhiteSpace($base64)) {
        throw 'Certificate PEM is empty.'
    }

    return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([Convert]::FromBase64String($base64))
}

function Import-PackageCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [AllowNull()]
        [securestring]$Password = $null,

        [switch]$WithPrivateKey
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
    if ($WithPrivateKey.IsPresent) {
        $flags = $flags -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::UserKeySet
    }

    if ($Password) {
        $plainTextPassword = ConvertFrom-PackageSecureString -SecureString $Password
        try {
            return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($resolvedPath, $plainTextPassword, $flags)
        }
        finally {
            $plainTextPassword = $null
        }
    }

    return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($resolvedPath)
}

function Get-PackageCertificateRsaPrivateKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    try {
        return [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Certificate)
    }
    catch {
        if ($Certificate.PrivateKey -is [System.Security.Cryptography.RSA]) {
            return $Certificate.PrivateKey
        }
    }

    return $null
}

function Get-PackageCertificateRsaPublicKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    try {
        return [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($Certificate)
    }
    catch {
        if ($Certificate.PublicKey -and $Certificate.PublicKey.Key -is [System.Security.Cryptography.RSA]) {
            return $Certificate.PublicKey.Key
        }
    }

    return $null
}

function Invoke-PackageRsaSignData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.RSA]$Rsa,

        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes
    )

    try {
        return $Rsa.SignData($Bytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    }
    catch {
        $sha256 = [System.Security.Cryptography.SHA256CryptoServiceProvider]::new()
        try {
            return $Rsa.SignData($Bytes, $sha256)
        }
        finally {
            $sha256.Dispose()
        }
    }
}

function Invoke-PackageRsaVerifyData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.RSA]$Rsa,

        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes,

        [Parameter(Mandatory = $true)]
        [byte[]]$SignatureBytes
    )

    try {
        return $Rsa.VerifyData($Bytes, $SignatureBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    }
    catch {
        $sha256 = [System.Security.Cryptography.SHA256CryptoServiceProvider]::new()
        try {
            return $Rsa.VerifyData($Bytes, $sha256, $SignatureBytes)
        }
        finally {
            $sha256.Dispose()
        }
    }
}

function New-PackageTrustEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [Parameter(Mandatory = $true)]
        [string]$PublisherId,

        [AllowNull()]
        [string]$PublisherName = $null,

        [AllowNull()]
        [string]$SignerDisplayName = $null,

        [string]$TrustSource = 'userApproved',

        [AllowNull()]
        [string]$TrustReason = $null
    )

    Assert-PackagePublisherId -PublisherId $PublisherId
    if ([string]::IsNullOrWhiteSpace($PublisherName)) {
        $PublisherName = $PublisherId
    }
    if ([string]::IsNullOrWhiteSpace($SignerDisplayName)) {
        $SignerDisplayName = Get-PackageCertificateDisplayName -Certificate $Certificate
    }

    $entry = [ordered]@{
        publisherId              = $PublisherId
        publisherName            = $PublisherName
        keyThumbprint            = (($Certificate.Thumbprint -replace '\s', '').ToUpperInvariant())
        certificatePem           = ConvertTo-PackageCertificatePem -Certificate $Certificate
        certificateSubject       = [string]$Certificate.Subject
        certificateIssuer        = [string]$Certificate.Issuer
        certificateSerialNumber  = [string]$Certificate.SerialNumber
        notBeforeUtc             = $Certificate.NotBefore.ToUniversalTime().ToString('o')
        notAfterUtc              = $Certificate.NotAfter.ToUniversalTime().ToString('o')
        signerDisplayName        = $SignerDisplayName
        trustSource              = $TrustSource
        trustedAtUtc             = [DateTime]::UtcNow.ToString('o')
        trustedBy                = [Environment]::UserName
        enabled                  = $true
    }
    if (-not [string]::IsNullOrWhiteSpace($TrustReason)) {
        $entry['trustReason'] = $TrustReason
    }

    return [pscustomobject]$entry
}

function Get-PackageTrustEntries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Document
    )

    if (-not $Document.PSObject.Properties['keys'] -or $null -eq $Document.keys) {
        return @()
    }
    if ($Document.keys -isnot [System.Array]) {
        throw 'Package trust inventory must define keys as an array.'
    }

    return @($Document.keys)
}

function Get-PackageRevokedKeyEntries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Document
    )

    if (-not $Document.PSObject.Properties['revokedKeys'] -or $null -eq $Document.revokedKeys) {
        return @()
    }
    if ($Document.revokedKeys -isnot [System.Array]) {
        throw 'Package trust inventory must define revokedKeys as an array.'
    }

    return @($Document.revokedKeys)
}

function Assert-PackageTrustInventorySchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$TrustInventoryDocumentInfo
    )

    $document = $TrustInventoryDocumentInfo.Document
    if (-not $document.PSObject.Properties['inventoryVersion']) {
        throw "Package trust inventory '$($TrustInventoryDocumentInfo.Path)' is missing inventoryVersion."
    }
    if (-not $document.PSObject.Properties['keys']) {
        throw "Package trust inventory '$($TrustInventoryDocumentInfo.Path)' is missing keys."
    }
    if (-not $document.PSObject.Properties['revokedKeys']) {
        throw "Package trust inventory '$($TrustInventoryDocumentInfo.Path)' is missing revokedKeys."
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in @(Get-PackageTrustEntries -Document $document)) {
        foreach ($requiredProperty in @('publisherId', 'publisherName', 'keyThumbprint', 'certificatePem', 'trustSource', 'trustedAtUtc', 'enabled')) {
            if (-not $entry.PSObject.Properties[$requiredProperty] -or
                ($requiredProperty -ne 'enabled' -and [string]::IsNullOrWhiteSpace([string]$entry.$requiredProperty))) {
                throw "Package trust inventory '$($TrustInventoryDocumentInfo.Path)' has a key entry missing '$requiredProperty'."
            }
        }
        Assert-PackagePublisherId -PublisherId ([string]$entry.publisherId)
        $thumbprint = ([string]$entry.keyThumbprint).Trim().ToUpperInvariant()
        if ($thumbprint -notmatch '^[A-F0-9]{40,128}$') {
            throw "Package trust inventory '$($TrustInventoryDocumentInfo.Path)' has invalid keyThumbprint '$($entry.keyThumbprint)'."
        }
        if (-not $seen.Add($thumbprint)) {
            throw "Package trust inventory '$($TrustInventoryDocumentInfo.Path)' defines duplicate keyThumbprint '$thumbprint'."
        }
    }

    foreach ($entry in @(Get-PackageRevokedKeyEntries -Document $document)) {
        if (-not $entry.PSObject.Properties['keyThumbprint'] -or [string]::IsNullOrWhiteSpace([string]$entry.keyThumbprint)) {
            throw "Package trust inventory '$($TrustInventoryDocumentInfo.Path)' has a revokedKeys entry missing keyThumbprint."
        }
    }
}

function Get-PackageTrustInventoryInfo {
    [CmdletBinding()]
    param()

    $inventoryPath = Get-PackageTrustInventoryPath
    $documentInfo = Read-PackageJsonDocument -Path $inventoryPath
    Assert-PackageTrustInventorySchema -TrustInventoryDocumentInfo $documentInfo
    $documentInfo | Add-Member -MemberType NoteProperty -Name Exists -Value $true -Force
    return $documentInfo
}

function Get-PackageTrustInventoryEditInfo {
    [CmdletBinding()]
    param()

    $documentInfo = Get-PackageTrustInventoryInfo
    if (-not $documentInfo.Document.PSObject.Properties['keys'] -or $null -eq $documentInfo.Document.keys) {
        Set-PackageObjectProperty -InputObject $documentInfo.Document -Name 'keys' -Value @()
    }
    if (-not $documentInfo.Document.PSObject.Properties['revokedKeys'] -or $null -eq $documentInfo.Document.revokedKeys) {
        Set-PackageObjectProperty -InputObject $documentInfo.Document -Name 'revokedKeys' -Value @()
    }
    return $documentInfo
}

function Save-PackageTrustInventoryDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DocumentInfo
    )

    Assert-PackageTrustInventorySchema -TrustInventoryDocumentInfo $DocumentInfo
    Save-PackageJsonDocument -Path $DocumentInfo.Path -Document $DocumentInfo.Document
}

function Get-PackageTrustEntryByThumbprint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Document,

        [Parameter(Mandatory = $true)]
        [string]$KeyThumbprint
    )

    $normalized = (($KeyThumbprint -replace '\s', '').ToUpperInvariant())
    foreach ($entry in @(Get-PackageTrustEntries -Document $Document)) {
        if ([string]::Equals((([string]$entry.keyThumbprint -replace '\s', '').ToUpperInvariant()), $normalized, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $entry
        }
    }
    return $null
}

function Test-PackageKeyThumbprintRevoked {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$TrustInventoryDocument,

        [Parameter(Mandatory = $true)]
        [string]$KeyThumbprint,

        [AllowNull()]
        [string]$PublisherId = $null
    )

    $normalized = (($KeyThumbprint -replace '\s', '').ToUpperInvariant())
    foreach ($revoked in @(Get-PackageRevokedKeyEntries -Document $TrustInventoryDocument)) {
        $revokedThumbprint = (([string]$revoked.keyThumbprint -replace '\s', '').ToUpperInvariant())
        if (-not [string]::Equals($revokedThumbprint, $normalized, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($PublisherId) -and
            $revoked.PSObject.Properties['publisherId'] -and
            -not [string]::IsNullOrWhiteSpace([string]$revoked.publisherId) -and
            -not [string]::Equals([string]$revoked.publisherId, $PublisherId, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        return $true
    }
    return $false
}

function Select-PackageTrustSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Entry,

        [Parameter(Mandatory = $true)]
        [string]$InventoryPath
    )

    return [pscustomobject]@{
        PublisherId        = [string]$Entry.publisherId
        PublisherName      = [string]$Entry.publisherName
        KeyThumbprint      = [string]$Entry.keyThumbprint
        SignerDisplayName  = if ($Entry.PSObject.Properties['signerDisplayName']) { [string]$Entry.signerDisplayName } else { $null }
        CertificateSubject = if ($Entry.PSObject.Properties['certificateSubject']) { [string]$Entry.certificateSubject } else { $null }
        NotBeforeUtc       = if ($Entry.PSObject.Properties['notBeforeUtc']) { [string]$Entry.notBeforeUtc } else { $null }
        NotAfterUtc        = if ($Entry.PSObject.Properties['notAfterUtc']) { [string]$Entry.notAfterUtc } else { $null }
        TrustSource        = [string]$Entry.trustSource
        TrustReason        = if ($Entry.PSObject.Properties['trustReason']) { [string]$Entry.trustReason } else { $null }
        TrustedAtUtc       = [string]$Entry.trustedAtUtc
        Enabled            = [bool]$Entry.enabled
        RevokedAtUtc       = if ($Entry.PSObject.Properties['revokedAtUtc']) { [string]$Entry.revokedAtUtc } else { $null }
        RevocationReason   = if ($Entry.PSObject.Properties['revocationReason']) { [string]$Entry.revocationReason } else { $null }
        InventoryPath      = $InventoryPath
    }
}

function Get-PackageTrustSummaries {
    [CmdletBinding()]
    param()

    $documentInfo = Get-PackageTrustInventoryEditInfo
    foreach ($entry in @(Get-PackageTrustEntries -Document $documentInfo.Document)) {
        Select-PackageTrustSummary -Entry $entry -InventoryPath $documentInfo.Path
    }
}

function Set-PackageDefinitionUnsignedSignature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition
    )

    if (-not $Definition.PSObject.Properties['definitionPublication'] -or -not $Definition.definitionPublication) {
        throw 'Package definition is missing definitionPublication.'
    }
    $signature = [pscustomobject][ordered]@{
        kind          = 'unsigned'
        format        = $script:PackageDefinitionSignatureFormat
        signedContent = $script:PackageDefinitionSignedContentKind
    }
    Set-PackageObjectProperty -InputObject $Definition.definitionPublication -Name 'definitionSignature' -Value $signature
}

function Set-PackageDefinitionSignature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition,

        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$SignatureValue
    )

    if (-not $Definition.PSObject.Properties['definitionPublication'] -or -not $Definition.definitionPublication) {
        throw 'Package definition is missing definitionPublication.'
    }

    $signerDisplayName = Get-PackageCertificateDisplayName -Certificate $Certificate
    $signature = [pscustomobject][ordered]@{
        kind               = 'signed'
        format             = $script:PackageDefinitionSignatureFormat
        signedContent      = $script:PackageDefinitionSignedContentKind
        keyThumbprint      = (($Certificate.Thumbprint -replace '\s', '').ToUpperInvariant())
        signerDisplayName  = $signerDisplayName
        certificateSubject = [string]$Certificate.Subject
        certificatePem     = ConvertTo-PackageCertificatePem -Certificate $Certificate
        signedAtUtc        = [DateTime]::UtcNow.ToString('o')
        signatureValue     = $SignatureValue
    }
    Set-PackageObjectProperty -InputObject $Definition.definitionPublication -Name 'definitionSignature' -Value $signature
}

function Invoke-PackageDefinitionDocumentSigning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition,

        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    Set-PackageDefinitionSignature -Definition $Definition -Certificate $Certificate -SignatureValue ''
    $signable = Get-PackageDefinitionSignableContent -Definition $Definition
    $rsa = Get-PackageCertificateRsaPrivateKey -Certificate $Certificate
    if (-not $rsa) {
        throw 'Signing certificate does not contain an RSA private key.'
    }
    try {
        $signatureBytes = Invoke-PackageRsaSignData -Rsa $rsa -Bytes $signable.Bytes
    }
    finally {
        $rsa.Dispose()
    }
    Set-PackageObjectProperty -InputObject $Definition.definitionPublication.definitionSignature -Name 'signatureValue' -Value ([Convert]::ToBase64String($signatureBytes))

    return [pscustomobject]@{
        KeyThumbprint        = (($Certificate.Thumbprint -replace '\s', '').ToUpperInvariant())
        CanonicalContentHash = $signable.Sha256
        SignatureValue       = [Convert]::ToBase64String($signatureBytes)
    }
}

function Test-PackageDefinitionSignatureDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition,

        [AllowNull()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate = $null,

        [AllowNull()]
        [psobject]$TrustInventoryDocument = $null
    )

    $publication = if ($Definition.PSObject.Properties['definitionPublication']) { $Definition.definitionPublication } else { $null }
    $signature = if ($publication -and $publication.PSObject.Properties['definitionSignature']) { $publication.definitionSignature } else { $null }
    if (-not $signature) {
        return [pscustomobject]@{
            Status               = 'missingSignature'
            Valid                = $false
            Trusted              = $false
            KeyThumbprint        = $null
            CanonicalContentHash = $null
            ErrorMessage         = 'definitionPublication.definitionSignature is missing.'
        }
    }
    if ([string]::Equals([string]$signature.kind, 'unsigned', [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{
            Status               = 'unsigned'
            Valid                = $false
            Trusted              = $false
            KeyThumbprint        = $null
            CanonicalContentHash = (Get-PackageDefinitionSignableContent -Definition $Definition).Sha256
            ErrorMessage         = $null
        }
    }
    if (-not [string]::Equals([string]$signature.kind, 'signed', [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{
            Status               = 'unsupportedSignatureKind'
            Valid                = $false
            Trusted              = $false
            KeyThumbprint        = $null
            CanonicalContentHash = $null
            ErrorMessage         = "Unsupported definitionSignature.kind '$($signature.kind)'."
        }
    }
    if (-not [string]::Equals([string]$signature.format, $script:PackageDefinitionSignatureFormat, [System.StringComparison]::Ordinal)) {
        return [pscustomobject]@{
            Status               = 'unsupportedSignatureFormat'
            Valid                = $false
            Trusted              = $false
            KeyThumbprint        = [string]$signature.keyThumbprint
            CanonicalContentHash = $null
            ErrorMessage         = "Unsupported definitionSignature.format '$($signature.format)'."
        }
    }
    if (-not $signature.PSObject.Properties['signatureValue'] -or [string]::IsNullOrWhiteSpace([string]$signature.signatureValue)) {
        return [pscustomobject]@{
            Status               = 'missingSignatureValue'
            Valid                = $false
            Trusted              = $false
            KeyThumbprint        = [string]$signature.keyThumbprint
            CanonicalContentHash = $null
            ErrorMessage         = 'definitionSignature.signatureValue is missing.'
        }
    }

    $keyThumbprint = (([string]$signature.keyThumbprint -replace '\s', '').ToUpperInvariant())
    $publisherId = if ($publication -and $publication.PSObject.Properties['publisherId']) { [string]$publication.publisherId } else { $null }
    $embeddedCertificatePem = if ($signature.PSObject.Properties['certificatePem']) { [string]$signature.certificatePem } else { $null }
    $embeddedCertificate = $null
    if (-not [string]::IsNullOrWhiteSpace($embeddedCertificatePem)) {
        try {
            $embeddedCertificate = ConvertFrom-PackageCertificatePem -CertificatePem $embeddedCertificatePem
        }
        catch {
            return [pscustomobject]@{
                Status               = 'invalidEmbeddedCertificate'
                Valid                = $false
                Trusted              = $false
                KeyThumbprint        = $keyThumbprint
                CanonicalContentHash = $null
                CertificatePem       = $embeddedCertificatePem
                ErrorMessage         = 'definitionSignature.certificatePem is not a valid certificate PEM.'
            }
        }

        $embeddedThumbprint = (($embeddedCertificate.Thumbprint -replace '\s', '').ToUpperInvariant())
        if (-not [string]::Equals($embeddedThumbprint, $keyThumbprint, [System.StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject]@{
                Status               = 'certificateThumbprintMismatch'
                Valid                = $false
                Trusted              = $false
                KeyThumbprint        = $keyThumbprint
                CanonicalContentHash = $null
                SignerDisplayName    = if ($signature.PSObject.Properties['signerDisplayName']) { [string]$signature.signerDisplayName } else { $null }
                CertificateSubject   = [string]$embeddedCertificate.Subject
                CertificatePem       = $embeddedCertificatePem
                CertificateNotBeforeUtc = $embeddedCertificate.NotBefore.ToUniversalTime().ToString('o')
                CertificateNotAfterUtc = $embeddedCertificate.NotAfter.ToUniversalTime().ToString('o')
                ErrorMessage         = "definitionSignature.certificatePem thumbprint '$embeddedThumbprint' does not match keyThumbprint '$keyThumbprint'."
            }
        }
    }

    $trustEntry = $null
    $trusted = $false
    $revoked = $false
    $certificateSource = if ($Certificate) { 'parameter' } else { $null }
    $trustEntryFound = $false
    $trustEntryPublisherMatches = $false
    if ($TrustInventoryDocument) {
        $revoked = Test-PackageKeyThumbprintRevoked -TrustInventoryDocument $TrustInventoryDocument -KeyThumbprint $keyThumbprint -PublisherId $publisherId
        $trustEntry = Get-PackageTrustEntryByThumbprint -Document $TrustInventoryDocument -KeyThumbprint $keyThumbprint
        $trustEntryFound = $null -ne $trustEntry
        if ($trustEntry -and $trustEntry.PSObject.Properties['publisherId'] -and
            [string]::Equals([string]$trustEntry.publisherId, [string]$publisherId, [System.StringComparison]::OrdinalIgnoreCase)) {
            $trustEntryPublisherMatches = $true
        }
        $trustEntryRevokedAtUtc = if ($trustEntry -and $trustEntry.PSObject.Properties['revokedAtUtc']) { [string]$trustEntry.revokedAtUtc } else { $null }
        if ($trustEntry -and [bool]$trustEntry.enabled -and $trustEntryPublisherMatches -and [string]::IsNullOrWhiteSpace($trustEntryRevokedAtUtc)) {
            $trusted = $true
        }
        if ($trustEntry -and -not $Certificate) {
            $Certificate = ConvertFrom-PackageCertificatePem -CertificatePem ([string]$trustEntry.certificatePem)
            $certificateSource = 'trustInventory'
        }
    }

    if ($revoked) {
        return [pscustomobject]@{
            Status               = 'revokedKey'
            Valid                = $false
            Trusted              = $false
            KeyThumbprint        = $keyThumbprint
            CanonicalContentHash = $null
            ErrorMessage         = "Definition signing key '$keyThumbprint' is revoked."
        }
    }
    if (-not $Certificate) {
        if ($embeddedCertificate) {
            $Certificate = $embeddedCertificate
            $certificateSource = 'embedded'
        }
    }

    if (-not $Certificate) {
        return [pscustomobject]@{
            Status               = 'unknownKey'
            Valid                = $false
            Trusted              = $false
            KeyThumbprint        = $keyThumbprint
            CanonicalContentHash = $null
            CertificatePem       = $embeddedCertificatePem
            ErrorMessage         = "No certificate was provided or trusted for key '$keyThumbprint'."
        }
    }

    $signable = Get-PackageDefinitionSignableContent -Definition $Definition
    try {
        $signatureBytes = [Convert]::FromBase64String([string]$signature.signatureValue)
    }
    catch {
        return [pscustomobject]@{
            Status               = 'invalidSignatureValue'
            Valid                = $false
            Trusted              = $trusted
            KeyThumbprint        = $keyThumbprint
            CanonicalContentHash = $signable.Sha256
            ErrorMessage         = 'definitionSignature.signatureValue is not valid base64.'
        }
    }

    $rsa = Get-PackageCertificateRsaPublicKey -Certificate $Certificate
    if (-not $rsa) {
        throw 'Verification certificate does not contain an RSA public key.'
    }
    try {
        $valid = Invoke-PackageRsaVerifyData -Rsa $rsa -Bytes $signable.Bytes -SignatureBytes $signatureBytes
    }
    finally {
        $rsa.Dispose()
    }

    return [pscustomobject]@{
        Status               = if ($valid) { if ($trusted) { 'validTrusted' } else { 'validUntrusted' } } else { 'invalidSignature' }
        Valid                = [bool]$valid
        Trusted              = [bool]($valid -and $trusted)
        KeyThumbprint        = $keyThumbprint
        CanonicalContentHash = $signable.Sha256
        SignerDisplayName    = if ($signature.PSObject.Properties['signerDisplayName']) { [string]$signature.signerDisplayName } else { $null }
        CertificateSubject   = [string]$Certificate.Subject
        CertificatePem       = $embeddedCertificatePem
        CertificateSource    = $certificateSource
        CertificateNotBeforeUtc = $Certificate.NotBefore.ToUniversalTime().ToString('o')
        CertificateNotAfterUtc = $Certificate.NotAfter.ToUniversalTime().ToString('o')
        TrustEntryFound      = [bool]$trustEntryFound
        TrustEntryPublisherMatches = [bool]$trustEntryPublisherMatches
        ErrorMessage         = if ($valid) { $null } else { 'Signature verification failed.' }
    }
}
