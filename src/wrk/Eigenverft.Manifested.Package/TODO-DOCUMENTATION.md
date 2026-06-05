# DOCUMENTATION — Design Issues

Design scratchpad for a **hybrid product documentation system**: markdown sources in the repository, release-built static HTML shipped inside the module, and an exported command to open it locally. Issue ratings and definitions follow [PROJECT-ISSUE-FRAMEWORK.md](PROJECT-ISSUE-FRAMEWORK.md) (V1.6): vertical ratings; **Option Kind** in each option heading; **💶 Value Assessment** after Options with **✅ Good Result**; **📬 Stakeholder Success Note** after Recommendation; one **Prefer/Choose Option X** per issue with required author and `YYYY-MM-DD HH:mm`. Facts re-verified against the repository on **2026-06-01**.

**Compose with:** [`PRODUCT-BOUNDARY.md`](PRODUCT-BOUNDARY.md) (canonical scope — link or summarize, do not fork). [`TODO-OWNERSHIP.md`](TODO-OWNERSHIP.md) — ownership/adoption guide chapter. [`DECISIONS.md`](DECISIONS.md) — shipped polish and recorded decisions (not the hybrid guide). [`DECISION-ENDPOINT-DISCOVERY-V1.md`](DECISION-ENDPOINT-DISCOVERY-V1.md) / [`TODO-DEPOTS-HTTP.md`](TODO-DEPOTS-HTTP.md) — conceptual mention in team-channel chapter only. Active `TODO-*.md` scratchpads — summarize and link in maintainer chapter, do not copy.

Open issues in this file are scheduled here. Scheduling implies **markdown sources, HTML build, module packaging, and a new exported command**.

---

## Open Issues

Sorted by **Priority** (higher urgency first), then higher **Benefit**, then lower **Effort** within the same priority.

**Priority 4/7 — Normal**

---
---

## 📌 Deliver hybrid product documentation (repo markdown → module HTML → open command)

- 🏷 Rating
  - 🚦 Priority: 4/7 Normal ▰▰▰▰▱▱▱
  - 🛠 Effort: 4/4 Major ▰▰▰▰
  - 🧠 Complexity: 2/5 Normal ▰▰▱▱▱
  - 🌍 Benefit: 3/4 Team ▰▰▰▱
  - 📦 Shape: 3/4 Epic / Theme ▰▰▰▱
  - 🎯 Quality: 🧭 Usability
  - 🚧 Readiness: 🟠 Needs Refinement

### 📝 Statement

The repo has a solid **README** and **PRODUCT-BOUNDARY**, but no structured manual for adopters, operators, or catalog maintainers — and **no offline guide for Gallery-only installs**.

**What this issue is (fixed scope, not an option set):** ship one documentation **system** with three parts:

1. **Sources** — markdown chapters in git; README links to the doc index.
2. **Bundle** — static HTML built from those sources, packaged in the module (offline, **no CDN**), e.g. under `Docs/Guide/`.
3. **Discovery** — exported command opens `index.html` via `file://`; clear failure if assets are missing.

Phasing is **implementation order** (content → build → bundle → command), not optional legs. Content includes concepts, team channel, positioning (one chapter), troubleshooting — not positioning alone. **PRODUCT-BOUNDARY** stays canonical; the guide summarizes and links.

**What this issue decides (options below):** which **v1 implementation path** to use for sources, HTML build, boundary presentation, opener command, and public web mirror — each option is one coherent, selectable stack (not a letter combination).

### 🧭 Related Context

Related Issues:
- [`TODO-OWNERSHIP.md`](TODO-OWNERSHIP.md) — ownership/adoption guide → chapter in same doc set.
- [`DECISIONS.md`](DECISIONS.md) — shipped `Get-PackageState` formatting and related polish; does not replace bundled guide.
- [DECISION-ENDPOINT-DISCOVERY-V1.md](DECISION-ENDPOINT-DISCOVERY-V1.md) / [`TODO-DEPOTS-HTTP.md`](TODO-DEPOTS-HTTP.md) — endpoint/depot backlog → conceptual mention in team-channel chapter only.

