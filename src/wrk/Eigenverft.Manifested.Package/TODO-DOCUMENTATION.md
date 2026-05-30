# TODO DOCUMENTATION

## Purpose

Design scratchpad for **in-depth product documentation** — a coherent doc set and optional packaged viewer, not just a one-off positioning page.

Today the repo has a **README** (entry, install, quick start) and [`PRODUCT-BOUNDARY.md`](PRODUCT-BOUNDARY.md) (scope and decision test for contributors). Those are necessary but not a full documentation story. This TODO tracks deeper material: concepts, workflows, examples, and presentation — with **product positioning / sweet spot** as **one section**, not the whole effort.

Promotion to [`PROJECT-TODO.md`](PROJECT-TODO.md) happens when work is scheduled. **No HTML, commands, or module files are implied by this document alone.**

---

## Documentation map (target shape)

| Layer | Audience | Status today | Target |
|-------|----------|--------------|--------|
| **README** | Everyone landing on the repo | Exists | Stays short; points into deeper docs |
| **Getting started** | New installer | Partially in README | Install paths (Gallery, corporate bootstrap), first `Invoke-Package`, `Get-PackageState` |
| **Concepts** | Users and maintainers | Fragmented in README + comments | Endpoints, depots, trust, inventory, install slots, assignment vs removal |
| **Team channel guide** | Team endpoint / depot owners | README team section | Expanded walkthrough: signing, trust preseed, layout on share |
| **Package definitions (overview)** | Catalog authors | Schema descriptions, shipped examples | How JSON maps to behavior without reading all of `*.ps1` |
| **Positioning / sweet spot** | Adopters, leads presenting the product | Paragraphs in PRODUCT-BOUNDARY + README | Clear “between WinGet/Scoop and fleet CM” narrative; comparisons; who it is for |
| **Product boundary** | Contributors, agents building features | [`PRODUCT-BOUNDARY.md`](PRODUCT-BOUNDARY.md) | **Included as a chapter** — in/out of scope, manager product, decision test; not duplicated, summarized in explainer with link to canonical file |
| **Command reference** | Daily users | Comment-based help | Optional generated or curated command/switch reference |
| **Maintainer / catalog** | Eigenverft and team catalog owners | Scattered TODO scratchpads | Links to `TODO-CATALOG-AGENT`, validation, dependency design docs when relevant |
| **Troubleshooting** | Support | Minimal | Common failures: trust prompt, offline, dependency not ready |

**Idea:** one documentation **system** (markdown sources + optional bundled HTML), not many unrelated one-pagers.

---

## Product goals

### Overall (documentation program)

As a user or maintainer, I want documentation that goes beyond README length — structured concepts, workflows, and examples — so I can adopt, operate, and present the product without reading the engine source.

**Outcome:** a maintained doc set (repo and/or module-bundled) with clear entry from README; PRODUCT-BOUNDARY remains the normative scope document.

### Positioning (subset — migrated from PROJECT-TODO)

As a maintainer presenting the project, I want the **sweet spot** explained: governed team package channel for Windows dev environments — more than WinGet/Scoop ad hoc scripts, lighter than enterprise fleet management — not a public app store, not a fleet manager.

**Outcome:** positioning content lives inside the larger doc IA (section or chapter), consistent with PRODUCT-BOUNDARY **Out Of Scope**.

### Extension model (subset — migrated from PROJECT-TODO)

As a package catalog maintainer, I want product language to present **team and online package endpoints** (and depots) as the normal way to grow the catalog beyond the shipped module set — without implying every definition must ship inside the Gallery package.

**Outcome:** documentation explains endpoint vs depot roles, filesystem team channel today, and HTTPS catalog / HTTP depot directions as backlog (see PROJECT-TODO P5). README points here instead of duplicating engine backlog detail.

---

## What exists today

| Asset | Role | Gap |
|-------|------|-----|
| [`README.md`](../../README.md) | Install, features, quick start, team basics | Not a full manual; evaluators need more narrative |
| [`PRODUCT-BOUNDARY.md`](PRODUCT-BOUNDARY.md) | Scope, risky decisions, manager boundary | Contributor-focused; should be **referenced**, not the only “deep” doc |
| `src/wrk/.../TODO-*.md` | Design scratchpads | Not end-user documentation |
| Module comment help | Per-command | No guided tour or concept graph |
| JSON Schema `description` / hints | Package authors | Not product-level story |

---

## Deliverable ideas (not locked)

### A — Markdown doc tree in repo (foundation)

