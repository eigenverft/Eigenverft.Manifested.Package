# Project Issue Framework V1.1

Version: V1.1
Purpose: A readable Markdown framework for defining, rating, comparing, and deciding project issues.

This framework has two layers:

1. Issue Rating — classifies the issue as it currently exists.
2. Issue Definition — describes the issue, related context, known facts, possible options, recommendation, decisions, and scope.

The issue rating answers: What kind of issue is this right now?
The issue definition answers: What do we know, what is connected, what can we do, what do we recommend, what is decided, and what is excluded?

---

# 1. Visual Style

Use a small, consistent visual system. The goal is fast scanning in Markdown without turning the document into decoration.

There are three visual layers:

1. Icons identify the field.
2. Meters show ordered numeric ratings.
3. Chips show state, category, or risk for fields that do not use meters.

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

- `▰▱` has a clear filled/unfilled pair.
- It is readable in plain Markdown.
- It looks like a dashboard meter rather than a review score.
- It avoids the emotional meaning of stars.
- It works for effort, complexity, support, agent difficulty, and similar scales.

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
🟣 Strategic / design direction
⚪ Neutral / deferred / inactive
🧩 Split / structuring
```

Use chips sparingly. Do not add a chip when it does not clarify the meaning.

Chip consistency rules:

- Use 🟢 for clearly favorable states.
- Use 🟡 for acceptable but incomplete states.
- Use 🟠 for caution or debt.
- Use 🔴 for risk, rejection, blockage, or harmful direction.
- Use 🔵 for informational or discovery states.
- Use 🟣 for strategic direction.
- Use ⚪ for neutral or deferred states.
- Use 🧩 only when the meaning is specifically splitting or structuring.

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
🏁 Recommendation
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

Use one icon per rating dimension:

```text
🚦 Priority
🛠 Effort
🧠 Complexity
🌍 Benefit
📦 Shape
🎯 Quality
🚧 Readiness
```

Use one icon per option-only dimension:

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

---

# 2. Issue Rating Legend

Use one readable vertical rating block for every issue.

Do not write the whole rating in one long line inside normal issue definitions. Long one-line ratings become hard to scan and hard to edit.

Use this vertical format:

```markdown
- 🏷 Rating
  - 🚦 Priority: 2/6 High ▰▰▰▰▰▱▱
  - 🛠 Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Complexity: 3/5 Complex ▰▰▰▱▱
  - 🌍 Benefit: 3/4 Team ▰▰▰▱
  - 📦 Shape: 1/4 Focused ▰▱▱▱
  - 🎯 Quality: 🧭 Usability
  - 🚧 Readiness: 🟢 Ready
```

The number is the source of truth. The meter is only a visual aid. Unordered dimensions such as Quality, Readiness, and Agent Work do not use meters.

Do not use short codes like `P2`, `E2`, `C3`, or `Q:U` in normal issue text.

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

Priority measures consequence of delay. Lower number means more urgent. The meter shows urgency strength.

```text
🚦 Priority:
0/6 Blocker  ▰▰▰▰▰▰▰
1/6 Critical ▰▰▰▰▰▰▱
2/6 High     ▰▰▰▰▰▱▱
3/6 Normal   ▰▰▰▰▱▱▱
4/6 Low      ▰▰▰▱▱▱▱
5/6 Backlog  ▰▰▱▱▱▱▱
6/6 Polish   ▰▱▱▱▱▱▱
```

Use 0/6 Blocker when work, release, build, migration, deployment, or production use cannot continue.
Use 1/6 Critical for serious correctness, security, trust, data-loss, compliance, or rollout risk.
Use 2/6 High for important work that should be scheduled soon.
Use 3/6 Normal for useful planned work with no immediate pressure.
Use 4/6 Low for worthwhile but safely deferrable work.
Use 5/6 Backlog for possible future work that should stay visible but not be planned yet.
Use 6/6 Polish for optional refinement, visual cleanup, consistency, or taste-level improvement.

---

## 2.3 🛠 Effort

Effort measures delivery load. Higher number means more delivery work.

```text
🛠 Effort:
1/4 Trivial     ▰▱▱▱
2/4 Moderate    ▰▰▱▱
3/4 Substantial ▰▰▰▱
4/4 Major       ▰▰▰▰
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
1/5 Simple  ▰▱▱▱▱
2/5 Normal  ▰▰▱▱▱
3/5 Complex ▰▰▰▱▱
4/5 Hard    ▰▰▰▰▱
5/5 Extreme ▰▰▰▰▰
```

Use 1/5 Simple when the problem and solution are obvious.
Use 2/5 Normal when normal project knowledge is enough.
Use 3/5 Complex when deep system understanding or careful tradeoffs are needed.
Use 4/5 Hard when design, research, prototyping, or expert review may be needed.
Use 5/5 Extreme for foundational, open-ended, research-level, or system-defining work.

Complexity is not Effort. A race condition fix can be low effort but high complexity. “Create a new operating system” can be clearly stated but still extreme.

---

## 2.5 🌍 Benefit

Benefit measures who benefits if this ships. Higher number means broader reach.

```text
🌍 Benefit:
0/4 Internal     ▱▱▱▱
1/4 Producer     ▰▱▱▱
2/4 Individual   ▰▰▱▱
3/4 Team         ▰▰▰▱
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
0/4 Atomic           ▱▱▱▱
1/4 Focused          ▰▱▱▱
2/4 Composite        ▰▰▱▱
3/4 Epic / Theme     ▰▰▰▱
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

