# PROJECT-ISSUE-DECISIONS-FRAMEWORK V0.2

Version: V0.2
Purpose: A readable Markdown framework for creating a durable issue decision record from a materialized project issue document.

Scope: Issue-level decision recording and handoff preparation.

This framework is used after a project issue has been written with the Project Issue Framework.

It creates a separate decision artifact:

```text
PROJECT-ISSUE-DECISIONS-<issue-slug>.md
```

The decision artifact records which issue option is selected, why it is selected, what issue context is carried forward, what decisions are resolved, what decisions remain open, and what must be handed to the implementation framework.

The issue document answers:

```text
What is the issue, what options exist, and what option is recommended?
```

The issue decision document answers:

```text
Which option is now selected, why is it selected, what does the decision include, and what must be preserved for implementation planning?
```

The implementation framework answers later:

```text
How should the selected decision be implemented inside the codebase?
```

---

# 0. Required Output Artifact

When an agent is asked to use this framework, the expected result is a filled-out Markdown issue decision document.

Required output file:

```text
PROJECT-ISSUE-DECISIONS-<issue-slug>.md
```

Do not modify the original issue document.
Do not append the decision record to the issue document.
Do not implement code.
Do not create the implementation plan yet.

The issue document remains the source issue.
The issue decision document is the selected decision record.
The implementation framework consumes this decision record later.

---

# 1. Inputs

The agent receives:

```text
1. PROJECT-ISSUE-DECISIONS-FRAMEWORK file
2. Materialized issue document created with the Project Issue Framework
3. Optional explicit selected option
4. Optional repository/codebase access for decision discovery
```

The selected option may come from:

```text
1. Explicit instruction from the user
2. Existing Recommendation section in the issue document
3. Resolved Decisions section in the issue document
```

If an explicit selected option is provided, use that option.

If no explicit selected option is provided, use the issue document's Recommendation.

If the issue document has no selected option and no recommendation, create a decision document with:

```text
Decision State: 🟣 Decision Needed
```

Do not silently choose an option.

---

# 2. Output File Naming

Use this filename pattern:

```text
PROJECT-ISSUE-DECISIONS-<issue-slug>.md
```

The slug should be stable, readable, and based on the issue title.

Examples:

```text
PROJECT-ISSUE-DECISIONS-resolver-error-message-ownership.md
PROJECT-ISSUE-DECISIONS-installer-adoption-removal-rules.md
PROJECT-ISSUE-DECISIONS-package-resolution-flow.md
```

Do not include timestamps unless the repository already uses timestamped decision records.

---

# 3. Decision Workflow

Use this workflow:

```text
1. Read the materialized issue document.
2. Identify the selected option.
3. Carry forward the selected option details.
4. Carry forward relevant issue rating, statement, required outcome, facts, value assessment, recommendation, decisions, scope, and extracted work.
5. Perform decision discovery if useful.
6. Record whether discovery supports, weakens, blocks, or changes confidence in the selected option.
7. Record the decision justification.
8. Record required checks before implementation planning.
9. Prepare the handoff to the implementation framework.
```

The important sequence is:

```text
Issue first.
Decision second.
Implementation planning third.
Code fourth.
```

---

# 4. Neutrality Rule

Sections before Decision Justification must be factual and neutral.

The document may carry forward a selected option, but it should not exaggerate it.

Allowed neutral phrases:

```text
The selected option is carried forward from the issue recommendation.
The selected option was provided by instruction.
The issue document rates this option as lower effort.
Repository discovery found existing support for this direction.
Repository discovery found unresolved placement risk.
```

Avoid unsupported preference language before Decision Justification:

```text
Best option
Obviously correct
Clearly superior
No-brainer
Just do this
```

The Decision Justification section is where the selected option is justified.

---

# 5. Visual Style

Use the same visual style as the issue framework.

Plain punctuation:
- Use the plain hyphen-minus character `-` for separators and option headings.
- Use straight double quotes `"`.
- Do not use typographic dash characters or smart quotes.

```text
▰ filled meter segment
▱ empty meter segment
```

Examples:

```text
1/4 ▰▱▱▱
2/4 ▰▰▱▱
3/4 ▰▰▰▱
4/4 ▰▰▰▰
```

Carry-forward meter rule:
- Preserve meters for source and option fields that use ordered scales.
- Include meters for Priority, Effort, Complexity, Benefit, Shape, Option Effort, Option Complexity, Future Impact, Reversibility, Agent Difficulty, Source Support, and Discovery Depth.
- Do not invent meters for categorical or state fields such as Decision State, Option Resolution, Quality, Readiness, Handoff Readiness, Integration, or Agent Work.

Semantic chips:

```text
🟢 Favorable / good / ready / helpful
🟡 Acceptable / partial / watch
🟠 Caution / needs work / adds debt
🔴 Harmful / blocked / reject / high risk
🔵 Informational / discovery / local
🟣 Decision / strategic direction
⚪ Neutral / deferred / inactive
🧩 Split / structuring
```

Section icons:

```text
📌 Decision title
📄 Source issue
🏷 Decision rating
📝 Decision statement
🧩 Selected option
💶 Value context
🧭 Decision discovery
♻️ Reuse signal
📍 Placement signal
⚠️ Decision risk
✅ Decision justification
❓ Required checks
🚫 Out of scope
🌱 Extracted work
🤖 Handoff
```

---

# 6. Decision Rating

Use this rating block in every issue decision document.

```markdown
- 🏷 Decision Rating
  - 🧭 Decision State: 🟢 Selected
  - 📚 Source Support: 2/3 Reasoned ▰▰▱
  - 🔎 Discovery Depth: 1/4 Local Scan ▰▱▱▱
  - 🧩 Option Resolution: <carried from selected option>
  - 🛠 Option Effort: <carried from selected option, including meter>
  - 🧠 Option Complexity: <carried from selected option, including meter>
  - 🔮 Future Impact: <carried from selected option, including meter>
  - 🤖 Agent Difficulty: <carried from selected option, including meter>
  - 🚧 Handoff Readiness: 🟠 Needs Checks
```

Do not add ratings together.
They are decision signals, not a score.

---

## 6.1 Decision State

Decision State describes whether a selected path exists.

```text
🧭 Decision State:
🟢 Selected
🟡 Preferred
🟠 Provisional
🟣 Decision Needed
🔴 Blocked
⚪ Deferred
```

Use 🟢 Selected when the option is chosen and can move toward implementation planning.

Use 🟡 Preferred when the option is favored but still needs checks.

Use 🟠 Provisional when the option is selected only if named conditions remain true.

Use 🟣 Decision Needed when the issue does not yet contain or receive a selected option.

Use 🔴 Blocked when the decision cannot responsibly move forward.

Use ⚪ Deferred when the decision is intentionally postponed.

---

## 6.2 Source Support

Source Support describes how well the issue document supports the decision.

```text
📚 Source Support:
1/3 Thin           ▰▱▱
2/3 Reasoned       ▰▰▱
3/3 Well Supported ▰▰▰
```

Use 1/3 Thin when the selected option exists but the issue document gives little reasoning.

Use 2/3 Reasoned when the option, tradeoff, value assessment, and recommendation are understandable.

Use 3/3 Well Supported when the issue document clearly supports the selected option through facts, option profile, value assessment, recommendation, decisions, scope, and risks.

---

## 6.3 Discovery Depth

Discovery Depth describes how much additional repository or project discovery was performed for the decision record.

```text
🔎 Discovery Depth:
0/4 None             ▱▱▱▱
1/4 Local Scan       ▰▱▱▱
2/4 Focused Mapping  ▰▰▱▱
3/4 Broad Mapping    ▰▰▰▱
4/4 Discovery First  ▰▰▰▰
```

Use 0/4 None when the issue document alone is enough for the decision record.

Use 1/4 Local Scan when nearby files, docs, tests, or references were checked.

Use 2/4 Focused Mapping when one module, workflow, or subsystem was inspected.

Use 3/4 Broad Mapping when several modules, workflows, or ownership areas were inspected.

