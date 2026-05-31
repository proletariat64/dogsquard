---
title: "Template Finalization PRD"
doc_type: "prd"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Template Finalization PRD

## Purpose

Define how Dogsquard becomes a reusable bootstrap kit for future repositories.

Dogsquard should help the user manually create a new GitHub repository, apply Dogsquard rules, files, scripts, and workflows, and quickly start real project work.

## Target User

The target user is the user as solo developer, product owner, and process owner.

Dogsquard assumes the user controls design, review, process, release decisions, and token spending while agents do most implementation work.

## Problem Statement

Dogsquard currently works as a reference repository, but it needs a clear template boundary and initialization flow before it can be reused in new projects.

Without that boundary, future repositories may inherit example business logic, local agent files, server-specific assumptions, or deployment settings that should remain optional or configurable.

## Goals

- new repo can be initialized from Dogsquard
- project starts with docs, Issue, PR, CI, and local commands ready
- agents can read stable rules
- user can focus on design and review
- dev deploy pattern is available but configurable
- example app does not confuse future product repos

## Non-Goals

- no production deployment
- no `us.hermes` route changes
- no public URL changes
- no Docker conversion
- no self-hosted runner
- no full product generator

## Template Core

Dogsquard initialization should copy or initialize this reusable core:

- docs governance structure
- Makefile and local scripts
- `.github` issue and PR templates
- PR Quality Gate workflow
- configurable Dev Deploy workflow template
- agent charter and Control Board docs
- README template
- CHANGELOG template
- `.env.example`

Template core should avoid business-domain assumptions. Project-specific meaning should be added after initialization through BRD, PRD, BDD, ADR, and issues.

## Example App Policy

Options:

### Option A: Keep Example App In Generated Project By Default

This gives every new repo a working Go backend, JS/TS frontend, smoke tests, and deploy flow.

Risk: future repos may confuse the example domain with their real business domain.

### Option B: Keep Example App In Dogsquard Only

This keeps generated repos clean and product-neutral.

Risk: new repos lose an immediately runnable full-stack validation target unless the init flow can include it on request.

### Option C: Move Example App Under examples/internal-task-intake

This keeps the example available while clearly marking it as reference material.

Risk: implementation work is needed to move paths and preserve tests/workflows.

### Option D: Make Example App Optional Via Init Flag

This gives the user choice per repository.

Risk: bootstrap implementation becomes more complex.

Recommended policy:

Treat the example app as optional example and validation material, not mandatory business starter logic. The 6E-B implementation makes it selectable through `INCLUDE_EXAMPLE_APP=true`. Moving it under `examples/internal-task-intake` remains optional future cleanup.

## Agent-Local Files Policy

Files to evaluate:

- `AGENTS.md`
- `CLAUDE.md`
- `roster.md`
- `.claude/`

Questions:

- should they be committed?
- should they be ignored?
- should they be templated?
- should they remain local only?

Recommended approach:

- Commit generic agent rules only when they are reusable and not tool-private.
- Keep tool-local, session-specific, or machine-specific files ignored.
- Provide template files when reusable agent guidance is useful.
- Do not commit secrets, private paths, local credentials, raw tool logs, or private model/backend configuration.

## Bootstrap Flow

Implemented flow:

1. User manually creates a GitHub repo.
2. User clones the repo locally.
3. User runs Dogsquard bootstrap/init process.
4. Bootstrap copies core files.
5. User reviews generated Control Board.
6. User configures GitHub environment and secrets if dev deploy is needed.
7. User opens first design issue.
8. First PR validates local and CI gates.

Bootstrap command:

```bash
scripts/init-new-repo.sh <target-path>
```

The command defaults to dry-run mode and requires explicit `DRY_RUN=false` to copy files.

## Configuration Replacement

Initialization must eventually handle placeholders for:

- project name
- app name
- module name
- dev host
- deploy root
- backend and frontend ports
- protected production host
- domain or project URL if any

Placeholder replacement should be explicit and reviewable. It must not hardcode secrets or assume `cn.ant`, `us.hermes`, `proletariat.icu`, or any production route for new repositories.

## v0.1.0 Readiness Criteria

- Control Board usable
- docs governance complete
- PR Quality Gate green
- example app working in Dogsquard
- dev deploy workflow validated
- bootstrap design approved
- template implementation merged
- README explains how to use Dogsquard
- no secrets committed
- production not required

## Acceptance Criteria

- template boundary documented
- example app policy decided
- agent-local file policy decided
- bootstrap flow documented
- `v0.1.0` criteria documented
- no behavior changed