Use visible dividers to separate large sections. This is important because options and recommendations can become long.

Use this divider between full issues:

```markdown
---
---
```

Use this divider before the Options section and before Recommendation:

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

#### Option A — First path

...

---

#### Option B — Second path

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
  - 🚦 Priority: 4/6 Low ▰▰▰▱▱▱▱
  - 🛠 Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Complexity: 2/5 Normal ▰▰▱▱▱
  - 🌍 Benefit: 0/4 Internal ▱▱▱▱
  - 📦 Shape: 2/4 Composite ▰▰▱▱
  - 🎯 Quality: 🧱 Maintainability
  - 🚧 Readiness: 🟠 Needs Refinement

### 📌 Resolver failure messages are not actionable

- 🏷 Rating
  - 🚦 Priority: 2/6 High ▰▰▰▰▰▱▱
  - 🛠 Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Complexity: 2/5 Normal ▰▰▱▱▱
  - 🌍 Benefit: 3/4 Team ▰▰▰▱
  - 📦 Shape: 1/4 Focused ▰▱▱▱
  - 🎯 Quality: 🧭 Usability
  - 🚧 Readiness: 🟢 Ready

### 🌱 Add consistency tests for resolver diagnostics

- 🏷 Rating
  - 🚦 Priority: 3/6 Normal ▰▰▰▰▱▱▱
  - 🛠 Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Complexity: 2/5 Normal ▰▰▱▱▱
  - 🌍 Benefit: 0/4 Internal ▱▱▱▱
  - 📦 Shape: 1/4 Focused ▰▱▱▱
  - 🎯 Quality: 🧱 Maintainability
  - 🚧 Readiness: 🟢 Ready
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
  - 🚦 Priority: 4/6 Low ▰▰▰▱▱▱▱
  - 🛠 Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Complexity: 2/5 Normal ▰▰▱▱▱
  - 🌍 Benefit: 0/4 Internal ▱▱▱▱
  - 📦 Shape: 2/4 Composite ▰▰▱▱
  - 🎯 Quality: 🧱 Maintainability
  - 🚧 Readiness: 🟠 Needs Refinement

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

#### Option A — <Short option name>

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟡 Temporary
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 💻 Local Code

Description:
<Explain the option in plain language. Say what this option does, why someone might choose it, and what tradeoff it makes. This should be a short paragraph of 3 to 6 sentences, not a slogan.>

Current State:
<Describe how the issue looks today if this option is not implemented. Focus on the visible behavior, code structure, workflow, risk, or missing information that currently exists.>

Resulting State:
<Describe how the issue would look after this option is implemented. Paint a clear picture of the changed behavior, structure, workflow, or decision state. A future reader should understand what improves without needing the original discussion.>

Solves:
- <What this option fixes, improves, or clarifies.>

Leaves Open:
- <What this option does not solve.>

Risks:
- <What could go wrong.>

Later Cost:
- <What this option may make harder later.>

---

#### Option B — <Short option name>

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - 🔮 Future Impact: 🟢 -2 Simplifies
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟣 Strategic
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
  - 🧾 Agent Work: 🧠 System Logic

Description:
<Explain the option in plain language. Say what this option does, why someone might choose it, and what tradeoff it makes. This should be a short paragraph of 3 to 6 sentences, not a slogan.>

Current State:
<Describe how the issue looks today if this option is not implemented. Focus on the visible behavior, code structure, workflow, risk, or missing information that currently exists.>

Resulting State:
<Describe how the issue would look after this option is implemented. Paint a clear picture of the changed behavior, structure, workflow, or decision state. A future reader should understand what improves without needing the original discussion.>

Solves:
- <What this option fixes, improves, or clarifies.>

Leaves Open:
- <What this option does not solve.>

Risks:
- <What could go wrong.>

Later Cost:
- <What this option may make harder later.>

---

#### Option C — <Short option name>

- 🧾 Option Profile
  - 🧭 Resolution: 🔵 Discovery
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
  - 🧾 Agent Work: 🔎 Research / Mapping

Description:
<Explain the option in plain language. Say what this option does, why someone might choose it, and what tradeoff it makes. This should be a short paragraph of 3 to 6 sentences, not a slogan.>

Current State:
<Describe how the issue looks today if this option is not implemented. Focus on the visible behavior, code structure, workflow, risk, or missing information that currently exists.>

Resulting State:
<Describe how the issue would look after this option is implemented. Paint a clear picture of the changed behavior, structure, workflow, or decision state. A future reader should understand what improves without needing the original discussion.>

Solves:
- <What this option fixes, improves, clarifies, or discovers.>

Leaves Open:
- <What this option does not solve.>

Risks:
- <What could go wrong.>

Later Cost:
- <What this option may make harder later.>

---