Use 4/4 Discovery First when the decision cannot move forward without dedicated discovery.

---

## 6.4 Handoff Readiness

Handoff Readiness describes whether the decision record is ready for the implementation framework.

```text
🚧 Handoff Readiness:
🟢 Ready for Implementation Framework
🟠 Needs Checks
🟣 Needs Decision
🧩 Needs Split
🔴 Blocked
⚪ Deferred
```

Use 🟢 Ready for Implementation Framework when the selected option and boundaries are clear enough.

Use 🟠 Needs Checks when implementation planning can start only after specific checks.

Use 🟣 Needs Decision when an unresolved decision affects implementation direction.

Use 🧩 Needs Split when the selected path requires separate issues before implementation planning.

Use 🔴 Blocked when the decision record cannot be used yet.

Use ⚪ Deferred when implementation planning is intentionally postponed.

---

# 7. Decision Discovery

Decision Discovery is optional but useful when the selected option needs grounding before implementation planning.

Decision Discovery is not a full implementation assessment.

It should answer:

```text
Does anything in the repository or project context support, weaken, block, or condition the selected option?
```

Focus on:

* affected files, modules, docs, schemas, commands, workflows, or tests
* existing helpers or support utilities
* existing repeated logic
* existing ownership signals
* likely implementation placement
* compatibility, release, security, migration, performance, or support constraints
* missing facts that affect the decision

Do not turn Decision Discovery into a full implementation plan.
Implementation planning belongs to the implementation framework.

---

# 8. Full Issue Decision Document Template

Use this template for normal issue decisions.

File name:

```text
PROJECT-ISSUE-DECISIONS-<issue-slug>.md
```

Template:

