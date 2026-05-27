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

function ConvertTo-PackageJsonEscapedString {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return '""'
    }

    $builder = [System.Text.StringBuilder]::new()
    $null = $builder.Append('"')
    foreach ($ch in $Value.ToCharArray()) {
        $code = [int][char]$ch
        switch ($code) {
            8 { $null = $builder.Append('\b'); continue }
            9 { $null = $builder.Append('\t'); continue }
            10 { $null = $builder.Append('\n'); continue }
            12 { $null = $builder.Append('\f'); continue }
            13 { $null = $builder.Append('\r'); continue }
            34 { $null = $builder.Append('\"'); continue }
            92 { $null = $builder.Append('\\'); continue }
        }
        if ($code -lt 32) {
            $null = $builder.Append(('\u{0:x4}' -f $code))
            continue
        }
        $null = $builder.Append($ch)
    }
    $null = $builder.Append('"')
    return $builder.ToString()
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

function Save-PackageJsonDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [psobject]$Document
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $directory = Split-Path -Parent $resolvedPath
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        $null = New-Item -ItemType Directory -Path $directory -Force
    }

    $temporaryPath = '{0}.{1}.tmp' -f $resolvedPath, ([guid]::NewGuid().ToString('N'))
    try {
        $Document | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
        Move-Item -LiteralPath $temporaryPath -Destination $resolvedPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }
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

function Get-PackageDefaultSigningDirectory {
    [CmdletBinding()]
    param()

    $documentsPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
    if ([string]::IsNullOrWhiteSpace($documentsPath)) {
        $documentsPath = Join-Path $HOME 'Documents'
    }

    return [System.IO.Path]::GetFullPath((Join-Path $documentsPath 'Eigenverft.Package\Signing'))
}

function Get-PackageSigningProfileInventoryPath {
    [CmdletBinding()]
    param()

    return [System.IO.Path]::GetFullPath((Join-Path (Join-Path (Get-PackageLocalRoot) 'Configuration\Private') 'PackageSigningProfiles.json'))
}

function New-PackageSigningProfileInventoryDocument {
    [CmdletBinding()]
    param()

    return [pscustomobject][ordered]@{
        inventoryVersion = 1
        profiles         = @()
    }
}

function Get-PackageSigningProfileEntries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Document
    )

    if (-not $Document.PSObject.Properties['profiles'] -or $null -eq $Document.profiles) {
        return @()
    }
    if ($Document.profiles -isnot [System.Array]) {
        throw 'Package signing profile inventory must define profiles as an array.'
    }

    return @($Document.profiles)
}

function Assert-PackageSigningProfileInventorySchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$ProfileInventoryDocumentInfo
    )

    $document = $ProfileInventoryDocumentInfo.Document
    if (-not $document.PSObject.Properties['inventoryVersion']) {
        throw "Package signing profile inventory '$($ProfileInventoryDocumentInfo.Path)' is missing inventoryVersion."
    }
    if (-not $document.PSObject.Properties['profiles']) {
        throw "Package signing profile inventory '$($ProfileInventoryDocumentInfo.Path)' is missing profiles."
    }

    foreach ($profile in @(Get-PackageSigningProfileEntries -Document $document)) {
        foreach ($requiredProperty in @('name', 'publisherId', 'pfxPath', 'keyThumbprint', 'protectedPassword', 'protectedPasswordKind')) {
            if (-not $profile.PSObject.Properties[$requiredProperty] -or [string]::IsNullOrWhiteSpace([string]$profile.$requiredProperty)) {
                throw "Package signing profile inventory '$($ProfileInventoryDocumentInfo.Path)' has a profile entry missing '$requiredProperty'."
            }
        }
        Assert-PackagePublisherId -PublisherId ([string]$profile.publisherId)
    }
}

function Get-PackageSigningProfileInventoryInfo {
    [CmdletBinding()]
    param()

    $profilePath = Get-PackageSigningProfileInventoryPath
    if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) {
        return [pscustomobject]@{
            Path     = $profilePath
            Document = New-PackageSigningProfileInventoryDocument
            Exists   = $false
        }
    }

    $documentInfo = Read-PackageJsonDocument -Path $profilePath
    Assert-PackageSigningProfileInventorySchema -ProfileInventoryDocumentInfo $documentInfo
    $documentInfo | Add-Member -MemberType NoteProperty -Name Exists -Value $true -Force
    return $documentInfo
}

function Save-PackageSigningProfileInventoryDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DocumentInfo
    )

    Assert-PackageSigningProfileInventorySchema -ProfileInventoryDocumentInfo $DocumentInfo
    Save-PackageJsonDocument -Path $DocumentInfo.Path -Document $DocumentInfo.Document
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