Affected Areas:
- Repo [`README.md`](../../../README.md); markdown tree (path TBD); `src/prj/Eigenverft.Manifested.Package/Docs/Guide/`; `.psd1` file list; new command; CI/release build.

May Influence:
- PSGallery package size; release pipeline; `Get-PackageDefinitionAuthoringGuide` / `PackageDefinitionAuthoring.md` onboarding.

Dependencies:
- Record choices under **✅ Resolved Decisions** from **🧩 Options** before bulk writing and packaging.

### 🎯 Required Outcome

| # | Leg | Done when |
|---|-----|-----------|
| 1 | **Sources** | Full chapter set ([map](#documentation-map-target-shape)) as repo markdown; index + README links; PRODUCT-BOUNDARY not duplicated as normative text. |
| 2 | **Build** | CI/release produces static HTML from markdown; **no CDN**; vendored licenses if JS/CSS used. |
| 3 | **Bundle** | Installed module contains offline `index.html` + chapters; `.psd1` includes files. |
| 4 | **Command** | Exported opener; module path resolution; tested on PowerShell 5.1 and 7+. |
| 5 | **Parity** | Git readers use markdown; `Install-Module` users get the **same** content via bundle + command. |

Implementation choices (repo path, renderer, boundary shape, command name, web mirror) are decided via **🧩 Options** and recorded in **✅ Resolved Decisions**.

### 🔎 Facts

Known:
- **README** (206 lines): no “Documentation” section (2026-06-01).
- **`docs/` tree:** does not exist.
- **Module:** no bundled guide path; **35** exported functions; **no** doc opener.
- **PRODUCT-BOUNDARY:** `src/wrk/Eigenverft.Manifested.Package/PRODUCT-BOUNDARY.md`.
- **Help:** comment-based only; wrk `TODO-*` are not user manuals.
- **Catalog examples:** **18** signed definitions under `Endpoint/Defaults/Eigenverft/`.
- **Drift risk:** README paraphrases positioning; boundary chapter shape is still an open choice between options.

Unknown:
- PSGallery size budget for HTML + vendor assets.
- Doc PR policy (docs-only vs mixed commits).

---

### 🧩 Options

*Each option is one **coherent v1 path** for the fixed hybrid system. Do not combine option letters in the recommendation.*

#### Option A — v1 default stack (repo `docs/`, CI static HTML, link-only boundary, `Show-PackageDocumentation`) (Implementation Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 4/4 Major ▰▰▰▰
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟣 Strategic
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
  - 🧾 Agent Work: 📝 Writing / Docs

Description:
Ship the full hybrid system using one integrated v1 stack. Maintainers author markdown under repo-root `docs/` with README links. CI pre-renders markdown to static HTML (tool TBD) and packages output under `Docs/Guide/` with **no CDN**. The product-boundary chapter summarizes purpose and **links** to `PRODUCT-BOUNDARY.md` without duplicating normative scope text. Export `Show-PackageDocumentation` to open `index.html` via `file://`. v1 delivers **module bundle only** — no GitHub Pages workflow yet.

Current State:
No doc tree, no HTML build, no bundle, no opener.

Resulting State:
Git contributors edit `docs/`; Gallery users get the same chapters offline via bundled HTML + command; single pipeline to maintain for v1.

Solves:
- Clear product entry for repo visitors; smallest sensible offline module; one scope source of truth for boundary; discoverable post-install command.

Leaves Open:
- Exact pre-render tool choice; PSGallery size after first artifact; ownership chapter may trail core phases.

Risks:
- CI must gate pack on successful HTML build; cross-tree build from repo `docs/` into module layout.

Later Cost:
- Ongoing doc + release pipeline maintenance; GitHub Pages can be a follow-up issue.

---

#### Option B — v1 stack with project-local markdown sources (Implementation Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 4/4 Major ▰▰▰▰
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: ⚪ 0 Neutral
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🔵 Local
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
  - 🧾 Agent Work: 📝 Writing / Docs

Description:
Same v1 stack as Option A (CI pre-render to static HTML, link-only boundary chapter, `Show-PackageDocumentation`, module bundle only) but markdown sources live beside the module project (e.g. `src/prj/Eigenverft.Manifested.Package/Docs/Source/` → build → `Docs/Guide/`). README links into the project path.

Current State:
No doc tree.

Resulting State:
Sources and bundle co-located in the module project folder; shorter paths for module-centric CI.

Solves:
- Convenient for developers working only in `src/prj/...`.

Leaves Open:
- Weaker repo-root discoverability for evaluators; longer README links.

Risks:
- Docs perceived as implementation-internal; may relocate to root `docs/` later.

Later Cost:
- Possible migration to Option A layout if onboarding suffers.

---

#### Option C — v1 stack with client-side markdown in the bundle (Reframed Implementation Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 4/4 Major ▰▰▰▰
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🔵 Local
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
  - 🧾 Agent Work: 🔌 Integration

Description:
Deliver the same hybrid outcomes (repo markdown at root, link-only boundary, `Show-PackageDocumentation`, module-only v1) but the module ships **markdown plus vendored client-side renderer** (e.g. marked/markdown-it) instead of CI pre-rendered HTML. CI mostly copies sources and vendor assets into `Docs/Guide/`.

Current State:
No bundle.

Resulting State:
Larger Gallery package; possible `file://` quirks; simpler CI copy step.

Solves:
- Avoids choosing a server-side renderer in CI initially.

Leaves Open:
- License and security review for vendored JS; heavier offline payload.

Risks:
- Renderer behavior under `file://`; may need later migration to pre-render (Option A style).

Later Cost:
- Likely second pass to pre-render if bundle size or reliability hurts adoption.

---

#### Option D — v1 default stack plus GitHub Pages from the same build (Combined Path Option)

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 4/4 Major ▰▰▰▰
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: ⚪ 0 Neutral
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🔵 Local
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
  - 🧾 Agent Work: 🔌 Integration

Description:
Deliver Option A’s full hybrid stack (repo `docs/`, CI pre-render, link-only boundary, `Show-PackageDocumentation`, module bundle) **and** publish the same built HTML to GitHub Pages on release in one v1 path. Module bundle remains required for offline Gallery users; Pages is a public mirror for evaluators, not a substitute for the bundle.

Current State:
No doc site or Pages workflow.

Resulting State:
Three surfaces: repo markdown, module bundle + command, public HTTPS docs.

Solves:
- Easier sharing during evaluations without installing the module.

Leaves Open:
- Second deploy target and CI complexity in v1.

Risks:
- Scope creep before bundle quality is proven; Pages drift if not same artifact as module.

Later Cost:
- Ongoing Pages deploy on every release.

---

### 💶 Value Assessment

- 💎 Value Type: 🧭 User Experience Improved · 🧲 Adoption / Retention Improved · 🚚 Delivery Unblocked
- 🧭 Value Direction: 🚀 Opportunity / Improvement
- 🧾 Value Mechanism: Gives git contributors and Gallery-only installers the same structured product guide (repo markdown + offline bundled HTML + open command); reduces evaluation friction, support threads, and README-only onboarding without duplicating PRODUCT-BOUNDARY as normative scope text.
- ⚖️ Option Value Summary:
  - Option A — v1 default stack (repo `docs/`, CI static HTML, link-only boundary, `Show-PackageDocumentation`) (Implementation Option)
    - 🧭 Resolution: 🟢 Full
    - 🛠 Option Effort: 4/4 Major ▰▰▰▰
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟢 -1 Improves
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧬 Integration: 🟣 Strategic
    - 🧾 Decision Note: Strongest v1 fit: common repo layout, smaller Gallery package via pre-render, boundary link-only, cmdlet naming aligned with existing surface.
  - Option B — v1 stack with project-local markdown sources (Implementation Option)
    - 🧭 Resolution: 🟢 Full
    - 🛠 Option Effort: 4/4 Major ▰▰▰▰
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: ⚪ 0 Neutral
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧾 Decision Note: Same hybrid outcomes as A with weaker repo-root discoverability; may relocate sources later.
  - Option C — v1 stack with client-side markdown in the bundle (Reframed Implementation Option)
    - 🧭 Resolution: 🟡 Partial
    - 🛠 Option Effort: 4/4 Major ▰▰▰▰
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧾 Decision Note: Defers CI renderer choice but adds vendored JS, `file://` risk, and likely pre-render migration later.
  - Option D — v1 default stack plus GitHub Pages from the same build (Combined Path Option)
    - 🧭 Resolution: 🟢 Full
    - 🛠 Option Effort: 4/4 Major ▰▰▰▰
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: ⚪ 0 Neutral
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧾 Decision Note: Best public sharing during evaluation; higher v1 CI scope — sensible after bundle pipeline is proven, not as first ship blocker.
- ✅ Good Result: Git and Gallery users access the same chapter set; offline `index.html` opens from an exported command; PRODUCT-BOUNDARY stays the single normative scope source.

---

### 🏁 Recommendation

- [2026-05-30 16:00 | Author: Composer | Recommendation: Prefer Option A | Support: 2/3 Reasoned ▰▰▱]

Reasoning:
Option A is one coherent v1 path that matches common open-source layout, keeps the module smaller via CI pre-render, avoids boundary drift with a link-only chapter, and uses a command name consistent with existing package cmdlets. Option B trades discoverability for project-local convenience. Option C adds vendored JS weight and `file://` risk without a strong v1 need. Option D is reasonable after the bundle pipeline is stable; it should not block first ship.

Required Checks:
- Confirm PSGallery package size after first pre-rendered HTML artifact.
- Pick CI build tool (mdbook, pandoc, or other) before Phase 5.
- Record **Choose Option A** under **✅ Resolved Decisions** when stakeholders agree.

### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: 🧑‍💼 Product Management · 🔧 Engineering · 🛟 Support / Customer Success
- 🗣 Communication Lens: 🧑‍💼 Product Summary
- 📬 Success Note: The product now ships a structured guide inside the module, not only README fragments. Gallery installs can open offline HTML that matches the repo markdown chapters. Evaluators and operators get clearer onboarding without hunting wrk scratchpads or duplicating scope text from PRODUCT-BOUNDARY.

### ✅ Resolved Decisions

- Decision: **Hybrid documentation system** is in scope — repo markdown, module HTML bundle, exported open command (three legs; phasing is order only).
  Reason: Gallery-only users need offline guide parity with git contributors.
  Consequence: Partial deliveries (markdown-only, bundle-only, command-only) do not close the issue.

- Decision: **PRODUCT-BOUNDARY** remains canonical for scope; guide must not replace it.
  Reason: Avoid two normative boundary texts.
  Consequence: Recommended path uses a link-only boundary chapter (Option A), not a duplicated excerpt.

- Decision: **Positioning** is one chapter in the IA, not a standalone doc effort.
  Reason: Migrated from prior project backlog positioning story.
  Consequence: Full chapter set still required per map.

- Decision: **English-only v1**; **no CDN** in bundled guide assets.
  Reason: Controlled/offline reading; defer localization.
  Consequence: Pre-rendered static HTML (Option A) preferred over client-side renderer (Option C).

- Decision: **Pending — v1 implementation path** — recommendation is **Prefer Option A**; not yet recorded as final until Required Checks pass.
  Reason: Framework requires one selectable option, not a letter combination.
  Consequence: Until confirmed, treat Option B/C/D as documented alternatives only.

### ❓ Open Decisions

- Confirm **Choose Option A** vs Option B/C/D (after Required Checks).
- Exact CI build tool when Option A is confirmed (mdbook, pandoc, custom PowerShell, other).
- PSGallery package size budget after first HTML artifact.
- Doc PR policy (docs-only PRs vs mixed).
- Whether ownership/adoption chapter ([`TODO-OWNERSHIP.md`](TODO-OWNERSHIP.md)) blocks v1 or trails in Phase 3+.

### 🚫 Out of Scope

- Markdown-only or bundle-only or command-only delivery (incomplete vs fixed hybrid scope).
- Replacing JSON Schema or `Get-Help`.
- Auto-generating docs from every `.ps1` unless a later tooling issue.
- Public marketing website (separate from guide + optional Pages).
- Fleet manager documentation beyond PRODUCT-BOUNDARY.
- HTTPS catalog / HTTP depot implementation (conceptual mention only).

### 🌱 Extracted Work

- [ ] **Phase 1 — IA + markdown skeleton** — map; index; placeholders; README links (repo `docs/` if Option A confirmed).
- [ ] **Phase 2 — Substantive markdown** — concepts, team channel, positioning.
- [ ] **Phase 3 — Remaining markdown** — install, trust, troubleshooting, maintainer index.
- [ ] **Phase 4 — README + boundary** — link-only boundary chapter; reconcile README duplication.
- [ ] **Phase 5 — HTML build in CI** — pre-render markdown → static HTML; review artifact.
- [ ] **Phase 6 — Module bundle + `.psd1`** — `Docs/Guide/` offline verify.
- [ ] **Phase 7 — `Show-PackageDocumentation`** — export opener; tests 5.1 + 7+.
- [ ] **Phase 8 — Release gates** — CI fails if sources or `index.html` missing from package.

Optional:
- [ ] **README package index / wrk catalog overview** — improve repo [`README.md`](../../../README.md) package list / quick-start and add a wrk index of the **18** shipped definitions (tables, grouping by kind). Complements shipped `Get-PackageState` formatting ([DECISIONS.md](DECISIONS.md)).
- [ ] **Ownership / adoption chapter** — when [`TODO-OWNERSHIP.md`](TODO-OWNERSHIP.md) guide content exists.
- [ ] **GitHub Pages** — only if **Choose Option D** is recorded (Combined Path Option includes Pages in v1; otherwise defer as follow-up after Option A ships).

---

## Delivery model (fixed architecture)

*Not an option — describes the system this issue ships.*

```text
  [Maintainers]  edit markdown in repo
        |
        v
  [CI / release]  markdown --> static HTML
        |
        v
  [Module package]  Docs/Guide/index.html  (offline, no CDN)
        |
        v
  [User]  <open-doc command>  -->  file:// index
```

| Audience | Entry |
|----------|--------|
| Git clone / PR | README → markdown tree |
| PSGallery install | Open-doc command → bundled HTML |

---

## Documentation map (target shape)

| Layer | Audience | Today | Target |
|-------|----------|-------|--------|
| **README** | Everyone | 206 lines | Short; links to docs + open-doc command |
| **Getting started** | New installer | Partial in README | Gallery, bootstrap, first assign |
| **Core concepts** | Users, maintainers | Fragmented | Endpoints, depots, trust, inventory |
| **Team channel guide** | Team owners | README section | Signing, trust, share layout |
| **Package definitions (overview)** | Authors | Schema + 18 examples | JSON → behavior |
| **Positioning / sweet spot** | Adopters | Scattered | WinGet/Scoop ← product → fleet CM |
| **Product boundary** | Contributors | PRODUCT-BOUNDARY.md | Summary + link (Option A path) |
| **Command reference** | Daily users | Comment help | Curated `Get-Help` tour |
| **Maintainer / catalog** | Owners | TODO scratchpads | Links only |
| **Troubleshooting** | Support | Minimal | Trust, depot, deps, removal |

---

## Content outlines (draft)

### Positioning

1. One-sentence definition. 2. Sweet spot diagram. 3. Primary users. 4. `Invoke-Package` scope. 5. Boundary link. 6. Open-doc command after install.

### Other chapters

Introduction · Install · Core concepts · First assignment (**18** defs) · Team channel · Trust and signing · Package definitions overview · Product boundary · Troubleshooting

---

## Closed / elsewhere

- README quick start — stays; guide adds depth.
- JSON Schema — author reference; guide is narrative.
- P6 cmdlet polish — separate issue.
