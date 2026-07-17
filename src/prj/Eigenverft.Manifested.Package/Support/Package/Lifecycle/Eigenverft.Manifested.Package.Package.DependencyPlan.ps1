<#
    Eigenverft.Manifested.Package.Package.DependencyPlan
#>

function New-PackageDependencyPlanViolation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Reason,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [AllowNull()]
        [string]$RootDefinitionId = $null,

        [AllowNull()]
        [string]$ParentNodeKey = $null,

        [AllowNull()]
        [string]$NodeKey = $null,

        [AllowNull()]
        [string]$PublisherId = $null,

        [AllowNull()]
        [string]$DefinitionId = $null,

        [AllowNull()]
        [string]$VersionRange = $null
    )

    return [pscustomobject]@{
        Reason           = $Reason
        Message          = $Message
        RootDefinitionId = $RootDefinitionId
        ParentNodeKey    = $ParentNodeKey
        NodeKey          = $NodeKey
        PublisherId      = $PublisherId
        DefinitionId     = $DefinitionId
        VersionRange     = $VersionRange
    }
}

function Add-PackageDependencyPlanViolation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Plan,

        [Parameter(Mandatory = $true)]
        [psobject]$Violation
    )

    $Plan.Violations.Add($Violation) | Out-Null
    $Plan.Accepted = $false
    $Plan.Status = 'Failed'
    return $Violation
}

function Join-PackageDependencyVersionRanges {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object[]]$VersionRanges
    )

    $ranges = @(
        foreach ($range in @($VersionRanges)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$range)) {
                ([string]$range).Trim()
            }
        }
    ) | Select-Object -Unique

    if ($ranges.Count -eq 0) {
        return $null
    }

    return ($ranges -join ' ')
}

function ConvertTo-PackageDependencyPlanArray {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return @()
    }
    if ($Value.PSObject.Methods['ToArray']) {
        return @($Value.ToArray())
    }

    return @($Value)
}

function Get-PackageDependencyPlanNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Plan,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$NodeKey
    )

    if ($Plan.NodeMap.ContainsKey($NodeKey)) {
        return $Plan.NodeMap[$NodeKey]
    }

    return $null
}

function Get-PackageDependencyPlanRootNodeKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Plan,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DefinitionId
    )

    foreach ($root in @(ConvertTo-PackageDependencyPlanArray -Value $Plan.Roots)) {
        if ([string]::Equals([string]$root.RequestedDefinitionId, $DefinitionId, [System.StringComparison]::OrdinalIgnoreCase)) {
            return [string]$root.NodeKey
        }
    }

    return $null
}

function Get-PackageDependencyPlanChildEdges {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Plan,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$NodeKey
    )

    if ($Plan.ChildrenByParentKey.ContainsKey($NodeKey)) {
        return @(ConvertTo-PackageDependencyPlanArray -Value $Plan.ChildrenByParentKey[$NodeKey])
    }

    return @()
}

function Select-PackageDependencyPlanVerdict {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Plan
    )

    $roots = @(ConvertTo-PackageDependencyPlanArray -Value $Plan.Roots)
    $nodes = @(ConvertTo-PackageDependencyPlanArray -Value $Plan.Nodes)
    $edges = @(ConvertTo-PackageDependencyPlanArray -Value $Plan.Edges)
    $violations = @(ConvertTo-PackageDependencyPlanArray -Value $Plan.Violations)

    return [pscustomobject]@{
        Status         = [string]$Plan.Status
        Accepted       = [bool]$Plan.Accepted
        RootCount      = $roots.Count
        NodeCount      = $nodes.Count
        EdgeCount      = $edges.Count
        ViolationCount = $violations.Count
        Violations     = @($violations)
    }
}

