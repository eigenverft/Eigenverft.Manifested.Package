<#
    Eigenverft.Manifested.Sandbox Package - execution engine helpers
#>

. "$PSScriptRoot\Eigenverft.Manifested.Sandbox.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Sandbox Package - execution engine helpers' -Body {
    It 'prefers Write-StandardMessage when it is available' {
        Mock Write-StandardMessage {}
        Mock Write-Host {}

        { Write-PackageExecutionMessage -Message '[STEP] Example step' } | Should -Not -Throw

        Assert-MockCalled Write-StandardMessage -Times 1
        Assert-MockCalled Write-Host -Times 0
    }

    It 'falls back to Write-Host when Write-StandardMessage throws' {
        Mock Write-StandardMessage { throw 'logger unavailable' }
        Mock Write-Host {}

        { Write-PackageExecutionMessage -Message '[STEP] Example step' } | Should -Not -Throw

        Assert-MockCalled Write-StandardMessage -Times 1
        Assert-MockCalled Write-Host -Times 1
    }

    It 'loads Write-StandardMessage from ExecutionCore and the Package logger adapter from Support Package' {
        $writeStandardMessage = Get-Command Write-StandardMessage -CommandType Function
        $packageExecutionMessage = Get-Command Write-PackageExecutionMessage -CommandType Function

        $writeStandardMessage.ScriptBlock.File | Should -Match 'Support\\ExecutionCore\\.*StandardMessage\.ps1$'
        $packageExecutionMessage.ScriptBlock.File | Should -Match 'Support\\Package\\.*ExecutionMessage\.ps1$'
    }

    It 'loads archive helpers from ExecutionCore' {
        $expandArchiveToDirectory = Get-Command Expand-ArchiveToDirectory -CommandType Function
        $getExpandedArchiveRoot = Get-Command Get-ExpandedArchiveRoot -CommandType Function

        $expandArchiveToDirectory.ScriptBlock.File | Should -Match 'Support\\ExecutionCore\\.*Archive\.ps1$'
        $getExpandedArchiveRoot.ScriptBlock.File | Should -Match 'Support\\ExecutionCore\\.*Archive\.ps1$'
    }

    It 'loads command resolution and filesystem helpers from ExecutionCore' {
        $getResolvedApplicationPath = Get-Command Get-ResolvedApplicationPath -CommandType Function
        $removePathIfExists = Get-Command Remove-PathIfExists -CommandType Function
        $copyFileToPath = Get-Command Copy-FileToPath -CommandType Function
        $getStableShortHash = Get-Command Get-StableShortHash -CommandType Function
        $resolveTemplateText = Get-Command Resolve-TemplateText -CommandType Function
        $resolveConfiguredPath = Get-Command Resolve-ConfiguredPath -CommandType Function

        $getResolvedApplicationPath.ScriptBlock.File | Should -Match 'Support\\ExecutionCore\\.*CommandResolution\.ps1$'
        $removePathIfExists.ScriptBlock.File | Should -Match 'Support\\ExecutionCore\\.*FileSystem\.ps1$'
        $copyFileToPath.ScriptBlock.File | Should -Match 'Support\\ExecutionCore\\.*FileSystem\.ps1$'
        $getStableShortHash.ScriptBlock.File | Should -Match 'Support\\ExecutionCore\\.*PathTemplate\.ps1$'
        $resolveTemplateText.ScriptBlock.File | Should -Match 'Support\\ExecutionCore\\.*PathTemplate\.ps1$'
        $resolveConfiguredPath.ScriptBlock.File | Should -Match 'Support\\ExecutionCore\\.*PathTemplate\.ps1$'
    }

    It 'loads generic npm helpers from ExecutionCore and the Package npm adapter from Support Package' {
        $getNpmRegistryUri = Get-Command Get-NpmRegistryUri -CommandType Function
        $getNpmGlobalConfigArguments = Get-Command Get-NpmGlobalConfigArguments -CommandType Function
        $installPackageNpmMaterializedPackage = Get-Command Install-PackageNpmMaterializedInstallGlobalPackage -CommandType Function

        $getNpmRegistryUri.ScriptBlock.File | Should -Match 'Support\\ExecutionCore\\.*Npm\.ps1$'
        $getNpmGlobalConfigArguments.ScriptBlock.File | Should -Match 'Support\\ExecutionCore\\.*Npm\.ps1$'
        $installPackageNpmMaterializedPackage.ScriptBlock.File | Should -Match 'Support\\Package\\.*Npm\.ps1$'
    }

    It 'returns null when Get-ResolvedApplicationPath cannot resolve a command' {
        Mock Get-Command { @() } -ParameterFilter { $Name -eq 'missing-tool' -and $CommandType -eq 'Application' -and $All }

        $resolvedPath = Get-ResolvedApplicationPath -CommandName 'missing-tool'

        $resolvedPath | Should -BeNullOrEmpty
    }

    It 'returns the normalized full path of the first resolved application' {
        Mock Get-Command {
            [pscustomobject]@{
                Source = 'C:\Tools\bin\tool.exe'
            }
        } -ParameterFilter { $Name -eq 'tool' -and $CommandType -eq 'Application' -and $All }

        $resolvedPath = Get-ResolvedApplicationPath -CommandName 'tool'

        $resolvedPath | Should -Be ([System.IO.Path]::GetFullPath('C:\Tools\bin\tool.exe'))
    }

    It 'returns false when Remove-PathIfExists receives a missing path' {
        $removed = Remove-PathIfExists -Path (Join-Path $TestDrive 'missing-path')

        $removed | Should -BeFalse
    }

    It 'removes an existing file and returns true' {
        $filePath = Join-Path $TestDrive 'remove-file\test.txt'
        Write-TestTextFile -Path $filePath -Content 'content'

        $removed = Remove-PathIfExists -Path $filePath

        $removed | Should -BeTrue
        Test-Path -LiteralPath $filePath | Should -BeFalse
    }

    It 'removes an existing directory and returns true' {
        $directoryPath = Join-Path $TestDrive 'remove-directory'
        Write-TestTextFile -Path (Join-Path $directoryPath 'test.txt') -Content 'content'

        $removed = Remove-PathIfExists -Path $directoryPath

        $removed | Should -BeTrue
        Test-Path -LiteralPath $directoryPath | Should -BeFalse
    }

    It 'throws when Remove-PathIfExists cannot remove an existing path' {
        $directoryPath = Join-Path $TestDrive 'remove-directory-failed'
        Write-TestTextFile -Path (Join-Path $directoryPath 'test.txt') -Content 'content'
        Mock Remove-Item {}

        { Remove-PathIfExists -Path $directoryPath } | Should -Throw '*Could not remove path*'

        Test-Path -LiteralPath $directoryPath | Should -BeTrue
    }

    It 'copies a file to a target path and returns the resolved target path' {
        $sourcePath = Join-Path $TestDrive 'copy-file\source.txt'
        $targetPath = Join-Path $TestDrive 'copy-file\target.txt'
        Write-TestTextFile -Path $sourcePath -Content 'version-a'

        $resolvedTarget = Copy-FileToPath -SourcePath $sourcePath -TargetPath $targetPath

        $resolvedTarget | Should -Be ([System.IO.Path]::GetFullPath($targetPath))
        (Get-Content -LiteralPath $targetPath -Raw) | Should -Be 'version-a'
    }

    It 'overwrites a copied file when requested' {
        $sourcePath = Join-Path $TestDrive 'copy-file-overwrite\source.txt'
        $targetPath = Join-Path $TestDrive 'copy-file-overwrite\target.txt'
        Write-TestTextFile -Path $sourcePath -Content 'version-b'
        Write-TestTextFile -Path $targetPath -Content 'version-a'

        Copy-FileToPath -SourcePath $sourcePath -TargetPath $targetPath -Overwrite | Out-Null

        (Get-Content -LiteralPath $targetPath -Raw) | Should -Be 'version-b'
    }

    It 'removes empty parent directories up to a ceiling after a leaf directory is deleted' {
        $ceiling = Join-Path $TestDrive 'parent-prune\Inst'
        $leaf = Join-Path $ceiling 'vsc-rt\stable\2.0.0\win32-x64'
        $null = New-Item -ItemType Directory -Path (Join-Path $leaf 'bin') -Force
        Write-TestTextFile -Path (Join-Path $leaf 'Code.exe') -Content 'x'

        Remove-PathIfExists -Path $leaf | Out-Null
        Remove-EmptyParentDirectoryChain -DeletedLeafPath $leaf -AncestorCeilingDirectory $ceiling

        Test-Path -LiteralPath $ceiling | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $ceiling 'vsc-rt') | Should -BeFalse
    }

    It 'stops pruning when a parent still has content' {
        $ceiling = Join-Path $TestDrive 'parent-prune-partial\Inst'
        $keepSibling = Join-Path $ceiling 'vsc-rt\stable\2.0.0\win32-arm64'
        $removeLeaf = Join-Path $ceiling 'vsc-rt\stable\2.0.0\win32-x64'
        $null = New-Item -ItemType Directory -Path (Join-Path $removeLeaf 't') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $keepSibling 't') -Force
        Write-TestTextFile -Path (Join-Path $keepSibling 'f.txt') -Content 'y'

        Remove-PathIfExists -Path $removeLeaf | Out-Null
        Remove-EmptyParentDirectoryChain -DeletedLeafPath $removeLeaf -AncestorCeilingDirectory $ceiling

        Test-Path -LiteralPath $keepSibling | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $ceiling 'vsc-rt\stable\2.0.0') | Should -BeTrue
    }

    It 'resolves Inst as prune ceiling when the leaf path is under preferred install root' {
        $inst = Join-Path $TestDrive 'prune-ceiling\Inst'
        $leaf = Join-Path $inst 'pkg\ver\leaf'
        $ceiling = Get-EmptyParentPruneCeilingDirectory -InstallLeafPath $leaf -PreferredInstallRootDirectory $inst

        $ceiling | Should -Be ([System.IO.Path]::GetFullPath($inst))
    }

    It 'resolves path root as prune ceiling when the leaf is outside preferred install root' {
        $inst = Join-Path $TestDrive 'prune-ceiling-ext\Inst'
        $leaf = Join-Path $TestDrive 'prune-ceiling-ext\External\pkg\ver'
        $ceiling = Get-EmptyParentPruneCeilingDirectory -InstallLeafPath $leaf -PreferredInstallRootDirectory $inst
        $expectedRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($leaf)))

        $ceiling | Should -Be $expectedRoot
    }

    It 'uses path root when preferred install root is empty' {
        $leaf = Join-Path $TestDrive 'prune-ceiling-no-pref\p\v'
        $ceiling = Get-EmptyParentPruneCeilingDirectory -InstallLeafPath $leaf -PreferredInstallRootDirectory ''

        $ceiling | Should -Be ([System.IO.Path]::GetFullPath([System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($leaf))))
    }

    It 'creates deterministic stable short hashes with the requested length' {
        $firstHash = Get-StableShortHash -InputText 'VSCodeRuntime|stable|1.119.0|win32-x64'
        $secondHash = Get-StableShortHash -InputText 'VSCodeRuntime|stable|1.119.0|win32-x64'
        $shortHash = Get-StableShortHash -InputText 'VSCodeRuntime|stable|1.119.0|win32-x64' -Length 6

        $firstHash | Should -Be $secondHash
        $firstHash | Should -Match '^[0-9a-f]{8}$'
        $shortHash | Should -Match '^[0-9a-f]{6}$'
        $firstHash.StartsWith($shortHash) | Should -BeTrue
    }

    It 'resolves template text while leaving unknown tokens visible' {
        $resolvedText = Resolve-TemplateText -Text '{known}-{missing}-{empty}' -Tokens @{
            known = 'value'
            empty = $null
        }

        $resolvedText | Should -Be 'value-{missing}-{empty}'
    }

    It 'resolves configured paths with env vars, tokens, relative base paths, and absolute paths' {
        $rootPath = Join-Path $TestDrive 'configured-path-root'
        $env:EVF_TEST_PATH_SEGMENT = 'EnvSegment'

        $relativePath = Resolve-ConfiguredPath -PathValue '%EVF_TEST_PATH_SEGMENT%/{name}/child' -BaseDirectory $rootPath -Tokens @{ name = 'TokenSegment' }
        $absoluteTarget = Join-Path $rootPath 'absolute-target'
        $absolutePath = Resolve-ConfiguredPath -PathValue $absoluteTarget -BaseDirectory (Join-Path $TestDrive 'other-root') -Tokens @{}

        $relativePath | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $rootPath 'EnvSegment\TokenSegment\child')))
        $absolutePath | Should -Be ([System.IO.Path]::GetFullPath($absoluteTarget))
    }

    It 'extracts an archive into an empty destination directory' {
        $rootPath = Join-Path $TestDrive 'archive-extract-empty'
        $sourceDirectory = Join-Path $rootPath 'source'
        $destinationDirectory = Join-Path $rootPath 'destination'
        $zipPath = Join-Path $rootPath 'package.zip'

        $null = New-Item -ItemType Directory -Path (Join-Path $sourceDirectory 'bin') -Force
        Write-TestTextFile -Path (Join-Path $sourceDirectory 'Code.exe') -Content 'binary-a'
        Write-TestTextFile -Path (Join-Path $sourceDirectory 'bin\code.cmd') -Content '@echo off'
        Write-TestZipFromDirectory -SourceDirectory $sourceDirectory -ZipPath $zipPath

        $resolvedDestination = Expand-ArchiveToDirectory -ArchivePath $zipPath -DestinationDirectory $destinationDirectory

        $resolvedDestination | Should -Be ([System.IO.Path]::GetFullPath($destinationDirectory))
        Test-Path -LiteralPath (Join-Path $destinationDirectory 'Code.exe') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $destinationDirectory 'bin\code.cmd') | Should -BeTrue
    }

    It 'extracts a nupkg archive through a zip alias and removes the alias' {
        $rootPath = Join-Path $TestDrive 'archive-extract-nupkg'
        $sourceDirectory = Join-Path $rootPath 'source'
        $destinationDirectory = Join-Path $rootPath 'destination'
        $zipPath = Join-Path $rootPath 'package.zip'
        $nupkgPath = Join-Path $rootPath 'python.1.0.0.nupkg'

        $null = New-Item -ItemType Directory -Path (Join-Path $sourceDirectory 'tools') -Force
        Write-TestTextFile -Path (Join-Path $sourceDirectory 'tools\python.exe') -Content 'python'
        Write-TestZipFromDirectory -SourceDirectory $sourceDirectory -ZipPath $zipPath
        Move-Item -LiteralPath $zipPath -Destination $nupkgPath

        $resolvedDestination = Expand-ArchiveToDirectory -ArchivePath $nupkgPath -DestinationDirectory $destinationDirectory

        $resolvedDestination | Should -Be ([System.IO.Path]::GetFullPath($destinationDirectory))
        Test-Path -LiteralPath (Join-Path $destinationDirectory 'tools\python.exe') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $destinationDirectory 'python.1.0.0.zip') | Should -BeFalse
    }

    It 'overwrites existing extracted files when requested' {
        $rootPath = Join-Path $TestDrive 'archive-extract-overwrite'
        $firstSourceDirectory = Join-Path $rootPath 'source-a'
        $secondSourceDirectory = Join-Path $rootPath 'source-b'
        $destinationDirectory = Join-Path $rootPath 'destination'
        $firstZipPath = Join-Path $rootPath 'package-a.zip'
        $secondZipPath = Join-Path $rootPath 'package-b.zip'

        $null = New-Item -ItemType Directory -Path $firstSourceDirectory -Force
        $null = New-Item -ItemType Directory -Path $secondSourceDirectory -Force
        Write-TestTextFile -Path (Join-Path $firstSourceDirectory 'app.txt') -Content 'version-a'
        Write-TestTextFile -Path (Join-Path $secondSourceDirectory 'app.txt') -Content 'version-b'
        Write-TestZipFromDirectory -SourceDirectory $firstSourceDirectory -ZipPath $firstZipPath
        Write-TestZipFromDirectory -SourceDirectory $secondSourceDirectory -ZipPath $secondZipPath

        Expand-ArchiveToDirectory -ArchivePath $firstZipPath -DestinationDirectory $destinationDirectory | Out-Null
        Expand-ArchiveToDirectory -ArchivePath $secondZipPath -DestinationDirectory $destinationDirectory -Overwrite | Out-Null

        (Get-Content -LiteralPath (Join-Path $destinationDirectory 'app.txt') -Raw) | Should -Be 'version-b'
    }

    It 'returns the single child directory when expanded content lands under one top-level folder' {
        $stagePath = Join-Path $TestDrive 'expanded-root-single-child'
        $childDirectory = Join-Path $stagePath 'payload'
        $null = New-Item -ItemType Directory -Path $childDirectory -Force
        Write-TestTextFile -Path (Join-Path $childDirectory 'tool.exe') -Content 'tool'

        $expandedRoot = Get-ExpandedArchiveRoot -StagePath $stagePath

        $expandedRoot | Should -Be ([System.IO.Path]::GetFullPath($childDirectory))
    }

    It 'returns the stage root when files are expanded directly into the stage' {
        $stagePath = Join-Path $TestDrive 'expanded-root-stage'
        $null = New-Item -ItemType Directory -Path $stagePath -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $stagePath 'payload') -Force
        Write-TestTextFile -Path (Join-Path $stagePath 'tool.exe') -Content 'tool'

        $expandedRoot = Get-ExpandedArchiveRoot -StagePath $stagePath

        $expandedRoot | Should -Be ([System.IO.Path]::GetFullPath($stagePath))
    }

}

