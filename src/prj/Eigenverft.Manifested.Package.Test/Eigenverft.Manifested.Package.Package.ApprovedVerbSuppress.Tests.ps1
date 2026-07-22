<#
    Guard: exported commands with unapproved verbs must declare SuppressMessageAttribute.
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

function global:Test-ApprovedVerbSuppressAttribute {
    [CmdletBinding()]
    param (
        [AllowNull()]
        [scriptblock] $ScriptBlock
    )

    if (-not $ScriptBlock) {
        return $false
    }

    foreach ($attribute in @($ScriptBlock.Attributes)) {
        if ($attribute -is [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute] -and
            [string]::Equals(
                [string]$attribute.Category,
                'PSUseApprovedVerbs',
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
            return $true
        }
    }

    return $false
}

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - approved verb suppress guard' -Body {
    It 'requires SuppressMessageAttribute on every exported unapproved Verb-Noun command' {
        # Authority: current-host Get-Verb. Prefer Windows PowerShell 5.1 for the module's Windows-first surface.
        $importWarnings = @()
        $null = Import-Module -Name $script:ModuleManifestPath -Force -PassThru -DisableNameChecking -WarningVariable +importWarnings
        $importWarnings | Should -BeNullOrEmpty

        $approvedVerbs = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        Get-Verb | ForEach-Object { [void]$approvedVerbs.Add([string]$_.Verb) }

        $requiredAttribute = "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]"
        $offenders = [System.Collections.Generic.List[string]]::new()

        foreach ($command in @(Get-Command -Module Eigenverft.Manifested.Package -CommandType Function, Cmdlet)) {
            $name = [string]$command.Name
            if ($name -notmatch '-') {
                continue
            }

            $verb = ($name -split '-', 2)[0]
            if ($approvedVerbs.Contains($verb)) {
                continue
            }

            $scriptBlock = $command.ScriptBlock
            if (Test-ApprovedVerbSuppressAttribute -ScriptBlock $scriptBlock) {
                continue
            }

            $definingFile = 'the file defining the function'
            if ($scriptBlock -and -not [string]::IsNullOrWhiteSpace([string]$scriptBlock.File)) {
                $definingFile = [string]$scriptBlock.File
            }

            [void]$offenders.Add(
                ("Unapproved verb '{0}' on export '{1}' without {2}. Add that attribute on the function in {3}." -f `
                    $verb, $name, $requiredAttribute, $definingFile)
            )
        }

        if ($offenders.Count -gt 0) {
            $message = @(
                "Exported commands use unapproved verbs without $requiredAttribute."
                'Fix only the exports listed below:'
            ) + @($offenders.ToArray())
            throw ($message -join [Environment]::NewLine)
        }
    }

    It 'proves that explicit Import-Module name checking, not analyzer suppression, emits the runtime warning' {
        # SuppressMessageAttribute is consumed only by PSScriptAnalyzer. Import-Module
        # independently checks exported verbs at runtime, so the same annotated module
        # warns without -DisableNameChecking and is quiet with that targeted switch.
        Remove-Module -Name Eigenverft.Manifested.Package -Force -ErrorAction SilentlyContinue
        $warningsWithNameChecking = @(
            & {
                Import-Module -Name $script:ModuleManifestPath -Force -ErrorAction Stop
            } 3>&1
        )

        Remove-Module -Name Eigenverft.Manifested.Package -Force -ErrorAction SilentlyContinue
        $warningsWithoutNameChecking = @(
            & {
                Import-Module -Name $script:ModuleManifestPath -Force -DisableNameChecking -ErrorAction Stop
            } 3>&1
        )

        @($warningsWithNameChecking).Count | Should -BeGreaterThan 0 -Because 'the module intentionally exports verbs outside Get-Verb and explicit imports perform runtime name checking'
        $warningsWithoutNameChecking | Should -BeNullOrEmpty -Because '-DisableNameChecking disables only the explicit import name check; analyzer annotations cannot do that'
    }

    It 'accepts the rule name only in the SuppressMessage category field' {
        $valid = [scriptblock]::Create(
            "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')] param()"
        )
        $wrongField = [scriptblock]::Create(
            "[Diagnostics.CodeAnalysis.SuppressMessageAttribute('DifferentRule', 'PSUseApprovedVerbs')] param()"
        )

        (Test-ApprovedVerbSuppressAttribute -ScriptBlock $valid) | Should -BeTrue
        (Test-ApprovedVerbSuppressAttribute -ScriptBlock $wrongField) | Should -BeFalse
        (Test-ApprovedVerbSuppressAttribute -ScriptBlock $null) | Should -BeFalse
    }
}
