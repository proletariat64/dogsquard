---
title: "Control Board Runbook"
doc_type: "runbook"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-06-02"
related_issue: "#1, #42"
related_pr: ""
supersedes: ""
---

# Control Board Runbook

## Purpose

Issue #1 is the one-screen project controller for Dogsquard.

It should let the user and agents understand the full project picture quickly without turning into a historical changelog.

Detailed roadmap, history, and phase grouping live in:

```text
docs/05_design/design-20260531-project-roadmap.md
```

## Correct Control Board Shape

Issue #1 should include:

- Freeze State
- Frozen Scope
- Change Requests
- Later / Parking Lot
- Current Milestone
- Current Objective
- Dashboard capability table
- Now / Next / Later
- Current Decisions
- Open Questions
- Guardrails
- Latest Completed
- Next Deliverable
- Links to detailed docs

The Control Board should be compact enough to read quickly and complete enough to show where the project stands.

## Freeze State

The Control Board must show whether work is still being designed or is approved for execution.

Use this section near the top of Issue #1:

```markdown
## Freeze State

- Lifecycle: Draft | Design Frozen | Implementation Frozen | Released | Reopened
- Design: Draft | Frozen | Reopened
- Implementation Plan: Draft | Frozen | Reopened
- Task Intake: Open | Change-control only | Closed
- Current Release Target:
- Last Freeze Decision:
- Approved By:
```

### Design Draft

Design Draft is for exploration.

Allowed:

- compare options
- identify risks
- propose scope
- create candidate tasks
- identify docs that may be needed

Not allowed:

- treating candidate tasks as approved work
- implementing speculative improvements
- opening multiple implementation PRs before scope is approved

Exit condition:

- the user explicitly approves design freeze

### Design Frozen

Design Frozen stops design expansion.

Allowed:

- clarify wording
- correct contradictions
- implement the approved design
- move non-blocking discoveries to Later

Not allowed without re-approval:

- new major design direction
- new capability group
- new ADR unless a real architectural decision is required
- new production or deploy behavior
- scope expansion based only on agent discovery

### Implementation Plan Draft

Implementation Plan Draft converts a frozen design into execution scope.

It must define:

- target outcome
- expected changed files or areas
- acceptance criteria
- non-goals
- validation commands
- PR budget
- artifact budget

Exit condition:

- the user explicitly approves implementation plan freeze

### Implementation Plan Frozen

Implementation Plan Frozen means agents execute only the approved scope.

Allowed:

- implement Frozen Scope
- fix failing validation for Frozen Scope
- update required docs only
- record non-blocking improvements in Change Requests or Later

Not allowed without re-approval:

- new PRD, BDD, ADR, runbook, or test plan outside the artifact budget
- new workflow
- new deploy surface
- new production behavior
- expanding PR count beyond budget

### Reopened

A frozen design or implementation plan can be reopened only when:

- acceptance criteria cannot be met without changing scope
- CI or test failure reveals missing required work
- a safety or security issue is found
- the user explicitly changes direction

Record each reopen decision with:

```markdown
Reason:
Impact:
New scope:
New non-goals:
New PR budget:
User approval:
```

### Released

Released means the deliverable met its release stop rule.

After Released:

- new ideas go to Change Requests or Later
- no new Now scope is added without explicit approval
- release evidence stays summarized, not expanded into a full command log

## Frozen Scope

Every active deliverable should have a bounded scope before implementation starts.

Use this format:

```markdown
## Frozen Scope

Outcome:
- <approved outcome>

Must Change:
- <files or areas that may change>

May Change:
- <secondary files or areas that may change if needed>

Must Not Change:
- <explicit non-goals>

Acceptance Criteria:
- <minimum evidence required>

PR Budget:
- Target:
- Maximum without re-approval:

Artifact Budget:
- Tier:
- Required artifacts:
- Forbidden unless re-approved:
```

After Implementation Plan Frozen, every current Now item must map to Frozen Scope or to an approved Change Request.

## Change Requests And Later

After freeze, discovery creates Change Requests, not automatic Now tasks.

Use this section for scope changes:

```markdown
## Change Requests

| ID | Request | Type | Reason | Decision | Disposition |
|---|---|---|---|---|---|
| CR-001 | ... | blocker/safety/required/cleanup/lesson/candidate | ... | pending/approved/rejected | Now/Later/Case Study/Reject |

## Later / Parking Lot

Non-blocking improvements discovered during implementation.
```

New work may enter Now after freeze only when one of these is true:

- it blocks Frozen Scope
- it fixes a safety or security issue
- it is required by acceptance criteria
- the user explicitly approves scope expansion

Otherwise, put it in Change Requests or Later.

## Artifact Budget

Use artifact tiers to stop small work from creating heavyweight governance bundles.

| Tier | Change type | Expected artifacts |
|---|---|---|
| 0 | typo, wording, link, README clarification | PR body only |
| 1 | small script, Makefile, or doc-check fix | PR body and direct test if needed |
| 2 | workflow behavior change | affected runbook or test update, not full bundle |
| 3 | new reusable capability | short design or PRD, test, and runbook if humans operate it |
| 4 | production, security, or server mutation | PRD/design, ADR, runbook, test plan, explicit approval, and safety gate |

Default rule:

- do not create more than two new governance artifacts for a PR unless the change is Tier 3 or Tier 4
- do not create a PRD + BDD + ADR + runbook + test-plan bundle for Tier 0, Tier 1, or Tier 2 work
- explain why each artifact is necessary when adding new governance artifacts

## PR Budget

One capability should normally take one or two PRs:

- PR 1: design or plan, only when needed
- PR 2: implementation and validation

For small changes, use one implementation PR.

A third PR for the same capability requires a budget exception:

```markdown
## PR Budget Exception

Capability:
Reason another PR is needed:
Risk avoided by splitting:
Files or areas affected:
Why this is not task sprawl:
User approval:
```

Avoid this sequence unless explicitly approved:

```text
design PR -> implementation PR -> validation PR -> hardening PR -> lessons PR -> alignment PR -> follow-up guidance PR
```

## Task Taxonomy

Classify newly discovered work before proposing it for Now.

| Type | Meaning | Default destination |
|---|---|---|
| Blocker | prevents Frozen Scope from working | Now |
| Safety | prevents harmful action | Now or approval gate |
| Required | needed for acceptance criteria | Now |
| Cleanup | improves quality but is not required | Later |
| Lesson | learned from a real project | Case Study |
| Candidate | possible future capability | Change Request |
| Archive | historical or superseded detail | Archive |

## Template Scope Classification

Real-project lessons should not automatically become Dogsquard Core.

Use these classifications:

- Core: minimal default-on template behavior
- Optional Pattern: reusable but opt-in capability
- Case Study: evidence from one real project
- Archive: historical or superseded detail

One real-project lesson becomes Case Study first. It becomes Core only after repeated evidence or explicit user approval.

## Stable Safety Invariants

Safety should be enforced by a small number of durable rules and guards.

Stable invariants:

- do not commit secrets
- do not commit raw server config or raw logs
- do not claim protected routes `/` or `/api`
- do not touch reverse proxy or server config without explicit approval
- do not deploy, restart, or rollback production runtime without explicit approval

A new safety doc or guard is justified only when:

- the risk can recur across projects
- existing guardrails do not cover it
- the new artifact is smaller than the risk it controls

## Release Stop Rule

Each release should define stop conditions.

Use this format:

```markdown
## Release Stop Rule

Release target:

Release when:
- <criterion 1>
- <criterion 2>
- <criterion 3>

Do not include in this release:
- <non-goal 1>
- <non-goal 2>

After release:
- new ideas go to Later or Change Requests
- no new scope without explicit approval
```

Release completion should not depend on resolving every open idea.

## Checklist And Status Style

Issue #1 should use checkbox and todo-list formatting.

Use these status indicators:

- 🟢 Done, healthy, or low risk
- 🟡 Active, pending, or needing attention
- 🔴 Blocked, risky, or not to touch without explicit approval

The overall project picture should stay high level. Only the next two or three deliverables should be broken down into actionable checklist detail.

## Balance

Too much:

- full historical checklist
- every PR detail
- every command
- every validation line

Too little:

