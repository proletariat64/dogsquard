---
title: "PR Quality Gate Runbook"
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

# PR Quality Gate Runbook

## Purpose

The PR Quality Gate is the first deterministic GitHub Actions quality gate for Dogsquard pull requests.

It checks shell syntax, repository hygiene, local documentation rules, early template-safe lint/test commands, and a temporary Phase 4 scope guard.

## Workflow Jobs

### Shell Check

Runs `bash -n scripts/*.sh` when shell scripts exist.

This catches syntax errors without executing the scripts.

### Repository Hygiene

Runs `git diff --check` against the PR base and head.

This catches whitespace errors such as trailing whitespace and extra blank lines at end of file.

### Local Foundation

Runs:

```bash
make help
make doc-check
make doc-guard
make release-check
```

This reuses the deterministic local foundation added in Phase 2.

### Temporary Scope Guard

Lists changed files and fails when this PR changes out-of-phase paths:

- `deploy/**`
- `docker-compose.yml`
- `Dockerfile`
- `.github/workflows/deploy.yml`
- Playwright config or test paths

Backend and frontend paths are allowed starting in Phase 5B. This guard remains intentionally temporary for deployment, Docker runtime, and Playwright paths.

### PR Quality Summary

Runs after the required jobs and fails if any required job failed or was cancelled.

This job is the intended future branch protection status check.

## Local Reproduction

Run:

```bash
make doc-check
make doc-guard
make release-check
git diff --check
bash -n scripts/*.sh
```

## Fixing Doc-Check Failures

Read the `FAIL:` lines from `make doc-check`.

Common fixes:

- create missing required docs folders
- add missing core documents
- rename docs to match folder naming rules
- add required front matter keys
- restore `## Unreleased` in `CHANGELOG.md`

Do not invent product meaning just to satisfy a documentation check.

## Fixing Shell Failures

Run:

```bash
bash -n scripts/*.sh
```

Fix the reported script and line number. Shell syntax checks do not execute scripts, so runtime failures need separate reproduction.

## Fixing Scope Guard Failures

Read the changed file list in the failed job.

If the PR changed a forbidden path, either:

- remove that change from the PR, or
- move it to the later phase where the path belongs

Do not bypass the guard by renaming files to hide deployment, app code, or Playwright behavior.

## Updating Or Relaxing The Scope Guard

Update or remove the temporary scope guard when the Control Board moves into a phase where one of the guarded areas becomes allowed.

Examples:

- A later testing phase may allow Playwright.
- Deployment phases may allow Docker and deploy workflow files.

Any relaxation should be explicit in the PR summary and related issue.

## Future Branch Protection

After the workflow is stable, repository settings should require `PR Quality Summary` before merging into `main`.

Branch protection is a GitHub repository setting and is not added by this Phase 4 workflow file.
