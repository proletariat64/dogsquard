---
title: "GitHub Dev Deploy Workflow Runbook"
doc_type: "runbook"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-30"
updated: "2026-05-30"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# GitHub Dev Deploy Workflow Runbook

## Purpose

Prepare the manual GitHub configuration needed for the dev deploy workflow that targets `cn.ant`.

Phase 6C-2 adds:

```text
.github/workflows/deploy-dev.yml
```

The workflow deploys only through the GitHub Environment `development`.

## Required GitHub Environment

Create one GitHub Environment:

```text
development
```

Use it only for development deployment settings.

## Required Secrets

Add these environment secrets:

```text
DEV_HOST
DEV_USER
DEV_SSH_KEY
```

Do not commit secret values to the repository.

## Required Variables

Add these environment variables:

```text
DEV_DEPLOY_ROOT
DEV_APP_NAME
DEV_BACKEND_PORT
DEV_FRONTEND_PORT
```

Suggested values:

```text
DEV_HOST=47.103.65.82 or actual hostname resolvable by GitHub runner
DEV_DEPLOY_ROOT=~/apps/dogsquard-dev or absolute user-writable path
DEV_APP_NAME=dogsquard
DEV_BACKEND_PORT=18080
DEV_FRONTEND_PORT=14173
```

The local SSH alias `cn.ant` may not exist on GitHub-hosted runners. Use a hostname or IP that the runner can resolve.

## Create Environment Manually

In GitHub:

1. Open repository settings.
2. Open Environments.
3. Create `development`.
4. Add environment secrets.
5. Add environment variables.
6. Do not create a production environment for this phase.

## Add Secrets Manually

For each secret:

1. Open the `development` environment.
2. Add the secret by name.
3. Paste the value.
4. Save.

Never paste secret values into issues, pull requests, docs, or workflow logs.

## Add Variables Manually

For each variable:

1. Open the `development` environment.
2. Add the variable by name.
3. Set the placeholder-compatible value.
4. Save.

## SSH Key Guidance

Prefer a deploy-specific key or limited user key.

Avoid a broad personal key when a narrower key is practical.

Recommended constraints:

- key can access only the dev host
- remote user can write only the Dogsquard deploy root
- no `sudo` is required
- key is rotated if exposed

## Workflow Trigger Expectations

The workflow runs on:

- push to `main`
- manual `workflow_dispatch`

The workflow should not deploy from pull request branches.

Manual dispatch inputs:

- `deploy_ref`: optional Git ref to deploy. If omitted, the current workflow ref is used.
- `dry_run`: `"true"` or `"false"`. Dry-run deploys the plan without activating a release.
- `restart_runtime`: `"true"` or `"false"`. If false, deployment can complete without runtime restart or health check.

For normal development deployment, use:

```text
dry_run=false
restart_runtime=true
```

## Inspect Workflow Logs

When the workflow runs:

1. Open the Actions tab.
2. Select `Dev Deploy`.
3. Read stage output in order.
4. Check package, SSH, deploy, runtime, and health stages.
5. Check diagnostic output only after failures.

## Diagnose Failure

Use these local commands first when debugging:

```bash
make package-release
make deploy-dev-dry-run HOST=cn.ant DEPLOY_ROOT='~/apps/dogsquard-dev'
make runtime-diagnose HOST=cn.ant DEPLOY_ROOT='~/apps/dogsquard-dev'
```

Quote `DEPLOY_ROOT='~/apps/dogsquard-dev'` in local commands when the path should expand on the remote host. Without quotes, the local shell may expand `~` before `make` runs.

In workflow logs, look for:

- missing secret or variable
- SSH connection error
- package failure
- artifact upload failure
- runtime restart failure
- runtime health failure

On failure, the workflow attempts safe diagnostics:

- runtime status
- runtime diagnose
- runtime logs

Diagnostics should not use `sudo`, edit server config, or dump secrets.

## Manual Rollback

Rollback remains explicit:

```bash
make rollback-dev HOST=cn.ant TARGET_RELEASE=<release-id> DEPLOY_ROOT='~/apps/dogsquard-dev'
```

Do not rollback to an unverified release id.

Do not run rollback on `us.hermes` in this phase.

## Explicit Warnings

- `DEV_HOST` must identify the `cn.ant` dev target or its real hostname/IP.
- The local SSH alias `cn.ant` may not work from GitHub-hosted runners.
- The workflow rejects `us.hermes`, `proletariat.icu`, `www.proletariat.icu`, and `43.130.49.185`.
- Do not configure `us.hermes` for dev deploy yet.
- Do not expose a public URL yet.
- Do not configure production.
- Do not configure reverse proxy routes.
- Do not add Docker or Docker Compose for Dogsquard.
- Do not require `sudo`.

## Phase 6C-3 Validation

Phase 6C-3 validated the workflow behavior using the GitHub Environment `development`.

Sanitized results:

- the first automatic `push` run failed early because required environment values were incomplete
- `DEV_HOST`, `DEV_USER`, and required variables were then configured without changing or exposing `DEV_SSH_KEY`
- manual `workflow_dispatch` with `dry_run=true` and `restart_runtime=false` succeeded
- dry-run packaged the release, configured SSH, ran deploy planning, and skipped runtime restart
- manual `workflow_dispatch` with `dry_run=false` and `restart_runtime=true` succeeded
- real workflow deploy activated a release on `cn.ant`, restarted runtime, and passed runtime health
- local `runtime-status` confirmed backend and frontend processes running from `~/apps/dogsquard-dev`
- no pull request deploy trigger was added
- no `us.hermes`, `proletariat.icu`, or `43.130.49.185` deploy target was used

GitHub-hosted workflow logs should be inspected for stage-level status only. Do not copy raw logs into repository docs if they contain paths, host details, or other sensitive operational data.