function Add-PackageDependencyPlanEdge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Plan,

        [Parameter(Mandatory = $true)]
        [psobject]$ParentNode,

        [Parameter(Mandatory = $true)]
        [psobject]$ChildNode,

        [AllowNull()]
        [string]$VersionRange = $null
    )

    $edgeKey = '{0}|{1}|{2}' -f [string]$ParentNode.NodeKey, [string]$ChildNode.NodeKey, $(if ([string]::IsNullOrWhiteSpace($VersionRange)) { '<none>' } else { [string]$VersionRange })
    if ($Plan.EdgeMap.ContainsKey($edgeKey)) {
        return $Plan.EdgeMap[$edgeKey]
    }

    $edge = [pscustomobject]@{
        EdgeKey          = $edgeKey
        ParentNodeKey    = [string]$ParentNode.NodeKey
        ParentPublisherId = [string]$ParentNode.PublisherId
        ParentDefinitionId = [string]$ParentNode.DefinitionId
        ChildNodeKey     = [string]$ChildNode.NodeKey
        PublisherId      = [string]$ChildNode.PublisherId
        DefinitionId     = [string]$ChildNode.DefinitionId
        VersionRange     = if ([string]::IsNullOrWhiteSpace($VersionRange)) { $null } else { [string]$VersionRange }
    }
    $Plan.Edges.Add($edge) | Out-Null
    $Plan.EdgeMap[$edgeKey] = $edge
    if (-not $Plan.ChildrenByParentKey.ContainsKey([string]$ParentNode.NodeKey)) {
        $Plan.ChildrenByParentKey[[string]$ParentNode.NodeKey] = New-Object 'System.Collections.Generic.List[object]'
    }
    $Plan.ChildrenByParentKey[[string]$ParentNode.NodeKey].Add($edge) | Out-Null
    return $edge
}

function Resolve-PackageDependencyPlanNodeSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Context,

        [Parameter(Mandatory = $true)]
        [psobject]$Node
    )

    $versionRange = Join-PackageDependencyVersionRanges -VersionRanges @($Node.IncomingVersionRanges)
    if (-not [string]::IsNullOrWhiteSpace($versionRange)) {
        try {
            $null = Resolve-PackageVersionRangeTerms -VersionRange $versionRange
        }
        catch {
            Add-PackageDependencyPlanViolation -Plan $Context.Plan -Violation (New-PackageDependencyPlanViolation -Reason 'DependencyVersionRangeInvalid' -Message $_.Exception.Message -RootDefinitionId $Context.RootDefinitionId -NodeKey ([string]$Node.NodeKey) -PublisherId ([string]$Node.PublisherId) -DefinitionId ([string]$Node.DefinitionId) -VersionRange $versionRange) | Out-Null
            return
        }
    }

    $packageVersionOverride = $null
    if ([bool]$Node.IsRoot -and [bool]$Context.PackageVersionOverrideSpecified) {
        $packageVersionOverride = [string]$Context.PackageVersion
    }

    try {
        $selectedPackage = Resolve-PackageEffectivePackage_2_0 -PackageConfig $Node.PackageConfig -PackageVersionOverride $packageVersionOverride -PackageVersionRange $versionRange
    }
    catch {
        $reason = if (-not [string]::IsNullOrWhiteSpace($versionRange) -and $_.Exception.Message -like '*versionRange*') {
            'DependencyVersionRangeUnsatisfied'
        }
        else {
            'DependencyPlanInvalid'
        }
        Add-PackageDependencyPlanViolation -Plan $Context.Plan -Violation (New-PackageDependencyPlanViolation -Reason $reason -Message $_.Exception.Message -RootDefinitionId $Context.RootDefinitionId -NodeKey ([string]$Node.NodeKey) -PublisherId ([string]$Node.PublisherId) -DefinitionId ([string]$Node.DefinitionId) -VersionRange $versionRange) | Out-Null
        return
    }

    $Node.Package = $selectedPackage
    $Node.PackageId = [string]$selectedPackage.id
    $Node.PackageVersion = [string]$selectedPackage.version
    $Node.VersionRange = $versionRange
    $Node.ReleaseTrack = [string]$selectedPackage.releaseTrack
    $Node.ArtifactDistributionVariant = [string]$selectedPackage.artifactDistributionVariant
}