- e.g. `docs/` at repo root or `src/prj/.../Docs/` with index (`README.md` or `Index.md`) linking chapters.
- Chapters align with [Documentation map](#documentation-map-target-shape); PRODUCT-BOUNDARY stays in `src/wrk` or is linked as canonical boundary chapter (avoid two diverging boundary texts).
- README gets a “Documentation” section with 3–5 links.

**Pros:** Git-reviewed, offline, no module release required for first value.  
**Cons:** User must find and open files manually.

### B — Bundled local HTML documentation site (idea)

Ship static **HTML + JS** inside the PowerShell module (path TBD, e.g. `Docs/Guide/`):

| Piece | Idea |
|-------|------|
| **Scope** | Full doc set (getting started through positioning and boundary summary), not positioning-only |
| **Source** | Author in **Markdown**; render to HTML at build time or client-side |
| **JS** | Small markdown renderer or pre-rendered pages |
| **Libraries** | Vendored/materialized in the module package (no CDN) — offline-friendly |
| **Entry** | `index.html` — table of contents for all chapters |

**Pros:** One offline-capable “manual” after `Install-Module`; good for demos and onboarding workshops.  
**Cons:** Module size; sync with repo `docs/` and PRODUCT-BOUNDARY.

### C — Command to open documentation locally (idea)

Exported command (name TBD, e.g. `Show-PackageDocumentation` / `Open-PackageGuide`):

- Resolves `index.html` under the **installed module directory**.
- Opens default browser via local file URI — no web server for v1.
- Fails clearly if bundled docs missing.

**Pros:** Discoverable next step after install.  
**Cons:** New command; tests on Windows PowerShell 5.1 and 7+.

### D — Hybrid (likely end state)

- Markdown sources in repo (`docs/`); release pipeline copies or builds HTML into module layout.
- Command opens bundled site.
- README → repo docs for contributors cloning git; command → same content for Gallery-only users.

---

## Content outline — positioning chapter (draft)

One chapter inside the larger doc; not the whole site.

1. One-sentence product definition.
2. Sweet spot: WinGet/Scoop ← this product → Intune/ConfigMgr (manager = future).
3. Primary users (developers, team owners, security-conscious operators).
4. What `Invoke-Package` does and does not do (local, explicit, inventory-backed).
5. Pointer to **Product boundary** chapter / PRODUCT-BOUNDARY file for scope rules.
6. Next steps (install, team channel, maintainer paths).

---

## Content outline — other chapters (draft)

- **Introduction** — what the module is; relationship to Eigenverft.Manifested.* ecosystem if any.
- **Install** — Gallery, corporate bootstrap, requirements (mirror README, can go deeper).
- **Core concepts** — definition, endpoint, depot, trust, assignment inventory, operation history.
- **First assignment** — walkthrough with shipped packages.
- **Team package channel** — signing, endpoint layout, depot mirror (expand README).
- **Trust and signing** — catalog trust policy, unknown key prompt, `.cer` preseed.
- **Package definitions (author overview)** — point to schema and AgentSkills/TODOs, not duplicate wire spec.
- **Product boundary** — summary + link to PRODUCT-BOUNDARY.md (canonical).
- **Positioning / sweet spot** — [outline above](#content-outline--positioning-chapter-draft).
- **Troubleshooting** — trust, offline, dependencies, removal blocked.

---

## Materialization of JS/CSS libs (idea)

If the HTML site uses client-side markdown rendering:

- Vendor libraries under module `Docs/.../vendor/` (or pre-render in CI and ship static HTML only).
- License files alongside vendored assets.
- No runtime `npm install` on the reader’s machine.

**Open:** marked vs markdown-it vs build-time static HTML only.

---

## Relationship to other work

| Topic | Where |
|-------|--------|
| HTTPS catalog / HTTP depot (engine) | PROJECT-TODO P5 — document conceptually in team-channel chapter |
| Catalog agent skill | [`TODO-CATALOG-AGENT.md`](TODO-CATALOG-AGENT.md) |
| Catalog validation | [`TODO-CATALOG-VALIDATION.md`](TODO-CATALOG-VALIDATION.md) |
| Dependency / resolver design | [`TODO-DEPENDENCY.md`](TODO-DEPENDENCY.md) |
| Supply-chain selection policy | [`TODO-SUPPLY-CHAIN.md`](TODO-SUPPLY-CHAIN.md) |

Design scratchpads stay in `TODO-*`; user-facing docs **summarize and link**, not copy entire design docs.

---

## Future implementation checklist

Reference only.

1. Agree doc IA (map above) and repo path (`docs/` vs module `Docs/`).
2. Phase 1 markdown chapters in repo; README links.
3. Reconcile positioning + boundary chapters with PRODUCT-BOUNDARY (single source of truth for scope).
4. Prototype HTML site (repo only).
5. Ship HTML in module + file list in `.psd1`.
6. Open-documentation command.
7. Optional: GitHub Pages from same sources (separate from module bundle).

### Phased delivery

| Phase | Deliverable |
|-------|-------------|
| 1 | `docs/` markdown skeleton + 2–3 substantive chapters (concepts, team channel, positioning) |
| 2 | Remaining chapters; README documentation index |
| 3 | Static HTML prototype; positioning + boundary integrated |
| 4 | Module-bundled HTML + open command |
| 5 | Markdown → HTML build pipeline; vendored or pre-rendered assets |

---

## Resolved (facts about today)

- README and PRODUCT-BOUNDARY are the only sustained product docs; depth is the gap.
- PRODUCT-BOUNDARY should remain canonical for **scope**; documentation **embeds** it, does not replace it.
- Positioning “sweet spot” is one PROJECT-TODO story now owned here, not a separate TODO file.

---

## Still open

- Single repo path convention (`/docs` vs `src/prj/.../Docs`).
- Whether boundary chapter is excerpt vs link-only to `src/wrk/PRODUCT-BOUNDARY.md`.
- Gallery package size budget for bundled HTML + vendor JS.
- Who maintains docs vs code (same PR policy as schema?).
- Localization — English-only v1 assumed.
- Whether command name is “Documentation” vs “Guide” vs “Help”.
- GitHub Pages vs module-only distribution.

---

## Out of scope

- Replacing JSON Schema or inline command help with the doc site.
- Public marketing website (unless explicitly added later).
- Auto-generating docs from every `.ps1` (unless a later explicit tooling story).
- Fleet manager product documentation (PRODUCT-BOUNDARY out-of-scope section only).
