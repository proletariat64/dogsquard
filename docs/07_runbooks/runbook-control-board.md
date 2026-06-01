---
title: "Control Board Runbook"
doc_type: "runbook"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-06-01"
related_issue: "#1"
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

- after merging a deliverable PR
- when current milestone changes
- when a key decision changes
- when an open question is answered
- when guardrails change

## When Not To Update Issue #1

Do not update Issue #1:

- after every command
- for every tiny validation
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
- treat Issue #1 as the current controller
- use roadmap docs for detailed history
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