function Resolve-PackageDependencyPolicyPublisherId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PolicyReference
    )

    if ($PolicyReference.PSObject.Properties['publisherId'] -and -not [string]::IsNullOrWhiteSpace([string]$PolicyReference.publisherId)) {
        return [string]$PolicyReference.publisherId
    }

    return $null
}

function Find-PackageDependencyPlanMatchingNodes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Plan,

        [Parameter(Mandatory = $true)]
        [psobject]$PolicyReference
    )

    $publisherId = Resolve-PackageDependencyPolicyPublisherId -PolicyReference $PolicyReference
    $definitionId = if ($PolicyReference.PSObject.Properties['definitionId']) { [string]$PolicyReference.definitionId } else { $null }
    $versionRange = if ($PolicyReference.PSObject.Properties['versionRange']) { [string]$PolicyReference.versionRange } else { $null }

    return @(
        foreach ($node in @(ConvertTo-PackageDependencyPlanArray -Value $Plan.Nodes)) {
            if ([string]::IsNullOrWhiteSpace($definitionId) -or
                -not [string]::Equals([string]$node.DefinitionId, $definitionId, [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }
            if (-not [string]::IsNullOrWhiteSpace($publisherId) -and
                -not [string]::Equals([string]$node.PublisherId, $publisherId, [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }
            if (-not [string]::IsNullOrWhiteSpace($versionRange) -and
                -not (Test-PackageVersionRange -VersionText ([string]$node.PackageVersion) -VersionRange $versionRange)) {
                continue
            }

            $node
        }
    )
}

function Test-PackageDependencyInventoryContainsReference {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageConfig,

        [Parameter(Mandatory = $true)]
        [psobject]$PolicyReference
    )

    $definitionId = if ($PolicyReference.PSObject.Properties['definitionId']) { [string]$PolicyReference.definitionId } else { $null }
    if ([string]::IsNullOrWhiteSpace($definitionId)) {
        return $false
    }

    $publisherId = Resolve-PackageDependencyPolicyPublisherId -PolicyReference $PolicyReference
    $versionRange = if ($PolicyReference.PSObject.Properties['versionRange']) { [string]$PolicyReference.versionRange } else { $null }
    $inventory = Get-PackageInventory -PackageConfig $PackageConfig
    foreach ($record in @($inventory.Records)) {
        if (-not [string]::Equals([string]$record.definitionId, $definitionId, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($publisherId) -and
            $record.PSObject.Properties['definitionPublisherId'] -and
            -not [string]::Equals([string]$record.definitionPublisherId, $publisherId, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($versionRange) -and
            -not (Test-PackageVersionRange -VersionText ([string]$record.currentVersion) -VersionRange $versionRange)) {
            continue
        }

        return $true
    }

    return $false
}

function Test-PackageDependencyPlanPolicyReference {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Plan,

        [Parameter(Mandatory = $true)]
        [psobject]$Node,

        [Parameter(Mandatory = $true)]
        [psobject]$PolicyReference,

        [Parameter(Mandatory = $true)]
        [ValidateSet('conflictsWith', 'requiresAbsent')]
        [string]$Kind
    )

    if (-not $PolicyReference.PSObject.Properties['definitionId'] -or [string]::IsNullOrWhiteSpace([string]$PolicyReference.definitionId)) {
        Add-PackageDependencyPlanViolation -Plan $Plan -Violation (New-PackageDependencyPlanViolation -Reason 'DependencyPlanInvalid' -Message "Package definition '$($Node.DefinitionId)' dependency.policy.$Kind entry is missing definitionId." -NodeKey ([string]$Node.NodeKey) -PublisherId ([string]$Node.PublisherId) -DefinitionId ([string]$Node.DefinitionId)) | Out-Null
        return $false
    }
    if ($PolicyReference.PSObject.Properties['publisherId'] -and [string]::IsNullOrWhiteSpace([string]$PolicyReference.publisherId)) {
        Add-PackageDependencyPlanViolation -Plan $Plan -Violation (New-PackageDependencyPlanViolation -Reason 'DependencyPlanInvalid' -Message "Package definition '$($Node.DefinitionId)' dependency.policy.$Kind entry has empty publisherId." -NodeKey ([string]$Node.NodeKey) -PublisherId ([string]$Node.PublisherId) -DefinitionId ([string]$Node.DefinitionId)) | Out-Null
        return $false
    }
    if ($PolicyReference.PSObject.Properties['publisherId']) {
        Assert-PackagePublisherId -PublisherId ([string]$PolicyReference.publisherId)
    }
    if ($PolicyReference.PSObject.Properties['versionRange'] -and -not [string]::IsNullOrWhiteSpace([string]$PolicyReference.versionRange)) {
        try {
            $null = Resolve-PackageVersionRangeTerms -VersionRange ([string]$PolicyReference.versionRange)
        }
        catch {
            Add-PackageDependencyPlanViolation -Plan $Plan -Violation (New-PackageDependencyPlanViolation -Reason 'DependencyVersionRangeInvalid' -Message $_.Exception.Message -NodeKey ([string]$Node.NodeKey) -PublisherId ([string]$Node.PublisherId) -DefinitionId ([string]$Node.DefinitionId) -VersionRange ([string]$PolicyReference.versionRange)) | Out-Null
            return $false
        }
    }

    return $true
}

function Test-PackageDependencyPlanPeerPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Plan
    )

    foreach ($node in @(ConvertTo-PackageDependencyPlanArray -Value $Plan.Nodes)) {
        $definition = $node.PackageConfig.Definition
        $dependencyModel = Get-PackageDefinitionDependencyModel_2_0 -Definition $definition -DefinitionId ([string]$node.DefinitionId)
        foreach ($conflict in @($dependencyModel.ConflictsWith)) {
            if (-not (Test-PackageDependencyPlanPolicyReference -Plan $Plan -Node $node -PolicyReference $conflict -Kind 'conflictsWith')) {
                continue
            }
            foreach ($match in @(Find-PackageDependencyPlanMatchingNodes -Plan $Plan -PolicyReference $conflict)) {
                Add-PackageDependencyPlanViolation -Plan $Plan -Violation (New-PackageDependencyPlanViolation -Reason 'DependencyConflict' -Message ("Package definition '{0}' conflicts with planned package '{1}'." -f [string]$node.DefinitionId, [string]$match.DefinitionId) -NodeKey ([string]$node.NodeKey) -PublisherId ([string]$match.PublisherId) -DefinitionId ([string]$match.DefinitionId) -VersionRange $(if ($conflict.PSObject.Properties['versionRange']) { [string]$conflict.versionRange } else { $null })) | Out-Null
            }
        }

        foreach ($requiresAbsent in @($dependencyModel.RequiresAbsent)) {
            if (-not (Test-PackageDependencyPlanPolicyReference -Plan $Plan -Node $node -PolicyReference $requiresAbsent -Kind 'requiresAbsent')) {
                continue
            }
            $plannedMatches = @(Find-PackageDependencyPlanMatchingNodes -Plan $Plan -PolicyReference $requiresAbsent)
            if ($plannedMatches.Count -gt 0) {
                foreach ($match in @($plannedMatches)) {
                    Add-PackageDependencyPlanViolation -Plan $Plan -Violation (New-PackageDependencyPlanViolation -Reason 'DependencyRequiresAbsent' -Message ("Package definition '{0}' requires package '{1}' to be absent, but it is in the approved plan." -f [string]$node.DefinitionId, [string]$match.DefinitionId) -NodeKey ([string]$node.NodeKey) -PublisherId ([string]$match.PublisherId) -DefinitionId ([string]$match.DefinitionId) -VersionRange $(if ($requiresAbsent.PSObject.Properties['versionRange']) { [string]$requiresAbsent.versionRange } else { $null })) | Out-Null
                }
            }
            if (Test-PackageDependencyInventoryContainsReference -PackageConfig $node.PackageConfig -PolicyReference $requiresAbsent) {
                Add-PackageDependencyPlanViolation -Plan $Plan -Violation (New-PackageDependencyPlanViolation -Reason 'DependencyRequiresAbsent' -Message ("Package definition '{0}' requires package '{1}' to be absent, but it is assigned locally." -f [string]$node.DefinitionId, [string]$requiresAbsent.definitionId) -NodeKey ([string]$node.NodeKey) -PublisherId $(Resolve-PackageDependencyPolicyPublisherId -PolicyReference $requiresAbsent) -DefinitionId ([string]$requiresAbsent.definitionId) -VersionRange $(if ($requiresAbsent.PSObject.Properties['versionRange']) { [string]$requiresAbsent.versionRange } else { $null })) | Out-Null
            }
        }
    }
}

function Resolve-PackageDependencyPlanNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Context,

        [AllowNull()]
        [string]$PublisherId = $null,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DefinitionId,

        [AllowNull()]
        [string]$ParentNodeKey = $null,

        [AllowNull()]
        [string]$VersionRange = $null,

        [object[]]$Stack = @(),

        [switch]$IsRoot
    )

    try {
        $config = Get-PackageConfig -PublisherId $PublisherId -DefinitionId $DefinitionId -DesiredState 'Assigned' -AcceptUnknownSigningKey:([bool]$Context.AcceptUnknownSigningKey)
    }
    catch {
        Add-PackageDependencyPlanViolation -Plan $Context.Plan -Violation (New-PackageDependencyPlanViolation -Reason 'DependencyDefinitionNotFound' -Message $_.Exception.Message -RootDefinitionId $Context.RootDefinitionId -ParentNodeKey $ParentNodeKey -PublisherId $PublisherId -DefinitionId $DefinitionId -VersionRange $VersionRange) | Out-Null
        return $null
    }

    $resolvedPublisherId = [string]$config.DefinitionPublisherId
    $resolvedDefinitionId = [string]$config.DefinitionId
    $nodeKey = Get-PackageDependencyReferenceKey -PublisherId $resolvedPublisherId -DefinitionId $resolvedDefinitionId
    if (@($Stack) -contains $nodeKey) {
        Add-PackageDependencyPlanViolation -Plan $Context.Plan -Violation (New-PackageDependencyPlanViolation -Reason 'DependencyCycle' -Message ("Package dependency cycle detected: {0} -> {1}." -f ((@($Stack) -join ' -> ')), $nodeKey) -RootDefinitionId $Context.RootDefinitionId -ParentNodeKey $ParentNodeKey -NodeKey $nodeKey -PublisherId $resolvedPublisherId -DefinitionId $resolvedDefinitionId -VersionRange $VersionRange) | Out-Null
        return $null
    }

    $node = $null
    if ($Context.Plan.NodeMap.ContainsKey($nodeKey)) {
        $node = $Context.Plan.NodeMap[$nodeKey]
        if (-not [string]::IsNullOrWhiteSpace($VersionRange) -and -not $node.IncomingVersionRanges.Contains([string]$VersionRange)) {
            $node.IncomingVersionRanges.Add([string]$VersionRange) | Out-Null
            Resolve-PackageDependencyPlanNodeSelection -Context $Context -Node $node
        }
        return $node
    }

    $incomingRanges = New-Object 'System.Collections.Generic.List[string]'
    if (-not [string]::IsNullOrWhiteSpace($VersionRange)) {
        $incomingRanges.Add([string]$VersionRange) | Out-Null
    }

    $node = [pscustomobject]@{
        NodeKey                     = $nodeKey
        PublisherId                 = $resolvedPublisherId
        DefinitionId                = $resolvedDefinitionId
        DefinitionRevision          = $config.DefinitionRevision
        DefinitionEndpointName      = $config.DefinitionEndpointName
        IsRoot                      = [bool]$IsRoot
        PackageConfig               = $config
        IncomingVersionRanges       = $incomingRanges
        VersionRange                = $null
        Package                     = $null
        PackageId                   = $null
        PackageVersion              = $null
        ReleaseTrack                = $null
        ArtifactDistributionVariant = $null
    }
    $Context.Plan.NodeMap[$nodeKey] = $node
    $Context.Plan.Nodes.Add($node) | Out-Null
    Resolve-PackageDependencyPlanNodeSelection -Context $Context -Node $node

    $definition = $config.Definition
    $dependencyModel = Get-PackageDefinitionDependencyModel_2_0 -Definition $definition -DefinitionId $resolvedDefinitionId
    $nextStack = @($Stack) + $nodeKey
    foreach ($dependency in @($dependencyModel.Requires)) {
        if ($null -eq $dependency) {
            continue
        }
        if (-not $dependency.PSObject.Properties['definitionId'] -or [string]::IsNullOrWhiteSpace([string]$dependency.definitionId)) {
            Add-PackageDependencyPlanViolation -Plan $Context.Plan -Violation (New-PackageDependencyPlanViolation -Reason 'DependencyPlanInvalid' -Message "Package definition '$resolvedDefinitionId' has dependency without definitionId." -RootDefinitionId $Context.RootDefinitionId -ParentNodeKey $nodeKey -NodeKey $nodeKey -PublisherId $resolvedPublisherId -DefinitionId $resolvedDefinitionId) | Out-Null
            continue
        }

        try {
            $dependencyPublisherId = Resolve-PackageDependencyPublisherId -PackageResult ([pscustomobject]@{ DefinitionPublisherId = $resolvedPublisherId; PackageConfig = $config }) -Dependency $dependency
        }
        catch {
            Add-PackageDependencyPlanViolation -Plan $Context.Plan -Violation (New-PackageDependencyPlanViolation -Reason 'DependencyPlanInvalid' -Message $_.Exception.Message -RootDefinitionId $Context.RootDefinitionId -ParentNodeKey $nodeKey -NodeKey $nodeKey -PublisherId $resolvedPublisherId -DefinitionId $resolvedDefinitionId) | Out-Null
            continue
        }
        $dependencyVersionRange = if ($dependency.PSObject.Properties['versionRange'] -and -not [string]::IsNullOrWhiteSpace([string]$dependency.versionRange)) {
            [string]$dependency.versionRange
        }
        else {
            $null
        }

        $child = Resolve-PackageDependencyPlanNode -Context $Context -PublisherId $dependencyPublisherId -DefinitionId ([string]$dependency.definitionId) -ParentNodeKey $nodeKey -VersionRange $dependencyVersionRange -Stack $nextStack
        if ($child) {
            Add-PackageDependencyPlanEdge -Plan $Context.Plan -ParentNode $node -ChildNode $child -VersionRange $dependencyVersionRange | Out-Null
        }
    }

    return $node
}

