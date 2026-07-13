<#
    Eigenverft.Manifested.Package Package - install and npm
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

function global:Write-TestTarGzipEntry {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Path,

                [Parameter(Mandatory = $true)]
                [string]$EntryName,

                [Parameter(Mandatory = $true)]
                [string]$Content
            )

            $resolvedPath = [System.IO.Path]::GetFullPath($Path)
            $parent = Split-Path -Parent $resolvedPath
            if (-not [string]::IsNullOrWhiteSpace($parent)) {
                $null = New-Item -ItemType Directory -Path $parent -Force
            }

            Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
            $contentBytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
            $header = New-Object byte[] 512
            $nameBytes = [System.Text.Encoding]::ASCII.GetBytes(($EntryName -replace '\\', '/'))
            [Array]::Copy($nameBytes, 0, $header, 0, [Math]::Min($nameBytes.Length, 100))
            $modeBytes = [System.Text.Encoding]::ASCII.GetBytes('0000644')
            [Array]::Copy($modeBytes, 0, $header, 100, $modeBytes.Length)
            $uidBytes = [System.Text.Encoding]::ASCII.GetBytes('0000000')
            [Array]::Copy($uidBytes, 0, $header, 108, $uidBytes.Length)
            [Array]::Copy($uidBytes, 0, $header, 116, $uidBytes.Length)
            $sizeBytes = [System.Text.Encoding]::ASCII.GetBytes(('{0:00000000000}' -f [Convert]::ToString($contentBytes.Length, 8)))
            [Array]::Copy($sizeBytes, 0, $header, 124, $sizeBytes.Length)
            $mtimeBytes = [System.Text.Encoding]::ASCII.GetBytes('00000000000')
            [Array]::Copy($mtimeBytes, 0, $header, 136, $mtimeBytes.Length)
            for ($i = 148; $i -lt 156; $i++) {
                $header[$i] = 32
            }
            $header[156] = [byte][char]'0'
            $magicBytes = [System.Text.Encoding]::ASCII.GetBytes('ustar')
            [Array]::Copy($magicBytes, 0, $header, 257, $magicBytes.Length)

            $checksum = 0
            foreach ($value in $header) {
                $checksum += $value
            }
            $checksumBytes = [System.Text.Encoding]::ASCII.GetBytes(('{0:000000}' -f [Convert]::ToString($checksum, 8)))
            [Array]::Copy($checksumBytes, 0, $header, 148, $checksumBytes.Length)
            $header[154] = 0
            $header[155] = 32

            $paddingLength = (512 - ($contentBytes.Length % 512)) % 512
            $fileStream = [System.IO.File]::Create($resolvedPath)
            $gzipStream = $null
            try {
                $gzipStream = New-Object System.IO.Compression.GZipStream($fileStream, [System.IO.Compression.CompressionMode]::Compress)
                $gzipStream.Write($header, 0, $header.Length)
                $gzipStream.Write($contentBytes, 0, $contentBytes.Length)
                if ($paddingLength -gt 0) {
                    $padding = New-Object byte[] $paddingLength
                    $gzipStream.Write($padding, 0, $padding.Length)
                }
                $zeroBlocks = New-Object byte[] 1024
                $gzipStream.Write($zeroBlocks, 0, $zeroBlocks.Length)
            }
            finally {
                if ($gzipStream) {
                    $gzipStream.Dispose()
                }
                $fileStream.Dispose()
            }
        }

function global:Write-TestNpmPackageTarball {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Path,

                [Parameter(Mandatory = $true)]
                [string]$Name,

                [Parameter(Mandatory = $true)]
                [string]$Version,

                [AllowNull()]
                [hashtable]$Dependencies,

                [AllowNull()]
                [hashtable]$OptionalDependencies,

                [AllowNull()]
                [string[]]$OS,

                [AllowNull()]
                [string[]]$CPU
            )

            $package = [ordered]@{
                name    = $Name
                version = $Version
            }
            if ($Dependencies) {
                $package.dependencies = $Dependencies
            }
            if ($OptionalDependencies) {
                $package.optionalDependencies = $OptionalDependencies
            }
            if ($OS) {
                $package.os = @($OS)
            }
            if ($CPU) {
                $package.cpu = @($CPU)
            }

            Write-TestTarGzipEntry -Path $Path -EntryName 'package/package.json' -Content ($package | ConvertTo-Json -Depth 10 -Compress)
        }
