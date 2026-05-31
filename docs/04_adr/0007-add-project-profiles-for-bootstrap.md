---
title: "Add Project Profiles for Bootstrap"
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

# Add Project Profiles for Bootstrap

## Status

Draft.

## Context

Dogsquard v0.1.0 can initialize a fresh repository with governance files, local commands, issue templates, PR templates, and PR Quality Gate. The first real-world trial applied Dogsquard governance to `dogpdteamreport`, an existing Node.js, Express, TypeScript, sql.js, and static frontend app.

The trial succeeded, but it required manual adaptation:

- Node Makefile behavior replaced Dogsquard's reference Go/frontend assumptions.
- PR Quality Gate needed Node Quality instead of Dogsquard example app checks.
- Existing README, `ddd/`, `spec/`, source, and tests had to be preserved.
- Dogsquard example app and dev deploy workflow were not appropriate default assets.
- A runtime directory placeholder was needed for ignored `data/` files.

## Decision

Dogsquard will support project profiles for bootstrap, with `PROJECT_TYPE=node` as the first external-project profile candidate.

Profiles define what Dogsquard copies, adapts, preserves, or skips for a target repository. The initial profile set should include:

- `PROJECT_TYPE=node`
- `PROJECT_TYPE=go-js`
- `PROJECT_TYPE=docs-only`

## Consequences

- Bootstrap can become safer for existing real projects.
- Node repositories can receive npm-based Makefile and CI commands without manual rewrite.
- Dogsquard can keep its example app and dev deployment assets optional.
- Profile behavior needs explicit tests before becoming the default bootstrap path.

## Alternatives Considered

### Single Default Bootstrap

Rejected because the `dogpdteamreport` trial showed a single default shape creates manual adaptation work and risks copying irrelevant assets.

### Copy Everything And Let User Delete

Rejected because it increases noise and may accidentally introduce deployment, example app, or server-specific material into unrelated repos.

### Separate Template Repositories Per Stack

Deferred. Multiple repos may be useful later, but profile-aware bootstrap keeps Dogsquard easier to evolve at the current stage.

## Why Project Profiles Are Needed

Different repositories need different validation gates. A Node app, Go/JS app, and docs-only repo should not inherit the same Makefile or CI assumptions.

## Why Node Profile Is First

The first real-world adoption target was a Node.js project. The trial provided concrete evidence for what a Node profile must generate and preserve.

## Why Dogsquard Example App Should Not Be Copied Blindly

The example app validates Dogsquard itself. It is not mandatory business starter logic for every future project.

## Why Deployment Workflow Should Be Opt-in

Deployment depends on host, route, secrets, ports, and operational context. Copying deployment workflow by default is unsafe and creates irrelevant setup work for repos that are not ready to deploy.

## Why Existing Files Must Be Preserved

Real repositories already contain product-specific README, docs, source, tests, and workflow assumptions. Bootstrap should add governance without overwriting domain knowledge.

## Future Migration Path

The next implementation should update `scripts/init-new-repo.sh` to accept `PROJECT_TYPE`, generate profile-specific Makefile and PR Quality Gate assets, and keep dry-run behavior as the default.
