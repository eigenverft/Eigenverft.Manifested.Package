# Project Issue Framework V1.8

Version: V1.8
Purpose: A readable Markdown framework for defining, rating, comparing, assessing value, deciding, and communicating project issues.

This framework has two layers:

1. Issue Rating - classifies the issue as it currently exists.
2. Issue Definition - describes the issue, related context, required outcome, known facts, possible options, value assessment, recommendation, stakeholder success note, decisions, and scope.

The issue rating answers: What kind of issue is this right now?
The issue definition answers: What do we know, what is connected, what must be true, what options exist, what value do the options offer, which option do we recommend, what can be communicated, what is decided, and what is excluded?

---

# 1. Visual Style

Use a small, consistent visual system. The goal is fast scanning in Markdown without turning the document into decoration.

There are three visual layers:

1. Icons identify the field.
2. Meters show ordered numeric ratings.
3. Chips show state, category, value direction, or risk for fields that do not use meters.

The text is always the source of truth. Icons, meters, and chips are only visual aids.

---

## 1.1 Visual Meter

Use `▰` for a filled segment and `▱` for an empty segment.

```text
▰ filled
▱ empty
```

Example:

```text
1/4 ▰▱▱▱
2/4 ▰▰▱▱
3/4 ▰▰▰▱
4/4 ▰▰▰▰
```

Use `▰▱` instead of stars, emoji ratings, or color-only markers.

Reason:

* `▰▱` has a clear filled/unfilled pair.
* It is readable in plain Markdown.
* It looks like a dashboard meter rather than a review score.
* It avoids the emotional meaning of stars.
* It works for effort, complexity, support, agent difficulty, and similar scales.

Do not use `⭐` as the main rating symbol. Stars can imply quality, preference, or approval, which is not what every rating means.

---

## 1.2 Semantic Chips

Use chips for fields that do not have a numeric meter.

```text
🟢 Favorable / good / ready / helpful
🟡 Acceptable / partial / temporary / watch
🟠 Caution / needs work / adds debt
🔴 Harmful / blocked / reject / high risk
🔵 Informational / discovery / local
🟣 Decision / strategic direction
⚪ Neutral / deferred / inactive
🧩 Split / structuring
```

Use chips sparingly. Do not add a chip when it does not clarify the meaning.

Chip consistency rules:

* Use 🟢 for clearly favorable states.
* Use 🟡 for acceptable but incomplete states.
* Use 🟠 for caution or debt.
* Use 🔴 for risk, rejection, blockage, or harmful direction.
* Use 🔵 for informational or discovery states.
* Use 🟣 for decision or strategic direction.
* Use ⚪ for neutral or deferred states.
* Use 🧩 only when the meaning is specifically splitting or structuring.

---

## 1.3 Section Icons

Use professional emoji icons for headings and major concepts.

```text
📌 Issue title
🏷 Rating
📝 Statement
🧭 Related Context
🎯 Required Outcome
🔎 Facts
🧩 Options
💶 Value Assessment
🏁 Recommendation
📬 Stakeholder Success Note
✅ Resolved Decisions
❓ Open Decisions
🚫 Out of Scope
🌱 Extracted Work
```

Use these icons consistently. Do not mix multiple icon styles for the same section.

Recommended issue title style:

```markdown
## 📌 Installer adoption and removal rules are unclear (MSI and similar)
```

Do not use `- [ ]` for full issue definitions. Checkboxes belong only in compact issue lists or extracted work lists, not in the issue document title.

---

## 1.4 Rating Icons

Use one icon per issue-rating dimension:

```text
🚦 Priority
🛠 Effort
🧠 Complexity
🌍 Benefit
📦 Shape
🎯 Quality
🚧 Readiness
```

Use one icon per option-profile dimension:

```text
🧭 Resolution
🛠 Option Effort
🧠 Option Complexity
🔮 Future Impact
↩️ Reversibility
🧬 Integration
🤖 Agent Difficulty
🧾 Agent Work
```

Use one icon per value-assessment field:

```text
💎 Value Type
🧭 Value Direction
🧾 Value Mechanism
⚖️ Option Value Summary
✅ Good Result
```

Use one icon per stakeholder-success field:

```text
👥 Stakeholder Role
🗣 Communication Lens
📬 Success Note
```

---

## 1.5 Plain Punctuation

Use plain punctuation in framework-authored issue documents.

Rules:

* Use the plain hyphen-minus character `-` for separators and option headings.
* Use straight double quotes `"`.
* Do not use typographic dash characters or smart quotes.
* Option headings use `Option A - <short option name>`.
* Tables use a `Rationale` column instead of a punctuation separator.

This keeps issue text copyable, searchable, and easy for validation scripts to scan.

---

# 2. Issue Rating Legend

Use one readable rating table for every issue.

Do not write the whole rating in one long line inside normal issue definitions. Long one-line ratings become hard to scan and hard to edit.

Use this table format:

```markdown
- 🏷 Rating

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🚦 Priority | 5/7 High | ▰▰▰▰▰▱▱ | delay increases trust risk soon |
| 🛠 Effort | 2/4 Moderate | ▰▰▱▱ | one subsystem plus focused tests |
| 🧠 Complexity | 3/5 Complex | ▰▰▰▱▱ | policy tradeoffs need careful review |
| 🌍 Benefit | 3/4 Team | ▰▰▰▱ | shared workflow improves for one team |
| 📦 Shape | 1/4 Focused | ▰▱▱▱ | one clear outcome with small steps |
| 🎯 Quality | 🧭 Usability | - | makes operator choices easier to see |
| 🚧 Readiness | 🟢 Ready | - | enough facts exist to start safely |
```

The number is the source of truth. The meter is only a visual aid. Unordered dimensions such as Quality, Readiness, Integration, Value Type, Value Direction, Option Kind, and Agent Work do not use meters.

Ordered non-numeric dimensions use meters when the scale has a clear strength, burden, or difficulty direction. In the option profile, Resolution, Future Impact, and Reversibility use meters even though their labels are chip-based.

Do not use short codes like `P2`, `E2`, `C3`, or `Q:U` in normal issue text.

Each reviewable assessment row must include a short rationale in the `Rationale` column.

Rationale rules:

* Explain why that rating was chosen, not what the label means.
* Use simple words and keep it about 40-60 characters when possible.
* Prefer one concrete reason over a broad justification.
* Do not repeat the section name, for example avoid `Priority because...`.
* If the rating is uncertain, say what fact is missing.
* Apply this to Issue Rating and Option Profile tables.
* In Option Value Summary, either carry the same rationale or rely on the Decision Note when repeating every rationale would make the summary noisy.

Rationale scope:

* Required: Issue Rating fields, including Priority, Effort, Complexity, Benefit, Shape, Quality, and Readiness.
* Required: Option Profile fields, including Resolution, Option Effort, Option Complexity, Future Impact, Reversibility, Integration, Agent Difficulty, and Agent Work.
* Optional: Value Type, Value Direction, Stakeholder Role, and Communication Lens when the following prose already explains the choice.
* Not required: Statement, Facts, Value Mechanism, Decision Note, Success Note, Required Checks, and other prose fields because they are already explanations.

Good:

```markdown
| 🧬 Integration | 🟢 Compatible | - | fits current schema without changing contracts |
```

Bad:

```markdown
| 🧬 Integration | 🟢 Compatible | - | good |
```

---

## 2.1 Core Dimensions

🚦 Priority answers: How bad is it if this waits?
🛠 Effort answers: How much delivery work is needed?
🧠 Complexity answers: How hard is the topic, system, domain, or reasoning problem?
🌍 Benefit answers: Who benefits if this ships?
📦 Shape answers: Is this really one well-shaped issue?
🎯 Quality answers: What kind of improvement is this?
🚧 Readiness answers: Can implementation start now?

Do not add the numbers together. They are ratings, not a score.

---

## 2.2 🚦 Priority

Priority measures consequence of delay. Higher number means more urgent. The number and meter use the same urgency-strength scale.

```text
🚦 Priority:
7/7 Blocker ▰▰▰▰▰▰▰
6/7 Critical ▰▰▰▰▰▰▱
5/7 High ▰▰▰▰▰▱▱
4/7 Normal ▰▰▰▰▱▱▱
3/7 Low ▰▰▰▱▱▱▱
2/7 Backlog ▰▰▱▱▱▱▱
1/7 Polish ▰▱▱▱▱▱▱
```

Use 7/7 Blocker when work, release, build, migration, deployment, or production use cannot continue.
Use 6/7 Critical for serious correctness, security, trust, data-loss, compliance, or rollout risk.
Use 5/7 High for important work that should be scheduled soon.
Use 4/7 Normal for useful planned work with no immediate pressure.
Use 3/7 Low for worthwhile but safely deferrable work.
Use 2/7 Backlog for possible future work that should stay visible but not be planned yet.
Use 1/7 Polish for optional refinement, visual cleanup, consistency, or taste-level improvement.

