# Hybrid product documentation

**Status:** Open
**Priority:** 4/7 Normal
**Recommendation:** Repository markdown → release-built static HTML → offline module bundle → opener command.

## Gap

The README, comment help, product boundary, LLM package-authoring guide, and packaged documentation shell are useful but do not form a structured installed-product manual. `DocTemplate.html` keeps pages identical outside embedded Markdown; each page has one stylesheet link and one loader script. Neutral `documentation.*` assets build the shell, sequentially load pinned local Bootstrap, Bootstrap Icons, Marked, Mermaid, and ClipboardJS, and centrally supply the page dropdown and explicit online project links. The template itself is now a visible, self-bootstrapping guide with npm, LibMan/repository-manifest, and verified direct-download materialization choices, canonical license mappings, exact project-owned source blueprints, authoring rules, and offline checks. `Open-PackageDocumentation` resolves and opens the active module version's index through `Open-UrlInBrowser`; the complete multi-page product content is not yet written.

## Decisions already made

- [PRODUCT-BOUNDARY.md](PRODUCT-BOUNDARY.md) remains the normative scope source; documentation summarizes and links rather than forks it.
- The installed guide must work without a network or CDN; the current shell vendors Bootstrap 5.3.8, Bootstrap Icons 1.13.1, ClipboardJS 2.0.11, Marked 18.0.6, and Mermaid 11.16.0 with their MIT licenses.
- English-only is sufficient for the first version.
- Repository markdown and bundled HTML must contain the same chapter content.
- GitHub Pages is optional follow-up work, not a prerequisite.
- `Open-PackageDocumentation` is the version-aware installed-documentation entry point and reuses `Open-UrlInBrowser` as the shared browser-launch primitive.
- Direct `file://` use must not depend on `fetch()` for local Markdown; multi-page content must be embedded or release-built into classic local assets unless a local web server becomes an explicit requirement.
- Every packaged HTML page is registered once in `documentation.pages.js`; tests reject unregistered pages, template-shell drift, or drift between embedded and shipped neutral runtime sources.

## Remaining delivery

1. Write the structured product pages from `DocTemplate.html` and register them in the central menu.
2. Cover installation/bootstrap, first assignment, core concepts, artifact files, endpoints, depots, trust/signing, team shares, state/removal, troubleshooting, package-definition overview, positioning, and maintainer links.
3. Include the ownership/adoption material from [TODO-OWNERSHIP.md](TODO-OWNERSHIP.md).
4. Extend the pinned local renderer stack into a deterministic multi-page build without CDN assets.
5. Package the result under a stable module path such as `Docs/Guide/`.
6. Add release gates ensuring markdown sources and the built index are present and test the opener on Windows PowerShell 5.1 and PowerShell 7+.

## Open decisions

- Repository-root `docs/` versus project-local source path.
- Package-size budget for the rendered guide.
- Whether ownership content blocks the first guide release or lands immediately after the core chapters.

## Out of scope

- Replacing JSON Schema, comment help, or the package-definition authoring guide.
- A public marketing site.
- Auto-generating prose from every PowerShell file.
- Copying active scratchpad details into user documentation.

## Acceptance

Git users and Gallery-only/offline users can reach the same structured guide; the packaged opener works without internet access and release automation fails if the guide is missing.