function Select-PackageSigningProfileSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Profile,

        [Parameter(Mandatory = $true)]
        [string]$ProfileInventoryPath
    )

    return [pscustomobject]@{
        Name                 = [string]$Profile.name
        PublisherId          = [string]$Profile.publisherId
        PublisherName        = if ($Profile.PSObject.Properties['publisherName']) { [string]$Profile.publisherName } else { $null }
        PfxPath              = [string]$Profile.pfxPath
        CertificatePath      = if ($Profile.PSObject.Properties['certificatePath']) { [string]$Profile.certificatePath } else { $null }
        TrustExportPath      = if ($Profile.PSObject.Properties['trustExportPath']) { [string]$Profile.trustExportPath } else { $null }
        KeyThumbprint        = [string]$Profile.keyThumbprint
        CertificateSubject   = if ($Profile.PSObject.Properties['certificateSubject']) { [string]$Profile.certificateSubject } else { $null }
        CreatedAtUtc         = if ($Profile.PSObject.Properties['createdAtUtc']) { [string]$Profile.createdAtUtc } else { $null }
        UpdatedAtUtc         = if ($Profile.PSObject.Properties['updatedAtUtc']) { [string]$Profile.updatedAtUtc } else { $null }
        LastUsedAtUtc        = if ($Profile.PSObject.Properties['lastUsedAtUtc']) { [string]$Profile.lastUsedAtUtc } else { $null }
        IsDefault            = if ($Profile.PSObject.Properties['isDefault']) { [bool]$Profile.isDefault } else { $false }
        PasswordStored       = -not [string]::IsNullOrWhiteSpace([string]$Profile.protectedPassword)
        PasswordStorage      = if ($Profile.PSObject.Properties['protectedPasswordKind']) { [string]$Profile.protectedPasswordKind } else { $null }
        ProfileInventoryPath = $ProfileInventoryPath
    }
}

function Get-PackageSigningProfileSummaries {
    [CmdletBinding()]
    param()

    $documentInfo = Get-PackageSigningProfileInventoryInfo
    foreach ($profile in @(Get-PackageSigningProfileEntries -Document $documentInfo.Document)) {
        Select-PackageSigningProfileSummary -Profile $profile -ProfileInventoryPath $documentInfo.Path
    }
}

function Get-PackageSigningProfileByPublisherId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PublisherId
    )

    $documentInfo = Get-PackageSigningProfileInventoryInfo
    $matches = @(
        Get-PackageSigningProfileEntries -Document $documentInfo.Document | Where-Object {
            [string]::Equals([string]$_.publisherId, $PublisherId, [System.StringComparison]::OrdinalIgnoreCase)
        }
    )
    if ($matches.Count -eq 0) {
        return $null
    }

    $selected = @($matches | Sort-Object -Property `
            @{ Expression = { if ($_.PSObject.Properties['isDefault'] -and [bool]$_.isDefault) { 1 } else { 0 } } }, `
            @{ Expression = { if ($_.PSObject.Properties['lastUsedAtUtc']) { [string]$_.lastUsedAtUtc } else { '' } } }, `
            @{ Expression = { if ($_.PSObject.Properties['updatedAtUtc']) { [string]$_.updatedAtUtc } else { '' } } } `
            -Descending | Select-Object -First 1)
    return $selected[0]
}

function Get-PackageSigningProfileByPfxPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PfxPath
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($PfxPath)
    $documentInfo = Get-PackageSigningProfileInventoryInfo
    foreach ($profile in @(Get-PackageSigningProfileEntries -Document $documentInfo.Document)) {
        if ($profile.PSObject.Properties['pfxPath'] -and
            [string]::Equals([System.IO.Path]::GetFullPath([string]$profile.pfxPath), $resolvedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $profile
        }
    }

    return $null
}