---

## 2.3 🛠 Effort

Effort measures delivery load. Higher number means more delivery work.

```text
🛠 Effort:
1/4 Trivial ▰▱▱▱
2/4 Moderate ▰▰▱▱
3/4 Substantial ▰▰▰▱
4/4 Major ▰▰▰▰
```

Use 1/4 Trivial for hours of work, narrow changes, and low regression risk.
Use 2/4 Moderate for days of work, one subsystem, and localized tests.
Use 3/4 Substantial for weeks of work, several areas touched, and design likely needed.
Use 4/4 Major for multi-week, architectural, migratory, or phased delivery.

Effort is not Complexity. Renaming many files can be high effort but low complexity.

---

## 2.4 🧠 Complexity

Complexity measures inherent problem difficulty. Higher number means harder reasoning.

```text
🧠 Complexity:
1/5 Simple ▰▱▱▱▱
2/5 Normal ▰▰▱▱▱
3/5 Complex ▰▰▰▱▱
4/5 Hard ▰▰▰▰▱
5/5 Extreme ▰▰▰▰▰
```

Use 1/5 Simple when the problem and solution are obvious.
Use 2/5 Normal when normal project knowledge is enough.
Use 3/5 Complex when deep system understanding or careful tradeoffs are needed.
Use 4/5 Hard when design, research, prototyping, or expert review may be needed.
Use 5/5 Extreme for foundational, open-ended, research-level, or system-defining work.

Complexity is not Effort. A race condition fix can be low effort but high complexity. "Create a new operating system" can be clearly stated but still extreme.

---

## 2.5 🌍 Benefit

Benefit measures who benefits if this ships. Higher number means broader reach.

```text
🌍 Benefit:
0/4 Internal ▱▱▱▱
1/4 Producer ▰▱▱▱
2/4 Individual ▰▰▱▱
3/4 Team ▰▰▰▱
4/4 Organization ▰▰▰▰
```

Use 0/4 Internal when only the delivering team benefits.
Use 1/4 Producer when authors, maintainers, publishers, operators, or registry owners benefit.
Use 2/4 Individual when one practitioner, seat, machine, or local environment benefits.
Use 3/4 Team when a bounded group sharing a workflow, catalog, config, or deployment benefits.
Use 4/4 Organization when many teams, many seats, policy, compliance, governance, rollout, or trust benefits.

Choose the narrowest level that fully fits the intended beneficiary.

---

## 2.6 📦 Shape

Shape measures whether the issue is actually shaped like one implementable issue. Higher number means worse issue shape.

```text
📦 Shape:
0/4 Atomic ▱▱▱▱
1/4 Focused ▰▱▱▱
2/4 Composite ▰▰▱▱
3/4 Epic / Theme ▰▰▰▱
4/4 Dump / Catch-all ▰▰▰▰
```

Use 0/4 Atomic for one narrow change, one reason, one owner, and one clear done condition.
Use 1/4 Focused for one clear outcome with several small steps.
Use 2/4 Composite when several related changes are bundled together.
Use 3/4 Epic / Theme when the issue has many outcomes, areas, owners, or definitions of done.
Use 4/4 Dump / Catch-all when the issue is vague, mixed, emotional, exploratory, or not plannable.

Shape is the reality-check dimension. A high-priority issue can still be badly shaped.

---

## 2.7 🎯 Quality

Quality describes what kind of improvement the issue primarily delivers. Quality has no meter because it is a category, not a rank.

```text
🎯 Quality:
✨ Functionality
🧭 Usability
🧱 Maintainability
📡 Operability
🛡 Security / Trust
🔁 Data / Compatibility
⚡ Performance
```

Use ✨ Functionality for new or corrected capability.
Use 🧭 Usability for clarity, learnability, documentation, commands, errors, defaults, or human operability.
Use 🧱 Maintainability for code structure, tests, modularity, refactoring, architecture clarity, or reduced future change cost.
Use 📡 Operability for reliability, diagnostics, observability, recovery, deployment safety, or runtime behavior.
Use 🛡 Security / Trust for integrity, permissions, signatures, policy, compliance, auditability, or safe adoption.
Use 🔁 Data / Compatibility for schema, migration, versioning, import/export, catalog compatibility, or interoperability.
Use ⚡ Performance for latency, throughput, memory, startup time, scale, or resource use.

Use one primary Quality value. Use two only if the issue is genuinely mixed.

---

## 2.8 🚧 Readiness

Readiness describes whether implementation can start. Readiness has no meter because it is a state, not a numeric scale.

```text
🚧 Readiness:
🟢 Ready
🟠 Needs Refinement
🔴 Blocked
```

Use 🟢 Ready when acceptance criteria are clear, the solution direction is understood, effort can be estimated, and implementation can start.
Use 🟠 Needs Refinement when clarification, splitting, design, research, or a decision is needed before normal implementation.
Use 🔴 Blocked when the issue cannot move because it depends on something outside the issue.

Readiness is not Shape. Shape judges issue structure. Readiness judges whether work can start.

---

# 3. Document Dividers

Use visible dividers to separate large sections. This is important because options, value assessment, and recommendations can become long.

Use this divider between full issues:

```markdown
---
---
```

Use this divider before Options, Value Assessment, and Recommendation:

```markdown
---
```

Use this divider between options:

```markdown
---
```

Recommended layout:

```markdown
---
---

## 📌 Issue Title

...

---

### 🧩 Options

#### Option A - First path (Implementation Option)

...

---

#### Option B - Second path (Reframed Implementation Option)

...

---

### 💶 Value Assessment

...

---

### 🏁 Recommendation

...
```

Do not overuse dividers inside short sections. Use them where the reader needs a clear visual stop.

---

# 4. Compact Open Issue List

Use compact issue cards when listing many open issues at the end of a project file. The compact list points to issue definitions; it does not replace them.

```markdown
## Open Issues

### 📌 Installer adoption and removal rules are unclear (MSI and similar)

- 🏷 Rating

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🚦 Priority | 3/7 Low | ▰▰▰▱▱▱▱ | runtime exists; guide can wait safely |
| 🛠 Effort | 2/4 Moderate | ▰▰▱▱ | guide and schema text, no engine rewrite |
| 🧠 Complexity | 2/5 Normal | ▰▰▱▱▱ | known behavior needs careful wording |
| 🌍 Benefit | 0/4 Internal | ▱▱▱▱ | mainly helps the maintaining team |
| 📦 Shape | 2/4 Composite | ▰▰▱▱ | policy guide plus examples are bundled |
| 🎯 Quality | 🧱 Maintainability | - | reduces future policy confusion |
| 🚧 Readiness | 🟠 Needs Refinement | - | needs option choice before writing |
```

Use 📌 for normal issue entries.
Use 🌱 only for extracted work or child issues.

---

# 5. Issue Definition Format

Each issue should be written as a small decision document, not only as a task line.

Use this structure:

```markdown
---
---

## 📌 <Issue Title>

- 🏷 Rating

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🚦 Priority | 3/7 Low | ▰▰▰▱▱▱▱ | runtime exists; guide can wait safely |
| 🛠 Effort | 2/4 Moderate | ▰▰▱▱ | guide and schema text, no engine rewrite |
| 🧠 Complexity | 2/5 Normal | ▰▰▱▱▱ | known behavior needs careful wording |
| 🌍 Benefit | 0/4 Internal | ▱▱▱▱ | mainly helps the maintaining team |
| 📦 Shape | 2/4 Composite | ▰▰▱▱ | policy guide plus examples are bundled |
| 🎯 Quality | 🧱 Maintainability | - | reduces future policy confusion |
| 🚧 Readiness | 🟠 Needs Refinement | - | needs option choice before writing |

### 📝 Statement

<Describe the issue, request, report, pain point, or requirement. Include original wording when useful.>

### 🧭 Related Context

<Describe known relationships to other issues, areas, risks, dependencies, duplicates, or future work. Write "None known" when no relationship is known yet.>

### 🎯 Required Outcome

<Describe what must be true when this issue is resolved. Avoid implementation detail unless already decided.>

### 🔎 Facts

Known:
- <Verified fact.>

Unknown:
- <Fact still to gather.>

---

### 🧩 Options

#### Option A - <Short option name> (<Option Kind>)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | <resolution> | <meter> | <40-60 char reason this path resolves enough> |
| 🛠 Option Effort | <option effort> | <meter> | <40-60 char reason for delivery load> |
| 🧠 Option Complexity | <option complexity> | <meter> | <40-60 char reason for reasoning load> |
| 🔮 Future Impact | <future impact> | <meter> | <40-60 char reason for later cost> |
| ↩️ Reversibility | <reversibility> | <meter> | <40-60 char reason for undo cost> |
| 🧬 Integration | <integration> | - | <40-60 char reason for design fit> |
| 🤖 Agent Difficulty | <agent difficulty> | <meter> | <40-60 char reason for review need> |
| 🧾 Agent Work | <agent work> | - | <40-60 char reason for task type> |

Description:
<Explain the option in plain language. Say what this option does, why someone might choose it, and what tradeoff it makes. This should be a short paragraph of 3 to 6 sentences, not a slogan. The option must be independently selectable; it must describe one coherent path that could be recommended on its own.>

Current State:
<Describe how the issue looks today if this option is not implemented. Focus on the visible behavior, code structure, workflow, risk, or missing information that currently exists.>

Resulting State:
<Describe how the issue would look after this option is implemented. Paint a clear picture of the changed behavior, structure, workflow, or decision state. A future reader should understand what improves without needing the original discussion.>

Solves:
- <What this option fixes, improves, clarifies, decides, discovers, splits, defers, or rejects.>

Leaves Open:
- <What this option does not solve.>

Risks:
- <What could go wrong.>

Later Cost:
- <What this option may make harder later.>
```

