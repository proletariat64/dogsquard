---
title: "Dev Deploy Workflow PRD"
doc_type: "prd"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-30"
updated: "2026-05-30"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Dev Deploy Workflow PRD

## Purpose

Define the future GitHub Actions workflow that deploys Dogsquard to the development host after changes are merged to `main`.

Phase 6C-1 is design only. It does not add the workflow file or run deployment automation.

## Target User

The target user is the repository owner operating Dogsquard as a one-person bootstrap kit with agent-assisted implementation and human-controlled release decisions.

## Problem Statement

Dogsquard already has local packaging, SSH deploy, runtime, health, diagnostics, and rollback scripts. The next step is to design a deterministic GitHub Actions workflow that can reuse those scripts for dev deployment without expanding scope into production, public routing, or server configuration.

## Goals

- deploy to the preferred dev target `cn.ant`
- run only after code is merged to `main` or manually triggered
- reuse existing local scripts
- keep deployment behavior observable and diagnosable
- keep `us.hermes` protected
- preserve manual rollback control
- avoid exposing secrets in logs

## Non-Goals

- no GitHub Actions deploy workflow in Phase 6C-1
- no production deployment
- no deployment to `us.hermes`
- no public URL exposure
- no reverse proxy configuration
- no Docker or Docker Compose
- no self-hosted runner
- no database or auth setup

## Preferred Target Host

The preferred first dev deployment target is `cn.ant`.

`cn.ant` has already accepted isolated deployment under:

```text
~/apps/dogsquard-dev
```

Runtime validation has succeeded on localhost-only ports:

```text
backend:  127.0.0.1:18080
frontend: 127.0.0.1:14173
```

## Protected Host

`us.hermes` is protected and must not be targeted by the first dev deploy workflow.

`us.hermes` hosts `proletariat.icu` and existing multica routes:

```text
/    -> multica frontend Docker service
/api -> multica backend Docker service
```

Dogsquard must not claim `/` or `/api`.

## Workflow Triggers

Future Phase 6C-2 workflow should support:

- `push` to `main`
- `workflow_dispatch`

The workflow should not run on pull requests as a deployment workflow. Pull requests are already covered by PR Quality Gate.

## Workflow Stages

The future workflow should run these stages:

1. checkout repository
2. validate repository state
3. build and package release artifact
4. upload and deploy artifact to `cn.ant`
5. restart Dogsquard runtime
6. run runtime health check
7. collect failure diagnostics

## Script Usage

The workflow should reuse existing scripts:

- `scripts/package-release.sh`
- `scripts/deploy-dev.sh`
- `scripts/runtime-dev.sh`

The workflow should prefer existing `make` targets when practical:

- `make package-release`
- `make deploy-dev`
- `make runtime-restart`
- `make runtime-health`
- `make runtime-diagnose`

## GitHub Environment

Recommended environment:

```text
development
```

The environment should contain only development deployment settings.

## GitHub Secrets

Required placeholder secret names:

```text
DEV_HOST
DEV_USER
DEV_SSH_KEY
```

No real secret values belong in repository files.

## GitHub Variables

Required placeholder variable names:

```text
DEV_DEPLOY_ROOT
DEV_APP_NAME
DEV_BACKEND_PORT
DEV_FRONTEND_PORT
```

Suggested values:

```text
DEV_DEPLOY_ROOT=~/apps/dogsquard-dev
DEV_APP_NAME=dogsquard
DEV_BACKEND_PORT=18080
DEV_FRONTEND_PORT=14173
```

`DEV_HOST` should resolve from the GitHub-hosted runner, so it may need the real host name or IP rather than the local SSH alias.

## Security Requirements

- secrets must never be printed
- SSH key should be restricted to dev deploy use
- workflow must not target production
- workflow must not target `us.hermes`
- workflow must not use `sudo`
- workflow must not edit reverse proxy config
- workflow must not start Docker containers for Dogsquard
- logs should include diagnostics but not raw environment dumps

## Failure Behavior

Failure should stop the workflow and report enough context to debug safely.

Expected behavior:

- package failure stops deployment
- SSH failure stops deployment
- deploy failure does not restart runtime
- runtime restart failure runs diagnostics
- health failure fails the workflow and runs diagnostics
- current working release should remain recoverable

## Rollback Expectations

Rollback remains manual or explicitly triggered.

The first deploy workflow should not auto-rollback unless a later phase defines that behavior.

Manual rollback should continue to use the explicit release id model:

```bash
make rollback-dev HOST=cn.ant TARGET_RELEASE=<release-id> DEPLOY_ROOT=~/apps/dogsquard-dev
```

## Manual Override Expectations

`workflow_dispatch` should allow the owner to trigger a dev deployment manually.

Manual override must still respect:

- development environment only
- `cn.ant` target only
- no production
- no `us.hermes`
- no public routing

## Acceptance Criteria For Phase 6C-2 Implementation

- workflow deploys only to the development environment
- workflow target is `cn.ant`
- workflow does not target `us.hermes`
- workflow runs on `push` to `main`
- workflow supports `workflow_dispatch`
- workflow runs validation before package/deploy
- workflow uses existing package/deploy/runtime scripts
- workflow restarts runtime and checks health
- workflow reports diagnostics on failure
- workflow does not expose secrets
- workflow does not deploy production
- workflow does not modify reverse proxy config
- workflow does not expose a public URL