function Set-PackageSigningProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$PublisherId,

        [AllowNull()]
        [string]$PublisherName = $null,

        [Parameter(Mandatory = $true)]
        [string]$PfxPath,

        [AllowNull()]
        [string]$CertificatePath = $null,

        [AllowNull()]
        [string]$TrustExportPath = $null,

        [Parameter(Mandatory = $true)]
        [string]$KeyThumbprint,

        [AllowNull()]
        [string]$CertificateSubject = $null,

        [Parameter(Mandatory = $true)]
        [securestring]$Password
    )

    Assert-PackagePublisherId -PublisherId $PublisherId
    $documentInfo = Get-PackageSigningProfileInventoryInfo
    $now = [DateTime]::UtcNow.ToString('o')
    $protectedPassword = Protect-PackageSigningProfilePassword -Password $Password
    $profiles = New-Object System.Collections.Generic.List[object]
    $existingCreatedAtUtc = $null

    foreach ($profile in @(Get-PackageSigningProfileEntries -Document $documentInfo.Document)) {
        if ([string]::Equals([string]$profile.publisherId, $PublisherId, [System.StringComparison]::OrdinalIgnoreCase)) {
            if ($profile.PSObject.Properties['createdAtUtc']) {
                $existingCreatedAtUtc = [string]$profile.createdAtUtc
            }
            continue
        }
        $profiles.Add($profile) | Out-Null
    }

    $profile = [pscustomobject][ordered]@{
        name                  = $Name
        publisherId           = $PublisherId
        publisherName         = if ([string]::IsNullOrWhiteSpace($PublisherName)) { $PublisherId } else { $PublisherName }
        pfxPath               = [System.IO.Path]::GetFullPath($PfxPath)
        certificatePath       = if ([string]::IsNullOrWhiteSpace($CertificatePath)) { $null } else { [System.IO.Path]::GetFullPath($CertificatePath) }
        trustExportPath       = if ([string]::IsNullOrWhiteSpace($TrustExportPath)) { $null } else { [System.IO.Path]::GetFullPath($TrustExportPath) }
        keyThumbprint         = (($KeyThumbprint -replace '\s', '').ToUpperInvariant())
        certificateSubject    = $CertificateSubject
        protectedPassword     = $protectedPassword
        protectedPasswordKind = 'dpapi-current-user-securestring'
        createdAtUtc          = if ([string]::IsNullOrWhiteSpace($existingCreatedAtUtc)) { $now } else { $existingCreatedAtUtc }
        updatedAtUtc          = $now
        lastUsedAtUtc         = $null
        isDefault             = $true
        userName              = [Environment]::UserName
        machineName           = [Environment]::MachineName
    }
    $profiles.Add($profile) | Out-Null
    Set-PackageObjectProperty -InputObject $documentInfo.Document -Name 'profiles' -Value @($profiles.ToArray())
    Save-PackageSigningProfileInventoryDocument -DocumentInfo $documentInfo

    return Select-PackageSigningProfileSummary -Profile $profile -ProfileInventoryPath $documentInfo.Path
}

function Set-PackageSigningProfileLastUsed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PublisherId,

        [Parameter(Mandatory = $true)]
        [string]$KeyThumbprint
    )

    $documentInfo = Get-PackageSigningProfileInventoryInfo
    $normalizedThumbprint = (($KeyThumbprint -replace '\s', '').ToUpperInvariant())
    $now = [DateTime]::UtcNow.ToString('o')
    $changed = $false
    foreach ($profile in @(Get-PackageSigningProfileEntries -Document $documentInfo.Document)) {
        if (-not [string]::Equals([string]$profile.publisherId, $PublisherId, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $isSelected = [string]::Equals((([string]$profile.keyThumbprint -replace '\s', '').ToUpperInvariant()), $normalizedThumbprint, [System.StringComparison]::OrdinalIgnoreCase)
        if ($isSelected) {
            Set-PackageObjectProperty -InputObject $profile -Name 'lastUsedAtUtc' -Value $now
            Set-PackageObjectProperty -InputObject $profile -Name 'updatedAtUtc' -Value $now
        }
        Set-PackageObjectProperty -InputObject $profile -Name 'isDefault' -Value $isSelected
        $changed = $true
    }

    if ($changed) {
        Save-PackageSigningProfileInventoryDocument -DocumentInfo $documentInfo
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

function Resolve-PackagePublisherIdFromCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    $candidate = Get-PackageCertificateCommonName -Certificate $Certificate
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        return $null
    }

    try {
        Assert-PackagePublisherId -PublisherId $candidate
        return $candidate
    }
    catch {
        return $null
    }
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
        $SignerDisplayName = if ([string]::IsNullOrWhiteSpace($Certificate.FriendlyName)) { $Certificate.Subject } else { $Certificate.FriendlyName }
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

    $signerDisplayName = if ([string]::IsNullOrWhiteSpace($Certificate.FriendlyName)) { $Certificate.Subject } else { $Certificate.FriendlyName }
    $signature = [pscustomobject][ordered]@{
        kind               = 'signed'
        format             = $script:PackageDefinitionSignatureFormat
        signedContent      = $script:PackageDefinitionSignedContentKind
        keyThumbprint      = (($Certificate.Thumbprint -replace '\s', '').ToUpperInvariant())
        signerDisplayName  = $signerDisplayName
        certificateSubject = [string]$Certificate.Subject
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
    $trustEntry = $null
    $trusted = $false
    $revoked = $false
    if ($TrustInventoryDocument) {
        $revoked = Test-PackageKeyThumbprintRevoked -TrustInventoryDocument $TrustInventoryDocument -KeyThumbprint $keyThumbprint -PublisherId $publisherId
        $trustEntry = Get-PackageTrustEntryByThumbprint -Document $TrustInventoryDocument -KeyThumbprint $keyThumbprint
        $trustEntryPublisherMatches = $false
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
        return [pscustomobject]@{
            Status               = 'unknownKey'
            Valid                = $false
            Trusted              = $false
            KeyThumbprint        = $keyThumbprint
            CanonicalContentHash = $null
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
        ErrorMessage         = if ($valid) { $null } else { 'Signature verification failed.' }
    }
}