---

# 6. Section Rules

## 6.1 📌 Title

The title should name the issue, not the solution, unless the solution is already decided.

Good:

```markdown
## 📌 Resolver failure messages are not actionable
```

Good when the solution is already decided:

```markdown
## 📌 Add actionable resolver failure hints
```

Bad:

```markdown
## 📌 Fix resolver stuff
```

---

## 6.2 📝 Statement

The Statement section explains the issue in human terms. It should say what was reported, requested, noticed, or required; why it matters; and what pain, risk, gap, or limitation exists today.

Preserve the original report when the raw wording carries useful intent:

```markdown
### 📝 Statement

The current resolver error handling is difficult to maintain because message construction is spread across several code paths. The original report asked to "clean up resolver errors," but the underlying issue appears to mix duplicated formatting logic, inconsistent wording, and missing tests.

Original report:

> Clean up resolver errors. They are confusing and duplicated.
```

The Statement should be clear enough that someone can understand the issue without reading the full discussion history.

---

## 6.3 🧭 Related Context

Related Context records what this issue touches or may influence. It appears early so readers can see whether the issue is isolated or connected.

Use it for related issues, possible duplicates, dependencies, affected modules or workflows, known conflicts, downstream effects, future work that may be influenced by this issue, and decisions elsewhere that may constrain this issue.

Recommended form:

```markdown
### 🧭 Related Context

Related Issues:
- <Issue or topic that may be connected.>

Affected Areas:
- <Code area, workflow, command, schema, document, or user group.>

May Influence:
- <Later issue, design direction, migration path, or compatibility concern.>

Dependencies:
- <Decision, issue, access, approval, or fact this issue may depend on.>
```

If nothing is known yet, write:

```markdown
### 🧭 Related Context

None known.
```

Do not invent relationships just to fill the section.

---

## 6.4 🎯 Required Outcome

Required Outcome defines success without forcing a specific implementation. It should say what must be true after resolution and how the issue will be judged as done.

```markdown
### 🎯 Required Outcome

Resolver error construction should have one clear ownership model. Equivalent failures should use consistent wording, message structure, and test coverage. Future resolver errors should be easier to add without duplicating formatting logic.
```

Avoid implementation detail unless it has already been decided.

---

## 6.5 🔎 Facts

Facts are verified observations, not guesses. Use Facts to prevent implementation based on assumptions. If facts are missing, say so directly.

```markdown
### 🔎 Facts

Known:
- Resolver errors are currently created in multiple locations.
- Some messages include source information while others do not.
- Test coverage exists for failed resolution, but not for message consistency.

Unknown:
- Whether all resolver paths should share one formatter.
- Whether CLI output and machine-readable output should use the same message model.
- Whether existing downstream tooling depends on current message text.
```

Facts should be updated during refinement. Do not hide uncertainty inside confident prose.

---

# 7. Options

Options describe possible ways to handle the issue. An option can implement, reframe, partly solve, mitigate, discover, decide, split, combine, defer, or reject.

Each option has two separate concepts:

```text
Option Kind = what kind of path this option is.
Resolution = what this option achieves.
```

The option heading must include the option kind.

Use this heading format:

```markdown
#### Option A - <Short option name> (<Option Kind>)
```

Example:

```markdown
#### Option B - Define supported installer behavior instead of automating every removal path (Reframed Implementation Option)
```

The option title must describe the concrete path. The option kind classifies the path. The Resolution field classifies what the path achieves.

---

## 7.1 Option Kinds

Use one of these option kinds in the option heading.

```text
Option Kinds:
Implementation Option
Reframed Implementation Option
Discovery Option
Decision Option
Split Option
Combined Path Option
Defer Option
Reject Option
```

---

### Implementation Option

Use when the option is a concrete implementation path.

Typical resolutions:

```text
🟢 Full
🟡 Partial
🟠 Mitigation
```

Example:

```markdown
#### Option A - Introduce a shared resolver error model (Implementation Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🟢 Full | ▰▰▰▰▰ | addresses the whole stated outcome |
```

Implementation options should describe what will be built, changed, removed, or corrected.

---

### Reframed Implementation Option

Use when the original issue is valid, but the current framing points toward unnecessary effort, poor alignment, or excessive complexity.

The option keeps the original concern, but changes the target outcome so the implementation becomes simpler, better aligned, or lower effort.

Typical resolutions:

```text
🟢 Full
🟡 Partial
🟠 Mitigation
```

Example:

```markdown
#### Option B - Define supported installer behavior instead of automating every removal path (Reframed Implementation Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🟡 Partial | ▰▰▰▰▱ | preserves value but narrows scope |
```

The description should make the reframe explicit:

```text
Reframe the issue from "support every installer removal path automatically" to "make supported and unsupported removal behavior explicit."
```

A reframed implementation option must explain:

* what the original concern was
* what the simpler or better-aligned framing is
* what implementation becomes unnecessary
* what value is preserved
* what is intentionally left open or out of scope

Do not add `Reframe` as a Resolution value. Reframing is an option kind, not an outcome.

---

### Discovery Option

Use when the option gathers facts, maps the current state, prototypes, or produces evidence before choosing implementation.

Resolution:

```text
🔵 Discovery
```

Example:

```markdown
#### Option C - Map current resolver error ownership first (Discovery Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🔵 Discovery | ▰▰▱▱▱ | produces facts before choosing work |
```

A Discovery option must say what facts, map, prototype, or evidence it will produce, and what later decision it enables.

---

### Decision Option

Use when the option produces a required design, product, scope, release, security, or business decision before implementation.

Resolution:

```text
🟣 Decision
```

Example:

```markdown
#### Option D - Decide whether machine-readable errors are in scope (Decision Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🟣 Decision | ▰▰▱▱▱ | settles the blocking product choice |
```

A Decision option must say which decision will be made, why it blocks a responsible implementation choice, and which role or decision authority is expected to decide.

---

### Split Option

Use when the option turns one bundled issue into smaller separately rated issues.

Resolution:

```text
🧩 Split
```

Example:

```markdown
#### Option E - Separate wording cleanup from internal error modeling (Split Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🧩 Split | ▰▰▱▱▱ | separates work into cleaner issues |
```

A Split option must say what stays in the current issue and what becomes separate work.

---

### Combined Path Option

Use when several actions must be chosen together to form one coherent path.

Typical resolutions:

```text
🟢 Full
🟡 Partial
🟠 Mitigation
```

Example:

```markdown
#### Option F - Improve visible wording now and prepare shared model later (Combined Path Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🟡 Partial | ▰▰▰▰▱ | solves near-term need and defers depth |
```

A Combined Path option is not a bundle of unrelated tasks. It must be one coherent, independently selectable path.

Use this when the recommendation would otherwise become invalid, such as:

```text
Recommendation: A + C + E
```

Instead, create one Combined Path option and recommend that option.

---

### Defer Option

Use when the option intentionally postpones the issue under a clear revisit condition.

Resolution:

```text
⚪ Defer
```

Example:

```markdown
#### Option G - Defer until resolver diagnostics become release-blocking (Defer Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | ⚪ Defer | ▰▱▱▱▱ | waits for a clearer trigger |
```

A Defer option must say why now is not the right time and what condition should cause the issue to be revisited.

---

### Reject Option

Use when the option closes the issue because it should not be pursued.

Resolution:

```text
🔴 Reject
```

Example:

```markdown
#### Option H - Reject because the behavior is intentional (Reject Option)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | 🔴 Reject | ▱▱▱▱▱ | issue conflicts with intended behavior |
```

A Reject option must explain why the issue should not be pursued.

---

## 7.2 Resolution Values

Resolution describes what the option achieves.

