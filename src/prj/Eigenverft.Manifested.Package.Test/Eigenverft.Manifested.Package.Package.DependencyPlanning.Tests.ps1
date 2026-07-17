<#
    Eigenverft.Manifested.Package Package - dependency planning
#>

. "$PSScriptRoot\\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - dependency planning' -Body {

    It 'ensures direct package dependencies before package-specific install flow continues' {
        $definition = [pscustomobject]@{
            definitionId = 'CodexCli'
            dependency = [pscustomobject]@{
                requires = @(
                    [pscustomobject]@{ definitionId = 'VisualCppRedistributable' }
                    [pscustomobject]@{ definitionId = 'NodeRuntime' }
                )
            }
        }
        $result = [pscustomobject]@{
            DefinitionId                = 'CodexCli'
            DefinitionPublisherId       = 'Eigenverft'
            PackageConfig = [pscustomobject]@{
                Definition = $definition
            }
            Dependencies  = @()
        }

        Mock Invoke-PackageDefinitionCommandCore {
            [pscustomobject]@{
                DefinitionPublisherId = 'Eigenverft'
                Status               = 'Ready'
                InstallOrigin        = 'PackageReused'
                Install                = [pscustomobject]@{ Status = 'ReusedPackageOwned' }
                EntryPoints            = [pscustomobject]@{
                    Commands = @(
                        [pscustomobject]@{
                            Name = if ($DefinitionId -eq 'NodeRuntime') { 'npm' } else { 'vc-runtime' }
                            Path = Join-Path $TestDrive "$DefinitionId.cmd"
                        }
                    )
                }
            }
        }

        $resolved = Resolve-PackageDependencies -PackageResult $result

        @($resolved.Dependencies.DefinitionId) | Should -Be @('VisualCppRedistributable', 'NodeRuntime')
        @($resolved.Dependencies.PublisherId) | Should -Be @('Eigenverft', 'Eigenverft')
        @($resolved.Dependencies.Status) | Should -Be @('Ready', 'Ready')
        @($resolved.Dependencies[1].Commands.Name) | Should -Be @('npm')
    }

    It 'materializes direct package dependencies recursively in materialize-only mode' {
        $definition = [pscustomobject]@{
            definitionId = 'CodexCli'
            dependency = [pscustomobject]@{
                requires = @(
                    [pscustomobject]@{ definitionId = 'NodeRuntime' }
                )
            }
        }
        $result = [pscustomobject]@{
            DefinitionId          = 'CodexCli'
            DefinitionPublisherId = 'Eigenverft'
            Offline               = $true
            MaterializeOnly       = $true
            PackageConfig         = [pscustomobject]@{
                Definition = $definition
            }
            Dependencies          = @()
        }

        Mock Invoke-PackageDefinitionCommandCore {
            [pscustomobject]@{
                DefinitionPublisherId = 'Eigenverft'
                DefinitionId          = $DefinitionId
                CommandMode           = if ($MaterializeOnly) { 'MaterializeOnly' } else { $DesiredState }
                Offline               = [bool]$Offline
                Status                = 'Materialized'
            }
        }

        $resolved = Resolve-PackageDependencies -PackageResult $result

        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 1 -ParameterFilter {
            $DefinitionId -eq 'NodeRuntime' -and
            [bool]$MaterializeOnly -and
            [bool]$Offline
        }
        @($resolved.Dependencies.DefinitionId) | Should -Be @('NodeRuntime')
        @($resolved.Dependencies.Status) | Should -Be @('Materialized')
        @($resolved.Dependencies.CommandMode) | Should -Be @('MaterializeOnly')
    }

    It 'fails clearly when materialize-only command-backed work requires a missing command' {
        $result = [pscustomobject]@{
            PackageId       = 'OpenCodeCli'
            MaterializeOnly = $true
            Dependencies    = @()
        }

        { Resolve-PackageDependencyCommandPath -PackageResult $result -CommandName 'evf-missing-materializer-command' } | Should -Throw '*already be ready*MaterializeOnly*'
    }

    It 'fails clearly when direct package dependencies contain a cycle' {
        $definition = [pscustomobject]@{
            definitionId = 'CodexCli'
            dependency = [pscustomobject]@{
                requires = @(
                    [pscustomobject]@{ definitionId = 'NodeRuntime' }
                )
            }
        }
        $result = [pscustomobject]@{
            DefinitionId       = 'CodexCli'
            DefinitionPublisherId = 'Eigenverft'
            PackageConfig = [pscustomobject]@{
                Definition = $definition
            }
            Dependencies       = @()
        }

        { Resolve-PackageDependencies -PackageResult $result -DependencyStack @('Eigenverft:CodexCli', 'Eigenverft:NodeRuntime') } | Should -Throw '*dependency cycle*'
    }

    It 'builds a single-root dependency plan and preserves dependency objects' {
        $configs = @{
            CodexCli    = New-TestDependencyPlannerConfig -DefinitionId 'CodexCli' -Dependencies @([pscustomobject]@{ definitionId = 'NodeRuntime' }) -InventoryPath (Join-Path $TestDrive 'planner-legacy-inventory.json')
            NodeRuntime = New-TestDependencyPlannerConfig -DefinitionId 'NodeRuntime' -Versions @('1.0.0') -InventoryPath (Join-Path $TestDrive 'planner-legacy-inventory.json')
        }
        Mock Get-PackageConfig { $configs[$DefinitionId] }

        $plan = New-PackageDependencyPlan -DefinitionId 'CodexCli'

        $plan.Accepted | Should -BeTrue
        @($plan.Nodes.DefinitionId) | Should -Be @('CodexCli', 'NodeRuntime')
        @($plan.Edges.DefinitionId) | Should -Be @('NodeRuntime')
        $plan.Violations.Count | Should -Be 0
    }

    It 'dedupes shared dependencies and selects the newest version satisfying all incoming ranges' {
        $configs = @{
            RootA      = New-TestDependencyPlannerConfig -DefinitionId 'RootA' -Dependencies @([pscustomobject]@{ definitionId = 'SharedRuntime'; versionRange = '>=1.0.0 <3.0.0' }) -InventoryPath (Join-Path $TestDrive 'planner-dedupe-inventory.json')
            RootB      = New-TestDependencyPlannerConfig -DefinitionId 'RootB' -Dependencies @([pscustomobject]@{ definitionId = 'SharedRuntime'; versionRange = '<2.0.0' }) -InventoryPath (Join-Path $TestDrive 'planner-dedupe-inventory.json')
            SharedRuntime = New-TestDependencyPlannerConfig -DefinitionId 'SharedRuntime' -Versions @('1.0.0', '1.5.0', '2.5.0') -InventoryPath (Join-Path $TestDrive 'planner-dedupe-inventory.json')
        }
        Mock Get-PackageConfig { $configs[$DefinitionId] }

        $plan = New-PackageDependencyPlan -DefinitionId RootA, RootB
        $shared = @($plan.Nodes | Where-Object DefinitionId -EQ 'SharedRuntime')

        $plan.Accepted | Should -BeTrue
        @($shared).Count | Should -Be 1
        $shared[0].PackageVersion | Should -Be '1.5.0'
        @($plan.Edges | Where-Object DefinitionId -EQ 'SharedRuntime').Count | Should -Be 2
    }

    It 'fails dependency planning for cycles, invalid ranges, and unsatisfied ranges' {
        $cycleConfigs = @{
            RootA = New-TestDependencyPlannerConfig -DefinitionId 'RootA' -Dependencies @([pscustomobject]@{ definitionId = 'RootB' }) -InventoryPath (Join-Path $TestDrive 'planner-cycle-inventory.json')
            RootB = New-TestDependencyPlannerConfig -DefinitionId 'RootB' -Dependencies @([pscustomobject]@{ definitionId = 'RootA' }) -InventoryPath (Join-Path $TestDrive 'planner-cycle-inventory.json')
        }
        Mock Get-PackageConfig { $cycleConfigs[$DefinitionId] }
        $cyclePlan = New-PackageDependencyPlan -DefinitionId 'RootA'
        @($cyclePlan.Violations.Reason) | Should -Contain 'DependencyCycle'

        $rangeConfigs = @{
            RootA = New-TestDependencyPlannerConfig -DefinitionId 'RootA' -Dependencies @([pscustomobject]@{ definitionId = 'Runtime'; versionRange = '^1.0.0' }) -InventoryPath (Join-Path $TestDrive 'planner-invalid-range-inventory.json')
            Runtime = New-TestDependencyPlannerConfig -DefinitionId 'Runtime' -Versions @('1.0.0') -InventoryPath (Join-Path $TestDrive 'planner-invalid-range-inventory.json')
        }
        Mock Get-PackageConfig { $rangeConfigs[$DefinitionId] }
        $invalidRangePlan = New-PackageDependencyPlan -DefinitionId 'RootA'
        @($invalidRangePlan.Violations.Reason) | Should -Contain 'DependencyVersionRangeInvalid'

        $unsatisfiedConfigs = @{
            RootA = New-TestDependencyPlannerConfig -DefinitionId 'RootA' -Dependencies @([pscustomobject]@{ definitionId = 'Runtime'; versionRange = '>=9.0.0' }) -InventoryPath (Join-Path $TestDrive 'planner-unsatisfied-range-inventory.json')
            Runtime = New-TestDependencyPlannerConfig -DefinitionId 'Runtime' -Versions @('1.0.0') -InventoryPath (Join-Path $TestDrive 'planner-unsatisfied-range-inventory.json')
        }
        Mock Get-PackageConfig { $unsatisfiedConfigs[$DefinitionId] }
        $unsatisfiedPlan = New-PackageDependencyPlan -DefinitionId 'RootA'
        @($unsatisfiedPlan.Violations.Reason) | Should -Contain 'DependencyVersionRangeUnsatisfied'
    }

    It 'enforces dependency peer policy conflicts and requiresAbsent checks' {
        $conflictPolicy = [pscustomobject]@{
            conflictsWith = @([pscustomobject]@{ definitionId = 'RootB' })
        }
        $conflictConfigs = @{
            RootA = New-TestDependencyPlannerConfig -DefinitionId 'RootA' -DependencyPolicy $conflictPolicy -InventoryPath (Join-Path $TestDrive 'planner-conflict-inventory.json')
            RootB = New-TestDependencyPlannerConfig -DefinitionId 'RootB' -InventoryPath (Join-Path $TestDrive 'planner-conflict-inventory.json')
        }
        Mock Get-PackageConfig { $conflictConfigs[$DefinitionId] }
        $conflictPlan = New-PackageDependencyPlan -DefinitionId RootA, RootB
        @($conflictPlan.Violations.Reason) | Should -Contain 'DependencyConflict'

        $requiresAbsentPolicy = [pscustomobject]@{
            requiresAbsent = @([pscustomobject]@{ definitionId = 'BlockedRuntime'; versionRange = '>=1.0.0' })
        }
        $inventoryPath = Join-Path $TestDrive 'planner-absent-inventory.json'
        Write-TestJsonDocument -Path $inventoryPath -Document @{
            records = @(
                @{
                    installSlotId = 'BlockedRuntime-stable-win32-x64'
                    definitionId = 'BlockedRuntime'
                    definitionPublisherId = 'Eigenverft'
                    currentVersion = '1.2.0'
                }
            )
        }
        $absentConfigs = @{
            RootA = New-TestDependencyPlannerConfig -DefinitionId 'RootA' -DependencyPolicy $requiresAbsentPolicy -InventoryPath $inventoryPath
            BlockedRuntime = New-TestDependencyPlannerConfig -DefinitionId 'BlockedRuntime' -Versions @('1.2.0') -InventoryPath $inventoryPath
        }
        Mock Get-PackageConfig { $absentConfigs[$DefinitionId] }
        $inventoryPlan = New-PackageDependencyPlan -DefinitionId 'RootA'
        @($inventoryPlan.Violations.Reason) | Should -Contain 'DependencyRequiresAbsent'

        $planConflict = New-PackageDependencyPlan -DefinitionId RootA, BlockedRuntime
        @($planConflict.Violations.Reason) | Should -Contain 'DependencyRequiresAbsent'
    }

    It 'passes approved dependency plan context through recursive dependency execution' {
        $configs = @{
            RootA = New-TestDependencyPlannerConfig -DefinitionId 'RootA' -Dependencies @(
                [pscustomobject]@{ definitionId = 'VisualRuntime'; versionRange = '>=1.0.0' }
                [pscustomobject]@{ definitionId = 'NodeRuntime'; versionRange = '>=2.0.0' }
            ) -InventoryPath (Join-Path $TestDrive 'planner-execution-inventory.json')
            VisualRuntime = New-TestDependencyPlannerConfig -DefinitionId 'VisualRuntime' -Versions @('1.2.0') -InventoryPath (Join-Path $TestDrive 'planner-execution-inventory.json')
            NodeRuntime = New-TestDependencyPlannerConfig -DefinitionId 'NodeRuntime' -Versions @('2.4.0') -InventoryPath (Join-Path $TestDrive 'planner-execution-inventory.json')
        }
        Mock Get-PackageConfig { $configs[$DefinitionId] }
        $plan = New-PackageDependencyPlan -DefinitionId 'RootA'
        $rootNodeKey = Get-PackageDependencyPlanRootNodeKey -Plan $plan -DefinitionId 'RootA'
        $childEdges = @(Get-PackageDependencyPlanChildEdges -Plan $plan -NodeKey $rootNodeKey)
        $executedDefinitions = New-Object System.Collections.Generic.List[string]

        Mock Invoke-PackageDefinitionCommandCore {
            $executedDefinitions.Add([string]$DefinitionId) | Out-Null
            [pscustomobject]@{
                DefinitionPublisherId = 'Eigenverft'
                DefinitionId          = $DefinitionId
                CommandMode           = if ($MaterializeOnly) { 'MaterializeOnly' } else { $DesiredState }
                Offline               = [bool]$Offline
                Status                = 'Ready'
                InstallOrigin         = 'PackageReused'
                Assigned              = [pscustomobject]@{ Status = 'ReusedPackageOwned' }
            }
        }
        $result = [pscustomobject]@{
            DefinitionId          = 'RootA'
            DefinitionPublisherId = 'Eigenverft'
            PackageConfig         = $configs.RootA
            DependencyPlan        = $plan
            DependencyPlanNodeKey = $rootNodeKey
            Dependencies          = @()
        }

        $resolvedOutput = @(Resolve-PackageDependencies -PackageResult $result)
        $resolved = $resolvedOutput[0]

        $resolvedOutput.Count | Should -Be 1
        $resolved.DefinitionId | Should -Be 'RootA'
        @($executedDefinitions) | Should -Be @('VisualRuntime', 'NodeRuntime')
        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 1 -ParameterFilter {
            $DefinitionId -eq 'VisualRuntime' -and
            $DependencyPlan -eq $plan -and
            $DependencyPlanNodeKey -eq $childEdges[0].ChildNodeKey
        }
        Assert-MockCalled Invoke-PackageDefinitionCommandCore -Times 1 -ParameterFilter {
            $DefinitionId -eq 'NodeRuntime' -and
            $DependencyPlan -eq $plan -and
            $DependencyPlanNodeKey -eq $childEdges[1].ChildNodeKey
        }
        @($resolved.Dependencies.DefinitionId) | Should -Be @('VisualRuntime', 'NodeRuntime')
        @($resolved.Dependencies.PlanNodeKey) | Should -Be @($childEdges.ChildNodeKey)
    }

    It 'executes the assigned install step for every approved dependency before the root package' {
        $configs = @{
            RootA = New-TestDependencyPlannerConfig -DefinitionId 'RootA' -Dependencies @(
                [pscustomobject]@{ definitionId = 'VisualRuntime'; versionRange = '>=1.0.0' }
                [pscustomobject]@{ definitionId = 'NodeRuntime'; versionRange = '>=2.0.0' }
            ) -InventoryPath (Join-Path $TestDrive 'planner-install-execution-inventory.json')
            VisualRuntime = New-TestDependencyPlannerConfig -DefinitionId 'VisualRuntime' -Versions @('1.2.0') -InventoryPath (Join-Path $TestDrive 'planner-install-execution-inventory.json')
            NodeRuntime = New-TestDependencyPlannerConfig -DefinitionId 'NodeRuntime' -Versions @('2.4.0') -InventoryPath (Join-Path $TestDrive 'planner-install-execution-inventory.json')
        }
        Mock Get-PackageConfig { $configs[$DefinitionId] }
        $plan = New-PackageDependencyPlan -DefinitionId 'RootA'
        $rootNodeKey = Get-PackageDependencyPlanRootNodeKey -Plan $plan -DefinitionId 'RootA'
        $installOrder = New-Object System.Collections.Generic.List[string]

        Mock Initialize-PackageCommandLocalEnvironment { [pscustomobject]@{ Status = 'Initialized' } }
        Mock Resolve-PackagePackage {
            $planNode = @($plan.Nodes | Where-Object DefinitionId -EQ $PackageResult.DefinitionId)[0]
            $PackageResult | Add-Member -MemberType NoteProperty -Name PackageId -Value ([string]$PackageResult.DefinitionId) -Force
            $PackageResult | Add-Member -MemberType NoteProperty -Name PackageVersion -Value ([string]$planNode.PackageVersion) -Force
            $PackageResult | Add-Member -MemberType NoteProperty -Name Package -Value ([pscustomobject]@{
                id = [string]$PackageResult.DefinitionId
                version = [string]$planNode.PackageVersion
            }) -Force
            $PackageResult
        }
        Mock Resolve-PackagePaths { $PackageResult }
        Mock Resolve-PackagePreAssignmentSatisfaction { $PackageResult }
        Mock Build-PackageAcquisitionPlan { $PackageResult }
        Mock Find-PackageExistingPackage { $PackageResult }
        Mock Set-PackageExistingPackage { $PackageResult }
        Mock Resolve-PackageExistingPackageDecision { $PackageResult }
        Mock Resolve-PackageArtifactFiles { $PackageResult }
        Mock Invoke-PackageDepotDistribution { $PackageResult }
        Mock Invoke-PackageNpmMaterialization { $PackageResult }
        Mock Set-PackageAssignedState {
            $installOrder.Add([string]$PackageResult.DefinitionId) | Out-Null
            $PackageResult | Add-Member -MemberType NoteProperty -Name Assigned -Value ([pscustomobject]@{ Status = 'Installed' }) -Force
            $PackageResult | Add-Member -MemberType NoteProperty -Name InstallOrigin -Value 'PackageInstalled' -Force
            $PackageResult
        }
        Mock Test-PackageAssignedReadiness {
            $PackageResult | Add-Member -MemberType NoteProperty -Name Readiness -Value ([pscustomobject]@{ Accepted = $true }) -Force
            $PackageResult
        }
        Mock Register-PackagePath { $PackageResult }
        Mock Remove-PackageReplacedPackageOwnedInstallDirectory { $PackageResult }
        Mock Resolve-PackageEntryPoints { $PackageResult }
        Mock Update-PackageInventoryRecord { $PackageResult }
        Mock Clear-PackageWorkDirectories { $PackageResult }
        Mock Get-PackageOutcomeSummary { '[OK] test package completed.' }
        Mock Add-PackageOperationHistoryRecord {}

        $result = Invoke-PackageDefinitionCommandCore -DefinitionId 'RootA' -DependencyPlan $plan -DependencyPlanNodeKey $rootNodeKey

        @($installOrder) | Should -Be @('VisualRuntime', 'NodeRuntime', 'RootA')
        $result.Status | Should -Be 'Ready'
        @($result.Dependencies.DefinitionId) | Should -Be @('VisualRuntime', 'NodeRuntime')
        @($result.Dependencies.InstallStatus) | Should -Be @('Installed', 'Installed')
        Assert-MockCalled Set-PackageAssignedState -Times 1 -ParameterFilter { $PackageResult.DefinitionId -eq 'VisualRuntime' }
        Assert-MockCalled Set-PackageAssignedState -Times 1 -ParameterFilter { $PackageResult.DefinitionId -eq 'NodeRuntime' }
        Assert-MockCalled Set-PackageAssignedState -Times 1 -ParameterFilter { $PackageResult.DefinitionId -eq 'RootA' }
    }

    It 'accepts dependency versionRange and dependency.policy schema additions' {
        $definitionDocument = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'RootA' -Releases @(
                New-TestPackageRelease -Id 'RootA-win-x64-1.0.0' -Version '1.0.0' -Architecture 'x64'
            ))
        $definitionDocument.dependency.requires = @(
            [pscustomobject]@{ publisherId = 'Eigenverft'; definitionId = 'Runtime'; versionRange = '>=1.0.0 <2.0.0' }
        )
        $definitionDocument.dependency | Add-Member -MemberType NoteProperty -Name policy -Value ([pscustomobject]@{
                conflictsWith = @([pscustomobject]@{ definitionId = 'OldRuntime'; versionRange = '<1.0.0' })
                requiresAbsent = @([pscustomobject]@{ publisherId = 'Eigenverft'; definitionId = 'BlockedRuntime' })
            }) -Force
        $definitionInfo = [pscustomobject]@{
            Path     = Join-Path $TestDrive 'RootA.json'
            Document = $definitionDocument
        }

        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo $definitionInfo -DefinitionId 'RootA' } | Should -Not -Throw
    }

    It 'rejects invalid dependency planner wire fields' {
        $emptyRange = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'RootA' -Releases @(
                New-TestPackageRelease -Id 'RootA-win-x64-1.0.0' -Version '1.0.0' -Architecture 'x64'
            ))
        $emptyRange.dependency.requires = @([pscustomobject]@{ definitionId = 'Runtime'; versionRange = '' })
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo ([pscustomobject]@{ Path = Join-Path $TestDrive 'RootA-empty-range.json'; Document = $emptyRange }) -DefinitionId 'RootA' } | Should -Throw '*versionRange*'

        $invalidPolicy = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'RootA' -Releases @(
                New-TestPackageRelease -Id 'RootA-win-x64-1.0.0' -Version '1.0.0' -Architecture 'x64'
            ))
        $invalidPolicy.dependency | Add-Member -MemberType NoteProperty -Name policy -Value ([pscustomobject]@{
                conflictsWith = @([pscustomobject]@{ publisherId = ''; definitionId = 'Runtime' })
                requiresAbsent = @([pscustomobject]@{ definitionId = 'BlockedRuntime'; versionRange = '^1.0.0' })
            }) -Force
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo ([pscustomobject]@{ Path = Join-Path $TestDrive 'RootA-invalid-policy.json'; Document = $invalidPolicy }) -DefinitionId 'RootA' } | Should -Throw '*dependency.policy*'

        $retiredDependencies = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'RootA' -Releases @(
                New-TestPackageRelease -Id 'RootA-win-x64-1.0.0' -Version '1.0.0' -Architecture 'x64'
            ))
        $retiredDependencies | Add-Member -MemberType NoteProperty -Name dependencies -Value @([pscustomobject]@{ definitionId = 'Runtime' }) -Force
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo ([pscustomobject]@{ Path = Join-Path $TestDrive 'RootA-retired-dependencies.json'; Document = $retiredDependencies }) -DefinitionId 'RootA' } | Should -Throw "*retired top-level property 'dependencies'*"

        $retiredPolicy = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'RootA' -Releases @(
                New-TestPackageRelease -Id 'RootA-win-x64-1.0.0' -Version '1.0.0' -Architecture 'x64'
            ))
        $retiredPolicy | Add-Member -MemberType NoteProperty -Name dependencyPolicy -Value ([pscustomobject]@{
                conflictsWith = @([pscustomobject]@{ definitionId = 'Runtime' })
            }) -Force
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo ([pscustomobject]@{ Path = Join-Path $TestDrive 'RootA-retired-policy.json'; Document = $retiredPolicy }) -DefinitionId 'RootA' } | Should -Throw "*retired top-level property 'dependencyPolicy'*"

        $missingDependency = ConvertTo-TestPsObject (New-TestVSCodeDefinitionDocument -DefinitionId 'RootA' -Releases @(
                New-TestPackageRelease -Id 'RootA-win-x64-1.0.0' -Version '1.0.0' -Architecture 'x64'
            ))
        $missingDependency.PSObject.Properties.Remove('dependency')
        { Assert-PackageDefinitionSchema -DefinitionDocumentInfo ([pscustomobject]@{ Path = Join-Path $TestDrive 'RootA-missing-dependency.json'; Document = $missingDependency }) -DefinitionId 'RootA' } | Should -Throw '*dependency*'
    }

}