#### Optional Split Option — <Only include when splitting is a real candidate>

- 🧾 Option Profile
  - 🧭 Resolution: 🧩 Split
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 🧩 Planning / Structuring

Description:
<Explain how this issue could be split into smaller issues. Say which part should stay here, which part should move out, why the split would make the work clearer or safer, and what risk the split creates.>

Current State:
<Describe why the current issue is bundled, unclear, or too large to handle safely as one item.>

Resulting State:
<Describe what the issue structure would look like after the split. Say what remains here and what becomes separate work.>

Creates:
- <Separate issue or concern that should receive its own rating.>

Keeps Here:
- <Part that remains in this issue.>

Risks:
- <What could be lost, delayed, or duplicated by splitting.>

Later Cost:
- <Extra coordination or cleanup created by the split.>

---

### 🏁 Recommendation

- [YYYY-MM-DD | Author: <required author name> | Recommendation: <recommendation> | Support: <support level>]

Reasoning:
<Explain why this option is currently recommended. Mention the tradeoff honestly.>

Required Checks:
<State what must be checked before this recommendation becomes a final decision.>

### ✅ Resolved Decisions

- Decision: <Decision already made.>
  Reason: <Why this decision was made.>
  Consequence: <What this changes or excludes.>

### ❓ Open Decisions

- <Decision still needed.>

### 🚫 Out of Scope

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

# 6. Section Rules

## 📌 Title

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

## 🏷 Rating

The issue rating describes the issue as it currently stands, before choosing an option.

Use vertical layout:

```markdown
- 🏷 Rating
  - 🚦 Priority: 4/6 Low ▰▰▰▱▱▱▱
  - 🛠 Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Complexity: 2/5 Normal ▰▰▱▱▱
  - 🌍 Benefit: 0/4 Internal ▱▱▱▱
  - 📦 Shape: 2/4 Composite ▰▰▱▱
  - 🎯 Quality: 🧱 Maintainability
  - 🚧 Readiness: 🟠 Needs Refinement
```

Do not use one-line rating blocks inside full issue definitions.

If the issue is split, each child issue receives its own rating.

---

## 📝 Statement

The Statement section explains the issue in human terms. It should say what was reported, requested, noticed, or required; why it matters; and what pain, risk, gap, or limitation exists today.

Preserve the original report when the raw wording carries useful intent:

```markdown
### 📝 Statement

The current resolver error handling is difficult to maintain because message construction is spread across several code paths. The original report asked to “clean up resolver errors,” but the underlying issue appears to mix duplicated formatting logic, inconsistent wording, and missing tests.

Original report:

> Clean up resolver errors. They are confusing and duplicated.
```

The Statement should be clear enough that someone can understand the issue without reading the full discussion history.

---

## 🧭 Related Context

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

## 🎯 Required Outcome

Required Outcome defines success without forcing a specific implementation. It should say what must be true after resolution and how the issue will be judged as done.

```markdown
### 🎯 Required Outcome

Resolver error construction should have one clear ownership model. Equivalent failures should use consistent wording, message structure, and test coverage. Future resolver errors should be easier to add without duplicating formatting logic.
```

Avoid implementation detail unless it has already been decided.

---

## 🔎 Facts

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

Options describe possible ways to handle the issue. An option can fully solve the issue, partly solve it, reduce the pain, gather facts, defer the work, reject the issue, or split it.

Options should be written in simple language. The option should let a future reader understand the world before and after the option.

A good option must explain:

- what would actually change
- what would stay the same
- why someone might choose this option
- what tradeoff the option makes
- how the current state looks
- how the resulting state would look
- whether it is a quick fix, full fix, discovery step, split, deferral, or rejection

Do not write abstract descriptions like:

```text
Introduce aligned remediation path for diagnostic consistency.
```

Prefer plain descriptions like:

```text
Change the visible error messages first, without changing the internal resolver structure. This makes the output easier to understand now, but it leaves the duplicated error-building code in place. This option is useful when quick user-facing improvement matters more than solving the internal structure immediately.
```

Option descriptions should usually be a short paragraph of 3 to 6 sentences. One sentence is usually too thin unless the option is trivial.

---

## 7.1 Description, Current State, and Resulting State

Use these three fields together:

```markdown
Description:
<Explain the option itself.>

Current State:
<Describe the situation before this option.>

Resulting State:
<Describe the situation after this option.>
```

Description explains the idea and tradeoff.
Current State grounds the option in today’s reality.
Resulting State paints the future picture after implementation.

Do not merge these fields into one vague paragraph when the option is important.

---

## Number of Options

Most issues should have two or three real options. Use options mainly for implementation and integration choices. Do not create many artificial options just to fill the template.

A fourth option is allowed only when it is a true Split Option. This is useful when the issue may be better handled as two or more smaller issues.

The split option is optional. It should not be forced.

Use a Split Option when the issue is Shape: 2/4 Composite or higher, one part can be solved now and another part should move later, different parts have different owners or acceptance conditions, solving everything together would make review harder, or a smaller first issue would reduce risk without hiding the remaining work.

Do not use a Split Option when the issue is already Atomic or Focused.

---

## Option Profile Format

