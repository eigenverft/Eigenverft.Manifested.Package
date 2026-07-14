<#
    Eigenverft.Manifested.Package Package - discovery and removal
#>

. "$PSScriptRoot\\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - discovery and removal' -Body {

    It 'resolves shipped package definitions through signed trust and endpoint seams' {
        $reference = Resolve-PackageDefinitionReference -DefinitionId 'VSCodeRuntime'

        $reference.EndpointName | Should -Be 'moduleDefaults'
        $reference.PublisherId | Should -Be 'Eigenverft'
        $reference.DefinitionId | Should -Be 'VSCodeRuntime'
        $reference.SourceKind | Should -Be 'moduleLocal'
        Split-Path -Leaf $reference.DefinitionPath | Should -Be 'VSCodeRuntime.json'
    }

    It 'searches enabled endpoints by definition metadata and command names' {
        $rootPath = Join-Path $TestDrive 'search-command'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot') -CatalogTrustPolicy allowUnsigned -CatalogTrustAllowUnsignedPublisherIds @('Eigenverft')
        $nodeDefinition = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'NodeRuntime' -Releases @(
                New-TestPackageRelease -Id 'node-win-x64-stable' -Version '20.11.1' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
            ))
        $nodeDefinition.display.default.name = 'Node.js'
        $nodeDefinition.display.default.publisher = 'OpenJS'
        $nodeDefinition.display.default.corporation = 'OpenJS Foundation'
        $nodeDefinition.display.default.summary = 'Server-side JavaScript runtime'
        $nodeDefinition | Add-Member -MemberType NoteProperty -Name classification -Value ([pscustomobject]@{ tags = @('nodejs', 'runtime') })
        $nodeDefinition.discovery.presence.files = @('node.exe')
        $nodeDefinition.discovery.presence.directories = @()
        $nodeDefinition.discovery.presence.commands = @(
            [pscustomobject]@{
                name             = 'node'
                relativePath     = 'node.exe'
                requiredForState = $true
                exposeCommand    = $true
                stateChecks      = @()
            }
        )
        $nodeDefinition.discovery.presence.apps = @()

        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $nodeDefinition
        $definitionRoot = Split-Path -Parent (Split-Path -Parent $documents.DefinitionPath)
        $codeDefinitionPath = Join-Path (Join-Path $definitionRoot 'Eigenverft') 'VSCodeRuntime.json'
        $codeDefinition = New-TestVSCodeDefinitionDocument -DefinitionId 'VSCodeRuntime' -Releases @(
            New-TestPackageRelease -Id 'code-win-x64-stable' -Version '1.99.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        $codeDefinition.classification = @{ tags = @('editor', 'vscode') }
        Write-TestJsonDocument -Path $codeDefinitionPath -Document $codeDefinition
        $untaggedDefinitionPath = Join-Path (Join-Path $definitionRoot 'Eigenverft') 'UnclassifiedTool.json'
        $untaggedDefinition = New-TestVSCodeDefinitionDocument -DefinitionId 'UnclassifiedTool' -Releases @(
            New-TestPackageRelease -Id 'unclassified-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
        )
        $untaggedDefinition.display.default.name = 'Unclassified Tool'
        $untaggedDefinition.display.default.summary = 'Unclassified runtime tool'
        Write-TestJsonDocument -Path $untaggedDefinitionPath -Document $untaggedDefinition

        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageEndpointInventoryPath { $documents.EndpointInventoryPath }

        $nodeResults = @(Search-Package -Query 'node' -Platform windows -Architecture x64 -ReleaseTrack stable)
        $codeResults = @(Search-Package -Query 'Code editor' -PublisherId Eigenverft -EndpointName moduleDefaults -Platform windows -Architecture x64 -ReleaseTrack stable)
        $tagQueryResults = @(Search-Package -Query 'nodejs' -Platform windows -Architecture x64 -ReleaseTrack stable)
        $tagResults = @(Search-Package -Tag EDITOR,vscode -Platform windows -Architecture x64 -ReleaseTrack stable)
        $untaggedResults = @(Search-Package -Query 'unclassified' -Platform windows -Architecture x64 -ReleaseTrack stable)

        $nodeResults.Count | Should -Be 1
        $nodeResults[0].DefinitionId | Should -Be 'NodeRuntime'
        $nodeResults[0].Name | Should -Be 'Node.js'
        $nodeResults[0].Version | Should -Be '20.11.1'
        $nodeResults[0].PlatformAvailable | Should -BeTrue
        @($nodeResults[0].Commands) | Should -Be @('node')
        @($nodeResults[0].Tags) | Should -Be @('nodejs', 'runtime')
        $nodeResults[0].EndpointName | Should -Be 'moduleDefaults'
        $nodeResults[0].EndpointSourceKind | Should -Be 'filesystem'
        $nodeResults[0].CatalogTrustStatus | Should -Be 'unsignedConfigTrust'
        $nodeResults[0].InvokeCommand | Should -Be "Invoke-Package -DefinitionId 'NodeRuntime' -PublisherId 'Eigenverft'"
        $codeResults.Count | Should -Be 1
        $codeResults[0].DefinitionId | Should -Be 'VSCodeRuntime'
        $tagQueryResults.Count | Should -Be 1
        $tagQueryResults[0].DefinitionId | Should -Be 'NodeRuntime'
        $tagResults.Count | Should -Be 1
        $tagResults[0].DefinitionId | Should -Be 'VSCodeRuntime'
        @(Search-Package -Tag editor,runtime -Platform windows -Architecture x64 -ReleaseTrack stable).Count | Should -Be 0
        @(Search-Package -Tag runtime -Platform windows -Architecture x64 -ReleaseTrack stable).DefinitionId | Should -Be @('NodeRuntime')
        $untaggedResults.Count | Should -Be 1
        @($untaggedResults[0].Tags) | Should -Be @()
        Test-Path -LiteralPath (Join-Path (Join-Path $rootPath 'AppRoot') 'PkgEndpoint') | Should -BeFalse
    }

    It 'filters Search-Package results by catalog trust and current platform eligibility' {
        $rootPath = Join-Path $TestDrive 'search-trust-platform'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot') -CatalogTrustPolicy allowUnsigned -CatalogTrustAllowUnsignedPublisherIds @('Eigenverft')
        $allowedDefinition = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'AllowedTool' -Releases @(
                New-TestPackageRelease -Id 'allowed-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
            ))
        $allowedDefinition.display.default.name = 'Allowed Tool'
        $allowedDefinition.display.default.summary = 'Allowed endpoint fixture'

        $blockedDefinition = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'InternalTool' -PublisherId 'OtherTeam' -PublisherName 'Other Team' -Releases @(
                New-TestPackageRelease -Id 'internal-win-x64-stable' -Version '9.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64'
            ))
        $blockedDefinition.display.default.name = 'Internal Tool'
        $blockedDefinition.display.default.summary = 'Internal team fixture'

        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $allowedDefinition
        $definitionRoot = Split-Path -Parent (Split-Path -Parent $documents.DefinitionPath)
        Write-TestJsonDocument -Path (Join-Path (Join-Path $definitionRoot 'OtherTeam') 'InternalTool.json') -Document $blockedDefinition

        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageEndpointInventoryPath { $documents.EndpointInventoryPath }

        @(Search-Package -Query 'internal' -Platform windows -Architecture x64 -ReleaseTrack stable).Count | Should -Be 0

        $ineligible = @(Search-Package -Query 'internal' -IncludeIneligible -Platform windows -Architecture x64 -ReleaseTrack stable)
        $ineligible.Count | Should -Be 1
        $ineligible[0].DefinitionId | Should -Be 'InternalTool'
        $ineligible[0].CatalogTrustEligible | Should -BeFalse
        $ineligible[0].CatalogTrustReason | Should -Match 'not listed in catalogTrust.allowUnsignedPublisherIds'

        @(Search-Package -Query 'allowed' -Platform linux -Architecture x64 -ReleaseTrack stable -CurrentPlatformOnly).Count | Should -Be 0
        $incompatible = @(Search-Package -Query 'allowed' -Platform linux -Architecture x64 -ReleaseTrack stable)
        $incompatible.Count | Should -Be 1
        $incompatible[0].PlatformAvailable | Should -BeFalse
        $incompatible[0].SelectionError | Should -Not -BeNullOrEmpty
    }

    It 'ships Eigenverft defaults as trusted signed definitions with embedded public certificates' {
        $definitionRoot = Join-Path (Get-PackageShippedEndpointRoot) 'Defaults\Eigenverft'
        $catalog = Verify-PackageDefinitionCatalog -Path $definitionRoot -RequireTrusted
        $trustRows = @(Get-PackageTrust -PublisherId 'Eigenverft')
        $definitionFiles = @(Get-ChildItem -LiteralPath $definitionRoot -Filter '*.json' -File)
        $signedDocuments = @(
            foreach ($definitionFile in $definitionFiles) {
                (Read-PackageJsonDocument -Path $definitionFile.FullName).Document
            }
        )

        $catalog.CheckedCount | Should -Be $definitionFiles.Count
        $catalog.FailedCount | Should -Be 0
        $catalog.ValidCount | Should -Be $definitionFiles.Count
        $catalog.TrustedCount | Should -Be $definitionFiles.Count
        $trustRows.Count | Should -Be 1
        $trustRows[0].TrustSource | Should -Be 'moduleShipped'
        $trustRows[0].KeyThumbprint | Should -Not -Be 'DD1E9435FB3AE68ABF2DB99E5638502E00D2FD90'
        @($catalog.Results | Where-Object { $_.KeyThumbprint -ne $trustRows[0].KeyThumbprint }).Count | Should -Be 0
        @($signedDocuments | Where-Object { -not $_.definitionPublication.definitionSignature.PSObject.Properties['certificatePem'] }).Count | Should -Be 0
        @($signedDocuments | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.definitionPublication.definitionSignature.certificatePem) }).Count | Should -Be 0
    }

    It 'ships Eigenverft dependency planner examples for ranges, model runtime dependencies, and command conflicts' {
        $codexPlan = New-PackageDependencyPlan -DefinitionId 'CodexCli'
        $codexNode = @($codexPlan.Nodes | Where-Object DefinitionId -EQ 'CodexCli')[0]
        $codexEdges = @(Get-PackageDependencyPlanChildEdges -Plan $codexPlan -NodeKey $codexNode.NodeKey)
        $nodeEdge = @($codexEdges | Where-Object DefinitionId -EQ 'NodeRuntime')[0]
        $nodeRuntime = @($codexPlan.Nodes | Where-Object DefinitionId -EQ 'NodeRuntime')[0]

        $codexPlan.Accepted | Should -BeTrue
        @($codexEdges.DefinitionId) | Should -Be @('VisualCppRedistributable', 'NodeRuntime')
        @($codexEdges.VersionRange) | Should -Be @('>=14.0 <15.0', '>=16.0.0')
        $nodeEdge.VersionRange | Should -Be '>=16.0.0'
        $nodeRuntime.PackageVersion | Should -Be '26.5.0'

        $qwenPlan = New-PackageDependencyPlan -DefinitionId 'Qwen35_9B_Q6_K_Model'
        $qwenNode = @($qwenPlan.Nodes | Where-Object DefinitionId -EQ 'Qwen35_9B_Q6_K_Model')[0]
        $llamaEdge = @(Get-PackageDependencyPlanChildEdges -Plan $qwenPlan -NodeKey $qwenNode.NodeKey | Where-Object DefinitionId -EQ 'LlamaCppRuntime')[0]

        $qwenPlan.Accepted | Should -BeTrue
        $llamaEdge.VersionRange | Should -Be '>=9094'
        @($qwenPlan.Nodes.DefinitionId) | Should -Contain 'LlamaCppRuntime'

        $miniCpmPlan = New-PackageDependencyPlan -DefinitionId 'MiniCPM5_1B_Q8_Model'
        $miniCpmNode = @($miniCpmPlan.Nodes | Where-Object DefinitionId -EQ 'MiniCPM5_1B_Q8_Model')[0]
        $miniCpmLlamaEdge = @(Get-PackageDependencyPlanChildEdges -Plan $miniCpmPlan -NodeKey $miniCpmNode.NodeKey | Where-Object DefinitionId -EQ 'LlamaCppRuntime')[0]

        $miniCpmPlan.Accepted | Should -BeTrue
        $miniCpmLlamaEdge.VersionRange | Should -Be '>=9094'
        @($miniCpmPlan.Nodes.DefinitionId) | Should -Contain 'LlamaCppRuntime'

        $vsCodeConflictPlan = New-PackageDependencyPlan -DefinitionId VSCodeRuntime, VSCodeUser

        $vsCodeConflictPlan.Accepted | Should -BeFalse
        @($vsCodeConflictPlan.Violations.Reason) | Should -Contain 'DependencyConflict'
    }

    It 'ships no package-definition filesystem acquisition candidates' {
        $definitionRoot = Join-Path (Get-PackageShippedEndpointRoot) 'Defaults\Eigenverft'
        $filesystemCandidatePaths = New-Object System.Collections.Generic.List[string]
        foreach ($definitionFile in @(Get-ChildItem -LiteralPath $definitionRoot -Filter '*.json' -File)) {
            $document = Get-Content -LiteralPath $definitionFile.FullName -Raw | ConvertFrom-Json
            foreach ($target in @($document.artifacts.targets)) {
                foreach ($candidate in @($target.acquisitionCandidates)) {
                    if ([string]::Equals([string]$candidate.kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
                        $filesystemCandidatePaths.Add("$($definitionFile.Name):target:$($target.id)") | Out-Null
                    }
                }
            }
            foreach ($release in @($document.artifacts.releases)) {
                foreach ($artifactProperty in @($release.targetArtifacts.PSObject.Properties)) {
                    foreach ($candidate in @($artifactProperty.Value.acquisitionCandidates)) {
                        if ([string]::Equals([string]$candidate.kind, 'filesystem', [System.StringComparison]::OrdinalIgnoreCase)) {
                            $filesystemCandidatePaths.Add("$($definitionFile.Name):release:$($release.version):$($artifactProperty.Name)") | Out-Null
                        }
                    }
                }
            }
        }

        @($filesystemCandidatePaths.ToArray()) | Should -Be @()
    }

    It 'fails clearly when a publisher id selector does not match a discovered definition' {
        { Resolve-PackageDefinitionReference -PublisherId 'OtherPublisher' -DefinitionId 'VSCodeRuntime' } | Should -Throw "*publisher 'OtherPublisher'*"
    }

    It 'applies definition publisher conflict policy across eligible publishers' {
        $rootPath = Join-Path $TestDrive 'publisher-conflict-policy'
        $endpointA = Join-Path $rootPath 'EndpointA'
        $endpointB = Join-Path $rootPath 'EndpointB'
        $localEndpointRoot = Join-Path $rootPath 'PkgEndpoint'

        Write-TestJsonDocument -Path (Join-Path (Join-Path $endpointA 'Alpha') 'SharedTool.json') -Document (New-TestVSCodeDefinitionDocument -DefinitionId 'SharedTool' -PublisherId 'Alpha' -PublisherName 'Alpha' -Releases @(
                New-TestPackageRelease -Id 'shared-alpha' -Version '1.0.0' -Architecture 'x64'
            ))
        Write-TestJsonDocument -Path (Join-Path (Join-Path $endpointB 'Beta') 'SharedTool.json') -Document (New-TestVSCodeDefinitionDocument -DefinitionId 'SharedTool' -PublisherId 'Beta' -PublisherName 'Beta' -Releases @(
                New-TestPackageRelease -Id 'shared-beta' -Version '1.0.0' -Architecture 'x64'
            ))

        $endpointInventoryPath = Join-Path $rootPath 'PackageEndpointInventory.json'
        Write-TestJsonDocument -Path $endpointInventoryPath -Document @{
            inventoryVersion = 2
            endpoints = @(
                @{ endpointName = 'alphaEndpoint'; kind = 'filesystem'; enabled = $true; searchOrder = 100; basePath = $endpointA },
                @{ endpointName = 'betaEndpoint'; kind = 'filesystem'; enabled = $true; searchOrder = 200; basePath = $endpointB }
            )
        }

        Mock Get-PackageEndpointInventoryPath { $endpointInventoryPath }

        { Resolve-PackageDefinitionReference -DefinitionId 'SharedTool' -LocalEndpointRoot $localEndpointRoot -CatalogTrustPolicy allowUnsigned -CatalogTrustAllowUnsignedPublisherIds @('Alpha', 'Beta') -DefinitionPublisherConflictMode 'fail' } | Should -Throw '*multiple eligible publisherIds*Use -PublisherId*'

        $first = Resolve-PackageDefinitionReference -DefinitionId 'SharedTool' -LocalEndpointRoot $localEndpointRoot -CatalogTrustPolicy allowUnsigned -CatalogTrustAllowUnsignedPublisherIds @('Alpha', 'Beta') -DefinitionPublisherConflictMode 'warnFirst'
        $last = Resolve-PackageDefinitionReference -DefinitionId 'SharedTool' -LocalEndpointRoot $localEndpointRoot -CatalogTrustPolicy allowUnsigned -CatalogTrustAllowUnsignedPublisherIds @('Alpha', 'Beta') -DefinitionPublisherConflictMode 'last'

        $first.PublisherId | Should -Be 'Alpha'
        $last.PublisherId | Should -Be 'Beta'
    }

    It 'fails when one publisher reuses a definition revision with different bytes across endpoints' {
        $rootPath = Join-Path $TestDrive 'publisher-reused-revision'
        $endpointA = Join-Path $rootPath 'EndpointA'
        $endpointB = Join-Path $rootPath 'EndpointB'
        $localEndpointRoot = Join-Path $rootPath 'PkgEndpoint'

        Write-TestJsonDocument -Path (Join-Path (Join-Path $endpointA 'Alpha') 'SharedTool.json') -Document (New-TestVSCodeDefinitionDocument -DefinitionId 'SharedTool' -PublisherId 'Alpha' -PublisherName 'Alpha' -DefinitionRevision 7 -Releases @(
                New-TestPackageRelease -Id 'shared-alpha' -Version '1.0.0' -Architecture 'x64'
            ))
        Write-TestJsonDocument -Path (Join-Path (Join-Path $endpointB 'Alpha') 'SharedTool.json') -Document (New-TestVSCodeDefinitionDocument -DefinitionId 'SharedTool' -PublisherId 'Alpha' -PublisherName 'Alpha' -DefinitionRevision 7 -Releases @(
                New-TestPackageRelease -Id 'shared-alpha' -Version '1.0.1' -Architecture 'x64'
            ))

        $endpointInventoryPath = Join-Path $rootPath 'PackageEndpointInventory.json'
        Write-TestJsonDocument -Path $endpointInventoryPath -Document @{
            inventoryVersion = 2
            endpoints = @(
                @{ endpointName = 'alphaPrimary'; kind = 'filesystem'; enabled = $true; searchOrder = 100; basePath = $endpointA },
                @{ endpointName = 'alphaMirror'; kind = 'filesystem'; enabled = $true; searchOrder = 200; basePath = $endpointB }
            )
        }

        Mock Get-PackageEndpointInventoryPath { $endpointInventoryPath }

        { Resolve-PackageDefinitionReference -DefinitionId 'SharedTool' -LocalEndpointRoot $localEndpointRoot -CatalogTrustPolicy allowUnsigned -CatalogTrustAllowUnsignedPublisherIds @('Alpha') } | Should -Throw '*reused definitionRevision*different content across endpoints*'
    }

    It 'completes removed desired state when inventory is missing and whenNotInInventory is succeed' {
        $rootPath = Join-Path $TestDrive 'removed-no-inventory-succeed'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument

        $inventoryPath = Join-Path (Join-Path $rootPath 'AppRoot') 'State\PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $inventoryPath) -Force
        Write-TestJsonDocument -Path $inventoryPath -Document @{ schemaVersion = 1; records = @() }
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $result = Invoke-Package -DefinitionId 'VSCodeRuntime' -DesiredState Removed

        $result.Status | Should -Be 'Ready'
        $result.Removed.Accepted | Should -Be $true
    }

    It 'fails removed desired state when inventory is missing and whenNotInInventory is fail' {
        $rootPath = Join-Path $TestDrive 'removed-no-inventory-fail'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $definitionDocument.packageOperations.removed.policy.whenNotInInventory = 'fail'
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument

        $inventoryPath = Join-Path (Join-Path $rootPath 'AppRoot') 'State\PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $inventoryPath) -Force
        Write-TestJsonDocument -Path $inventoryPath -Document @{ schemaVersion = 1; records = @() }
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $result = Invoke-Package -DefinitionId 'VSCodeRuntime' -DesiredState Removed

        $result.Status | Should -Be 'Failed'
        $result.FailureReason | Should -Be 'RemovalInventoryResolutionFailed'
    }

    It 'fails removed flow when removeDependencies policy is true' {
        $rootPath = Join-Path $TestDrive 'removed-deps-not-implemented'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $definitionDocument.packageOperations.removed.policy.removeDependencies = $true
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument

        $inventoryPath = Join-Path (Join-Path $rootPath 'AppRoot') 'State\PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $inventoryPath) -Force
        Write-TestJsonDocument -Path $inventoryPath -Document @{ schemaVersion = 1; records = @() }
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $result = Invoke-Package -DefinitionId 'VSCodeRuntime' -DesiredState Removed

        $result.Status | Should -Be 'Failed'
        $result.FailureReason | Should -Be 'RemovalPolicyRejected'
        $result.ErrorMessage | Should -Match 'removeDependencies'
    }

    It 'forgets machine prerequisite inventory without installDirectory when removal is no-op and absence-free' {
        $rootPath = Join-Path $TestDrive 'removed-machine-prerequisite-forget-only'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definitionDocument = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'MachinePrereqRuntime' -Releases @(
                New-TestPackageRelease -Id 'machine-prereq-win-x64-stable' -Version '1.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'machine-prereq.exe' -AcquisitionCandidates @(
                    @{
                        kind        = 'packageDepot'
                        searchOrder = 10
                    }
                )
            ))
        $definitionDocument.packageOperations.assigned.install = [pscustomobject]@{
            kind             = 'runInstaller'
            targetKind       = 'machinePrerequisite'
            installerKind    = 'customExe'
            uiMode           = 'quiet'
            elevation        = 'required'
            timeoutSec       = 300
            commandArguments = @('/quiet')
            successExitCodes = @(0)
            restartExitCodes = @()
        }
        $definitionDocument.packageOperations.assigned.pathRegistration = [pscustomobject]@{
            mode = 'none'
        }
        foreach ($flag in @('files', 'directories', 'commands', 'apps', 'metadataFiles', 'signatures', 'fileDetails', 'registry', 'powerShellModules')) {
            $definitionDocument.packageOperations.assigned.readyStateCheck.require.$flag = $false
            $definitionDocument.packageOperations.removed.absenceVerification.require.$flag = $false
        }
        $definitionDocument.packageOperations.removed.policy.allowedInventoryOwnershipKinds = @('PackageApplied')
        $definitionDocument.packageOperations.removed.operation = [pscustomobject]@{
            kind = 'none'
        }
        $definitionDocument.packageOperations.removed.postRemoveCleanup.generatedShims = $false
        $definitionDocument.packageOperations.removed.postRemoveCleanup.pathEntries = $false

        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument
        $appRoot = Join-Path $rootPath 'AppRoot'
        $inventoryPath = Join-Path $appRoot 'State\PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $inventoryPath) -Force
        $assignedSnapshotPath = Join-Path $appRoot 'PkgEndpoint\Assigned\Eigenverft\MachinePrereqRuntime.json'
        Write-TestJsonDocument -Path $assignedSnapshotPath -Document $definitionDocument
        $record = @{
            installSlotId       = 'MachinePrereqRuntime:stable:win32-x64'
            definitionId        = 'MachinePrereqRuntime'
            definitionPublisherId = 'Eigenverft'
            definitionPublisherName = 'Eigenverft'
            definitionRevision = 1
            definitionPublishedAtUtc = '2026-05-13T00:00:00Z'
            definitionEndpointName = 'moduleDefaults'
            definitionSourceKind = 'filesystem'
            definitionSourcePath = $documents.DefinitionPath
            definitionSourceHash = (Get-PackageFileSha256 -Path $documents.DefinitionPath)
            definitionAssignedSnapshotPath = $assignedSnapshotPath
            definitionAssignedSnapshotHash = (Get-PackageFileSha256 -Path $assignedSnapshotPath)
            releaseTrack        = 'stable'
            artifactDistributionVariant = 'win32-x64'
            currentReleaseId    = 'machine-prereq-win-x64-stable'
            currentVersion      = '1.0.0'
            installDirectory    = $null
            ownershipKind       = 'PackageApplied'
            pathRegistration    = $null
            updatedAtUtc        = [DateTime]::UtcNow.ToString('o')
        }
        Write-TestJsonDocument -Path $inventoryPath -Document @{ schemaVersion = 1; records = @($record) }
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $result = Invoke-Package -DefinitionId 'MachinePrereqRuntime' -DesiredState Removed

        $result.Status | Should -Be 'Ready'
        $result.InstallDirectory | Should -BeNullOrEmpty
        $result.Removed.Accepted | Should -Be $true
        $invAfter = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
        @($invAfter.records).Count | Should -Be 0
    }

    It 'removes install directory and inventory when removed flow runs with matching inventory record' {
        $rootPath = Join-Path $TestDrive 'removed-delete-success'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument

        $appRoot = Join-Path $rootPath 'AppRoot'
        $preferredRoot = Join-Path $appRoot 'Inst'
        $installDir = Join-Path $preferredRoot 'vsc-rt\stable\2.0.0\win32-x64'
        $null = New-Item -ItemType Directory -Path (Join-Path $installDir 'bin') -Force
        Write-TestTextFile -Path (Join-Path $installDir 'Code.exe') -Content 'x'
        Write-TestTextFile -Path (Join-Path $installDir 'bin\code.cmd') -Content '@echo off'

        $inventoryPath = Join-Path $appRoot 'State\PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $inventoryPath) -Force
        $assignedSnapshotPath = Join-Path $appRoot 'PkgEndpoint\Assigned\Eigenverft\VSCodeRuntime.json'
        Write-TestJsonDocument -Path $assignedSnapshotPath -Document $definitionDocument
        $record = @{
            installSlotId       = 'VSCodeRuntime:stable:win32-x64'
            definitionId        = 'VSCodeRuntime'
            definitionPublisherId = 'Eigenverft'
            definitionPublisherName = 'Eigenverft'
            definitionRevision = 1
            definitionPublishedAtUtc = '2026-05-13T00:00:00Z'
            definitionEndpointName = 'moduleDefaults'
            definitionSourceKind = 'filesystem'
            definitionSourcePath = $documents.DefinitionPath
            definitionSourceHash = (Get-PackageFileSha256 -Path $documents.DefinitionPath)
            definitionAssignedSnapshotPath = $assignedSnapshotPath
            definitionAssignedSnapshotHash = (Get-PackageFileSha256 -Path $assignedSnapshotPath)
            releaseTrack        = 'stable'
            artifactDistributionVariant = 'win32-x64'
            currentReleaseId    = 'vsCode-win-x64-stable'
            currentVersion      = '2.0.0'
            installDirectory    = $installDir
            ownershipKind       = 'PackageInstalled'
            pathRegistration    = $null
            updatedAtUtc        = [DateTime]::UtcNow.ToString('o')
        }
        Write-TestJsonDocument -Path $inventoryPath -Document @{ schemaVersion = 1; records = @($record) }
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $result = Invoke-Package -DefinitionId 'VSCodeRuntime' -DesiredState Removed

        $result.Status | Should -Be 'Ready'
        $result.Removed.Accepted | Should -Be $true
        Test-Path -LiteralPath $installDir | Should -Be $false
        Test-Path -LiteralPath (Join-Path $preferredRoot 'vsc-rt') | Should -Be $false

        $invAfter = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
        @($invAfter.records).Count | Should -Be 0
    }

    It 'keeps inventory when removed absence verification fails before cleanup' {
        $rootPath = Join-Path $TestDrive 'removed-absence-failure-keeps-inventory'
        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $definitionDocument.packageOperations.removed.operation = @{
            kind = 'none'
        }
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument

        $appRoot = Join-Path $rootPath 'AppRoot'
        $installDir = Join-Path $appRoot 'Inst\vsc-rt\stable\2.0.0\win32-x64'
        Write-TestTextFile -Path (Join-Path $installDir 'Code.exe') -Content 'x'
        Write-TestTextFile -Path (Join-Path $installDir 'bin\code.cmd') -Content "@echo off`r`necho 2.0.0`r`n"
        $null = New-Item -ItemType Directory -Path (Join-Path $installDir 'data') -Force

        $inventoryPath = Join-Path $appRoot 'State\PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $inventoryPath) -Force
        $assignedSnapshotPath = Join-Path $appRoot 'PkgEndpoint\Assigned\Eigenverft\VSCodeRuntime.json'
        Write-TestJsonDocument -Path $assignedSnapshotPath -Document $definitionDocument
        $record = @{
            installSlotId       = 'VSCodeRuntime:stable:win32-x64'
            definitionId        = 'VSCodeRuntime'
            definitionPublisherId = 'Eigenverft'
            definitionPublisherName = 'Eigenverft'
            definitionRevision = 1
            definitionPublishedAtUtc = '2026-05-13T00:00:00Z'
            definitionEndpointName = 'moduleDefaults'
            definitionSourceKind = 'filesystem'
            definitionSourcePath = $documents.DefinitionPath
            definitionSourceHash = (Get-PackageFileSha256 -Path $documents.DefinitionPath)
            definitionAssignedSnapshotPath = $assignedSnapshotPath
            definitionAssignedSnapshotHash = (Get-PackageFileSha256 -Path $assignedSnapshotPath)
            releaseTrack        = 'stable'
            artifactDistributionVariant = 'win32-x64'
            currentReleaseId    = 'vsCode-win-x64-stable'
            currentVersion      = '2.0.0'
            installDirectory    = $installDir
            ownershipKind       = 'PackageInstalled'
            pathRegistration    = $null
            updatedAtUtc        = [DateTime]::UtcNow.ToString('o')
        }
        Write-TestJsonDocument -Path $inventoryPath -Document @{ schemaVersion = 1; records = @($record) }
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }
        Mock Get-PackageDefinitionPath { param($DefinitionId) $documents.DefinitionPath }

        $result = Invoke-Package -DefinitionId 'VSCodeRuntime' -DesiredState Removed

        $result.Status | Should -Be 'Failed'
        $result.ErrorMessage | Should -Match 'absence verification failed'
        $invAfter = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
        @($invAfter.records).Count | Should -Be 1
    }

    It 'blocks removed when another inventory record definition still depends on the target' {
        $rootPath = Join-Path $TestDrive 'removed-blocked-by-dependents'
        $defDir = Join-Path $rootPath 'RepoDefs'
        $null = New-Item -ItemType Directory -Path $defDir -Force
        $moduleProjectRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'Eigenverft.Manifested.Package'
        $shippedDefs = Join-Path $moduleProjectRoot 'Endpoint\Defaults\Eigenverft'
        Copy-Item -LiteralPath (Join-Path $shippedDefs 'CodexCli.json') -Destination (Join-Path $defDir 'CodexCli.json') -Force
        Copy-Item -LiteralPath (Join-Path $shippedDefs 'NodeRuntime.json') -Destination (Join-Path $defDir 'NodeRuntime.json') -Force

        $globalDocument = New-TestPackageGlobalDocument -ApplicationRootDirectory (Join-Path $rootPath 'AppRoot')
        $definitionDocument = New-TestVSCodeDefinitionDocument -Releases @(
            New-TestPackageRelease -Id 'vsCode-win-x64-stable' -Version '2.0.0' -Architecture 'x64' -ArtifactDistributionVariant 'win32-x64' -FileName 'VSCode-win32-x64-2.0.0.zip' -AcquisitionCandidates @(
                @{
                    kind        = 'packageDepot'
                    searchOrder = 10
                }
            )
        )
        $documents = Write-TestPackageDocuments -RootPath $rootPath -GlobalDocument $globalDocument -DefinitionDocument $definitionDocument

        Mock Get-PackageDefinitionPath { param($DefinitionId) Join-Path $defDir ("$DefinitionId.json") }

        $appRoot = Join-Path $rootPath 'AppRoot'
        $codexDir = Join-Path $appRoot 'Inst\codex-cli'
        $nodeDir = Join-Path $appRoot 'Inst\node'
        $null = New-Item -ItemType Directory -Path $codexDir -Force
        $null = New-Item -ItemType Directory -Path $nodeDir -Force

        $now = [DateTime]::UtcNow.ToString('o')
        $records = @(
            @{
                installSlotId                = 'CodexCli:stable:win32-x64'
                definitionId                 = 'CodexCli'
                definitionPublisherId        = 'Eigenverft'
                definitionPublisherName      = 'Eigenverft'
                definitionRevision           = 1
                definitionPublishedAtUtc     = '2026-05-13T12:00:00Z'
                definitionEndpointName        = 'moduleDefaults'
                definitionSourcePath         = (Join-Path $defDir 'CodexCli.json')
                definitionAssignedSnapshotPath = (Join-Path $defDir 'CodexCli.json')
                definitionAssignedSnapshotHash = (Get-PackageFileSha256 -Path (Join-Path $defDir 'CodexCli.json'))
                releaseTrack                 = 'stable'
                artifactDistributionVariant  = 'win32-x64'
                currentReleaseId             = 'CodexCli-win32-x64-stable'
                currentVersion               = '0.130.0'
                installDirectory             = $codexDir
                ownershipKind                = 'PackageInstalled'
                pathRegistration             = $null
                updatedAtUtc                 = $now
            }
            @{
                installSlotId                = 'NodeRuntime:stable:win-x64'
                definitionId                 = 'NodeRuntime'
                definitionPublisherId        = 'Eigenverft'
                definitionPublisherName      = 'Eigenverft'
                definitionRevision           = 1
                definitionPublishedAtUtc     = '2026-05-13T12:00:00Z'
                definitionEndpointName        = 'moduleDefaults'
                definitionSourcePath         = (Join-Path $defDir 'NodeRuntime.json')
                definitionAssignedSnapshotPath = (Join-Path $defDir 'NodeRuntime.json')
                definitionAssignedSnapshotHash = (Get-PackageFileSha256 -Path (Join-Path $defDir 'NodeRuntime.json'))
                releaseTrack                 = 'stable'
                artifactDistributionVariant  = 'win-x64'
                currentReleaseId             = 'NodeRuntime-win-x64-stable'
                currentVersion               = '22.0.0'
                installDirectory             = $nodeDir
                ownershipKind                = 'PackageInstalled'
                pathRegistration             = $null
                updatedAtUtc                 = $now
            }
        )
        $inventoryPath = Join-Path $appRoot 'State\PackageAssignmentInventory.json'
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $inventoryPath) -Force
        Write-TestJsonDocument -Path $inventoryPath -Document @{ schemaVersion = 1; records = $records }
        Mock Get-PackageConfigPath { $documents.GlobalConfigPath }
        Mock Get-PackageDepotInventoryPath { $documents.DepotInventoryPath }

        $result = Invoke-Package -DefinitionId 'NodeRuntime' -DesiredState Removed

        $result.Status | Should -Be 'Failed'
        $result.FailureReason | Should -Be 'RemovalDependencyDependentsBlocked'
        $result.ErrorMessage | Should -Match 'CodexCli'
    }

}
