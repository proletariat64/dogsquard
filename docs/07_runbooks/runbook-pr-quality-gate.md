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

The PR Quality Gate is the deterministic GitHub Actions quality gate for Dogsquard pull requests.

It checks shell syntax, repository hygiene, local documentation rules, template-safe lint/test/build commands, AI fake-completion markers, minimal Playwright smoke coverage, and a production safety guard.

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

### Fake Implementation Guard

Runs:

```bash
make fake-check
```

This scans changed production code for high-signal fake-completion markers such as todo, mock, stub, placeholder, hardcoded static returns, and not-implemented paths. It reports exact file and line findings and writes the same summary to the GitHub Actions step summary.

Intentional unfinished production placeholders must include `DOGSQUARD_INTENTIONAL_PLACEHOLDER: <reason>` near the flagged line and must be disclosed in the PR body.

### Playwright Smoke

Runs the minimal browser smoke path through:

```bash
make e2e-smoke
```

This verifies that the example app loads, shows the empty state, creates a valid task through the UI, and displays a missing-title validation error.

It is not a full frontend regression suite.

### Production Safety Guard

Lists changed files and fails when a PR attempts to add high-risk production/server artifacts without explicit approval:

- `docker-compose.yml`
- `Dockerfile`
- `.github/workflows/deploy.yml`
- `.github/workflows/deploy-production.yml`
- raw server or reverse-proxy config paths such as `nginx/**`, `caddy/**`, `traefik/**`, `server-config/**`, and `reverse-proxy/**`

Backend, frontend, deployment scaffold, runtime script, and Playwright smoke changes are now in scope when the PR itself is coherent and approved by the Control Board. The guard is no longer a phase-era blanket blocker; it protects against raw server config, Docker runtime files, and production workflow activation.

### PR Quality Summary

Runs after the required jobs and fails if any required job failed or was cancelled.

This job should become the main required branch protection status check.

Individual jobs explain what failed. The summary job gives branch protection one stable required check to enforce.

## Local Reproduction

Run:

```bash
make doc-check
make doc-guard
make fake-check
make release-check
git diff --check
bash -n scripts/*.sh
make e2e-smoke
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

## Fixing Fake Implementation Guard Failures

Read the file and line findings in the failed job.

Valid fixes are:

- implement the real behavior
- move test doubles into test or fixture paths
- rename production code that accidentally uses mock/fake/stub naming
- disclose an intentional unfinished placeholder with `DOGSQUARD_INTENTIONAL_PLACEHOLDER: <reason>` and explain it in the PR

Do not bypass the guard by hiding fake-complete behavior behind different wording.

## Fixing Production Safety Guard Failures

Read the changed file list in the failed job.

If the PR changed a forbidden path, either:

- remove that change from the PR, or
- get explicit approval and move it to a focused production/server PR

Do not bypass the guard by renaming files to hide production workflow, Docker runtime, raw server config, or reverse-proxy behavior.

## Fixing PR Quality Summary Failures

Open the failed individual job first.

`PR Quality Summary` is intentionally a final aggregate. It should not be fixed directly unless the workflow summary dependency list is wrong.

Fix the underlying job, push the correction, and let the summary rerun.

## Updating Or Relaxing The Production Safety Guard

Update or remove the production safety guard only when the Control Board explicitly approves a production/server capability that needs one of the guarded areas.

Examples:

- a production workflow implementation PR may allow `.github/workflows/deploy-production.yml`
- a Docker runtime decision may allow `Dockerfile` or `docker-compose.yml`
- a server-config management decision may allow reviewed reverse-proxy snippets

Any relaxation should be explicit in the PR summary and related issue.

## Future Branch Protection

Repository settings should require `PR Quality Summary` before merging into `main`.

Branch protection is a manual GitHub repository setting in Phase 5E. It is not configured automatically by this repository yet.