```markdown
---
---

# 📌 Project Issue Decision - <Issue Title>

Source Issue:
- Title: <issue title>
- Issue File: <relative path or identifier>
- Selected Option: <Option X - option title>
- Decision Document: PROJECT-ISSUE-DECISIONS-<issue-slug>.md

Decision Scope:
- This document records the selected issue-level decision.
- This document does not replace the source issue.
- This document does not implement code.
- This document prepares the selected option for implementation planning.

- 🏷 Decision Rating
  - 🧭 Decision State: <state>
  - 📚 Source Support: <support>
  - 🔎 Discovery Depth: <discovery depth>
  - 🧩 Option Resolution: <carried from selected option>
  - 🛠 Option Effort: <carried from selected option, including meter>
  - 🧠 Option Complexity: <carried from selected option, including meter>
  - 🔮 Future Impact: <carried from selected option, including meter>
  - 🤖 Agent Difficulty: <carried from selected option, including meter>
  - 🚧 Handoff Readiness: <handoff readiness>

### 📝 Decision Statement

<Explain which option is selected and what decision this document records.>

Selection Source:
- <Explicit user instruction / Issue Recommendation / Resolved Decision / Decision Needed>

### 📄 Source Issue Summary

Issue Rating:
- 🚦 Priority: <value, including meter>
- 🛠 Effort: <value, including meter>
- 🧠 Complexity: <value, including meter>
- 🌍 Benefit: <value, including meter>
- 📦 Shape: <value, including meter>
- 🎯 Quality: <value>
- 🚧 Readiness: <value>

Statement:
<Briefly restate the issue.>

Required Outcome:
<Restate what must be true when the issue is resolved.>

Known Facts:
- <Relevant known fact.>

Unknown Facts:
- <Relevant unknown fact.>

Related Context:
- <Relevant context, dependencies, affected areas, or related issues.>

### 🧩 Selected Option - Carried Forward

Option:
- <Option X - option title>

Option Kind:
- <Option kind from the issue document>

Option Profile:
- 🧭 Resolution: <value>
- 🛠 Option Effort: <value, including meter>
- 🧠 Option Complexity: <value, including meter>
- 🔮 Future Impact: <value, including meter>
- ↩️ Reversibility: <value, including meter>
- 🧬 Integration: <value>
- 🤖 Agent Difficulty: <value, including meter>
- 🧾 Agent Work: <value>

Description:
<Copy or faithfully restate the selected option description.>

Current State:
<Copy or faithfully restate the selected option current state.>

Resulting State:
<Copy or faithfully restate the selected option resulting state.>

Solves:
- <Carry forward the selected option solves list.>

Leaves Open:
- <Carry forward the selected option leaves-open list.>

Risks:
- <Carry forward the selected option risks.>

Later Cost:
- <Carry forward the selected option later cost.>

### 💶 Value and Recommendation Context

Relevant Value Assessment:
- <Summarize how the issue document assessed the selected option.>

Relevant Recommendation:
- <Summarize whether the issue document already recommended this option, or state that the option was selected by instruction.>

Decision Meaning:
- <Explain what choosing this option means for scope, tradeoff, value, and future work.>

Good Result:
- <Carry forward or restate the issue's good result in decision-facing language.>

### 🧭 Decision Discovery

Discovery Depth:
- <None / Local Scan / Focused Mapping / Broad Mapping / Discovery First>

Areas Inspected:
- <Files, folders, modules, tests, docs, configs, schemas, commands, workflows, or services inspected.>

Ownership Signals:
- <Which file, module, class, service, document, or workflow appears to own the relevant behavior?>

Existing Patterns:
- <Naming, logging, error handling, dependency, validation, testing, placement, documentation, or configuration patterns found.>

Reusable Assets:
- <Existing code, helpers, services, fixtures, types, config, docs, examples, or tests that may support the selected option.>

Repeated Logic Signals:
- <Repeated validation, mapping, formatting, conversion, parsing, logging, diagnostics, setup, branching, or other repeated logic found.>

Constraints Found:
- <Architecture, compatibility, migration, release, security, performance, operational, support, or test constraints.>

Unknowns:
- <Facts still missing.>

Discovery Judgement:
<Explain what discovery says about the selected option without silently changing the decision.>

### ♻️ Reuse and Helper Signals

Reuse Directly:
- <Existing code, document, helper, service, model, fixture, test, config, or convention that may be reused.>

Extend:
- <Existing asset that may be extended safely.>

Avoid Duplicating:
- <Existing behavior, helper, service, type, config, fixture, or test utility that must not be reimplemented.>

General-Purpose Function Candidate:
- <Yes / No / Maybe / Not applicable>

Candidate Responsibility:
- <If yes or maybe, what concept would the helper/function own?>

Candidate Location:
- <Where the helper/function would naturally belong.>

Reuse Judgement:
<Explain reuse and helper signals relevant to the decision.>

### 📍 Placement Signal

Likely Placement:
- <File, folder, class, function, module, document, workflow, or layer.>

Reason:
<Explain why implementation may belong there.>

Rejected Placement:
- <Nearby or tempting location that should not be used.>
  Reason: <Why it would be poor placement.>

New Files:
- <Yes / No / Maybe>

New File Reason:
<Explain why new files are or are not likely appropriate.>

Placement Confidence:
- <Low / Medium / High>

### 🗺 Workflow / 🌳 Logic Signal

Diagram Need:
- <Not Needed / Workflow Useful / Logic Tree Useful / Workflow + Logic Tree Useful / Required Before Implementation>

Workflow:
<Include Mermaid workflow if useful. Otherwise write "Not applicable.">

Logic Tree:
<Include Mermaid logic tree if useful. Otherwise write "Not applicable.">

### ⚠️ Decision Risks

Known Risks:
- <Risks from the issue document.>

Discovery Risks:
- <Risks found during decision discovery.>

Decision Risk:
- <Low / Medium / High / Blocked>

Risk Handling:
- <How these risks should be handled before implementation planning.>

### ❓ Required Checks Before Implementation Framework

- [ ] <Check one.>
- [ ] <Check two.>
- [ ] <Check three.>

These checks must be completed before implementation planning if they affect placement, reuse, compatibility, migration, security, public behavior, release safety, or issue scope.

### ✅ Decision Justification

Decision:
- <Choose / Prefer / Defer / Block / Need Decision for> <Option X - option title>

Support:
- <1/3 Thin / 2/3 Reasoned / 3/3 Well Supported>

Justification:
<Explain why the selected option is justified based on the issue document, value assessment, required outcome, selected scope, and discovery. Mention the tradeoff honestly.>

Conditions:
- <Conditions that must remain true for this decision to stay valid.>

If Conditions Fail:
- <Pause / Discovery needed / Decision needed / Split needed / Human review needed>

### ✅ Resolved Decisions Carried Forward

- Decision: <Decision already made in the issue document, if relevant.>
  Reason: <Reason.>
  Consequence: <Consequence.>

If none:
- None.

### ❓ Open Decisions Carried Forward

- <Open decision from the issue document that still affects implementation planning.>

If none:
- None.

### 🚫 Out of Scope Carried Forward

- <Out-of-scope item relevant to this decision.>

If none:
- None.

### 🌱 Extracted Work

Required:
- [ ] <Separate issue that must exist, if any.>
  Reason: <Why it must be tracked separately.>

Optional:
- [ ] <Separate issue that may be useful later, if any.>
  Reason: <Why it may be useful but is not required now.>

If none:
- None.

### 🤖 Handoff to Implementation Framework

Use this decision document as input to the Project Implementation Framework.

The implementation framework should receive:
- the source issue document
- this issue decision document
- the selected option
- value and recommendation context
- discovery results
- placement signal
- reuse/helper signals
- risks and required checks
- carried-forward open decisions
- out-of-scope boundaries
- extracted work

Agent instructions for the next stage:
- Do not modify the original issue document.
- Do not re-decide the selected option unless this document marks the decision as blocked or contradicted.
- Use the selected option as the implementation direction.
- Convert this decision into a filled-out implementation decision/planning document.
- Reuse existing code where possible.
- Do not duplicate existing helpers, support utilities, fixtures, or repeated logic.
- Do not create new files or abstractions unless justified by the decision and implementation framework.
- Stop and report if implementation discovery contradicts the selected option, if placement is unclear, or if implementation would create harmful growth or duplicate ownership.
```

