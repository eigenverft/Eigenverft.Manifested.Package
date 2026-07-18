<#
    Eigenverft.Manifested.Package Package - browser and packaged documentation
#>

. "$PSScriptRoot\Eigenverft.Manifested.Package.Module.TestHelpers.ps1"

Invoke-TestPackageDescribe -Name 'Eigenverft.Manifested.Package Package - browser and packaged documentation' -Body {
    It 'ships a standalone offline documentation index with explicit custom and library assets' {
        $moduleProjectRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'Eigenverft.Manifested.Package'
        $documentationRoot = Join-Path $moduleProjectRoot 'Documentation'
        $indexPath = Join-Path $documentationRoot 'index.html'
        $offlineBootstrapPath = Join-Path $documentationRoot 'OfflineBootstrap.html'
        $documentationCssPath = Join-Path $documentationRoot 'css\documentation.css'
        $documentationJavaScriptPath = Join-Path $documentationRoot 'js\documentation.js'
        $loaderJavaScriptPath = Join-Path $documentationRoot 'js\documentation.loader.js'
        $pagesJavaScriptPath = Join-Path $documentationRoot 'js\documentation.pages.js'
        $bootstrapCssPath = Join-Path $documentationRoot 'css\bootstrap.min.css'
        $bootstrapIconsCssPath = Join-Path $documentationRoot 'css\bootstrap-icons.min.css'
        $bootstrapIconsFontPath = Join-Path $documentationRoot 'css\fonts\bootstrap-icons.woff2'
        $bootstrapJavaScriptPath = Join-Path $documentationRoot 'js\bootstrap.bundle.min.js'
        $highlightJavaScriptPath = Join-Path $documentationRoot 'js\highlight.min.js'
        $highlightPowerShellPath = Join-Path $documentationRoot 'js\highlight.powershell.min.js'
        $highlightDosPath = Join-Path $documentationRoot 'js\highlight.dos.min.js'
        $clipboardJavaScriptPath = Join-Path $documentationRoot 'js\clipboard.min.js'
        $markedJavaScriptPath = Join-Path $documentationRoot 'js\marked.umd.js'
        $mermaidJavaScriptPath = Join-Path $documentationRoot 'js\mermaid.min.js'
        $highlightCssPath = Join-Path $documentationRoot 'css\highlight.github.min.css'
        $highlightDarkCssPath = Join-Path $documentationRoot 'css\highlight.github-dark.min.css'
        $thirdPartyNoticesPath = Join-Path $documentationRoot 'THIRD-PARTY-NOTICES.md'
        $bootstrapLicensePath = Join-Path $documentationRoot 'licenses\bootstrap.LICENSE.txt'
        $bootstrapIconsLicensePath = Join-Path $documentationRoot 'licenses\bootstrap-icons.LICENSE.txt'
        $clipboardLicensePath = Join-Path $documentationRoot 'licenses\clipboard.LICENSE.txt'
        $highlightLicensePath = Join-Path $documentationRoot 'licenses\highlight.LICENSE.txt'
        $markedLicensePath = Join-Path $documentationRoot 'licenses\marked.LICENSE.txt'
        $mermaidLicensePath = Join-Path $documentationRoot 'licenses\mermaid.LICENSE.txt'
        $content = Get-Content -LiteralPath $indexPath -Raw
        $offlineBootstrapContent = Get-Content -LiteralPath $offlineBootstrapPath -Raw

        Test-Path -LiteralPath $indexPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $offlineBootstrapPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $documentationCssPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $documentationJavaScriptPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $loaderJavaScriptPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $pagesJavaScriptPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $bootstrapCssPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $bootstrapIconsCssPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $bootstrapIconsFontPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $bootstrapJavaScriptPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $highlightJavaScriptPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $highlightPowerShellPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $highlightDosPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $clipboardJavaScriptPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $markedJavaScriptPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $mermaidJavaScriptPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $highlightCssPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $highlightDarkCssPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $thirdPartyNoticesPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $bootstrapLicensePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $bootstrapIconsLicensePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $clipboardLicensePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $highlightLicensePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $markedLicensePath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $mermaidLicensePath -PathType Leaf | Should -BeTrue
        $content | Should -Match '<!doctype html>'
        $content | Should -Match '# 📦 Eigenverft\.Manifested\.Package'
        $content | Should -Match '## 📚 Documentation'
        $content | Should -Match 'https://eigenverft\.github\.io/Eigenverft\.Manifested\.Package/'
        $content | Should -Match 'Open-PackageDocumentation'
        $content | Should -Match '\./OfflineBootstrap\.html'
        $content | Should -Match 'href="\./css/documentation\.css"'
        $content | Should -Match 'src="\./js/documentation\.loader\.js"'
        @([regex]::Matches($content, '<link\s+rel="stylesheet"')).Count | Should -Be 1
        @([regex]::Matches($content, '<script\s+src=')).Count | Should -Be 1
        $content | Should -Not -Match '<(?:main|nav|header)\b'
        $content | Should -Not -Match '(?i)(src|href)\s*=\s*["'']https?://'
        $content | Should -Not -Match '(?i)(jquery|markdown-it)'
        $documentationJavaScript = Get-Content -LiteralPath $documentationJavaScriptPath -Raw
        $loaderJavaScript = Get-Content -LiteralPath $loaderJavaScriptPath -Raw
        $pagesJavaScript = Get-Content -LiteralPath $pagesJavaScriptPath -Raw
        $documentationCss = Get-Content -LiteralPath $documentationCssPath -Raw
        $pagesJavaScript | Should -Match "brand:\s*'Eigenverft\.Manifested\.Package'"
        $pagesJavaScript | Should -Not -Match "brand:\s*'Eigenverft\.Package'"
        $pagesJavaScript | Should -Match "path:\s*'index\.html'.*title:\s*'Eigenverft\.Manifested\.Package documentation'"
        $pagesJavaScript | Should -Match "path:\s*'OfflineBootstrap\.html'.*label:\s*'Offline setup'.*title:\s*'Offline Windows setup"
        $offlineBootstrapContent | Should -Match '# 📦 Offline Windows setup from one shared depot'
        $offlineBootstrapContent | Should -Match 'Sync-PackageDepot -AllTrusted'
        $offlineBootstrapContent | Should -Match '<Networking>Disable</Networking>'
        $offlineBootstrapContent | Should -Match 'Invoke-Package -DefinitionId SevenZip,GitRuntime,NodeRuntime -Offline'
        $offlineBootstrapContent | Should -Match '## 3\. 🚀 Double-click the bootstrap command'
        $offlineBootstrapContent | Should -Match 'Eigenverft\.Manifested\.Package\.Bootstrap\.cmd'
        $offlineBootstrapContent | Should -Not -Match 'Initialize-ProxyCompact|Initialize-Bootstrap|<LogonCommand>'
        $documentationJavaScript | Should -Match "document\.title = currentPage && currentPage\.title \? currentPage\.title : config\.brand \+ ' documentation'"
        $documentationJavaScript | Should -Not -Match 'firstHeading\.textContent'
        $documentationCss | Should -Match '^@import url\("\./bootstrap\.min\.css"\);'
        $documentationCss | Should -Match '@import url\("\./bootstrap-icons\.min\.css"\);'
        $documentationCss | Should -Match '@import url\("\./highlight\.github\.min\.css"\) screen and \(prefers-color-scheme: light\);'
        $documentationCss | Should -Match '@import url\("\./highlight\.github-dark\.min\.css"\) screen and \(prefers-color-scheme: dark\);'
        $lastDependencyIndex = -1
        foreach ($dependency in @('documentation.pages.js', 'bootstrap.bundle.min.js', 'marked.umd.js', 'highlight.min.js', 'highlight.powershell.min.js', 'highlight.dos.min.js', 'clipboard.min.js', 'mermaid.min.js', 'documentation.js')) {
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
        $documentationJavaScript | Should -Match 'window\.hljs\.highlightElement'
        $documentationJavaScript.IndexOf('renderMermaidDiagrams(target);', [System.StringComparison]::Ordinal) | Should -BeLessThan $documentationJavaScript.IndexOf('highlightCodeBlocks(target);', [System.StringComparison]::Ordinal)
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
        $documentationCss | Should -Match '(?s)pre code\.hljs\s*\{[^}]*background:\s*transparent;[^}]*padding:\s*0;'
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
        (Get-Content -LiteralPath $highlightJavaScriptPath -TotalCount 4) -join "`n" | Should -Match 'Highlight\.js v11\.11\.1'
        (Get-Content -LiteralPath $highlightPowerShellPath -TotalCount 2) -join "`n" | Should -Match '`powershell` grammar compiled for Highlight\.js 11\.11\.1'
        (Get-Content -LiteralPath $highlightDosPath -TotalCount 2) -join "`n" | Should -Match '`dos` grammar compiled for Highlight\.js 11\.11\.1'
        (Get-Content -LiteralPath $markedJavaScriptPath -TotalCount 5) -join "`n" | Should -Match 'marked v18\.0\.6'
        (Get-Content -LiteralPath $mermaidJavaScriptPath -Raw) | Should -Match 'globalThis\["mermaid"\]'
        (Get-Content -LiteralPath $thirdPartyNoticesPath -Raw) | Should -Match 'Mermaid \| 11\.16\.0'
        (Get-Content -LiteralPath $thirdPartyNoticesPath -Raw) | Should -Match 'ClipboardJS \| 2\.0\.11'
        (Get-Content -LiteralPath $thirdPartyNoticesPath -Raw) | Should -Match 'Highlight\.js \| 11\.11\.1 \| BSD-3-Clause'
        (Get-Content -LiteralPath $thirdPartyNoticesPath -Raw) | Should -Match 'Bootstrap Icons \| 1\.13\.1'
        (Get-Content -LiteralPath $bootstrapLicensePath -Raw) | Should -Match 'MIT License'
        (Get-Content -LiteralPath $bootstrapIconsLicensePath -Raw) | Should -Match 'MIT License'
        (Get-Content -LiteralPath $clipboardLicensePath -Raw) | Should -Match 'MIT License'
        (Get-Content -LiteralPath $highlightLicensePath -Raw) | Should -Match 'BSD 3-Clause License'
        (Get-Content -LiteralPath $markedLicensePath -Raw) | Should -Match 'MIT License'
        (Get-Content -LiteralPath $mermaidLicensePath -Raw) | Should -Match 'MIT License'
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
