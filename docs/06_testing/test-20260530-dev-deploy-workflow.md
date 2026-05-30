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

Phase 6C-1 is design only. Phase 6C-2 may implement the workflow.

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

Phase 6C-2 should validate:

1. checkout works
2. repository validation passes
3. package-release succeeds
4. SSH setup succeeds
5. artifact deploy succeeds
6. runtime restart succeeds
7. runtime health succeeds
8. diagnostics run on failure

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