---

# 9. Small Issue Decision Document Template

Use this when the issue is small, the selected option is obvious, and no discovery is needed.

File name:

```text
PROJECT-ISSUE-DECISIONS-<issue-slug>.md
```

Template:

```markdown
---
---

# 📌 Project Issue Decision - <Issue Title>

Source Issue:
- Title: <issue title>
- Issue File: <relative path or identifier>
- Selected Option: <Option X - option title>
- Decision Document: PROJECT-ISSUE-DECISIONS-<issue-slug>.md

- 🏷 Decision Rating
  - 🧭 Decision State: 🟢 Selected
  - 📚 Source Support: <support>
  - 🔎 Discovery Depth: 0/4 None ▱▱▱▱
  - 🧩 Option Resolution: <carried from selected option>
  - 🛠 Option Effort: <carried from selected option, including meter>
  - 🧠 Option Complexity: <carried from selected option, including meter>
  - 🔮 Future Impact: <carried from selected option, including meter>
  - 🤖 Agent Difficulty: <carried from selected option, including meter>
  - 🚧 Handoff Readiness: 🟢 Ready for Implementation Framework

### 📝 Decision Statement

<Explain which option is selected and why this decision record exists.>

### 🧩 Selected Option Summary

Option:
- <Option X - option title>

Option Kind:
- <Option kind>

Description:
<Faithfully restate the selected option.>

Solves:
- <What it solves.>

Leaves Open:
- <What it leaves open.>

Risks:
- <Main risks.>

### ✅ Decision Justification

Decision:
- <Choose / Prefer> <Option X - option title>

Support:
- <1/3 Thin / 2/3 Reasoned / 3/3 Well Supported>

Justification:
<Brief justification based on the issue document.>

### 🚫 Out of Scope Carried Forward

- <Relevant boundary.>

If none:
- None.

### 🌱 Extracted Work

Required:
- [ ] <Separate issue, if any.>

Optional:
- [ ] <Separate issue, if any.>

If none:
- None.

### 🤖 Handoff to Implementation Framework

Use this decision document and the original issue as input to the implementation framework.
```

