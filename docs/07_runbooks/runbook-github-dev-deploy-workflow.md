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

Prepare the manual GitHub configuration needed for a future dev deploy workflow that targets `cn.ant`.

Phase 6C-1 does not add the workflow. It defines the setup rules for Phase 6C-2.

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
DEV_HOST=cn.ant or actual hostname resolvable by GitHub runner
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

The future workflow should run on:

- push to `main`
- manual `workflow_dispatch`

The workflow should not deploy from pull request branches.

## Inspect Workflow Logs

When the future workflow exists:

1. Open the Actions tab.
2. Select the dev deploy workflow run.
3. Read stage output in order.
4. Check package, SSH, deploy, runtime, and health stages.
5. Check diagnostic output only after failures.

## Diagnose Failure

Use these local commands first when debugging:

```bash
make package-release
make deploy-dev-dry-run HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev
make runtime-diagnose HOST=cn.ant DEPLOY_ROOT=~/apps/dogsquard-dev
```

In workflow logs, look for:

- missing secret or variable
- SSH connection error
- package failure
- artifact upload failure
- runtime restart failure
- runtime health failure

## Manual Rollback

Rollback remains explicit:

```bash
make rollback-dev HOST=cn.ant TARGET_RELEASE=<release-id> DEPLOY_ROOT=~/apps/dogsquard-dev
```

Do not rollback to an unverified release id.

Do not run rollback on `us.hermes` in this phase.

## Explicit Warnings

- Do not configure `us.hermes` for dev deploy yet.
- Do not expose a public URL yet.
- Do not configure production.
- Do not configure reverse proxy routes.
- Do not add Docker or Docker Compose for Dogsquard.
- Do not require `sudo`.
