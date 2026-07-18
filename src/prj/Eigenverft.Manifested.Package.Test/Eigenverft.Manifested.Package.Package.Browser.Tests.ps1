<#
    Eigenverft.Manifested.Package Package - browser and packaged documentation
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - browser and packaged documentation' -Body {
    It 'ships a standalone offline documentation index with explicit custom and library assets' {
        $moduleProjectRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'Eigenverft.Manifested.Package'
        $documentationRoot = Join-Path $moduleProjectRoot 'Documentation'
        $indexPath = Join-Path $documentationRoot 'index.html'
        $templatePath = Join-Path $documentationRoot 'DocTemplate.html'
        $documentationCssPath = Join-Path $documentationRoot 'css\documentation.css'
        $documentationJavaScriptPath = Join-Path $documentationRoot 'js\documentation.js'
        $loaderJavaScriptPath = Join-Path $documentationRoot 'js\documentation.loader.js'
        $pagesJavaScriptPath = Join-Path $documentationRoot 'js\documentation.pages.js'
        $bootstrapCssPath = Join-Path $documentationRoot 'css\bootstrap.min.css'
        $bootstrapIconsCssPath = Join-Path $documentationRoot 'css\bootstrap-icons.min.css'
        $bootstrapIconsFontPath = Join-Path $documentationRoot 'css\fonts\bootstrap-icons.woff2'
        $bootstrapJavaScriptPath = Join-Path $documentationRoot 'js\bootstrap.bundle.min.js'
        $clipboardJavaScriptPath = Join-Path $documentationRoot 'js\clipboard.min.js'
        $markedJavaScriptPath = Join-Path $documentationRoot 'js\marked.umd.js'
        $mermaidJavaScriptPath = Join-Path $documentationRoot 'js\mermaid.min.js'
        $thirdPartyNoticesPath = Join-Path $documentationRoot 'THIRD-PARTY-NOTICES.md'
        $bootstrapLicensePath = Join-Path $documentationRoot 'licenses\bootstrap.LICENSE.txt'
        $bootstrapIconsLicensePath = Join-Path $documentationRoot 'licenses\bootstrap-icons.LICENSE.txt'
        $clipboardLicensePath = Join-Path $documentationRoot 'licenses\clipboard.LICENSE.txt'
        $markedLicensePath = Join-Path $documentationRoot 'licenses\marked.LICENSE.txt'
        $mermaidLicensePath = Join-Path $documentationRoot 'licenses\mermaid.LICENSE.txt'
        $content = Get-Content -LiteralPath $indexPath -Raw

        Test-Path -LiteralPath $indexPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $templatePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $documentationCssPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $documentationJavaScriptPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $loaderJavaScriptPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $pagesJavaScriptPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $bootstrapCssPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $bootstrapIconsCssPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $bootstrapIconsFontPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $bootstrapJavaScriptPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $clipboardJavaScriptPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $markedJavaScriptPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $mermaidJavaScriptPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $thirdPartyNoticesPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $bootstrapLicensePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $bootstrapIconsLicensePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $clipboardLicensePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $markedLicensePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $mermaidLicensePath -PathType Leaf | Should -BeTrue
        $content | Should -Match '<!doctype html>'
        $content | Should -Match 'Packaged documentation works offline'
        $content | Should -Match 'href="\./css/documentation\.css"'
        $content | Should -Match 'src="\./js/documentation\.loader\.js"'
        @([regex]::Matches($content, '<link\s+rel="stylesheet"')).Count | Should -Be 1
        @([regex]::Matches($content, '<script\s+src=')).Count | Should -Be 1
        $content | Should -Not -Match '<(?:main|nav|header)\b'
        $content | Should -Match '```mermaid'
        $content | Should -Not -Match '(?i)(src|href)\s*=\s*["'']https?://'
        $content | Should -Not -Match '(?i)(jquery|markdown-it)'
        $documentationJavaScript = Get-Content -LiteralPath $documentationJavaScriptPath -Raw
        $loaderJavaScript = Get-Content -LiteralPath $loaderJavaScriptPath -Raw
        $pagesJavaScript = Get-Content -LiteralPath $pagesJavaScriptPath -Raw
        $documentationCss = Get-Content -LiteralPath $documentationCssPath -Raw
        $pagesJavaScript | Should -Match "brand:\s*'Eigenverft\.Manifested\.Package'"
        $pagesJavaScript | Should -Not -Match "brand:\s*'Eigenverft\.Package'"
        $pagesJavaScript | Should -Match "path:\s*'index\.html'.*title:\s*'Eigenverft\.Manifested\.Package documentation'"
        $documentationJavaScript | Should -Match "document\.title = currentPage && currentPage\.title \? currentPage\.title : config\.brand \+ ' documentation'"
        $documentationJavaScript | Should -Not -Match 'firstHeading\.textContent'
        $documentationCss | Should -Match '^@import url\("\./bootstrap\.min\.css"\);'
        $documentationCss | Should -Match '@import url\("\./bootstrap-icons\.min\.css"\);'
        $lastDependencyIndex = -1
        foreach ($dependency in @('documentation.pages.js', 'bootstrap.bundle.min.js', 'marked.umd.js', 'clipboard.min.js', 'mermaid.min.js', 'documentation.js')) {
            $dependencyIndex = $loaderJavaScript.IndexOf("'$dependency'", [System.StringComparison]::Ordinal)
            $dependencyIndex | Should -BeGreaterThan $lastDependencyIndex
            $lastDependencyIndex = $dependencyIndex
        }
        $loaderJavaScript | Should -Not -Match '\bfetch\s*\('
        $documentationJavaScript | Should -Match "createElement\('main', 'page-width documentation-content'\)"
        $documentationJavaScript | Should -Not -Match "createElement\('header'|page-header|badge text-bg-primary|\beyebrow\b"
        $documentationJavaScript | Should -Match 'navbar navbar-expand-md sticky-top'
        $documentationJavaScript | Should -Match "setAttribute\('data-bs-toggle', 'collapse'\)"
        $documentationJavaScript | Should -Match "setAttribute\('data-bs-toggle', 'dropdown'\)"
        $documentationJavaScript | Should -Match "appendIconLabel\(onlineToggle, 'bi-cloud', 'Online'\)"
        $documentationJavaScript | Should -Match "var link = createElement\('a', 'dropdown-item'\)"
        $documentationJavaScript | Should -Match "link\.target = '_blank'"
        $documentationJavaScript | Should -Match "link\.rel = 'noopener noreferrer'"
        $documentationJavaScript | Should -Match 'window\.marked\.parse'
        $documentationJavaScript | Should -Match 'window\.mermaid\.run'
        $documentationJavaScript | Should -Match "classList\.add\('table', 'table-striped'"
        $documentationJavaScript | Should -Match "className = 'copy-button'"
        $documentationJavaScript | Should -Match 'new window\.ClipboardJS'
        $documentationJavaScript | Should -Match "clipboardInstance\.on\('success'"
        $documentationJavaScript | Should -Not -Match 'navigator\.clipboard|document\.execCommand'
        $documentationJavaScript | Should -Not -Match '\bfetch\s*\('
        $pagesJavaScript | Should -Match 'global\.DocumentationSite'
        $pagesJavaScript | Should -Match 'onlineLinks:'
        $pagesJavaScript | Should -Match 'https://github\.com/eigenverft/Eigenverft\.Manifested\.Package'
        $pagesJavaScript | Should -Match 'https://www\.powershellgallery\.com/packages/Eigenverft\.Manifested\.Package'
        $pagesJavaScript | Should -Not -Match '\bfetch\s*\('
        $documentationCss | Should -Match '(?s)\.code-block\s*\{[^}]*font-size:\s*0\.92em'
        $documentationCss | Should -Match '(?s)\.code-block pre,\s*\.code-block code,\s*\.code-block \.copy-button\s*\{\s*font:\s*inherit'
        $documentationCss | Should -Match '(?s)html\s*\{[^}]*overflow-y:\s*scroll;[^}]*scrollbar-gutter:\s*stable'
        $documentationCss | Should -Match '(?s)\.documentation-navbar \.bi\s*\{[^}]*color:\s*var\(--accent\);[^}]*font-size:\s*1\.1em;'
        $documentationCss | Should -Match '(?s)\.documentation-navbar \.dropdown-item\.active \.bi,[^{]*\{[^}]*color:\s*currentColor;'
        $documentationCss | Should -Not -Match '(?s)\.documentation-navbar \.navbar-brand\s*\{[^}]*font-weight:'
        $documentationCss | Should -Not -Match '\.page-header|\.eyebrow'
        $bootstrapCss = Get-Content -LiteralPath $bootstrapCssPath -Raw
        $bootstrapCss.Substring(0, [Math]::Min(200, $bootstrapCss.Length)) | Should -Match 'Bootstrap\s+v5\.3\.8'
        (Get-Content -LiteralPath $bootstrapIconsCssPath -Raw) | Should -Match 'Bootstrap Icons v1\.13\.1'
        (Get-Content -LiteralPath $clipboardJavaScriptPath -Raw) | Should -Match 'clipboard\.js v2\.0\.11'
        (Get-Content -LiteralPath $markedJavaScriptPath -TotalCount 5) -join "`n" | Should -Match 'marked v18\.0\.6'
        (Get-Content -LiteralPath $mermaidJavaScriptPath -Raw) | Should -Match 'globalThis\["mermaid"\]'
        (Get-Content -LiteralPath $thirdPartyNoticesPath -Raw) | Should -Match 'Mermaid \| 11\.16\.0'
        (Get-Content -LiteralPath $thirdPartyNoticesPath -Raw) | Should -Match 'ClipboardJS \| 2\.0\.11'
        (Get-Content -LiteralPath $thirdPartyNoticesPath -Raw) | Should -Match 'Bootstrap Icons \| 1\.13\.1'
        (Get-Content -LiteralPath $bootstrapLicensePath -Raw) | Should -Match 'MIT License'
        (Get-Content -LiteralPath $bootstrapIconsLicensePath -Raw) | Should -Match 'MIT License'
        (Get-Content -LiteralPath $clipboardLicensePath -Raw) | Should -Match 'MIT License'
        (Get-Content -LiteralPath $markedLicensePath -Raw) | Should -Match 'MIT License'
        (Get-Content -LiteralPath $mermaidLicensePath -Raw) | Should -Match 'MIT License'
    }

    It 'keeps every documentation HTML page on one shared template and central menu' {
        $moduleProjectRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'Eigenverft.Manifested.Package'
        $documentationRoot = Join-Path $moduleProjectRoot 'Documentation'
        $indexContent = Get-Content -LiteralPath (Join-Path $documentationRoot 'index.html') -Raw
        $templateContent = Get-Content -LiteralPath (Join-Path $documentationRoot 'DocTemplate.html') -Raw
        $pagesJavaScript = Get-Content -LiteralPath (Join-Path $documentationRoot 'js\documentation.pages.js') -Raw
        $markdownPattern = '(?s)(<script id="documentation-markdown" type="text/markdown">).*?(</script>)'
        $normalizedIndex = [regex]::Replace($indexContent, $markdownPattern, '$1__MARKDOWN__$2')
        $normalizedTemplate = [regex]::Replace($templateContent, $markdownPattern, '$1__MARKDOWN__$2')
        $registeredPages = @([regex]::Matches($pagesJavaScript, "path:\s*'([^']+\.html)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
        $htmlPages = @(Get-ChildItem -LiteralPath $documentationRoot -Filter '*.html' -File -Recurse | ForEach-Object {
                $_.FullName.Substring($documentationRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
            } | Sort-Object)

        $normalizedTemplate | Should -Be $normalizedIndex
        $templateContent | Should -Match '# Portable offline documentation template'
        $templateContent | Should -Match 'During initial bootstrap, create only `index\.html` and the supplied `DocTemplate\.html`'
        $templateContent | Should -Match 'Stop after the minimal two-page shell passes'
        $templateContent | Should -Match '## Later page-authoring rules'
        $registeredPages | Should -Be $htmlPages
        $registeredPages | Should -Contain 'index.html'
        $registeredPages | Should -Contain 'DocTemplate.html'
    }

    It 'is a neutral self-bootstrapping guide whose embedded runtime sources cannot drift' {
        $moduleProjectRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'Eigenverft.Manifested.Package'
        $documentationRoot = Join-Path $moduleProjectRoot 'Documentation'
        $templateContent = Get-Content -LiteralPath (Join-Path $documentationRoot 'DocTemplate.html') -Raw
        $sourceFiles = [ordered]@{
            'css/documentation.css'       = @{ Language = 'css'; Path = 'css\documentation.css' }
            'js/documentation.loader.js'  = @{ Language = 'javascript'; Path = 'js\documentation.loader.js' }
            'js/documentation.js'         = @{ Language = 'javascript'; Path = 'js\documentation.js' }
        }

        $templateContent | Should -Not -Match 'Eigenverft|eigenverft\.|Open-PackageDocumentation|Open-UrlInBrowser'
        $templateContent | Should -Not -Match '<!--'
        @([regex]::Matches($templateContent, '</script>')).Count | Should -Be 2
        @([regex]::Matches($templateContent, '<\\/script>')).Count | Should -Be 2
        $templateContent | Should -Match '## Canonical page shell'
        $templateContent | Should -Match 'Every HTML page must have exactly one object in the `pages` array'
        foreach ($propertyName in @('path', 'label', 'title', 'icon')) {
            $templateContent | Should -Match ('\| `' + $propertyName + '` \|')
        }
        $templateContent | Should -Match 'must not require a web server, package manager, CDN, or network connection at runtime'
        $templateContent | Should -Match '### Option A: one-time npm staging outside the repository'
        $templateContent | Should -Match '### Option B: LibMan or a repository asset manifest'
        $templateContent | Should -Match '### Option C: verified direct downloads'
        $templateContent | Should -Match '## Capability preflight'
        $templateContent | Should -Match 'Complete this preflight before creating output files, downloading packages, or choosing a validation workflow'
        $templateContent | Should -Match 'Respect task restrictions before trying a tool'
        $templateContent | Should -Match 'Test whether an already-available browser capability permits direct `file:` navigation'
        $templateContent | Should -Match 'Decide and state the acquisition path, temporary-directory strategy, trust/integrity evidence, cleanup mechanism'
        $templateContent | Should -Match 'do not retry or install browser automation'
        $templateContent | Should -Match '\[System\.IO\.Path\]::GetTempPath\(\)'
        $templateContent | Should -Match '\[System\.IO\.Directory\]::Delete\(\$documentationVendorStage, \$true\)'
        $templateContent | Should -Match 'If only this template is available, no workflow is visible, and npm is permitted'
        $templateContent | Should -Match 'Do not install browser automation or other validation packages solely for this bootstrap'
        $templateContent | Should -Match 'exactly two HTML files: `index\.html` and `DocTemplate\.html`'
        $templateContent | Should -Match 'Do not invent project documentation, sample pages, or fictional project content'
        $templateContent | Should -Match '### Built-in Mermaid smoke test'
        $templateContent | Should -Match 'Markdown `fetch\(\)`'
        $templateContent | Should -Match 'scrollbar gutter is always reserved'
        $templateContent | Should -Match 'Navigation icons use the theme accent at `1\.1em`'
        $templateContent | Should -Match 'Mermaid runs with `securityLevel: ''strict''`'
        $templateContent | Should -Match 'global\.DocumentationSite'

        foreach ($relativePath in $sourceFiles.Keys) {
            $source = $sourceFiles[$relativePath]
            $pattern = '(?s)## Project-owned source: `' + [regex]::Escape($relativePath) + '`\s+```' + $source.Language + '\r?\n(.*?)\r?\n```'
            $match = [regex]::Match($templateContent, $pattern)
            $match.Success | Should -BeTrue
            $embeddedSource = ($match.Groups[1].Value -replace "`r`n", "`n").TrimEnd()
            $shippedSource = ((Get-Content -LiteralPath (Join-Path $documentationRoot $source.Path) -Raw) -replace "`r`n", "`n").TrimEnd()
            $embeddedSource | Should -BeExactly $shippedSource
        }
    }

    It 'exports the browser command with the intended public interface' {
        $module = Import-Module -Name $script:ModuleManifestPath -Force -PassThru
        $command = $module.ExportedCommands['Open-UrlInBrowser']

        $command | Should -Not -BeNullOrEmpty
        $publicParameterNames = @($command.Parameters.Keys | Where-Object {
                $_ -notin [System.Management.Automation.PSCmdlet]::CommonParameters -and
                $_ -notin [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
            })
        $publicParameterNames | Should -Be @('Path', 'Wait', 'Browser', 'BrowserPath')
    }

    It 'exports the package documentation helper with browser selection only' {
        $module = Import-Module -Name $script:ModuleManifestPath -Force -PassThru
        $command = $module.ExportedCommands['Open-PackageDocumentation']

        $command | Should -Not -BeNullOrEmpty
        $publicParameterNames = @($command.Parameters.Keys | Where-Object {
                $_ -notin [System.Management.Automation.PSCmdlet]::CommonParameters -and
                $_ -notin [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
            })
        $publicParameterNames | Should -Be @('Wait', 'Browser', 'BrowserPath')
    }

    It 'resolves documentation from the exact active module version and delegates browser launch' {
        $module = Import-Module -Name $script:ModuleManifestPath -Force -PassThru
        $command = $module.ExportedCommands['Open-PackageDocumentation']
        $script:ExpectedDocumentationPath = Join-Path (Join-Path $module.ModuleBase 'Documentation') 'index.html'
        $script:ExpectedBrowserPath = Join-Path $TestDrive 'documentation-browser.exe'
        Write-TestTextFile -Path $script:ExpectedBrowserPath -Content 'test browser placeholder'
        Mock Start-Process { $null } -ModuleName 'Eigenverft.Manifested.Package'

        & $command -BrowserPath $script:ExpectedBrowserPath -Wait

        Assert-MockCalled Start-Process -Times 1 -Exactly -ModuleName 'Eigenverft.Manifested.Package' -ParameterFilter {
            $FilePath -eq $script:ExpectedBrowserPath -and
            @($ArgumentList).Count -eq 1 -and
            $ArgumentList[0] -eq $script:ExpectedDocumentationPath -and
            $Wait
        }
    }

    It 'opens the packaged documentation index with the operating-system default browser' {
        $moduleProjectRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'Eigenverft.Manifested.Package'
        $script:ExpectedDocumentationPath = (Resolve-Path -LiteralPath (Join-Path $moduleProjectRoot 'Documentation\index.html')).Path
        Mock Start-Process { $null }

        Open-UrlInBrowser -Path $script:ExpectedDocumentationPath

        Assert-MockCalled Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq $script:ExpectedDocumentationPath -and -not $Wait
        }
    }

    It 'opens a URL with an explicit browser executable and forwards Wait' {
        $script:ExpectedBrowserPath = Join-Path $TestDrive 'test-browser.exe'
        $script:ExpectedBrowserUrl = 'https://example.org/documentation'
        Write-TestTextFile -Path $script:ExpectedBrowserPath -Content 'test browser placeholder'
        Mock Start-Process { $null }

        Open-UrlInBrowser -Path $script:ExpectedBrowserUrl -BrowserPath $script:ExpectedBrowserPath -Wait

        Assert-MockCalled Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq $script:ExpectedBrowserPath -and
            @($ArgumentList).Count -eq 1 -and
            $ArgumentList[0] -eq $script:ExpectedBrowserUrl -and
            $Wait
        }
    }

    It 'rejects missing local files before launching a process' {
        Mock Start-Process { throw 'must not launch' }

        { Open-UrlInBrowser -Path (Join-Path $TestDrive 'missing-index.html') } | Should -Throw '*File not found or invalid URL*'

        Assert-MockCalled Start-Process -Times 0 -Exactly
    }
}