Use vertical layout:

```markdown
- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟡 Temporary
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 💻 Local Code
```

The Option Profile is different from the Issue Rating.

The Issue Rating describes the problem.
The Option Profile describes the consequences of choosing this solution path.

---

## Option Profile Dimensions

### 🧭 Resolution

Resolution describes how the option handles the issue.

```text
🧭 Resolution:
🟢 Full
🟡 Partial
🟠 Mitigation
🔵 Discovery
🧩 Split
⚪ Defer
🔴 Reject
```

Use 🟢 Full when the option resolves the required outcome.
Use 🟡 Partial when the option solves part of the issue and leaves known work open.
Use 🟠 Mitigation when the option reduces pain or risk but does not solve the underlying issue.
Use 🔵 Discovery when the option gathers facts, prototypes, or produces a design decision.
Use 🧩 Split when the option turns one issue into smaller separately rated issues.
Use ⚪ Defer when the option intentionally postpones the issue.
Use 🔴 Reject when the option decides not to pursue the issue.

---

### 🛠 Option Effort

Option Effort measures delivery load for this option, not for the original issue.

```text
🛠 Option Effort:
1/4 Trivial     ▰▱▱▱
2/4 Moderate    ▰▰▱▱
3/4 Substantial ▰▰▰▱
4/4 Major       ▰▰▰▰
```

A partial option may be cheap even when the full issue is large.

---

### 🧠 Option Complexity

Option Complexity measures reasoning difficulty for this option, not for the original issue.

```text
🧠 Option Complexity:
1/5 Simple  ▰▱▱▱▱
2/5 Normal  ▰▰▱▱▱
3/5 Complex ▰▰▰▱▱
4/5 Hard    ▰▰▰▰▱
5/5 Extreme ▰▰▰▰▰
```

An option can make today’s work simpler while leaving harder work for later. That should be made visible through Future Impact and Later Cost.

---

### 🔮 Future Impact

Future Impact describes what choosing this option does to future work.

```text
🔮 Future Impact:
🟢 -2 Simplifies
🟢 -1 Improves
⚪  0 Neutral
🟠 +1 Adds Debt
🔴 +2 Rewrite Risk
```

Use 🟢 -2 Simplifies when the option strongly reduces future complexity, coupling, or migration cost.
Use 🟢 -1 Improves when the option slightly improves future work.
Use ⚪ 0 Neutral when the option does not meaningfully affect future work.
Use 🟠 +1 Adds Debt when the option is acceptable but leaves cleanup, inconsistency, or known later cost.
Use 🔴 +2 Rewrite Risk when the option is likely to cause rework, migration pain, incompatible design, or throwaway implementation.

Future Impact is the main guardrail against cheap options that quietly create expensive later work.

---

### ↩️ Reversibility

Reversibility describes how easy it is to undo or replace the option later.

```text
↩️ Reversibility:
🟢 Easy
🟡 Moderate
🟠 Hard
🔴 Irreversible
```

Use 🟢 Easy when the option can be changed later with little cost.
Use 🟡 Moderate when change is possible but requires planned cleanup.
Use 🟠 Hard when changing later would affect users, schema, contracts, or multiple subsystems.
Use 🔴 Irreversible when the option creates durable compatibility, policy, migration, or trust consequences.

---

### 🧬 Integration

Integration describes how the option fits into the long-term design.

```text
🧬 Integration:
🔵 Local
🟢 Compatible
🟣 Strategic
🟡 Temporary
🔴 Conflicting
```

Use 🔵 Local when the option is contained and does not define broader architecture.
Use 🟢 Compatible when the option fits the likely future direction.
Use 🟣 Strategic when the option directly advances the desired long-term design.
Use 🟡 Temporary when the option is intentionally short-lived.
Use 🔴 Conflicting when the option solves the near-term issue but works against the expected future design.

---

### 🤖 Agent Difficulty

Agent Difficulty estimates how suitable this option is for a coding agent.

```text
🤖 Agent Difficulty:
1/4 Routine   ▰▱▱▱
2/4 Guided    ▰▰▱▱
3/4 Strong    ▰▰▰▱
4/4 Human-Led ▰▰▰▰
```

Use 1/4 Routine when a coding agent can likely perform the work from clear instructions, with ordinary review. This fits simple edits, documentation, predictable refactors, mechanical changes, or local fixes with clear tests.

Use 2/4 Guided when a coding agent can likely help, but needs precise instructions, bounded scope, and human review. This fits local code changes, test additions, small behavior changes, or structured cleanup.

Use 3/4 Strong when only a strong coding agent should attempt the work, and human review is important. This fits cross-file logic, subtle behavior, non-obvious tests, integration changes, or code that requires understanding project architecture.

Use 4/4 Human-Led when the work should be led by a human, even if an agent can assist with drafts, exploration, tests, or mechanical edits. This fits architecture, security boundaries, migrations, public contracts, high-risk behavior, or decisions with long-term consequences.

Agent Difficulty is not a judgement of whether AI is allowed. It is a planning signal for how much supervision, review, and task decomposition are needed.

---

### 🧾 Agent Work

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

## Option Template