```text
🧭 Resolution:
🟢 Full ▰▰▰▰▰
🟡 Partial ▰▰▰▰▱
🟠 Mitigation ▰▰▰▱▱
🔵 Discovery ▰▰▱▱▱
🟣 Decision ▰▰▱▱▱
🧩 Split ▰▰▱▱▱
⚪ Defer ▰▱▱▱▱
🔴 Reject ▱▱▱▱▱
```

The meter represents direct resolution strength against the stated required outcome, not whether the option is recommended. More filled means the option handles more of the issue directly now. Reject can be correct, but its meter is empty because it intentionally delivers none of the stated outcome.

Use 🟢 Full when the option resolves the required outcome.

Use 🟡 Partial when the option solves part of the issue and leaves known work open.

Use 🟠 Mitigation when the option reduces pain or risk but does not solve the underlying issue.

Use 🔵 Discovery when the option gathers facts, maps the current state, prototypes, or produces evidence needed before a responsible implementation choice.

Use 🟣 Decision when the option produces a required design, product, scope, security, release, or business decision before implementation.

Use 🧩 Split when the option turns one issue into smaller separately rated issues.

Use ⚪ Defer when the option intentionally postpones the issue under a clear revisit condition.

Use 🔴 Reject when the option decides not to pursue the issue and gives a reason.

---

## 7.3 Independent Option Rule

Options must be framed so one recommendation can be chosen at the end.

Good option structure:

```text
Option A - Minimal wording cleanup (Implementation Option)
Option B - Shared resolver error model (Implementation Option)
Option C - Discovery map before implementation (Discovery Option)
Option D - Define supported behavior instead of full automation (Reframed Implementation Option)
```

Bad option structure:

```text
Option A - Rename messages
Option C - Add tests
Option E - Add docs
Option G - Review config
```

This often leads to bad recommendations like:

```text
Recommendation: A + C + E + G
```

That means the options were written as fragments, not selectable paths.

If several fragments must happen together, combine them into one Combined Path Option.

---

## 7.4 Description, Current State, and Resulting State

Use these fields together:

```markdown
Description:
<Explain the option itself.>

Current State:
<Describe the situation before this option.>

Resulting State:
<Describe the situation after this option.>
```

Description explains the idea and tradeoff.
Current State grounds the option in today's reality.
Resulting State paints the future picture after implementation.

Do not merge these fields into one vague paragraph when the option is important.

Do not place stakeholder messaging inside the option. Options should describe solution paths, not management communication.

---

## 7.5 Number of Options

Most issues should have two or three real options. Use options mainly for implementation and integration choices. Do not create many artificial options just to fill the template.

A fourth option is allowed when it is a true Split Option, Discovery Option, Decision Option, Defer Option, Reject Option, Reframed Implementation Option, or Combined Path Option.

Use a Discovery Option when facts are missing.
Use a Decision Option when a blocking decision is needed.
Use a Split Option when the issue is bundled.
Use a Defer Option when postponement is a real candidate.
Use a Reject Option when the issue should not be pursued.
Use a Reframed Implementation Option when a simpler framing can preserve the original concern.
Use a Combined Path Option when several actions must be selected together.

Do not use the recommendation line as a replacement for missing options.

---

# 8. Option Profile Dimensions

## 8.1 🛠 Option Effort

Option Effort measures delivery load for this option, not for the original issue.

```text
🛠 Option Effort:
1/4 Trivial ▰▱▱▱
2/4 Moderate ▰▰▱▱
3/4 Substantial ▰▰▰▱
4/4 Major ▰▰▰▰
```

A partial option may be cheap even when the full issue is large.

---

## 8.2 🧠 Option Complexity

Option Complexity measures reasoning difficulty for this option, not for the original issue.

```text
🧠 Option Complexity:
1/5 Simple ▰▱▱▱▱
2/5 Normal ▰▰▱▱▱
3/5 Complex ▰▰▰▱▱
4/5 Hard ▰▰▰▰▱
5/5 Extreme ▰▰▰▰▰
```

An option can make today's work simpler while leaving harder work for later. That should be made visible through Future Impact and Later Cost.

---

## 8.3 🔮 Future Impact

Future Impact describes what choosing this option does to future work.

```text
🔮 Future Impact:
🟢 -2 Simplifies   ▰▱▱▱▱
🟢 -1 Improves     ▰▰▱▱▱
⚪ 0 Neutral       ▰▰▰▱▱
🟠 +1 Adds Debt    ▰▰▰▰▱
🔴 +2 Rewrite Risk ▰▰▰▰▰
```

The meter represents future burden / rework risk, not desirability. More filled means more future cost or rewrite risk.

Use 🟢 -2 Simplifies when the option strongly reduces future complexity, coupling, or migration cost.
Use 🟢 -1 Improves when the option slightly improves future work.
Use ⚪ 0 Neutral when the option does not meaningfully affect future work.
Use 🟠 +1 Adds Debt when the option is acceptable but leaves cleanup, inconsistency, or known later cost.
Use 🔴 +2 Rewrite Risk when the option is likely to cause rework, migration pain, incompatible design, or throwaway implementation.

Future Impact is the main guardrail against cheap options that quietly create expensive later work.

---

## 8.4 ↩️ Reversibility

Reversibility describes how easy it is to undo or replace the option later.

```text
↩️ Reversibility:
🟢 Easy         ▰▱▱▱
🟡 Moderate     ▰▰▱▱
🟠 Hard         ▰▰▰▱
🔴 Irreversible ▰▰▰▰
```

The meter represents undo cost. More filled means harder to reverse.

Use 🟢 Easy when the option can be changed later with little cost.
Use 🟡 Moderate when change is possible but requires planned cleanup.
Use 🟠 Hard when changing later would affect users, schema, contracts, or multiple subsystems.
Use 🔴 Irreversible when the option creates durable compatibility, policy, migration, or trust consequences.

---

## 8.5 🧬 Integration

Integration describes how the option fits into the long-term design.

```text
🧬 Integration:
🔵 Local
🟢 Compatible
🟣 Strategic
🟡 Temporary
⚪ Neutral
🔴 Conflicting
```

Use 🔵 Local when the option is contained and does not define broader architecture.
Use 🟢 Compatible when the option fits the likely future direction.
Use 🟣 Strategic when the option directly advances the desired long-term design.
Use 🟡 Temporary when the option is intentionally short-lived.
Use ⚪ Neutral when the option does not materially affect long-term design.
Use 🔴 Conflicting when the option solves the near-term issue but works against the expected future design.

---

## 8.6 🤖 Agent Difficulty

Agent Difficulty estimates how suitable this option is for a coding agent.

```text
🤖 Agent Difficulty:
1/4 Routine ▰▱▱▱
2/4 Guided ▰▰▱▱
3/4 Strong ▰▰▰▱
4/4 Human-Led ▰▰▰▰
```

Use 1/4 Routine when a coding agent can likely perform the work from clear instructions, with ordinary review. This fits simple edits, documentation, predictable refactors, mechanical changes, or local fixes with clear tests.

Use 2/4 Guided when a coding agent can likely help, but needs precise instructions, bounded scope, and human review. This fits local code changes, test additions, small behavior changes, or structured cleanup.

Use 3/4 Strong when only a strong coding agent should attempt the work, and human review is important. This fits cross-file logic, subtle behavior, non-obvious tests, integration changes, or code that requires understanding project architecture.

Use 4/4 Human-Led when the work should be led by a human, even if an agent can assist with drafts, exploration, tests, or mechanical edits. This fits architecture, security boundaries, migrations, public contracts, high-risk behavior, or decisions with long-term consequences.

Agent Difficulty is not a judgement of whether AI is allowed. It is a planning signal for how much supervision, review, and task decomposition are needed.

---

## 8.7 🧾 Agent Work

Agent Work describes the kind of work a coding agent would mostly do. Agent Work has no meter because it is a category, not a rank.

```text
🧾 Agent Work:
📝 Writing / Docs
🔁 Mechanical Edit
💻 Local Code
🧠 System Logic
🔌 Integration
🔎 Research / Mapping
🧩 Planning / Structuring
```

Use 📝 Writing / Docs when the work is mostly documentation, issue text, comments, examples, help output, or explanation.
Use 🔁 Mechanical Edit when the work is mostly predictable editing, renaming, formatting, moving files, updating repeated patterns, or changing many similar locations.
Use 💻 Local Code when the work changes local behavior in a bounded area and can be checked with localized tests.
Use 🧠 System Logic when the work changes behavior that depends on several modules, state transitions, data flow, error handling, or domain rules.
Use 🔌 Integration when the work touches boundaries between systems, schemas, compatibility, migrations, deployment, public APIs, external tools, or release behavior.
Use 🔎 Research / Mapping when the work is mostly finding facts, reading the codebase, mapping ownership, listing affected areas, or preparing a decision.
Use 🧩 Planning / Structuring when the work is mostly splitting issues, preparing child issues, organizing options, or turning vague work into implementable work.

Use Agent Work together with Agent Difficulty.

