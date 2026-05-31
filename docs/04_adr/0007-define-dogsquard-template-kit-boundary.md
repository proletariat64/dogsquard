---
title: "Define Dogsquard Template Kit Boundary"
doc_type: "adr"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# ADR 0007: Define Dogsquard Template Kit Boundary

## Status

Draft.

## Context

Dogsquard has grown from process foundation into a working reference repository with docs governance, local commands, GitHub templates, PR Quality Gate, example app, Playwright smoke, dev deploy, runtime management, and SSH tunnel validation.

The next step is to make Dogsquard reusable as an initialization suite for future small and medium internal application repositories.

Dogsquard is not the future business product itself. It should provide the process, structure, and delivery foundation so product-specific meaning can be added after initialization.

## Decision

Dogsquard `v0.1.0` should ship as a reusable bootstrap kit focused on docs, local commands, GitHub workflow, PR quality, dev deploy pattern, and agent operating rules.

The example app should be treated as example and validation material, not mandatory business starter logic.

## Template Core Boundary

The reusable template core should include:

- docs governance structure and rules
- Makefile and local validation scripts
- GitHub issue and PR templates
- PR Quality Gate workflow
- configurable Dev Deploy workflow pattern
- agent charter and Control Board docs
- README and CHANGELOG templates
- `.env.example`
- release and bootstrap checklists

The reusable template core should not include hardcoded business domain meaning, secrets, raw server output, or private local tool state.

## Example App Decision

The Internal Task Intake example app remains useful for Dogsquard validation and demonstration.

It should not be mandatory business starter logic for every generated repository.

Future implementation should either:

- move it under `examples/internal-task-intake`, or
- make it optional through the bootstrap/init flow.

## Agent-Local File Decision

Generic reusable agent rules may be committed when they are project-neutral and safe.

Tool-local or session-specific files should stay local or ignored.

Policy:

- `AGENTS.md`: commit only if generic and reusable
- `CLAUDE.md`: commit only if generic and reusable, not tool-private backend configuration
- `roster.md`: template only if it describes reusable roles, not private session state
- `.claude/`: keep ignored unless a specific reusable skill or template is deliberately added

## Consequences

- future repositories start with governance and delivery structure instead of example business meaning
- product-specific BRD, PRD, BDD, and ADR work remains explicit
- dev deploy is available as a pattern but must be configured for the target repo
- example app remains useful for validating Dogsquard itself
- bootstrap implementation must distinguish template core from optional example material

## Alternatives Considered

### Ship Everything As-Is

This is simple but risks copying example business logic and local agent state into future product repositories.

### Strip Dogsquard To Docs Only

This is clean but loses the working local/CI/deploy proof that makes Dogsquard useful.

### Build A Full Product Generator

This could produce more complete starting applications, but it is too broad for `v0.1.0` and would invent product direction.

## Why Not Production Yet

Production deployment requires explicit approval, route strategy, release gates, and protection for existing services.

Template finalization should finish before production work begins.

## Why Not Public Route Yet

Milestone 6D validated SSH tunnel access as sufficient for current dev validation.

Public route work remains optional and should not block template finalization.

## Future Migration Path

1. Approve 6E-A template productization design.
2. Implement 6E-B bootstrap/init flow.
3. Validate a fresh repo initialization.
4. Improve README and release checklist.
5. Cut a `v0.1.0` candidate if readiness criteria pass.
6. Consider production deployment design later under Milestone 7.