```markdown
#### Option A — <Short option name>

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟡 Temporary
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 💻 Local Code

Description:
Explain the option in plain language. Say what this option does, why someone might choose it, and what tradeoff it makes. This should be a short paragraph of 3 to 6 sentences, not a slogan.

Current State:
Describe how the issue looks today if this option is not implemented. Focus on the visible behavior, code structure, workflow, risk, or missing information that currently exists.

Resulting State:
Describe how the issue would look after this option is implemented. Paint a clear picture of the changed behavior, structure, workflow, or decision state. A future reader should understand what improves without needing the original discussion.

Solves:
- What this option fixes, improves, or clarifies.

Leaves Open:
- What this option does not solve.

Risks:
- What could go wrong.

Later Cost:
- What this option may make harder later.
```

---

## Split Option Template

```markdown
#### Optional Split Option — <Short split name>

- 🧾 Option Profile
  - 🧭 Resolution: 🧩 Split
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 🧩 Planning / Structuring

Description:
Explain how this issue could be split into smaller issues. Say which part should stay here, which part should move out, why the split would make the work clearer or safer, and what risk the split creates.

Current State:
Describe why the current issue is bundled, unclear, or too large to handle safely as one item.

Resulting State:
Describe what the issue structure would look like after the split. Say what remains here and what becomes separate work.

Creates:
- <Separate issue or concern that should receive its own rating.>

Keeps Here:
- <Part that remains in this issue.>

Risks:
- <What could be lost, delayed, or duplicated by splitting.>

Later Cost:
- <Extra coordination or cleanup created by the split.>
```

---

## Option Examples

### Cheap partial option

```markdown
#### Option A — Improve visible wording only

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 1/5 Simple ▰▱▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟡 Temporary
  - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
  - 🧾 Agent Work: 📝 Writing / Docs

Description:
Change the visible resolver error messages first, without changing the internal resolver structure. This option is useful when quick user-facing improvement matters more than solving the internal structure immediately. It is intentionally limited: it improves the text people see, but it does not redesign how errors are built internally. The tradeoff is that the duplicated error-building code remains in place, so another cleanup pass may still be needed later.

Current State:
Resolver errors are hard to understand because some messages are vague, inconsistent, or missing recovery hints. The internal error-building logic remains spread across several places.

Resulting State:
Users see clearer resolver error messages with better wording and recovery hints. The internal structure is still duplicated, but the immediate user-facing pain is reduced.

Solves:
- Makes several confusing messages easier to understand.
- Reduces immediate user pain.
- Can be done quickly.

Leaves Open:
- Error formatting remains duplicated.
- Error ownership remains unclear.
- Future messages may drift again.

Risks:
- The issue may look solved even though the internal structure is still weak.
- Another cleanup pass may be needed later.

Later Cost:
- A later shared error model may need to rewrite these messages again.
```

---

### Strategic full option

```markdown
#### Option B — Introduce a shared resolver error model

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - 🔮 Future Impact: 🟢 -2 Simplifies
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟣 Strategic
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
  - 🧾 Agent Work: 🧠 System Logic

Description:
Create one shared internal model for resolver failures. The resolver records the failure in a structured way, and the CLI turns that structure into human-readable text. This takes more work now, but it gives the project one clear place to improve resolver errors later. The tradeoff is that this option may expose unclear boundaries between resolver, planner, and CLI, so it needs more careful implementation and review.

Current State:
Resolver failures are represented and formatted in multiple places. Similar failures may produce inconsistent messages, and tests may not clearly enforce one shared message structure.

Resulting State:
Resolver failures have one shared internal representation. Human-readable messages are produced from that structure, making wording, tests, and future diagnostics easier to maintain.

Solves:
- Centralizes resolver error ownership.
- Makes wording and structure consistent.
- Makes tests easier to write.
- Creates a base for possible machine-readable error output later.

Leaves Open:
- Existing tools may depend on exact message text and need to be checked.

Risks:
- More work than simple wording cleanup.
- May expose unclear boundaries between resolver, planner, and CLI.

Later Cost:
- Lower future cost if resolver diagnostics continue to grow.
```

---

### Discovery option

```markdown
#### Option C — Map current resolver error ownership first

- 🧾 Option Profile
  - 🧭 Resolution: 🔵 Discovery
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
  - 🧾 Agent Work: 🔎 Research / Mapping

Description:
Do not change behavior yet. First, list where resolver errors are created today, which messages are user-facing, which messages are tested, and where ownership is unclear. This gives enough facts to choose a safer implementation option. The tradeoff is that users will not see immediate improvement, but the implementation risk becomes lower.

Current State:
The team does not yet have a complete map of where resolver errors are built, displayed, and tested. Choosing an implementation path may rely on assumptions.

Resulting State:
The team has a clear map of resolver error ownership and can decide whether wording cleanup, shared modeling, or splitting is the best next step.

Solves:
- Replaces assumptions with verified facts.
- Reduces risk before changing behavior.
- May show that the issue should be split.

Leaves Open:
- Does not directly improve user-facing errors.

Risks:
- Adds a refinement step before visible improvement.
- Could become wasted effort if the issue is already obvious enough.

Later Cost:
- Low. The result should either guide the chosen option or justify closing the investigation.
```