- only current focus
- only next deliverable
- no capability map
- no later milestones
- no open questions

Correct:

- one-screen full-picture dashboard
- checkbox and todo-list style
- green, yellow, and red status indicators
- high-level capability map
- actionable detail for only the next two or three deliverables
- roadmap docs for detail

## When To Update Issue #1

Update Issue #1:

- when freeze state changes
- when Frozen Scope changes
- when a Change Request is approved for Now
- when a release stop rule changes
- after merging a deliverable PR
- when current milestone changes
- when a key decision changes
- when an open question is answered
- when guardrails change

## When Not To Update Issue #1

Do not update Issue #1:

- after every command
- for every tiny validation
- for every small doc edit
- for every non-blocking future idea
- for raw logs
- for full PR history

## PR Granularity Rules

### Good PR Size

A good PR represents:

- one deliverable capability
- one workflow-level improvement
- one coherent doc or design package
- one bounded implementation plus tests and docs

Examples:

- "Validate SSH tunnel dev access and document result"
- "Finalize template bootstrap runbook"
- "Add release v0.1.0 checklist"
- "Harden one workflow with tests and docs"

### Too Small

Avoid PRs for:

- one SSH command check
- one tunnel check
- one comment update
- one validation line
- one typo unless urgent

Examples:

- "Run one SSH tunnel command"
- "Confirm one curl response"
- "Add one checkbox to Issue #1"
- "Fix one sentence in roadmap docs"

### Too Large

Avoid combining unrelated high-risk surfaces, such as:

- deployment, production, public routing, and Docker in one PR
- backend feature, CI workflow, and server config in one PR
- product behavior change and infrastructure rollout in one PR

Examples:

- "Add public routing, Docker, production deploy, and branch protection"
- "Change backend behavior, deploy workflow, and server proxy at once"
- "Introduce auth, database, and production release together"

### Rule

A PR should be reviewable in one sitting and leave the repo in a coherent state.

## Agent Instructions

Agents should:

- read Issue #1 first, then roadmap docs
- read Freeze State before proposing work
- treat Issue #1 as the current controller
- use roadmap docs for detailed history
- implement only Frozen Scope after Implementation Plan Frozen
- move non-blocking discoveries to Change Requests or Later
- avoid PRD, BDD, ADR, runbook, and test-plan bundles for Tier 0-2 work
- avoid exceeding PR budget without explicit user approval
- avoid generalizing one adopted-app lesson into Core by default
- avoid inventing product direction
- avoid command-sized micro-phase PRs
- keep Issue #1 readable
- update relevant docs when process or roadmap meaning changes

## Milestone-Level Deliverables

The Control Board should track milestone-level deliverables, not command-level tasks.

For Milestone 6E, the intended split is:

- 6E-A Template Productization Design
- 6E-B Template Finalization Implementation

After 6E, move to one of:

- `v0.1.0` release candidate review
- Milestone 7 Production Deployment Later
- Milestone 8 Optional Hardening / Polish

Do not create `6F`, `6G`, or `6H` unless the user explicitly defines a genuinely new milestone.

After 6E-B, the next normal deliverable is the `v0.1.0` candidate review, not another 6E micro-phase.

## Anti-Patterns

Avoid:

- endless micro-phases
- one command per PR
- using Issue #1 as a full changelog
- shrinking Issue #1 until the user loses the project picture
- hiding decisions inside chat only
- shipping technical behavior without updating relevant docs

## Real Project Operating Loops

After Dogsquard is adopted into a real project, the Control Board should track operating-loop outcomes at milestone level.

An operating loop is larger than one command and smaller than an indefinite product roadmap. It should show whether Dogsquard can guide a real repo through:

- one real product PR
- stale backlog triage
- local and PR validation
- Control Board updates
- reusable Dogsquard friction capture

Do not split the loop into one PR per stale issue if no code change is needed. Close stale issues with evidence and update the Control Board.

Do not hide Dogsquard follow-up work inside the product repo. If real work exposes reusable template, runbook, or workflow improvements, capture them as a Dogsquard follow-up deliverable.

When moving from an operating loop to production design, keep the board explicit that production implementation remains approval-gated.
