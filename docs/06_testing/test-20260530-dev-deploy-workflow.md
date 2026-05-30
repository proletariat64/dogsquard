---
title: "Dev Deploy Workflow Test Plan"
doc_type: "test"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-30"
updated: "2026-05-30"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Dev Deploy Workflow Test Plan

## Objective

Define how to validate the future GitHub Actions development deployment workflow before it becomes a trusted release path.

Phase 6C-1 is design only. Phase 6C-2 implements the first dev deploy workflow.

## Local Preconditions

Before workflow implementation:

- `make doc-check` passes
- `make doc-guard` passes
- `make release-check` passes
- `make package-release` passes
- `cn.ant` has accepted manual isolated deployment
- `cn.ant` runtime health has been validated
- `us.hermes` remains protected

## GitHub Preconditions

Before enabling the workflow:

- PR Quality Gate is passing on `main`
- GitHub Environment `development` exists
- required secrets are configured
- required variables are configured
- branch protection prevents merging failed PRs

## Required Secrets And Variables Validation

Secrets:

```text
DEV_HOST
DEV_USER
DEV_SSH_KEY
```

Variables:

```text
DEV_DEPLOY_ROOT
DEV_APP_NAME
DEV_BACKEND_PORT
DEV_FRONTEND_PORT
```

The workflow should fail clearly if a required value is missing.

It should not print secret values.

## Workflow Validation Steps

Phase 6C-2 validates:

1. checkout works
2. repository validation passes
3. package-release succeeds
4. SSH setup succeeds
5. artifact deploy succeeds
6. runtime restart succeeds
7. runtime health succeeds
8. diagnostics run on failure

Workflow file:

```text
.github/workflows/deploy-dev.yml
```

## Phase 6C-2 Validation

Required local validation:

- `make doc-check`
- `make doc-guard`
- `make release-check`
- `git diff --check`
- `bash -n scripts/*.sh`
- `cd backend && go test ./...`
- `cd frontend && npm install`
- `cd frontend && npm run build`
- `make e2e-smoke`
- `make package-release`
- `make deploy-dev-dry-run HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev`
- `make runtime-status HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev`

The dev deploy workflow should not run from pull requests.

After merge, it may run on push to `main`. If the `development` environment is not configured yet, it should fail with a clear missing configuration message.

## Dry-Run Workflow Test

Manual `workflow_dispatch` with `dry_run=true` should:

- checkout the selected ref
- validate local quality
- package release artifact
- configure SSH
- run the deploy wrapper in dry-run mode
- skip runtime restart and health activation
- run only safe status if configured to do so

## Real Deploy Workflow Test Expectation

Manual `workflow_dispatch` with `dry_run=false` and `restart_runtime=true` should:

- deploy artifact to `cn.ant`
- update the dev `current` symlink under `DEV_DEPLOY_ROOT`
- restart runtime through `scripts/runtime-dev.sh`
- run runtime health
- fail if health fails

This test requires configured environment secrets and variables.

## Failure Diagnostic Expectation

If deploy, restart, or health fails, the workflow should attempt:

- runtime status
- runtime diagnose
- runtime logs

Diagnostics must not target `us.hermes` and must not print secrets.

## Success Path Test

Given secrets and variables are configured correctly:

- merge a small approved change to `main`
- confirm the dev deploy workflow starts
- confirm package-release succeeds
- confirm artifact deploys to `cn.ant`
- confirm runtime restarts
- confirm runtime health passes
- confirm previous releases remain available

## Failure Path Tests

Required failure cases:

- missing secret fails before SSH
- package failure stops before deploy
- SSH failure stops before runtime restart
- deploy failure stops before runtime restart
- runtime restart failure reports diagnostics
- runtime health failure fails workflow

## SSH Failure Test

Use an intentionally invalid development host or key in a controlled test environment.

Expected result:

- workflow fails at SSH setup or connection
- no runtime restart is attempted
- logs do not print key material

## Package Failure Test

Create a controlled package failure in a test branch or temporary workflow test.

Expected result:

- package step fails
- no artifact upload occurs
- no remote runtime action occurs

## Runtime Health Failure Test

Use a controlled failure such as an occupied runtime port or stopped backend in a test run.

Expected result:

- workflow fails health check
- runtime diagnostics are collected
- logs point to backend and frontend status

## Rollback Validation

Rollback should remain manual or explicitly triggered.

Validation should confirm:

- releases can be listed
- `TARGET_RELEASE` is required
- current symlink changes only under `DEV_DEPLOY_ROOT`
- runtime is not restarted unless explicitly requested

## Log And Diagnostic Expectations

Workflow logs should show:

- current stage
- package artifact name
- sanitized target host label
- runtime status
- health result
- diagnose output on failure

Workflow logs should not show:

- private key material
- raw secrets
- full environment dumps
- raw server config

## Excluded From Phase 6C-2

- production deployment
- `us.hermes` deployment
- public URL exposure
- reverse proxy configuration
- Docker or Docker Compose
- self-hosted runner
- database setup
- auth setup

## Acceptance Criteria

- workflow is scoped to development environment
- workflow targets `cn.ant` only
- workflow runs after merge to `main`
- workflow supports manual dispatch
- workflow uses existing scripts
- workflow checks runtime health
- workflow reports diagnostics on failure
- workflow does not print secrets
- workflow does not deploy production
- workflow does not deploy to `us.hermes`
- workflow does not expose a public URL
- workflow rejects protected `us.hermes` and `proletariat.icu` targets