---

# 9. Value Assessment

Value Assessment is written after Options.

It compares the value tradeoff of the presented options. It must be neutral, option-aware, and not written as a stakeholder preference.

Value Assessment does not replace Recommendation. It prepares the ground for Recommendation.

```text
Value Assessment = what value the options offer.
Recommendation = which one option should be chosen now.
Stakeholder Success Note = how to communicate the solved result.
```

Use this format:

```markdown
### 💶 Value Assessment

- 💎 Value Type: <primary value type>
- 🧭 Value Direction: <value direction>
- 🧾 Value Mechanism: <how the issue creates value, avoids waste, reduces risk, or enables upside>
- ⚖️ Option Value Summary:
  - Option A - <short option name> (<option kind>)
    - 🧭 Resolution: <resolution, including meter>
    - 🛠 Option Effort: <option effort, including meter>
    - 🧠 Option Complexity: <option complexity, including meter>
    - 🔮 Future Impact: <future impact, including meter>
    - 🤖 Agent Difficulty: <agent difficulty, including meter>
    - 🧾 Decision Note: <short value and effort judgement>
  - Option B - <short option name> (<option kind>)
    - 🧭 Resolution: <resolution, including meter>
    - 🛠 Option Effort: <option effort, including meter>
    - 🧠 Option Complexity: <option complexity, including meter>
    - 🔮 Future Impact: <future impact, including meter>
    - 🤖 Agent Difficulty: <agent difficulty, including meter>
    - 🧾 Decision Note: <short value and effort judgement>
- ✅ Good Result: <what would make the issue worthwhile across the acceptable option paths>
```

Value Assessment must be applicable to all reasonable options. Do not write it so that only one option can satisfy it unless the options themselves prove that.

---

## 9.1 💎 Value Type

Value Type describes the main type of value created by resolving the issue.

```text
💎 Value Type:
💰 Revenue Enabled
🧲 Adoption / Retention Improved
✨ Product Capability Improved
🧭 User Experience Improved
🛟 Support Effort Reduced
🧱 Maintenance Effort Reduced
⚡ Operating Cost Reduced
🚚 Delivery Unblocked
🛡 Risk / Loss Avoided
🔁 Rework Avoided
🔎 Better Decision
```

Use 💰 Revenue Enabled when the issue helps create or unlock revenue.
Use 🧲 Adoption / Retention Improved when the issue makes users more likely to adopt, continue using, upgrade, or not abandon the product.
Use ✨ Product Capability Improved when the issue adds, completes, or corrects a capability users or customers care about.
Use 🧭 User Experience Improved when the issue makes the product easier to understand, operate, learn, or recover from.
Use 🛟 Support Effort Reduced when the issue reduces tickets, escalations, diagnosis time, or support dependency on engineering.
Use 🧱 Maintenance Effort Reduced when the issue reduces repeated engineering effort, duplicated logic, review uncertainty, or future change cost.
Use ⚡ Operating Cost Reduced when the issue reduces recurring infrastructure, compute, storage, licensing, or runtime cost.
Use 🚚 Delivery Unblocked when the issue enables blocked project, release, migration, rollout, or adoption work to continue.
Use 🛡 Risk / Loss Avoided when the issue reduces the chance of outage, rollback, security problem, compliance problem, data loss, trust loss, or failed rollout.
Use 🔁 Rework Avoided when the issue prevents doing the same work again, choosing a throwaway path, or paying later for avoidable cleanup.
Use 🔎 Better Decision when the issue produces facts, mapping, prototype evidence, or design clarity that prevents a bad investment decision.

---

## 9.2 🧭 Value Direction

Value Direction describes the broad business lens.

```text
🧭 Value Direction:
💰 Cost / Efficiency
🛡 Risk / Protection
🚀 Opportunity / Improvement
🔎 Decision / Learning
```

Use 💰 Cost / Efficiency when the value is mainly lower effort, lower spend, lower waste, lower recurring cost, or better use of fixed capacity.
Use 🛡 Risk / Protection when the value is mainly avoiding loss, outage, rollback, security exposure, compliance problems, adoption failure, or trust damage.
Use 🚀 Opportunity / Improvement when the value is mainly better product capability, better user experience, improved adoption, or upside potential.
Use 🔎 Decision / Learning when the value is mainly better facts, better investment choice, better design direction, or reduced uncertainty before committing effort.

Value Direction is not a score. It helps the reader understand which kind of value the issue creates.

---

## 9.3 🧾 Value Mechanism

Value Mechanism explains the concrete mechanism by which value is created.

Good Value Mechanism examples:

```text
Reduces repeated engineering effort by making installer adoption and removal rules easier to understand, change, and review.
```

```text
Protects adoption by making setup failures less confusing for new users.
```

```text
Reduces support effort because users and support staff can diagnose resolver failures without engineering help.
```

```text
Avoids rework by checking compatibility before the release path is chosen.
```

Bad Value Mechanism examples:

```text
Improves things.
```

```text
Creates business value.
```

```text
Makes the product better.
```

These are too vague.

---

## 9.4 ⚖️ Option Value Summary

Option Value Summary compares the value, effort, difficulty, and future impact of the presented options.

It should be short, neutral, and useful for judgement.

Each option summary should use a compact multi-line block. Do not force all fields into one long line.

Default format:

```markdown
- Option A - <short option name> (<option kind>)
    - 🧭 Resolution: <resolution, including meter>
    - 🛠 Option Effort: <option effort, including meter>
    - 🧠 Option Complexity: <option complexity, including meter>
    - 🔮 Future Impact: <future impact, including meter>
    - 🤖 Agent Difficulty: <agent difficulty, including meter>
    - 🧾 Decision Note: <short value and effort judgement>
```

Default fields:

```text
Option Kind
🧭 Resolution
🛠 Option Effort
🧠 Option Complexity
🔮 Future Impact
🤖 Agent Difficulty
🧾 Decision Note
```

Optional fields may be added only when they are decision-relevant:

```text
↩️ Reversibility
🧬 Integration
🧾 Agent Work
```

Use optional fields when they change the decision. For example, include Reversibility when an option is hard to undo, include Integration when an option is strategic or conflicting, and include Agent Work when delegation type matters.

Resolution, Option Effort, Option Complexity, Future Impact, and Agent Difficulty always include their meters in Option Value Summary. When Reversibility is included in Option Value Summary, include its meter. Integration and Agent Work remain meterless because they are categories.

Good example:

```markdown
⚖️ Option Value Summary:
- Option A - Improve visible wording only (Implementation Option)
    - 🧭 Resolution: 🟡 Partial ▰▰▰▰▱
    - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
    - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
    - 🔮 Future Impact: 🟠 +1 Adds Debt ▰▰▰▰▱
    - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
    - 🧾 Decision Note: Fast visible improvement, but weak long-term value because the internal structure remains duplicated.
- Option B - Introduce a shared resolver error model (Implementation Option)
    - 🧭 Resolution: 🟢 Full ▰▰▰▰▰
    - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
    - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
    - 🔮 Future Impact: 🟢 -2 Simplifies ▰▱▱▱▱
    - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
    - 🧾 Decision Note: Higher effort, but strongest long-term value because it reduces maintenance effort and repeated rework.
- Option C - Map current ownership first (Discovery Option)
    - 🧭 Resolution: 🔵 Discovery ▰▰▱▱▱
    - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
    - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
    - 🔮 Future Impact: 🟢 -1 Improves ▰▰▱▱▱
    - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
    - 🧾 Decision Note: Good when facts are weak; improves decision quality but delays visible improvement.
```

Bad example:

```text
⚖️ Option Value Summary:
- Option A: Low effort.
- Option B: Best.
- Option C: Maybe.
```

This is too shallow and biased.

Another bad example:

```text
⚖️ Option Value Summary:
- Option A + C + E should be done together.
```

This breaks the Independent Option Rule. If several actions belong together, create one Combined Path Option that describes that path.

---

## 9.5 ✅ Good Result

Good Result describes what would make the issue worthwhile from a value perspective across acceptable option paths.

It should not be a progress update. It is a result criterion.

Good examples:

```text
Future installer changes require less investigation, create less rework, and consume less senior engineering attention.
```

```text
Users can complete the workflow without external tools or manual workaround steps.
```

```text
Support can diagnose the failure without escalating to engineering.
```

```text
The release path is safer because the compatibility risk is understood and controlled.
```

Bad examples:

```text
Work started.
```

```text
Issue in progress.
```

```text
Team aligned.
```

These are status statements, not good results.

---

# 10. Recommendation

Recommendation is separate from Options and Value Assessment.

Options describe possible paths.
Value Assessment compares what value the options offer.
Recommendation says which one option is currently preferred and why.

The recommendation line must always include timestamp, author, recommendation, and support level. Do not leave author empty. If an LLM writes the recommendation, name it as the author.