---

### Split option

```markdown
#### Optional Split Option — Separate wording cleanup from internal structure

- 🧾 Option Profile
  - 🧭 Resolution: 🧩 Split
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 🧩 Planning / Structuring

Description:
Split the issue into two parts. Keep the user-facing wording cleanup as the first issue, because it gives quick visible improvement. Move the shared internal error model into a separate issue, because it has different risks, tests, and design questions. The tradeoff is that splitting makes each issue easier to review, but it also creates a risk that the deeper internal cleanup is delayed after the visible wording improves.

Current State:
The issue mixes visible wording cleanup with deeper internal structure questions. Handling both together may make the issue harder to estimate, review, and complete.

Resulting State:
The immediate wording cleanup remains here as a smaller implementation issue. The shared internal error model becomes separate work with its own rating, facts, options, and decisions.

Creates:
- Shared resolver error model.

Keeps Here:
- Improve visible resolver error messages.

Risks:
- The internal cleanup may be delayed after the visible wording improves.
- The wording cleanup may need small changes again after the shared model exists.

Later Cost:
- Requires tracking the internal cleanup separately so it is not forgotten.
```

---

# 8. Recommendation

Recommendation is separate from Options.

Options describe possible paths.
Recommendation says which path is currently preferred and why.

The recommendation line must always include date, author, recommendation, and support level. Do not leave author empty. If an LLM writes the recommendation, name it as the author.

Good:

```markdown
### 🏁 Recommendation

- [2026-05-30 | Author: GPT-5.5 Thinking | Recommendation: Prefer Option B | Support: 2/3 Reasoned ▰▰▱]
```

Bad:

```markdown
### 🏁 Recommendation

- [2026-05-30 | Author: — | Recommendation: Prefer Option B | Support: 2/3 Reasoned ▰▰▱]
```

---

## Recommendation Line Format

```markdown
### 🏁 Recommendation

- [YYYY-MM-DD | Author: <required author name> | Recommendation: <recommendation> | Support: <support level>]

Reasoning:
<Explain why this option is currently recommended. Mention the tradeoff honestly.>

Required Checks:
<State what must be checked before this recommendation becomes a final decision.>
```

The author is mandatory because recommendations are judgements. A judgement should have a source.

---

## Recommendation Types

```text
Recommendation:
Prefer Option A
Prefer Option B
Prefer Option C
Choose Option A
Choose Option B
Choose Option C
Split Issue
Needs More Facts
Defer
Reject
```

Use Prefer Option X when the option is currently favored but not final.
Use Choose Option X when the decision is made.
Use Split Issue when the current issue shape is too broad and the next action is splitting.
Use Needs More Facts when no responsible recommendation can be made yet.
Use Defer when the issue is valid but should not be worked on now.
Use Reject when the issue should not be pursued.

---

## Support Level

Support describes how well the recommendation is backed by facts, checked assumptions, and understood tradeoffs.

```text
Support:
1/3 Thin           ▰▱▱
2/3 Reasoned       ▰▰▱
3/3 Well Supported ▰▰▰
```

Use 1/3 Thin when important facts are missing, the recommendation is mostly a working guess, or the issue still needs investigation.

Use 2/3 Reasoned when the recommendation has a clear argument and known tradeoffs, but some checks remain.

Use 3/3 Well Supported when facts, constraints, risks, and tradeoffs are well understood, and only normal implementation uncertainty remains.

Support is not certainty. It says how much backing the recommendation currently has.

---

## Recommendation Rules

A recommendation must explain the tradeoff. Do not only say which option is preferred.

Good:

```text
Option B is recommended because it solves the duplicated error ownership problem. Option A is cheaper, but it only improves wording and leaves the internal structure unchanged.
```

Bad:

```text
Option B is better.
```

If the recommendation is Needs More Facts, name the missing facts.

If the recommendation is Split Issue, name the parts that should become separate issues.

If the recommendation is Defer, explain what condition would make the issue worth revisiting.

If the recommendation is Reject, explain why the issue should not be pursued.

---

# 9. Decisions

Decisions capture what has already been settled and what is still open.

## ✅ Resolved Decisions

Use this section for decisions already made. A resolved decision should include the decision, reason, and consequence.

```markdown
### ✅ Resolved Decisions

- Decision: Resolver error cleanup will not rename public CLI flags.
  Reason: Flag naming is broader than error handling and would expand the issue shape.
  Consequence: Flag naming is out of scope and may become extracted work if still valuable.
```

Do not bury decisions inside prose. Decisions should be easy to scan.

---

## ❓ Open Decisions

Use this section for decisions still required before implementation can start or finish.

```markdown
### ❓ Open Decisions

- Should resolver errors use one shared internal model, or should each resolver path own its own message construction?
- Should machine-readable error output be considered now, or explicitly excluded?
- Do existing tests or downstream tools depend on exact message text?
```

Open decisions are not todos. They are unresolved choices that affect design, scope, or implementation.

---

# 10. Out of Scope

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

# 11. Extracted Work

Extracted Work replaces generic “follow-up issues.”