function New-PackageDependencyPlan {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$PublisherId = $null,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$DefinitionId,

        [ValidateSet('Assigned', 'Removed')]
        [string]$DesiredState = 'Assigned',

        [AllowNull()]
        [string]$PackageVersion = $null,

        [bool]$PackageVersionOverrideSpecified = $false,

        [switch]$AcceptUnknownSigningKey
    )

    $nodeMap = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::OrdinalIgnoreCase)
    $edgeMap = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::OrdinalIgnoreCase)
    $childrenByParentKey = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([System.StringComparer]::OrdinalIgnoreCase)
    $plan = [pscustomobject]@{
        Kind                = 'PackageDependencyPlan'
        CreatedAtUtc        = [DateTime]::UtcNow.ToString('o')
        DesiredState        = $DesiredState
        Status              = 'Pending'
        Accepted            = $false
        Roots               = New-Object 'System.Collections.Generic.List[object]'
        Nodes               = New-Object 'System.Collections.Generic.List[object]'
        Edges               = New-Object 'System.Collections.Generic.List[object]'
        Violations          = New-Object 'System.Collections.Generic.List[object]'
        NodeMap             = $nodeMap
        EdgeMap             = $edgeMap
        ChildrenByParentKey = $childrenByParentKey
    }

    $context = [pscustomobject]@{
        Plan                            = $plan
        AcceptUnknownSigningKey          = [bool]$AcceptUnknownSigningKey
        PackageVersion                  = $PackageVersion
        PackageVersionOverrideSpecified = [bool]$PackageVersionOverrideSpecified
        RootDefinitionId                = $null
    }

    foreach ($rootDefinitionId in @($DefinitionId)) {
        $context.RootDefinitionId = [string]$rootDefinitionId
        $rootNode = Resolve-PackageDependencyPlanNode -Context $context -PublisherId $PublisherId -DefinitionId ([string]$rootDefinitionId) -Stack @() -IsRoot
        $plan.Roots.Add([pscustomobject]@{
            RequestedPublisherId  = $PublisherId
            RequestedDefinitionId = [string]$rootDefinitionId
            NodeKey               = if ($rootNode) { [string]$rootNode.NodeKey } else { $null }
            PublisherId           = if ($rootNode) { [string]$rootNode.PublisherId } else { $PublisherId }
            DefinitionId          = if ($rootNode) { [string]$rootNode.DefinitionId } else { [string]$rootDefinitionId }
            PackageConfig         = if ($rootNode) { $rootNode.PackageConfig } else { $null }
        }) | Out-Null
    }

    Test-PackageDependencyPlanPeerPolicy -Plan $plan

    if ($plan.Violations.Count -eq 0) {
        $plan.Status = 'Approved'
        $plan.Accepted = $true
    }
    else {
        $plan.Status = 'Failed'
        $plan.Accepted = $false
    }

    return $plan
}