Use local project time unless the project defines another timezone.

Good:

```markdown
### 🏁 Recommendation

- [2026-05-30 14:30 | Author: GPT-5.5 Thinking | Recommendation: Prefer Option B | Support: 2/3 Reasoned ▰▰▱]
```

Good when more facts are needed:

```markdown
### 🏁 Recommendation

- [2026-05-30 16:00 | Author: Composer | Recommendation: Prefer Option C | Support: 2/3 Reasoned ▰▰▱]
```

This is good only when Option C is a Discovery Option that clearly describes which facts will be gathered and what decision it enables.

Bad:

```markdown
### 🏁 Recommendation

- [2026-05-30 16:00 | Author: Composer | Recommendation: Needs More Facts | Support: 2/3 Reasoned ▰▰▱]
```

Bad:

```markdown
### 🏁 Recommendation

- [2026-05-30 | Author: Composer | Recommendation: A + C + E + G + I | Support: 2/3 Reasoned ▰▰▱]
```

The bad examples have one or more problems:

1. The timestamp is incomplete.
2. The recommendation does not select an option.
3. The recommendation bundles multiple option fragments instead of selecting one independently selectable option.

---

## 10.1 Recommendation Line Format

```markdown
### 🏁 Recommendation

- [YYYY-MM-DD HH:mm | Author: <required author name> | Recommendation: <Prefer Option X or Choose Option X> | Support: <support level>]

Reasoning:
<Explain why this one option is currently recommended. Mention the tradeoff honestly.>

Required Checks:
<State what must be checked before this recommendation becomes a final decision.>
```

The author is mandatory because recommendations are judgements. A judgement should have a source.

The timestamp is mandatory because recommendations age. A recommendation made before facts changed should be easy to identify.

The recommendation must reference one option.

---

## 10.2 Recommendation Types

```text
Recommendation:
Prefer Option A
Prefer Option B
Prefer Option C
Prefer Option D
Choose Option A
Choose Option B
Choose Option C
Choose Option D
```

Use Prefer Option X when the option is currently favored but not final.

Use Choose Option X when the decision is made.

Do not use recommendation types such as:

```text
Needs More Facts
Needs Decision
Split Issue
Defer
Reject
A + C + E
```

When those are the right direction, they must exist as independently selectable options first.

Examples:

```text
Needs More Facts → create a Discovery Option, then recommend that option.
Needs Decision → create a Decision Option, then recommend that option.
Split Issue → create a Split Option, then recommend that option.
Defer → create a Defer Option, then recommend that option.
Reject → create a Reject Option, then recommend that option.
A + C + E → create one Combined Path Option, then recommend that option.
```

---

## 10.3 Support Level

Support describes how well the recommendation is backed by facts, checked assumptions, understood tradeoffs, and value assessment.

```text
Support:
1/3 Thin ▰▱▱
2/3 Reasoned ▰▰▱
3/3 Well Supported ▰▰▰
```

Use 1/3 Thin when important facts are missing, the recommendation is mostly a working guess, or the issue still needs investigation.

Use 2/3 Reasoned when the recommendation has a clear argument and known tradeoffs, but some checks remain.

Use 3/3 Well Supported when facts, constraints, risks, value, and tradeoffs are well understood, and only normal implementation uncertainty remains.

Support is not certainty. It says how much backing the recommendation currently has.

A Discovery Option or Decision Option can still have Support: 2/3 Reasoned when the reason for gathering facts or making a decision is clear.

---

## 10.4 Recommendation Rules

A recommendation must explain the tradeoff. Do not only say which option is preferred.

Good:

```text
Option B is recommended because it solves the duplicated error ownership problem. Option A is cheaper, but it only improves wording and leaves the internal structure unchanged.
```

Bad:

```text
Option B is better.
```

If more facts are needed, the recommendation should point to a Discovery Option and name the missing facts in the option and reasoning.

If a decision is needed, the recommendation should point to a Decision Option and name the decision in the option and reasoning.

If splitting is needed, the recommendation should point to a Split Option and name what stays and what moves out.

If deferring is needed, the recommendation should point to a Defer Option and explain the revisit condition.

If rejecting is needed, the recommendation should point to a Reject Option and explain why the issue should not be pursued.

If the recommendation would need to combine several option letters, rewrite the options first. The recommendation should be the result of good option design, not a workaround for fragmented options.

The Recommendation may refer to the Value Assessment, but it must remain a separate judgement.

---

# 11. Stakeholder Success Note

Stakeholder Success Note is written after Recommendation.

It is not part of the value judgement. It is communication packaging.

Stakeholder Success Note answers:

```text
Who should be told when this is solved?
In what language should it be explained?
What 3-4 line message can be reused in mail, chat, release notes, or project updates?
```

Use this format:

```markdown
### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: <role or group to inform when this is solved>
- 🗣 Communication Lens: <business, product, support, release, trust, or technical summary>
- 📬 Success Note: <3-4 lines that can be reused in mail, chat, release notes, or a project update>
```

Stakeholder Success Note must not bias the Value Assessment. It is written for communication after a path is recommended or completed.

---

## 11.1 👥 Stakeholder Role

Stakeholder Role identifies the role or group that should be informed when this issue is solved.

Use roles, not personal names.

```text
👥 Stakeholder Role:
🔧 Engineering
🧑‍💼 Product Owner
🧑‍💼 Product Management
🛟 Support / Customer Success
📡 Operations
🛡 Security / Compliance
🚚 Release Owner
🏢 Leadership
👥 Customer / User Representative
```

Use 🔧 Engineering when the value is mainly technical correctness, maintainability, tests, architecture, or future change safety.

Use 🧑‍💼 Product Owner when the value affects product direction, backlog priority, user workflows, adoption, or tradeoff decisions.

Use 🧑‍💼 Product Management when the value affects roadmap, positioning, adoption, retention, customer-facing capability, or opportunity.

Use 🛟 Support / Customer Success when the value affects diagnosis, tickets, escalations, customer communication, or user recovery.

Use 📡 Operations when the value affects runtime behavior, deployment, observability, recovery, incidents, or operational reliability.

Use 🛡 Security / Compliance when the value affects trust, policy, auditability, access, risk, compliance, or safety boundaries.

Use 🚚 Release Owner when the value affects rollout, migration, compatibility, release safety, or rollback risk.

Use 🏢 Leadership when the value affects broad delivery risk, cost exposure, organizational trust, major adoption, or cross-team coordination.

Use 👥 Customer / User Representative when the value should be explained in user-facing language or validated with user needs.

---

## 11.2 🗣 Communication Lens

Communication Lens describes how the success should be explained.

```text
🗣 Communication Lens:
💼 Business Summary
🧑‍💼 Product Summary
🛟 Support Summary
🚚 Release Summary
🛡 Trust / Risk Summary
🔧 Technical Summary
```

Use 💼 Business Summary when the message should focus on cost, risk, value, capacity, adoption, or organizational impact.

Use 🧑‍💼 Product Summary when the message should focus on user workflow, capability, adoption, retention, or product quality.

Use 🛟 Support Summary when the message should focus on tickets, diagnosis, recovery, customer communication, or escalation reduction.

Use 🚚 Release Summary when the message should focus on rollout safety, compatibility, migration, release readiness, or rollback risk.

Use 🛡 Trust / Risk Summary when the message should focus on safety, compliance, policy, auditability, or trust.

Use 🔧 Technical Summary when the message should focus on engineering quality, maintainability, tests, architecture, or implementation clarity.

---

## 11.3 📬 Success Note

Success Note is a short message that can be reused when the issue is solved.

It should be 3-4 lines, plain-language, and written for the Stakeholder Role.

It should explain:

* what changed
* why it matters
* what value was created
* what limitation remains, if the result is partial

It should not claim more than the issue actually solved.

If the issue reduced risk but did not remove it, say reduced, not eliminated.
If the issue partially improved the situation, say partial.
If the issue produced facts instead of implementation, say the result is a better decision path.
If the issue is internal, write the note in business-readable language without unnecessary code detail.

Example:

```text
Installer adoption and removal rules are now clearer and easier to maintain.
Future installer-related changes should require less investigation and create less rework.
This reduces engineering friction around setup behavior and makes future product changes in this area safer.
```

Another example:

```text
The workflow can now be completed directly inside the product.
This removes a manual workaround and makes the product easier to adopt for users who need this capability.
The improvement strengthens the product's practical value in day-to-day use.
```

Another example:

```text
The compatibility risk for this release path has been reduced.
The affected behavior is now better understood and covered by the chosen implementation.
This lowers the chance of rollback or unexpected release disruption.
```

---

# 12. Decisions

Decisions capture what has already been settled and what is still open.

---

## 12.1 ✅ Resolved Decisions

Use this section for decisions already made. A resolved decision should include the decision, reason, and consequence.

