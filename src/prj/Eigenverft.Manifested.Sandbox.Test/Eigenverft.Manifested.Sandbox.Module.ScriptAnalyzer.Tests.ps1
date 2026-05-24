<#
    Eigenverft.Manifested.Sandbox module script-analyzer guard.
#>

Describe 'Eigenverft.Manifested.Sandbox module script analyzer' {
    It 'has no PSScriptAnalyzer error-severity findings' {
        $analyzerPath = Join-Path $PSScriptRoot 'Invoke-ModuleScriptAnalyzer.ps1'
        Test-Path -LiteralPath $analyzerPath -PathType Leaf | Should -BeTrue

        $rawOutput = @(& $analyzerPath -Severity Error 2>&1)
        $rawText = ($rawOutput | ForEach-Object { [string]$_ }) -join [Environment]::NewLine

        try {
            $result = $rawText | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "Invoke-ModuleScriptAnalyzer.ps1 did not return valid JSON. Output:$([Environment]::NewLine)$rawText"
        }

        if ($result.Status -in @('MissingDependency', 'InvalidSettings')) {
            throw [string]$result.Message
        }

        $errorIssues = @(
            foreach ($file in @($result.Files)) {
                foreach ($issue in @($file.Issues)) {
                    if ([string]$issue.Severity -eq 'Error') {
                        [pscustomobject]@{
                            RelativePath = [string]$file.RelativePath
                            Line         = $issue.Line
                            Column       = $issue.Column
                            RuleName     = [string]$issue.RuleName
                            Message      = [string]$issue.Message
                        }
                    }
                }
            }
        )

        $issueText = if ($errorIssues.Count -gt 0) {
            @(
                foreach ($issue in $errorIssues) {
                    '{0}:{1}:{2} {3} {4}' -f $issue.RelativePath, $issue.Line, $issue.Column, $issue.RuleName, $issue.Message
                }
            ) -join [Environment]::NewLine
        }
        else {
            'No PSScriptAnalyzer error-severity findings.'
        }

        $errorIssues | Should -BeNullOrEmpty -Because $issueText
    }
}