function Confirm-PackageDependencyPlanSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult
    )

    if (-not $PackageResult.PSObject.Properties['DependencyPlan'] -or -not $PackageResult.DependencyPlan -or
        -not $PackageResult.PSObject.Properties['DependencyPlanNodeKey'] -or
        [string]::IsNullOrWhiteSpace([string]$PackageResult.DependencyPlanNodeKey)) {
        return $PackageResult
    }

    $node = Get-PackageDependencyPlanNode -Plan $PackageResult.DependencyPlan -NodeKey ([string]$PackageResult.DependencyPlanNodeKey)
    if (-not $node) {
        throw "Dependency plan node '$($PackageResult.DependencyPlanNodeKey)' was not found."
    }
    if (-not [string]::Equals([string]$PackageResult.DefinitionId, [string]$node.DefinitionId, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Dependency plan node '$($node.NodeKey)' expected definition '$($node.DefinitionId)' but execution selected '$($PackageResult.DefinitionId)'."
    }
    if (-not [string]::Equals([string]$PackageResult.PackageVersion, [string]$node.PackageVersion, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Dependency plan node '$($node.NodeKey)' expected version '$($node.PackageVersion)' but execution selected '$($PackageResult.PackageVersion)'."
    }

    $PackageResult.DependencyPlanVerdict = Select-PackageDependencyPlanVerdict -Plan $PackageResult.DependencyPlan
    return $PackageResult
}

function Set-PackageResultDependencyPlanContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$PackageResult,

        [AllowNull()]
        [psobject]$DependencyPlan = $null,

        [AllowNull()]
        [string]$DependencyPlanNodeKey = $null
    )

    if (-not $DependencyPlan -or [string]::IsNullOrWhiteSpace($DependencyPlanNodeKey)) {
        return $PackageResult
    }

    $node = Get-PackageDependencyPlanNode -Plan $DependencyPlan -NodeKey $DependencyPlanNodeKey
    if (-not $node) {
        throw "Dependency plan node '$DependencyPlanNodeKey' was not found."
    }

    $PackageResult | Add-Member -MemberType NoteProperty -Name DependencyPlan -Value $DependencyPlan -Force
    $PackageResult | Add-Member -MemberType NoteProperty -Name DependencyPlanNodeKey -Value ([string]$DependencyPlanNodeKey) -Force
    $PackageResult | Add-Member -MemberType NoteProperty -Name DependencyPlanVerdict -Value (Select-PackageDependencyPlanVerdict -Plan $DependencyPlan) -Force
    if (-not [string]::IsNullOrWhiteSpace([string]$node.VersionRange)) {
        $PackageResult | Add-Member -MemberType NoteProperty -Name PackageVersionRange -Value ([string]$node.VersionRange) -Force
    }

    return $PackageResult
}

function New-PackageDependencyPlanFailureResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Plan,

        [Parameter(Mandatory = $true)]
        [psobject]$Root,

        [ValidateSet('Assigned', 'Removed')]
        [string]$DesiredState = 'Assigned',

        [switch]$Offline,

        [switch]$MaterializeOnly,

        [AllowNull()]
        [string]$PackageVersion = $null
    )

    $commandMode = if ($MaterializeOnly.IsPresent) { 'MaterializeOnly' } else { $DesiredState }
    $config = $Root.PackageConfig
    if ($config) {
        $result = New-PackageResult -DesiredState $DesiredState -CommandMode $commandMode -Offline:$Offline -MaterializeOnly:$MaterializeOnly -PackageConfig $config -PackageVersionSelector $PackageVersion
    }
    else {
        $result = [pscustomobject]@{
            OperationId            = [guid]::NewGuid().ToString('n')
            OperationStartedAtUtc  = [DateTime]::UtcNow.ToString('o')
            DesiredState           = $DesiredState
            CommandMode            = $commandMode
            Offline                = [bool]$Offline
            MaterializeOnly        = [bool]$MaterializeOnly
            PublisherId            = $Root.RequestedPublisherId
            DefinitionId           = $Root.RequestedDefinitionId
            DefinitionPublisherId  = $Root.PublisherId
            Status                 = 'Pending'
            FailureReason          = $null
            ErrorMessage           = $null
            CurrentStep            = 'Pending'
        }
    }

    $planViolations = @(ConvertTo-PackageDependencyPlanArray -Value $Plan.Violations)
    $firstViolation = @($planViolations | Where-Object {
            [string]::IsNullOrWhiteSpace([string]$_.RootDefinitionId) -or
            [string]::Equals([string]$_.RootDefinitionId, [string]$Root.RequestedDefinitionId, [System.StringComparison]::OrdinalIgnoreCase)
        } | Select-Object -First 1)
    if (-not $firstViolation) {
        $firstViolation = @($planViolations | Select-Object -First 1)
    }

    $result.Status = 'Failed'
    $result.FailureReason = 'PackageDependencyPlanFailed'
    $result.ErrorMessage = if ($firstViolation) { [string]$firstViolation.Message } else { 'Package dependency plan failed.' }
    $result.CurrentStep = 'PlanDependencies'
    $result | Add-Member -MemberType NoteProperty -Name DependencyPlanVerdict -Value (Select-PackageDependencyPlanVerdict -Plan $Plan) -Force
    return $result
}

function New-PackageDependencyPlanFailureResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Plan,

        [ValidateSet('Assigned', 'Removed')]
        [string]$DesiredState = 'Assigned',

        [switch]$Offline,

        [switch]$MaterializeOnly,

        [AllowNull()]
        [string]$PackageVersion = $null
    )

    return @(
        foreach ($root in @(ConvertTo-PackageDependencyPlanArray -Value $Plan.Roots)) {
            New-PackageDependencyPlanFailureResult -Plan $Plan -Root $root -DesiredState $DesiredState -Offline:$Offline -MaterializeOnly:$MaterializeOnly -PackageVersion $PackageVersion
        }
    )
}
