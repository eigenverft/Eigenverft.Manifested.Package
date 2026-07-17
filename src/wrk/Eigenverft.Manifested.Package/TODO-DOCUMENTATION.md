# Hybrid product documentation

**Status:** Open
**Priority:** 4/7 Normal
**Recommendation:** Repository markdown → release-built static HTML → offline module bundle → opener command.

## Gap

The README, comment help, product boundary, and LLM package-authoring guide are useful but do not form a structured installed-product manual. There is no documentation source tree, bundled HTML guide, or exported documentation opener.

## Decisions already made

- [PRODUCT-BOUNDARY.md](PRODUCT-BOUNDARY.md) remains the normative scope source; documentation summarizes and links rather than forks it.
- The installed guide must work without a network or CDN.
- English-only is sufficient for the first version.
- Repository markdown and bundled HTML must contain the same chapter content.
- GitHub Pages is optional follow-up work, not a prerequisite.

## Remaining delivery

1. Create a markdown source tree and index linked from the README.
2. Cover installation/bootstrap, first assignment, core concepts, artifact files, endpoints, depots, trust/signing, team shares, state/removal, troubleshooting, package-definition overview, positioning, and maintainer links.
3. Include the ownership/adoption material from [TODO-OWNERSHIP.md](TODO-OWNERSHIP.md).
4. Choose a deterministic static renderer and build HTML without CDN assets.
5. Package the result under a stable module path such as `Docs/Guide/`.
6. Export `Show-PackageDocumentation` to open the local index and fail clearly if packaging is incomplete.
7. Add release gates ensuring markdown sources and the built index are present and test the opener on Windows PowerShell 5.1 and PowerShell 7+.

## Open decisions

- Repository-root `docs/` versus project-local source path.
- Static renderer and vendored-asset/license policy.
- Package-size budget for the rendered guide.
- Whether ownership content blocks the first guide release or lands immediately after the core chapters.

## Out of scope

- Replacing JSON Schema, comment help, or the package-definition authoring guide.
- A public marketing site.
- Auto-generating prose from every PowerShell file.
- Copying active scratchpad details into user documentation.

## Acceptance

Git users and Gallery-only/offline users can reach the same structured guide; the packaged opener works without internet access and release automation fails if the guide is missing.
