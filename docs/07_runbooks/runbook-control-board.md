---
title: "Control Board Runbook"
doc_type: "runbook"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Control Board Runbook

## Purpose

Issue #1 is the Dogsquard Control Board.

Its purpose is to control current project progress, not to preserve every historical detail.

Detailed roadmap, history, and phase grouping live in:

```text
docs/05_design/design-20260531-project-roadmap.md
```

## What Belongs In Issue #1

Issue #1 should contain:

- current milestone
- current focus
- next deliverable
- active decisions
- open questions
- blocked items
- links to roadmap and key docs

The Control Board should be short enough to scan quickly before starting work.

## What Belongs In Roadmap Docs

Roadmap docs should contain:

- completed capability groups
- historical milestone summaries
- infrastructure decisions
- PR granularity rules
- future roadmap
- detailed open questions

## When To Update Issue #1

Update Issue #1 when:

- a major PR opens
- a major PR merges
- current milestone changes
- next deliverable changes
- a key decision changes
- a blocker appears or clears

Do not update Issue #1 for every command-level validation.

## When To Create A New PR

Create a PR when the repo gains one coherent deliverable, such as:

- a new design package
- a new tested local capability
- a workflow-level CI/CD improvement
- a bounded implementation with tests and docs
- a roadmap or governance update

## When Not To Create A PR

Do not create a separate PR for:

- one SSH command check
- one tunnel command check
- one validation line
- one issue comment update
- one tiny wording change unless urgent

Batch small related process updates into a coherent deliverable.

## How To Summarize Progress After Merge

After a PR merges:

1. Move the current milestone forward if needed.
2. Record only the capability-level result in Issue #1.
3. Put detailed history in roadmap docs, runbooks, test plans, or ADRs.
4. Keep validation detail in the PR body or relevant test plan.

## How Agents Should Use Issue #1

Agents should:

- read Issue #1 before starting
- treat it as the current controller
- follow links to roadmap docs for history
- avoid inventing product direction
- avoid adding micro-phases unless the user explicitly requests them
- propose PRs around useful deliverables, not single commands

## How The User Should Use Issue #1

The user should use Issue #1 to:

- set current focus
- approve or reject roadmap direction
- record key decisions
- capture blockers
- define the next useful deliverable

## PR Granularity Examples

Good PR examples:

- "Add dev public access design"
- "Validate SSH tunnel dev access and document result"
- "Finalize template bootstrap runbook"
- "Add release v0.1.0 checklist"

Too-small PR examples:

- "Run one SSH tunnel command"
- "Confirm one curl response"
- "Add one checkbox to Issue #1"
- "Fix one sentence in roadmap docs"

Too-large PR examples:

- "Add public routing, Docker, production deploy, and branch protection"
- "Change backend behavior, deploy workflow, and server proxy at once"
- "Introduce auth, database, and production release together"

## Anti-Patterns

Avoid:

- endless micro-phases
- one command per PR
- using Issue #1 as a full changelog
- hiding decisions inside chat only
- shipping technical behavior without updating relevant docs
- allowing docs to become a second source of truth that conflicts with Issue #1

## Practical Rule

A PR should be reviewable in one sitting and leave the repo in a coherent state.

Issue #1 should say what matters now.

The roadmap should explain how Dogsquard got here and where it is going.