---

# 10. Agent Prompt

Use this prompt when asking an agent to create the decision file.

```text
Use the PROJECT-ISSUE-DECISIONS-FRAMEWORK.

Input:
1. The materialized issue document created with the Project Issue Framework.
2. The selected option, if explicitly provided.
3. Repository access, if discovery is useful or required.

Create a separate Markdown file:

PROJECT-ISSUE-DECISIONS-<issue-slug>.md

Do not modify the original issue document.
Do not append the decision document to the issue document.
Do not implement code.
Do not create the implementation framework document yet.

Determine the selected option using this order:
1. Explicit selected option from the user.
2. Recommendation section in the issue document.
3. Resolved Decisions section in the issue document.
4. If none exists, mark Decision State as 🟣 Decision Needed.

Carry forward all relevant selected-option details:
- option title
- option kind
- option profile
- description
- current state
- resulting state
- solves
- leaves open
- risks
- later cost

Carry forward relevant issue context:
- issue rating
- statement
- related context
- required outcome
- known facts
- unknown facts
- value assessment
- recommendation
- stakeholder success note implications
- resolved decisions
- open decisions
- out of scope
- extracted work

Perform decision discovery only as needed.
Discovery should validate the selected option, not become full implementation planning.

Discovery may inspect:
- related files, modules, docs, schemas, tests, configs, commands, workflows, or services
- existing helpers, support utilities, fixtures, or reusable assets
- repeated logic
- ownership signals
- placement signals
- compatibility, release, security, migration, performance, support, or user-facing constraints

If discovery supports the selected option, explain why.

If discovery weakens or contradicts the selected option, do not silently switch options.
Record the contradiction under Decision Risks and Required Checks.
If the contradiction is serious, set Handoff Readiness to 🟣 Needs Decision, 🧩 Needs Split, or 🔴 Blocked.

Use the full template unless the issue is small and no discovery is needed.
Use the small template only for tiny, obvious decisions.

The result should be a decision record that can be handed to the Project Implementation Framework.
```

---

# 11. Practical Rules

If the selected option is explicit:

* Use it.
* Do not reselect a different option silently.

If the selected option comes from Recommendation:

* Carry forward the recommendation and support level.

If there is no selected option:

* Create a decision-needed record.
* Do not invent a decision.

If the issue recommendation is a bundle such as `Option A + Option C`:

* Record that the issue options need repair.
* Set Handoff Readiness to 🟣 Needs Decision or 🧩 Needs Split.

If the selected option is a Discovery Option:

* The decision document should describe what discovery must produce.
* Handoff may go to discovery before implementation planning.

If the selected option is a Decision Option:

* The decision document should describe what decision must be made and who or what role should decide.
* Handoff Readiness is usually 🟣 Needs Decision.

If the selected option is a Split Option:

* The decision document should describe what remains and what becomes separate.
* Handoff Readiness is usually 🧩 Needs Split.

If the selected option is a Defer Option:

* Record the revisit condition.
* Handoff Readiness is usually ⚪ Deferred.

If the selected option is a Reject Option:

* Record the rejection reason.
* Do not hand off to implementation.

If discovery contradicts the selected option:

* Do not silently change the selected option.
* Record the contradiction.
* Require a decision, split, discovery, or human review.

If out-of-scope boundaries exist:

* Carry them forward.
* Do not rely on memory.

If extracted work exists:

* Carry it forward only when it is real, separate, ratable, and worth preserving.

---

# 12. Final Rule

The issue document defines the problem and options.
The issue decision document records the selected issue-level path.
The implementation framework turns the selected path into implementation planning.
The code implementation follows the implementation plan.

The decision document must not replace the issue.
The decision document must not become the implementation plan.
The decision document must preserve the selected option, decision reasoning, boundaries, risks, and handoff context.

The selected option is carried forward.
The decision justification explains why it is selected.
The required checks protect against hidden uncertainty.
The handoff section prepares the next framework step.

A good issue has options.
A good decision records the selected option.
A good implementation starts from a clear decision.
