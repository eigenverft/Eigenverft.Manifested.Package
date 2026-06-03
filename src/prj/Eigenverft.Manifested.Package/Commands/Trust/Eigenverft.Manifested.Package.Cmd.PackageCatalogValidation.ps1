<#
    Public package-definition catalog validation surface.
#>

function Test-PackageDefinitionCatalog {
<#
.SYNOPSIS
Validates package-definition JSON without installing packages.

.DESCRIPTION
Validates one package-definition JSON file or an endpoint folder before package
assignment. The command returns a structured report with parse, schema,
signature, trust, duplicate identity, and static dependency-reference issues.
It does not run Invoke-Package, download packages, install software, register
PATH entries, or write package assignment inventory.

.PARAMETER Path
Path to one package-definition JSON file or an endpoint folder containing JSON
package definitions.

.PARAMETER CertificatePath
Optional public certificate path used for signature validation.

.PARAMETER RequireTrusted
Treat unsigned or untrusted package definitions as validation errors.

.PARAMETER StrictSchemaVersion
Treat mixed schemaVersion values in a directory catalog as validation errors.

.PARAMETER ErrorOnFailure
Throw a terminating error after building the report when validation has errors.

.EXAMPLE
Test-PackageDefinitionCatalog -Path .\Endpoint\Defaults\Eigenverft\CodexCli.json

Validates one package-definition file and returns a report object.

.EXAMPLE
Test-PackageDefinitionCatalog -Path .\Endpoint\Defaults\Eigenverft

Validates every JSON file under an endpoint folder.

.EXAMPLE
Test-PackageDefinitionCatalog -Path .\Endpoint\Defaults\Eigenverft -RequireTrusted

Validates a folder and fails definitions that are unsigned or not trusted.

.EXAMPLE
Test-PackageDefinitionCatalog -Path .\Endpoint\Defaults\Eigenverft -RequireTrusted -ErrorOnFailure

Builds the validation report, then throws if errors exist for CI usage.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [AllowNull()]
        [string]$CertificatePath = $null,

        [switch]$RequireTrusted,

        [switch]$StrictSchemaVersion,

        [switch]$ErrorOnFailure
    )

    $report = Invoke-PackageDefinitionCatalogValidation -Path $Path -CertificatePath $CertificatePath -RequireTrusted:$RequireTrusted -StrictSchemaVersion:$StrictSchemaVersion
    if ($ErrorOnFailure.IsPresent -and -not [bool]$report.Valid) {
        $message = "Package-definition catalog validation failed for '$($report.Path)' with $($report.ErrorCount) error(s) and $($report.WarningCount) warning(s)."
        $exception = [System.InvalidOperationException]::new($message)
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            $exception,
            'PackageDefinitionCatalogValidationFailed',
            [System.Management.Automation.ErrorCategory]::InvalidData,
            $report
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    return $report
}
