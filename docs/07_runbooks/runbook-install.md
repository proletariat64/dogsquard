---
title: "Install Shell Runbook"
doc_type: "runbook"
status: "draft"
owner: "coding-agent"
source: "agent"
created: "2026-07-01"
updated: "2026-07-01"
related_issue: ""
related_pr: ""
supersedes: ""
---

# Install Shell Runbook

## Purpose

Operate the Dogsquard install shell to install selected modules into a target repository, optionally configure AI PR review, validate, commit/push, and uninstall.

## Prerequisites

- Dogsquard repository cloned locally
- Target repository exists (created manually or via `git init`)
- bash, python3, sha256sum, git available
- For AI PR review: `qodercli` or `gh` authenticated when applicable

## Quick Start

### Dry-run (default)

```bash
./install --repo ../target-repo --project-type docs-only --modules governance,pr-quality
```

### Apply

```bash
./install --repo ../target-repo --project-type docs-only --modules governance,pr-quality --apply
```

### Interactive Menu

```bash
./install --menu
```

## Modules

| Module | Description | Requires Bootstrap |
|--------|-------------|-------------------|
| `governance` | docs structure, scripts, Makefile, templates | Yes (base) |
| `pr-quality` | profile-aware PR Quality Gate workflow | Yes (base) |
| `dev-deploy` | dev deployment scripts and workflow | Yes (needs governance or pr-quality) |
| `example-app` | sample Go/JS backend and frontend | Yes (needs governance or pr-quality) |
| `production-profile` | scaffold-only production planning docs | Yes (needs governance or pr-quality) |
| `ai-pr-review` | unified AI PR review workflow and configure shell | No |

## AI PR Review Pass-through

When installing `ai-pr-review` with configuration:

```bash
./install --repo ../target --project-type docs-only --modules ai-pr-review \
  --ai-enabled true --ai-engine qoder \
  --qoder-model Qwen3.7-Max --qoder-model GLM-5.2 --apply
```

Without configuration inputs, a disabled safe config is created:

```bash
./install --repo ../target --project-type docs-only --modules ai-pr-review --apply
```

Then configure later:

```bash
cd ../target && scripts/configure-ai-ci.sh
```

## Config File

Create a `KEY=value` file:

```bash
TARGET_DIR=../target-repo
PROJECT_TYPE=docs-only
MODULES=ai-pr-review
AI_REVIEW_ENABLED=true
AI_REVIEW_ENGINE=qoder
QODER_MODELS=Qwen3.7-Max,GLM-5.2
RUN_CHECKS=true
COMMIT_PUSH=false
FORCE=false
```

Use with:

```bash
./install --config install.env
```

CLI flags override config values. Unknown keys fail fast.

## Uninstall

```bash
./install --uninstall --repo ../target-repo          # dry-run
./install --uninstall --repo ../target-repo --apply   # apply
```

Uninstall is all-or-nothing. No module selection. Requires `.dogsquard/install-manifest.json`.

## Safety Rules

- Dry-run is default; use `--apply` to write files
- Existing files are preserved unless `--force` is set
- Overwritten files are backed up to `.dogsquard/backups/`
- Secret values are never read, printed, copied, or stored
- Commit/push is opt-in and never force-pushes
- Uninstall without manifest fails safely

## Validation

```bash
bash -n install scripts/install.sh scripts/test-install.sh
bash scripts/test-install.sh
make install-test
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `unknown config key` | Config file has unexpected key | Check allowlist in `--help` |
| `target directory must not be Dogsquard` | `--repo` points to Dogsquard itself | Use a different target path |
| `module requires governance or pr-quality` | Optional module selected without base | Add `governance` or `pr-quality` to `--modules` |
| `Auto is an implicit runner fallback` | `Auto` passed as `--qoder-model` | Use real model names only |
| `settings.json exists and --force is not set` | AI config change requested but target has existing config | Use `--force` or remove config flags |
