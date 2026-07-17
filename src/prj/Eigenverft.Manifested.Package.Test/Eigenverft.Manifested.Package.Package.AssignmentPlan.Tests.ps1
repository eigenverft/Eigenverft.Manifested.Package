<#
    Eigenverft.Manifested.Package Package - read-only assignment planning
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - read-only assignment planning' -Body {
    It 'previews a shipped package without creating local Package state' {
        $localRoot = Get-PackageLocalRoot
        Mock Invoke-WebRequestEx { throw 'Assignment planning must not make HTTP requests.' }
        Mock Get-GitHubRelease { throw 'Assignment planning must not query GitHub.' }
        $plan = Get-PackageAssignmentPlan -DefinitionId 'SevenZip' -Raw

        $plan.Status | Should -Be 'Ready'
        $plan.Accepted | Should -BeTrue
        $plan.MutationFree | Should -BeTrue
        $plan.Mode | Should -Be 'Assigned'
        $plan.Roots.Count | Should -Be 1
        $plan.Nodes.Count | Should -Be 1
        $plan.Nodes[0].DefinitionId | Should -Be 'SevenZip'
        $plan.Nodes[0].Version | Should -Be $plan.DependencyPlan.Nodes[0].PackageVersion
        $plan.Nodes[0].PlannedAction | Should -Be 'Install'
        $plan.Nodes[0].ArtifactFiles[0].SelectedCandidate.Reachability | Should -Be 'NotTested'
        $plan.DependencyPlan.Nodes[0].PackageConfig.InspectionOnly | Should -BeTrue
        $plan.DependencyPlan.Nodes[0].PackageConfig.DefinitionCandidatePath | Should -BeNullOrEmpty
        $plan.NextCommand | Should -Be "Invoke-Package -DefinitionId 'SevenZip'"

        Test-Path -LiteralPath $localRoot | Should -BeFalse
        Test-Path -LiteralPath (Get-PackageLocalConfigPath) | Should -BeFalse
        Test-Path -LiteralPath (Get-PackageLocalEndpointInventoryPath) | Should -BeFalse
        Test-Path -LiteralPath (Get-PackageLocalTrustInventoryPath) | Should -BeFalse
        Test-Path -LiteralPath (Get-PackageLocalDepotInventoryPath) | Should -BeFalse
        Assert-MockCalled Invoke-WebRequestEx -Times 0 -Exactly
        Assert-MockCalled Get-GitHubRelease -Times 0 -Exactly
    }

    It 'reports every missing offline bootstrap artifact and dependency' {
        $plan = Get-PackageAssignmentPlan -DefinitionId 'EigenverftManifestedPackage' -Offline -MaterializeOnly -Raw
        $rootNode = @($plan.Nodes | Where-Object DefinitionId -EQ 'EigenverftManifestedPackage')[0]

        $plan.Status | Should -Be 'Blocked'
        $plan.Accepted | Should -BeFalse
        $plan.VerifyDepotContent | Should -BeTrue
        @($plan.Nodes.DefinitionId) | Should -Contain 'PackageManagement'
        @($plan.Nodes.DefinitionId) | Should -Contain 'PowerShellGet'
        @($plan.Nodes | Where-Object DefinitionId -EQ 'PackageManagement').Count | Should -Be 1
        @($rootNode.ArtifactFiles.Id) | Should -Be @('package', 'packageManagementPackage', 'powerShellGetPackage', 'bootstrapCommand', 'bootstrapPowerShell')
        @($plan.Blockers | Where-Object DefinitionId -EQ 'EigenverftManifestedPackage').ArtifactFileId | Should -Be @('package', 'packageManagementPackage', 'powerShellGetPackage', 'bootstrapCommand', 'bootstrapPowerShell')
        @($plan.Blockers | Where-Object Code -EQ 'ArtifactFileUnavailable' | ForEach-Object ExpectedDepotPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count | Should -BeGreaterThan 0
        $plan.NextCommand | Should -Be "Invoke-Package -DefinitionId 'EigenverftManifestedPackage' -Offline -MaterializeOnly"
    }

    It 'detects invalid depot content and keeps the online repair source feasible' {
        $initialPlan = Get-PackageAssignmentPlan -DefinitionId 'SevenZip' -MaterializeOnly -Raw
        $artifactPath = [string]$initialPlan.Nodes[0].ArtifactFiles[0].ExpectedDepotPath
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $artifactPath) -Force
        Set-Content -LiteralPath $artifactPath -Value 'corrupt-test-content' -Encoding UTF8

        $offlinePlan = Get-PackageAssignmentPlan -DefinitionId 'SevenZip' -Offline -MaterializeOnly -Raw
        $onlinePlan = Get-PackageAssignmentPlan -DefinitionId 'SevenZip' -MaterializeOnly -VerifyDepotContent -Raw

        $offlinePlan.Status | Should -Be 'Blocked'
        $offlinePlan.Nodes[0].ArtifactFiles[0].Candidates[0].Status | Should -Be 'Invalid'
        $onlinePlan.Status | Should -Be 'Ready'
        $onlinePlan.Nodes[0].ArtifactFiles[0].Candidates[0].Status | Should -Be 'Invalid'
        $onlinePlan.Nodes[0].ArtifactFiles[0].SelectedCandidate.Status | Should -Be 'ResolvableOnline'
        $onlinePlan.Nodes[0].PlannedAction | Should -Be 'Materialize'
    }

    It 'checks archive-derived files without extracting them' {
        $depotRoot = Join-Path $TestDrive 'archive-preview-depot'
        $archiveInput = Join-Path $TestDrive 'archive-preview-input'
        $entryPath = 'Bootstrap/Test.Bootstrap.ps1'
        $entryFile = Join-Path $archiveInput ($entryPath -replace '/', '\')
        $entryContent = "Write-Output 'offline bootstrap'"
        Write-TestTextFile -Path $entryFile -Content $entryContent
        $archivePath = Join-Path $depotRoot 'bundle.nupkg'
        Write-TestZipFromDirectory -SourceDirectory $archiveInput -ZipPath $archivePath
        $entryHash = Get-TestFileContentSha256 -Content $entryContent
        $archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()

        $sourceFile = [pscustomobject]@{
            Id = 'modulePackage'; RelativePath = 'bundle.nupkg'; StagingPath = (Join-Path $TestDrive 'stage\bundle.nupkg'); DefaultDepotPath = $archivePath
            AcquisitionCandidates = @([pscustomobject]@{ kind = 'packageDepot' })
            AcquisitionPlan = [pscustomobject]@{ Candidates = @([pscustomobject]@{
                        kind = 'packageDepot'; sourceRef = [pscustomobject]@{ scope = 'environment'; id = 'testDepot' }; sourcePath = 'bundle.nupkg'
                        verification = [pscustomobject]@{ mode = 'required'; algorithm = 'sha256'; sha256 = $archiveHash }
                    }) }
        }
        $derivedFile = [pscustomobject]@{
            Id = 'bootstrap'; RelativePath = 'Test.Bootstrap.ps1'; StagingPath = (Join-Path $TestDrive 'stage\Test.Bootstrap.ps1'); DefaultDepotPath = (Join-Path $depotRoot 'Test.Bootstrap.ps1')
            AcquisitionCandidates = @([pscustomobject]@{ kind = 'archiveEntry'; sourceArtifactFileId = 'modulePackage'; entryPath = $entryPath })
            AcquisitionPlan = [pscustomobject]@{ Candidates = @([pscustomobject]@{
                        kind = 'archiveEntry'; sourceArtifactFileId = 'modulePackage'; entryPath = $entryPath
                        verification = [pscustomobject]@{ mode = 'required'; algorithm = 'sha256'; sha256 = $entryHash }
                    }) }
        }
        $packageResult = [pscustomobject]@{
            Offline = $true
            Package = [pscustomobject]@{ id = 'archive-preview' }
            PackageConfig = [pscustomobject]@{
                EnvironmentSources = [pscustomobject]@{ testDepot = [pscustomobject]@{ kind = 'filesystem'; basePath = $depotRoot } }
                DefinitionSources = [pscustomobject]@{}
            }
            ArtifactFiles = @($sourceFile, $derivedFile)
        }
        $pathsBefore = @(Get-ChildItem -LiteralPath $TestDrive -File -Recurse | Select-Object -ExpandProperty FullName)

        $preview = Resolve-PackageAssignmentArtifactPreview -PackageResult $packageResult -ArtifactFile $derivedFile -Resolved @{} -Visiting @{} -VerifyDepotContent
        $pathsAfter = @(Get-ChildItem -LiteralPath $TestDrive -File -Recurse | Select-Object -ExpandProperty FullName)

        $preview.Ready | Should -BeTrue
        $preview.Status | Should -Be 'Derivable'
        $preview.SelectedCandidate.Verification.Status | Should -Be 'VerificationPassed'
        $pathsAfter | Should -Be $pathsBefore
        Test-Path -LiteralPath $derivedFile.StagingPath | Should -BeFalse
        Test-Path -LiteralPath $derivedFile.DefaultDepotPath | Should -BeFalse
    }

    It 'deduplicates a dependency that is also requested as a root' {
        $plan = Get-PackageAssignmentPlan -DefinitionId 'CodexCli', 'NodeRuntime' -MaterializeOnly -Raw

        $plan.Accepted | Should -BeTrue
        $plan.Roots.Count | Should -Be 2
        @($plan.Nodes | Where-Object DefinitionId -EQ 'NodeRuntime').Count | Should -Be 1
        @($plan.Nodes | Where-Object DefinitionId -EQ 'NodeRuntime')[0].IsRoot | Should -BeTrue
        @($plan.Edges | Where-Object DefinitionId -EQ 'NodeRuntime').Count | Should -Be 1
        @($plan.Nodes | Where-Object DefinitionId -EQ 'CodexCli')[0].NpmMaterialization.Status | Should -Be 'ResolvableOnline'
    }
}