Do not add this section just because a template expects “next steps.” Most issues should not produce extracted work.

Use Extracted Work only when a real separate issue should exist because of a split, chosen option, rejected option, partial resolution, or explicit out-of-scope boundary.

---

## Extracted Work Threshold

Only add extracted work when all of these are true:

1. It is a real separate issue, not a vague reminder.
2. It has a different owner, scope, option path, or acceptance condition.
3. It can receive its own issue rating.
4. It should not be silently forgotten.
5. It is not already covered by the current issue’s Required Outcome.

If these conditions are not met, do not list it.

---

## Extracted Work Format

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

## Extracted Work Examples

Required extracted work:

```markdown
### 🌱 Extracted Work

Required:
- [ ] Add consistency tests for resolver diagnostics.
  Reason: The chosen option changes resolver message structure and needs separate test coverage work.
```

Optional extracted work:

```markdown
### 🌱 Extracted Work

Optional:
- [ ] Add machine-readable resolver error output.
  Reason: The shared error model may enable this later, but it is not required to solve the current issue.
```

Bad extracted work:

```markdown
### 🌱 Extracted Work

- [ ] Improve things later.
- [ ] Think about docs.
- [ ] Maybe refactor more.
```

These are too vague. Do not write them.

---

# 12. Full Issue Template

```markdown
---
---

## 📌 <Issue Title>

- 🏷 Rating
  - 🚦 Priority: 4/6 Low ▰▰▰▱▱▱▱
  - 🛠 Effort: 2/4 Moderate ▰▰▱▱
  - 🧠 Complexity: 2/5 Normal ▰▰▱▱▱
  - 🌍 Benefit: 0/4 Internal ▱▱▱▱
  - 📦 Shape: 2/4 Composite ▰▰▱▱
  - 🎯 Quality: 🧱 Maintainability
  - 🚧 Readiness: 🟠 Needs Refinement

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

#### Option A — <Short option name>

- 🧾 Option Profile
  - 🧭 Resolution: 🟡 Partial
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟠 +1 Adds Debt
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟡 Temporary
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 💻 Local Code

Description:
<Explain the option in plain language. Say what this option does, why someone might choose it, and what tradeoff it makes. This should be a short paragraph of 3 to 6 sentences, not a slogan.>

Current State:
<Describe how the issue looks today if this option is not implemented. Focus on the visible behavior, code structure, workflow, risk, or missing information that currently exists.>

Resulting State:
<Describe how the issue would look after this option is implemented. Paint a clear picture of the changed behavior, structure, workflow, or decision state. A future reader should understand what improves without needing the original discussion.>

Solves:
- <What this option fixes, improves, or clarifies.>

Leaves Open:
- <What this option does not solve.>

Risks:
- <What could go wrong.>

Later Cost:
- <What this option may make harder later.>

---

#### Option B — <Short option name>

- 🧾 Option Profile
  - 🧭 Resolution: 🟢 Full
  - 🛠 Option Effort: 3/4 Substantial ▰▰▰▱
  - 🧠 Option Complexity: 3/5 Complex ▰▰▰▱▱
  - 🔮 Future Impact: 🟢 -2 Simplifies
  - ↩️ Reversibility: 🟡 Moderate
  - 🧬 Integration: 🟣 Strategic
  - 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱
  - 🧾 Agent Work: 🧠 System Logic

Description:
<Explain the option in plain language. Say what this option does, why someone might choose it, and what tradeoff it makes. This should be a short paragraph of 3 to 6 sentences, not a slogan.>

Current State:
<Describe how the issue looks today if this option is not implemented. Focus on the visible behavior, code structure, workflow, risk, or missing information that currently exists.>

Resulting State:
<Describe how the issue would look after this option is implemented. Paint a clear picture of the changed behavior, structure, workflow, or decision state. A future reader should understand what improves without needing the original discussion.>

Solves:
- <What this option fixes, improves, or clarifies.>

Leaves Open:
- <What this option does not solve.>

Risks:
- <What could go wrong.>

Later Cost:
- <What this option may make harder later.>

---

#### Option C — <Short option name>

- 🧾 Option Profile
  - 🧭 Resolution: 🔵 Discovery
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 1/4 Routine ▰▱▱▱
  - 🧾 Agent Work: 🔎 Research / Mapping

Description:
<Explain the option in plain language. Say what this option does, why someone might choose it, and what tradeoff it makes. This should be a short paragraph of 3 to 6 sentences, not a slogan.>

Current State:
<Describe how the issue looks today if this option is not implemented. Focus on the visible behavior, code structure, workflow, risk, or missing information that currently exists.>

Resulting State:
<Describe how the issue would look after this option is implemented. Paint a clear picture of the changed behavior, structure, workflow, or decision state. A future reader should understand what improves without needing the original discussion.>

Solves:
- <What this option fixes, improves, clarifies, or discovers.>

Leaves Open:
- <What this option does not solve.>

Risks:
- <What could go wrong.>

Later Cost:
- <What this option may make harder later.>

---

#### Optional Split Option — <Only include when splitting is a real candidate>

- 🧾 Option Profile
  - 🧭 Resolution: 🧩 Split
  - 🛠 Option Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Option Complexity: 2/5 Normal ▰▰▱▱▱
  - 🔮 Future Impact: 🟢 -1 Improves
  - ↩️ Reversibility: 🟢 Easy
  - 🧬 Integration: 🟢 Compatible
  - 🤖 Agent Difficulty: 2/4 Guided ▰▰▱▱
  - 🧾 Agent Work: 🧩 Planning / Structuring

Description:
<Explain how this issue could be split into smaller issues. Say which part should stay here, which part should move out, why the split would make the work clearer or safer, and what risk the split creates.>

Current State:
<Describe why the current issue is bundled, unclear, or too large to handle safely as one item.>

Resulting State:
<Describe what the issue structure would look like after the split. Say what remains here and what becomes separate work.>

Creates:
- <Separate issue or concern that should receive its own rating.>

Keeps Here:
- <Part that remains in this issue.>

Risks:
- <What could be lost, delayed, or duplicated by splitting.>

Later Cost:
- <Extra coordination or cleanup created by the split.>

---

### 🏁 Recommendation

- [YYYY-MM-DD | Author: <required author name> | Recommendation: <recommendation> | Support: <support level>]

Reasoning:
<Explain why this option is currently recommended. Mention the tradeoff honestly.>

Required Checks:
<State what must be checked before this recommendation becomes a final decision.>

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

# 13. Small Issue Template

Use this only when the issue is simple, ready, and does not need option analysis.

```markdown
---
---