```markdown
### ✅ Resolved Decisions

- Decision: Resolver error cleanup will not rename public CLI flags.
  Reason: Flag naming is broader than error handling and would expand the issue shape.
  Consequence: Flag naming is out of scope and may become extracted work if still valuable.
```

Do not bury decisions inside prose. Decisions should be easy to scan.

---

## 12.2 ❓ Open Decisions

Use this section for decisions still required before implementation can start or finish.

```markdown
### ❓ Open Decisions

- Should resolver errors use one shared internal model, or should each resolver path own its own message construction?
- Should machine-readable error output be considered now, or explicitly excluded?
- Do existing tests or downstream tools depend on exact message text?
```

Open decisions are not todos. They are unresolved choices that affect design, scope, or implementation.

If an open decision blocks a responsible recommendation, create a Decision Option in Options.

---

# 13. Out of Scope

Out of Scope says what this issue explicitly will not solve.

This prevents hidden scope creep.

```markdown
### 🚫 Out of Scope

- Renaming public CLI flags.
- Adding machine-readable error output.
- Changing resolver behavior.
- Reworking planner diagnostics.
```

Out of Scope is also a decision section. It records boundaries.

If an out-of-scope item is important enough to preserve, put it under Extracted Work. If not, leave it only in Out of Scope.

---

# 14. Extracted Work

Extracted Work replaces generic "follow-up issues."

Do not add this section just because a template expects "next steps." Most issues should not produce extracted work.

Use Extracted Work only when a real separate issue should exist because of a split, chosen option, rejected option, partial resolution, or explicit out-of-scope boundary.

---

## 14.1 Extracted Work Threshold

Only add extracted work when all of these are true:

1. It is a real separate issue, not a vague reminder.
2. It has a different owner, scope, option path, or acceptance condition.
3. It can receive its own issue rating.
4. It should not be silently forgotten.
5. It is not already covered by the current issue's Required Outcome.

If these conditions are not met, do not list it.

---

## 14.2 Extracted Work Format

```markdown
### 🌱 Extracted Work

Required:
- [ ] <Issue title>
  Reason: <Why this must become separate work.>

Optional:
- [ ] <Issue title>
  Reason: <Why this may be useful later, but is not required now.>
```

Use Required only when the current issue cannot be honestly resolved without creating or tracking the separate work.

Use Optional when the idea may be useful later but is not required for the current issue.

If there is no extracted work, omit the section entirely or write:

```markdown
### 🌱 Extracted Work

None.
```

---

# 15. Full Issue Template

```markdown
---
---

## 📌 <Issue Title>

- 🏷 Rating

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🚦 Priority | 3/7 Low | ▰▰▰▱▱▱▱ | <40-60 char reason delay is acceptable> |
| 🛠 Effort | 2/4 Moderate | ▰▰▱▱ | <40-60 char reason for delivery load> |
| 🧠 Complexity | 2/5 Normal | ▰▰▱▱▱ | <40-60 char reason for reasoning load> |
| 🌍 Benefit | 0/4 Internal | ▱▱▱▱ | <40-60 char reason for beneficiary scope> |
| 📦 Shape | 2/4 Composite | ▰▰▱▱ | <40-60 char reason for issue shape> |
| 🎯 Quality | 🧱 Maintainability | - | <40-60 char reason for quality type> |
| 🚧 Readiness | 🟠 Needs Refinement | - | <40-60 char reason work is not ready> |

### 📝 Statement

<Describe the issue, request, report, pain point, or requirement in clear language. Include original wording when useful.>

Original report:

> <Optional raw original text.>

### 🧭 Related Context

Related Issues:
- <Issue or topic that may be connected.>

Affected Areas:
- <Code area, workflow, command, schema, document, or user group.>

May Influence:
- <Later issue, design direction, migration path, or compatibility concern.>

Dependencies:
- <Decision, issue, access, approval, or fact this issue may depend on.>

### 🎯 Required Outcome

<Describe what must be true when this issue is resolved. Avoid implementation detail unless already decided.>

### 🔎 Facts

Known:
- <Verified fact.>
- <Verified fact.>

Unknown:
- <Fact still to gather.>
- <Fact still to gather.>

---

### 🧩 Options

#### Option A - <Short option name> (<Option Kind>)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | <resolution> | <meter> | <40-60 char reason this path resolves enough> |
| 🛠 Option Effort | <option effort> | <meter> | <40-60 char reason for delivery load> |
| 🧠 Option Complexity | <option complexity> | <meter> | <40-60 char reason for reasoning load> |
| 🔮 Future Impact | <future impact> | <meter> | <40-60 char reason for later cost> |
| ↩️ Reversibility | <reversibility> | <meter> | <40-60 char reason for undo cost> |
| 🧬 Integration | <integration> | - | <40-60 char reason for design fit> |
| 🤖 Agent Difficulty | <agent difficulty> | <meter> | <40-60 char reason for review need> |
| 🧾 Agent Work | <agent work> | - | <40-60 char reason for task type> |

Description:
<Explain the option in plain language. Say what this option does, why someone might choose it, and what tradeoff it makes. This should be a short paragraph of 3 to 6 sentences, not a slogan. The option must be independently selectable; it must describe one coherent path that could be recommended on its own.>

Current State:
<Describe how the issue looks today if this option is not implemented. Focus on the visible behavior, code structure, workflow, risk, or missing information that currently exists.>

Resulting State:
<Describe how the issue would look after this option is implemented. Paint a clear picture of the changed behavior, structure, workflow, or decision state. A future reader should understand what improves without needing the original discussion.>

Solves:
- <What this option fixes, improves, clarifies, decides, discovers, splits, defers, or rejects.>

Leaves Open:
- <What this option does not solve.>

Risks:
- <What could go wrong.>

Later Cost:
- <What this option may make harder later.>

---

#### Option B - <Short option name> (<Option Kind>)

- 🧾 Option Profile

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🧭 Resolution | <resolution> | <meter> | <40-60 char reason this path resolves enough> |
| 🛠 Option Effort | <option effort> | <meter> | <40-60 char reason for delivery load> |
| 🧠 Option Complexity | <option complexity> | <meter> | <40-60 char reason for reasoning load> |
| 🔮 Future Impact | <future impact> | <meter> | <40-60 char reason for later cost> |
| ↩️ Reversibility | <reversibility> | <meter> | <40-60 char reason for undo cost> |
| 🧬 Integration | <integration> | - | <40-60 char reason for design fit> |
| 🤖 Agent Difficulty | <agent difficulty> | <meter> | <40-60 char reason for review need> |
| 🧾 Agent Work | <agent work> | - | <40-60 char reason for task type> |

Description:
<Explain the option in plain language.>

Current State:
<Describe the current state.>

Resulting State:
<Describe the resulting state.>

Solves:
- <What this option solves.>

Leaves Open:
- <What remains open.>

Risks:
- <Risk.>

Later Cost:
- <Later cost.>

---

### 💶 Value Assessment

- 💎 Value Type: <primary value type>
- 🧭 Value Direction: <cost, risk, opportunity, or decision>
- 🧾 Value Mechanism: <how the issue creates value, avoids waste, reduces risk, or enables upside>
- ⚖️ Option Value Summary:
  - Option A - <short option name> (<option kind>)
    - 🧭 Resolution: <resolution, including meter>
    - 🛠 Option Effort: <option effort, including meter>
    - 🧠 Option Complexity: <option complexity, including meter>
    - 🔮 Future Impact: <future impact, including meter>
    - 🤖 Agent Difficulty: <agent difficulty, including meter>
    - 🧾 Decision Note: <short value and effort judgement>
  - Option B - <short option name> (<option kind>)
    - 🧭 Resolution: <resolution, including meter>
    - 🛠 Option Effort: <option effort, including meter>
    - 🧠 Option Complexity: <option complexity, including meter>
    - 🔮 Future Impact: <future impact, including meter>
    - 🤖 Agent Difficulty: <agent difficulty, including meter>
    - 🧾 Decision Note: <short value and effort judgement>
- ✅ Good Result: <what would make the issue worthwhile across the acceptable option paths>

---

### 🏁 Recommendation

- [YYYY-MM-DD HH:mm | Author: <required author name> | Recommendation: <Prefer Option X or Choose Option X> | Support: <support level>]

Reasoning:
<Explain why this one option is currently recommended. Mention the tradeoff honestly.>

Required Checks:
<State what must be checked before this recommendation becomes a final decision.>

### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: <role or group to inform when this is solved>
- 🗣 Communication Lens: <business, product, support, release, trust, or technical summary>
- 📬 Success Note: <3-4 lines that can be reused in mail, chat, release notes, or a project update>

### ✅ Resolved Decisions

- Decision: <Decision already made.>
  Reason: <Why this decision was made.>
  Consequence: <What this changes or excludes.>

### ❓ Open Decisions

- <Decision still needed.>
- <Decision still needed.>

### 🚫 Out of Scope

- <Explicitly excluded item.>
- <Explicitly excluded item.>

### 🌱 Extracted Work

Required:
- [ ] <Only include if a separate issue must exist.>
  Reason: <Why this must be tracked separately.>

Optional:
- [ ] <Only include if valuable but not required now.>
  Reason: <Why this may be useful later.>
```

