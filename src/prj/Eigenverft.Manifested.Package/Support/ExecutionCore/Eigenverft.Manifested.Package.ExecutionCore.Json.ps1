<#
    Eigenverft.Manifested.Package.ExecutionCore.Json
    Generic JSON read/write helpers for module-owned documents.
#>

function Read-PackageJsonDocument {
<#
.SYNOPSIS
Reads a Package JSON document from disk.

.DESCRIPTION
Resolves a JSON file path, validates that it contains content, parses it, and
returns the resolved path together with the parsed document object.

.PARAMETER Path
Path to the JSON file that should be loaded.

.EXAMPLE
Read-PackageJsonDocument -Path .\Configuration\Internal\PackageConfig.json
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $rawContent = Get-Content -LiteralPath $resolvedPath -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($rawContent)) {
        throw "Package JSON file '$resolvedPath' is empty."
    }

    try {
        $document = $rawContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Package JSON file '$resolvedPath' could not be parsed. $($_.Exception.Message)"
    }

    return [pscustomobject]@{
        Path     = $resolvedPath
        Document = $document
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
        $escaped = switch ($code) {
            8 { '\b'; break }
            9 { '\t'; break }
            10 { '\n'; break }
            12 { '\f'; break }
            13 { '\r'; break }
            34 { '\"'; break }
            92 { '\\'; break }
            default {
                if ($code -lt 32) {
                    '\u{0:x4}' -f $code
                    break
                }
                [string]$ch
                break
            }
        }
        $null = $builder.Append($escaped)
    }
    $null = $builder.Append('"')
    return $builder.ToString()
}

function ConvertTo-PackagePrettyJson {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value,

        [int]$Depth = 0
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
    if ($Value -is [string] -or $Value -is [char] -or $Value -is [guid]) {
        return ConvertTo-PackageJsonEscapedString -Value ([string]$Value)
    }
    if ($Value -is [datetime]) {
        $utcDate = ([datetime]$Value).ToUniversalTime()
        $dateText = if (($utcDate.Ticks % [TimeSpan]::TicksPerSecond) -eq 0) {
            $utcDate.ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)
        }
        else {
            $utcDate.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
        }
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
            throw 'JSON cannot represent NaN or Infinity.'
        }
        return $doubleValue.ToString('R', [Globalization.CultureInfo]::InvariantCulture)
    }

    $indent = ' ' * ($Depth * 2)
    $childIndent = ' ' * (($Depth + 1) * 2)

    if ($Value -is [System.Collections.IDictionary]) {
        $properties = @(
            foreach ($key in @($Value.Keys)) {
                [pscustomobject]@{
                    Name  = [string]$key
                    Value = $Value[$key]
                }
            }
        )

        if ($properties.Count -eq 0) {
            return '{}'
        }

        $propertyParts = @(
            foreach ($property in @($properties)) {
                '{0}{1}: {2}' -f $childIndent, (ConvertTo-PackageJsonEscapedString -Value $property.Name), (ConvertTo-PackagePrettyJson -Value $property.Value -Depth ($Depth + 1))
            }
        )
        return '{' + [Environment]::NewLine + ($propertyParts -join (',' + [Environment]::NewLine)) + [Environment]::NewLine + $indent + '}'
    }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = @(
            foreach ($item in $Value) {
                ConvertTo-PackagePrettyJson -Value $item -Depth ($Depth + 1)
            }
        )

        if ($items.Count -eq 0) {
            return '[]'
        }

        $itemParts = @(
            foreach ($itemJson in @($items)) {
                '{0}{1}' -f $childIndent, $itemJson
            }
        )
        return '[' + [Environment]::NewLine + ($itemParts -join (',' + [Environment]::NewLine)) + [Environment]::NewLine + $indent + ']'
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
    )

    if ($objectProperties.Count -eq 0) {
        return '{}'
    }

    $objectParts = @(
        foreach ($property in @($objectProperties)) {
            '{0}{1}: {2}' -f $childIndent, (ConvertTo-PackageJsonEscapedString -Value $property.Name), (ConvertTo-PackagePrettyJson -Value $property.Value -Depth ($Depth + 1))
        }
    )
    return '{' + [Environment]::NewLine + ($objectParts -join (',' + [Environment]::NewLine)) + [Environment]::NewLine + $indent + '}'
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
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($temporaryPath, (ConvertTo-PackagePrettyJson -Value $Document), $utf8NoBom)
        Move-Item -LiteralPath $temporaryPath -Destination $resolvedPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }
}