## 📌 <Issue Title>

- 🏷 Rating
  - 🚦 Priority: 3/6 Normal ▰▰▰▰▱▱▱
  - 🛠 Effort: 1/4 Trivial ▰▱▱▱
  - 🧠 Complexity: 1/5 Simple ▰▱▱▱▱
  - 🌍 Benefit: 2/4 Individual ▰▰▱▱
  - 📦 Shape: 0/4 Atomic ▱▱▱▱
  - 🎯 Quality: 🧭 Usability
  - 🚧 Readiness: 🟢 Ready

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

### 🚫 Out of Scope

- <Only include if relevant.>
```

Use the full template when the issue has Shape: 2/4 Composite or higher, Readiness: Needs Refinement, multiple options, unresolved design questions, meaningful scope risk, or possible extracted work.

---

# 14. Practical Rules

If an issue is Shape: 0/4 Atomic or Shape: 1/4 Focused, it may not need options.

If an issue is Shape: 2/4 Composite, options should usually include at least one split, partial-resolution, or discovery path.

If an issue is Shape: 3/4 Epic / Theme, use it as a parent issue and create child issues only when the child issues are real, ratable, and separately useful.

If an issue is Shape: 4/4 Dump / Catch-all, do not implement it. Rewrite it, split it, or convert it into discovery.

If an option has 🔮 Future Impact: 🔴 +2 Rewrite Risk, do not choose it casually. It may still be valid, but it should be explicit debt.

If an option has 🧭 Resolution: 🟡 Partial, it must say what remains open.

If an option has 🧭 Resolution: 🔵 Discovery, it must say what decision or facts it will produce.

If an option has 🧭 Resolution: 🧩 Split, it must say what stays here and what becomes separate.

If an option has 🤖 Agent Difficulty: 3/4 Strong ▰▰▰▱ or 🤖 Agent Difficulty: 4/4 Human-Led ▰▰▰▰, require human review before merging implementation work.

If something is excluded, put it in Out of Scope. Do not rely on memory.

If a decision is made, put it in Resolved Decisions. Do not leave it hidden in discussion.

If there is no real extracted work, omit Extracted Work or write None.

If an LLM writes a recommendation, the LLM must be named as the author. Do not write `Author: —`.

Use dividers to protect readability. In long issue files, poor separation makes options and decisions hard to review.

Option descriptions should be verbose enough to preserve the idea. Do not compress them into slogans.

Use Description, Current State, and Resulting State together when an option is important. This makes the option easier to judge without needing the original discussion.

Use chips to clarify state and risk. Do not add chips where they create noise.

Keep chip meanings consistent. For example, use `🟢 -2 Simplifies` and `🟢 -1 Improves` for helpful Future Impact values, not a mixture such as `✅ -2 Simplifies` and `🟢 -1 Improves`.

---

# 15. Final Rule

The rating classifies the issue.
The vertical rating layout keeps ratings readable.
The visual meters make ordered ratings easier to scan.
The semantic chips make states, categories, and risks easier to read.
The section icons make issue documents easier to navigate.
The dividers separate large issue blocks and option blocks.
The statement explains the issue.
The related context shows connections.
The required outcome defines success.
The facts ground the issue.
The options compare possible paths.
The option profile shows the cost, risk, future impact, and agent suitability of each path.
The option description explains the idea and tradeoff.
The current state shows the world before the option.
The resulting state shows the world after the option.
The recommendation states the preferred path and why.
The support level says how well-backed the recommendation is.
The resolved decisions record what has been chosen.
The open decisions show what is still unresolved.
The out-of-scope section protects the boundary.
The extracted work section exists only when separate work is real, necessary, and worth preserving.