---

# 16. Small Issue Template

Use this only when the issue is simple, ready, and does not need option analysis.

```markdown
---
---

## 📌 <Issue Title>

- 🏷 Rating

| Field | Rating | Meter | Rationale |
| --- | --- | --- | --- |
| 🚦 Priority | 4/7 Normal | ▰▰▰▰▱▱▱ | <40-60 char reason this is planned work> |
| 🛠 Effort | 1/4 Trivial | ▰▱▱▱ | <40-60 char reason for small delivery> |
| 🧠 Complexity | 1/5 Simple | ▰▱▱▱▱ | <40-60 char reason the path is clear> |
| 🌍 Benefit | 2/4 Individual | ▰▰▱▱ | <40-60 char reason for beneficiary scope> |
| 📦 Shape | 0/4 Atomic | ▱▱▱▱ | <40-60 char reason this is one change> |
| 🎯 Quality | 🧭 Usability | - | <40-60 char reason for quality type> |
| 🚧 Readiness | 🟢 Ready | - | <40-60 char reason work can start> |

### 📝 Statement

<What is wrong, missing, requested, or required?>

### 🧭 Related Context

None known.

### 🎯 Required Outcome

<What must be true when done?>

### 🔎 Facts

Known:
- <Verified fact.>

Unknown:
- <Only include if relevant.>

### 💶 Value Assessment

- 💎 Value Type: <primary value type>
- 🧭 Value Direction: <cost, risk, opportunity, or decision>
- 🧾 Value Mechanism: <how the issue creates value, avoids waste, reduces risk, or enables upside>
- ⚖️ Option Value Summary:
  - Direct Fix - <short fix name> (Implementation Option)
    - 🧭 Resolution: 🟢 Full ▰▰▰▰▰
    - 🛠 Option Effort: <effort, including meter>
    - 🧠 Option Complexity: <complexity, including meter>
    - 🔮 Future Impact: <future impact, including meter>
    - 🤖 Agent Difficulty: <agent difficulty, including meter>
    - 🧾 Decision Note: <short value and effort judgement>
- ✅ Good Result: <what would make the issue worthwhile>

### 🏁 Recommendation

- [YYYY-MM-DD HH:mm | Author: <required author name> | Recommendation: Choose Direct Fix | Support: <support level>]

Reasoning:
<Explain why the direct fix is recommended.>

Required Checks:
<State what must be checked before this recommendation becomes final, if anything.>

### 📬 Stakeholder Success Note

- 👥 Stakeholder Role: <role or group to inform when this is solved>
- 🗣 Communication Lens: <business, product, support, release, trust, or technical summary>
- 📬 Success Note: <3-4 lines that can be reused in mail, chat, release notes, or a project update>

### 🚫 Out of Scope

- <Only include if relevant.>
```

Use the full template when the issue has Shape: 2/4 Composite or higher, Readiness: Needs Refinement, multiple options, unresolved design questions, meaningful scope risk, or possible extracted work.

Use the small template only when the solution path is obvious enough that a separate option comparison would add noise.

---

# 17. Practical Rules

If an issue is Shape: 0/4 Atomic or Shape: 1/4 Focused, it may not need multiple options.

If an issue is Shape: 2/4 Composite, options should usually include at least one split, partial-resolution, discovery, decision, or reframed implementation path.

If an issue is Shape: 3/4 Epic / Theme, use it as a parent issue and create child issues only when the child issues are real, ratable, and separately useful.

If an issue is Shape: 4/4 Dump / Catch-all, do not implement it. Rewrite it, split it, reframe it, or convert it into discovery.

If an option has 🔮 Future Impact: 🔴 +2 Rewrite Risk, do not choose it casually. It may still be valid, but it should be explicit debt.

If an option has 🧭 Resolution: 🟡 Partial, it must say what remains open.

If an option has 🧭 Resolution: 🔵 Discovery, it must say what facts, map, prototype, or evidence it will produce.

If an option has 🧭 Resolution: 🟣 Decision, it must say which decision it will produce and who or what role is expected to decide.

If an option has 🧭 Resolution: 🧩 Split, it must say what stays here and what becomes separate.

If an option has 🧭 Resolution: ⚪ Defer, it must say the revisit condition.

If an option has 🧭 Resolution: 🔴 Reject, it must say why the issue should not be pursued.

If an option has 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱ or 🤖 Agent Difficulty: 4/4 Human-Led ▰▰▰▰, require human review before merging implementation work.

If an option cannot be selected independently, rewrite it. Do not let the recommendation become a bundle of option letters.

If the best path combines several actions, create one coherent Combined Path Option and recommend that option.

If the issue can be made much simpler by changing the framing while preserving the real concern, create a Reframed Implementation Option.

Do not add `Reframe` as a Resolution value. Reframing is an option kind, not an outcome.

Write Value Assessment after Options. Do not write it before Options.

Value Assessment must compare what the options show. It must not be a stakeholder preference disguised as economics.

Value Assessment should summarize option value and effort tradeoffs, but it must not choose the option by itself.

Option Value Summary should use compact multi-line option snapshots. Do not force all option fields into one long line.

Option Value Summary should include Option Kind, Resolution, Option Effort, Option Complexity, Future Impact, Agent Difficulty, and a Decision Note by default.

Option Value Summary may include Reversibility, Integration, or Agent Work only when they are decision-relevant.

Recommendation must reference one option or the small-template Direct Fix. Do not use `Needs More Facts`, `Needs Decision`, `Split Issue`, `Defer`, `Reject`, or option-letter bundles as recommendation values.

Recommendation chooses one option after facts, options, and value assessment are visible.

Stakeholder Success Note belongs after Recommendation. It packages communication; it must not drive the option analysis.

If the Success Note would overclaim, rewrite it. A Success Note must match what the issue actually solved or what the recommended option can honestly deliver.

If the result is partial, the Success Note must say the improvement is partial.

If the result reduces risk but does not remove it, the Success Note must say reduced, not eliminated.

Use roles, not personal names, for Stakeholder Role.

If something is excluded, put it in Out of Scope. Do not rely on memory.

If a decision is made, put it in Resolved Decisions. Do not leave it hidden in discussion.

If there is no real extracted work, omit Extracted Work or write None.

If an LLM writes a recommendation, the LLM must be named as the author. Do not write `Author: <name missing>`.

Use `YYYY-MM-DD HH:mm` in recommendation lines. Recommendations age and should be timestamped.

Use dividers to protect readability. In long issue files, poor separation makes options, value assessment, and decisions hard to review.

Option descriptions should be verbose enough to preserve the idea. Do not compress them into slogans.

Use Description, Current State, and Resulting State together when an option is important. This makes the option easier to judge without needing the original discussion.

Use chips to clarify state, value direction, and risk. Do not add chips where they create noise.

Keep chip meanings consistent. For example, use `🟢 -2 Simplifies` and `🟢 -1 Improves` for helpful Future Impact values, not a mixture such as `✅ -2 Simplifies` and `🟢 -1 Improves`.

---

# 18. Final Rule

The rating classifies the issue.
The rating table layout keeps ratings readable.
The visual meters make ordered ratings easier to scan.
The semantic chips make states, categories, value direction, and risks easier to read.
The section icons make issue documents easier to navigate.
The dividers separate large issue blocks and option blocks.
The statement explains the issue.
The related context shows connections.
The required outcome defines success.
The facts ground the issue.
The options compare possible paths.
Each option must be independently selectable.
Each option has an explicit option kind in the option heading.
The option kind describes what kind of path the option is.
The resolution describes what the option achieves.
A reframed implementation option preserves the original concern while changing the framing to make the work simpler or better aligned.
The value assessment is written after options and compares what value the options offer.
The option value summary gives decision-makers readable snapshots of option kind, value, effort, complexity, future impact, agent difficulty, and judgement.
The value assessment must remain neutral and must not be written as stakeholder preference.
The recommendation chooses one option.
The stakeholder success note packages the result for communication after recommendation or completion.
The option profile shows the cost, risk, future impact, and agent suitability of each path.
The rating rationale after each profile value explains why that rating was chosen.
The option description explains the idea and tradeoff.
The current state shows the world before the option.
The resulting state shows the world after the option.
The recommendation timestamp shows when the judgement was made.
The support level says how well-backed the recommendation is.
The resolved decisions record what has been chosen.
The open decisions show what is still unresolved.
The out-of-scope section protects the boundary.
The extracted work section exists only when separate work is real, necessary, and worth preserving.
