<#
    Eigenverft.Manifested.Sandbox.ExecutionCore.Upstream.GitHubRelease
#>

function Get-GitHubRelease {
<#
.SYNOPSIS
Gets one fixed GitHub release by tag through the GitHub Releases API.

.DESCRIPTION
Calls the GitHub REST API through Invoke-WebRequestEx, parses the release
metadata JSON, and returns a normalized release object with normalized asset
metadata. This helper is intentionally focused on fixed release lookup by tag
for Package upstream resolution and does not implement "latest" behavior.

.PARAMETER RepositoryOwner
The GitHub repository owner or organization name.

.PARAMETER RepositoryName
The GitHub repository name.

.PARAMETER ReleaseTag
The GitHub release tag name to resolve.

.EXAMPLE
Get-GitHubRelease -RepositoryOwner ggml-org -RepositoryName llama.cpp -ReleaseTag b9094
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryOwner,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ReleaseTag
    )

    $headers = @{
        'User-Agent'           = 'Eigenverft.Manifested.Sandbox'
        'Accept'               = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }

    $encodedTag = [System.Uri]::EscapeDataString($ReleaseTag)
    $uri = 'https://api.github.com/repos/{0}/{1}/releases/tags/{2}' -f $RepositoryOwner, $RepositoryName, $encodedTag

    try {
        $response = Invoke-WebRequestEx -Uri $uri -Headers $headers -UseBasicParsing -ErrorAction Stop
    }
    catch {
        throw "Get-GitHubRelease failed for repository '$RepositoryOwner/$RepositoryName' and release tag '$ReleaseTag'. $($_.Exception.Message)"
    }

    try {
        $release = $response.Content | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Get-GitHubRelease received invalid JSON for repository '$RepositoryOwner/$RepositoryName' and release tag '$ReleaseTag'. $($_.Exception.Message)"
    }

    $assets = @(
        foreach ($asset in @($release.assets)) {
            $sha256 = $null
            if ($asset.PSObject.Properties['digest'] -and -not [string]::IsNullOrWhiteSpace([string]$asset.digest)) {
                $digestMatch = [regex]::Match([string]$asset.digest, '^sha256:(?<value>[0-9a-fA-F]{64})$')
                if ($digestMatch.Success) {
                    $sha256 = $digestMatch.Groups['value'].Value.ToLowerInvariant()
                }
            }

            [pscustomobject]@{
                Id          = if ($asset.PSObject.Properties['id']) { [string]$asset.id } else { $null }
                Name        = if ($asset.PSObject.Properties['name']) { [string]$asset.name } else { $null }
                DownloadUrl = if ($asset.PSObject.Properties['browser_download_url']) { [string]$asset.browser_download_url } else { $null }
                ContentType = if ($asset.PSObject.Properties['content_type']) { [string]$asset.content_type } else { $null }
                Size        = if ($asset.PSObject.Properties['size']) { [int64]$asset.size } else { 0L }
                Digest      = if ($asset.PSObject.Properties['digest']) { [string]$asset.digest } else { $null }
                Sha256      = $sha256
                CreatedAtUtc = if ($asset.PSObject.Properties['created_at']) { [string]$asset.created_at } else { $null }
                UpdatedAtUtc = if ($asset.PSObject.Properties['updated_at']) { [string]$asset.updated_at } else { $null }
            }
        }
    )

    return [pscustomobject]@{
        RepositoryOwner = $RepositoryOwner
        RepositoryName  = $RepositoryName
        ReleaseId       = if ($release.PSObject.Properties['id']) { [string]$release.id } else { $null }
        ReleaseTag      = if ($release.PSObject.Properties['tag_name']) { [string]$release.tag_name } else { $ReleaseTag }
        ReleaseName     = if ($release.PSObject.Properties['name']) { [string]$release.name } else { $null }
        HtmlUrl         = if ($release.PSObject.Properties['html_url']) { [string]$release.html_url } else { $null }
        PublishedAtUtc  = if ($release.PSObject.Properties['published_at']) { [string]$release.published_at } else { $null }
        Draft           = if ($release.PSObject.Properties['draft']) { [bool]$release.draft } else { $false }
        Prerelease      = if ($release.PSObject.Properties['prerelease']) { [bool]$release.prerelease } else { $false }
        Immutable       = if ($release.PSObject.Properties['immutable']) { [bool]$release.immutable } else { $false }
        Assets          = @($assets)
    }
}

