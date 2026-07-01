---
title: "Install Shell Implementation Spec"
doc_type: "design"
status: "draft"
owner: "coding-agent"
source: "agent"
created: "2026-07-01"
updated: "2026-07-01"
related_issue: ""
related_pr: ""
supersedes: ""
---

# Install Shell Implementation Spec

## Source Requirement

Primary PRD: [[docs/02_prd/prd-20260701-install-scripts.md]]

Related AI CI design:

- [[docs/02_prd/prd-20260701-unified-ai-pr-review-ci.md]]
- [[docs/05_design/design-20260701-ai-ci-configure-shell-spec.md]]
- [[docs/05_design/design-20260701-unified-ai-pr-review-implementation-spec.md]]

This spec defines the implementation path for a root `./install` entrypoint and `scripts/install.sh` helper that can install selected Dogsquard modules into a target repository, delegate AI PR review configuration to the existing AI CI configure shell, record a non-secret install manifest, and uninstall all Dogsquard-managed assets safely.

## Current Code Baseline

Current Dogsquard repository has:

```text
scripts/bootstrap-project.sh
scripts/configure-ai-ci.sh
scripts/test-bootstrap-project.sh
scripts/test-configure-ai-ci.sh
scripts/upsert-pr-comment.sh
.github/workflows/ai-pr-review.yml
.github/workflows/scripts/ai_review_pr.py
.github/workflows/prompts/pr-review-policy.md
.github/workflows/prompts/pr-review-output-contract.md
.github/ai-review/settings.json
.github/claude/deepseek-settings.json
.github/qoder/settings.json
.github/workflows/pr-quality.yml
```

Missing for this feature:

```text
install
scripts/install.sh
scripts/test-install.sh
docs/07_runbooks/runbook-install.md
```

Useful existing behavior:

- `scripts/bootstrap-project.sh` is the canonical source for profile-aware governance, PR Quality Gate, optional dev deploy, optional example app, and optional production-profile scaffold.
- `scripts/bootstrap-project.sh` is dry-run by default and skips existing files unless `FORCE=true`.
- `scripts/configure-ai-ci.sh` owns AI review enabled/disabled state, engine selection, Qoder model validation, optional non-secret GitHub variable sync, and secret setup handoff.
- The unified AI PR review workflow already preserves one Dogsquard comment marker and one active workflow.

Current implementation gaps:

- no root install shim exists
- no user-facing module selector exists
- no non-secret install manifest exists
- `scripts/bootstrap-project.sh` does not yet emit a structured operation ledger
- uninstall cannot be implemented safely without a manifest and checksums
- no install UAT script exists for the dedicated UAT playground

## Settled Decisions

### Command Names

Add:

```text
./install
scripts/install.sh
```

Do not expose a bare `install` command because it conflicts with coreutils `install`.

### Bootstrap Reuse

Do not duplicate the bootstrap file list in `scripts/install.sh`.

The install shell should invoke `scripts/bootstrap-project.sh` for bootstrap-backed modules and add only minimal ledger instrumentation to bootstrap helper primitives. `scripts/bootstrap-project.sh` remains the source of truth for profile copy/write behavior.

### AI PR Review Delegation

`ai-pr-review` is a module but not an install-script-owned provider framework.

`install.sh` copies the unified AI review assets and delegates configuration to the target repo's copied `scripts/configure-ai-ci.sh`. It must not reimplement:

- provider registry
- Qoder model picker
- Qoder fallback ordering
- GitHub variable sync
- secret setup

### AI Review Default During Install

`ai-pr-review` is explicit-only for MVP. It is not included by default for app repositories.

When `ai-pr-review` is selected without AI config inputs in non-interactive mode:

- install the AI review assets
- ensure the target does not silently invoke a provider by generating a disabled AI review config when no target config exists
- preserve an existing target `.github/ai-review/settings.json` unless `--force` is explicit
- print the follow-up command:

```bash
cd <target> && scripts/configure-ai-ci.sh
```

The disabled config is an install safety state, not a provider choice. The user can enable and choose provider/model through `scripts/configure-ai-ci.sh` afterward.

### Install Plan Artifact

Interactive mode may write a local reviewed plan to:

```text
.tmp/install/plan.env
```

The plan file is local working context and is not committed by default.

The committed/auditable target artifact is:

```text
.dogsquard/install-manifest.json
```

### Uninstall Scope

Uninstall is all-or-nothing for all Dogsquard-managed assets in the target repo. No module picker appears during uninstall.

Uninstall must never guess when no manifest exists.

### GitHub Secrets And Variables

The install shell must never read, print, copy, store, unset, or delete GitHub secret values.

Uninstall must not unset GitHub repository secrets or variables. It may print manual cleanup guidance.

`--ai-apply-github-vars` is explicit, valid only with install `--apply`, and delegates non-secret variable writes to `scripts/configure-ai-ci.sh --apply-github-vars`.

## New File Layout

Add:

```text
install
scripts/install.sh
scripts/test-install.sh
docs/07_runbooks/runbook-install.md
```

Modify minimally:

```text
scripts/bootstrap-project.sh
```

Only add optional ledger emission to bootstrap helper primitives. Do not change bootstrap default behavior when no ledger env var is provided.

## Command Contract

### Root Shim

`./install` should be a thin shim:

```bash
#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$script_dir/scripts/install.sh" "$@"
```

### Help

```bash
./install --help
```

Must document:

- dry-run default
- interactive menu
- non-interactive install
- config file
- modules
- AI configure pass-through flags
- uninstall
- force
- validation
- commit/push

### Primary Non-interactive Install

```bash
./install --repo ../target-repo --project-type node --modules governance,pr-quality,ai-pr-review
```

Dry-run by default.

Apply requires:

```bash
./install --repo ../target-repo --project-type node --modules governance,pr-quality --apply
```

### Interactive Menu

```bash
./install --menu
```

Menu prompts:

1. target repo path
2. project type: `node`, `go-js`, `docs-only`
3. selected modules
4. if `ai-pr-review` is selected, whether to configure AI review now
5. if configuring AI review, pass through to the AI CI configure choices or collect equivalent non-secret flags
6. whether to run validation
7. whether to commit/push after validation
8. final apply confirmation

Uninstall mode must not show module selection.

### AI PR Review Install

```bash
./install \
  --repo ../target-repo \
  --project-type docs-only \
  --modules ai-pr-review \
  --ai-enabled true \
  --ai-engine qoder \
  --qoder-model Qwen3.7-Max \
  --qoder-model GLM-5.2 \
  --apply
```

Install passes through to the copied target helper:

```bash
scripts/configure-ai-ci.sh \
  --enabled true \
  --engine qoder \
  --qoder-model Qwen3.7-Max \
  --qoder-model GLM-5.2 \
  --apply
```

When `--ai-apply-github-vars` is set, append `--apply-github-vars` to the configure helper invocation.

### Uninstall

Dry-run:

```bash
./install --uninstall --repo ../target-repo
```

Apply:

```bash
./install --uninstall --repo ../target-repo --apply
```

Uninstall ignores module flags and must fail if `.dogsquard/install-manifest.json` is missing.

## Config File Contract

Config file is simple non-secret `KEY=value` shell-like data, but it must be parsed by the installer allowlist, not sourced as executable shell.

Allowed keys:

```text
TARGET_DIR
PROJECT_TYPE
MODULES
AI_REVIEW_ENABLED
AI_REVIEW_ENGINE
QODER_MODELS
AI_REVIEW_APPLY_GITHUB_VARS
RUN_CHECKS
COMMIT_PUSH
FORCE
UNINSTALL
```

Rules:

- unknown key fails fast
- duplicate key fails fast except repeated CLI `--qoder-model`
- CLI flags override config values
- secret values are invalid in config
- whitespace around `=` is not supported in MVP
- comments beginning with `#` are allowed
- empty lines are allowed

Example:

```bash
TARGET_DIR=/home/daishun/dev/dogci-uat-demo-20260630-102459
PROJECT_TYPE=docs-only
MODULES=ai-pr-review
AI_REVIEW_ENABLED=true
AI_REVIEW_ENGINE=qoder
QODER_MODELS=Qwen3.7-Max,GLM-5.2
AI_REVIEW_APPLY_GITHUB_VARS=false
RUN_CHECKS=true
COMMIT_PUSH=false
FORCE=false
```

## Module Model

### Module Names

Allowed modules:

```text
governance
pr-quality
dev-deploy
example-app
production-profile
ai-pr-review
```

`ai-fix-bug` is out of MVP.

### Bootstrap-backed Modules

These modules are bootstrap-backed:

```text
governance
pr-quality
dev-deploy
example-app
production-profile
```

MVP coupling rule:

- selecting `governance` or `pr-quality` runs `scripts/bootstrap-project.sh`
- bootstrap currently installs governance core plus profile-aware PR Quality Gate together
- the plan must print this coupling explicitly
- `dev-deploy`, `example-app`, and `production-profile` require bootstrap base and are invalid by themselves in MVP

Flag translation:

| Install module | Bootstrap input |
|---|---|
| `governance` | bootstrap base, always with profile scaffolding |
| `pr-quality` | bootstrap profile workflow, currently coupled with base |
| `dev-deploy` | `INCLUDE_DEV_DEPLOY=true` |
| `example-app` | `INCLUDE_EXAMPLE_APP=true` |
| `production-profile` | `INCLUDE_PRODUCTION_PROFILE=true` |

Bootstrap invocation shape:

```bash
PROJECT_TYPE=<node|go-js|docs-only> \
TARGET_DIR=<target> \
DRY_RUN=<true|false> \
FORCE=<true|false> \
INCLUDE_DEV_DEPLOY=<true|false> \
INCLUDE_EXAMPLE_APP=<true|false> \
INCLUDE_PRODUCTION_PROFILE=<true|false> \
DOGSQUARD_LEDGER_FILE=<tmp-ledger-jsonl> \
scripts/bootstrap-project.sh
```

### AI PR Review Module

AI module files:

```text
.github/workflows/ai-pr-review.yml
.github/workflows/scripts/ai_review_pr.py
.github/workflows/prompts/pr-review-policy.md
.github/workflows/prompts/pr-review-output-contract.md
.github/claude/deepseek-settings.json
.github/qoder/settings.json
scripts/configure-ai-ci.sh
scripts/upsert-pr-comment.sh
```

`.github/ai-review/settings.json` is generated or preserved as target config, not blindly copied from Dogsquard's active local config.

Apply logic:

1. copy AI module files with normal skip/force behavior
2. ensure scripts are executable where required
3. decide target settings behavior:
   - existing settings and no `--force`: preserve; if AI config inputs were supplied, fail with a message requiring `--force` or manual target configure
   - existing settings and `--force`: back up, then allow configure helper to overwrite
   - no settings and AI config inputs: run configure helper with pass-through args
   - no settings and no AI config inputs: create disabled safe config and print follow-up configure command
4. print required secret names only
5. never pass secret values

Disabled safe config for no-input install:

```json
{
  "enabled": false,
  "engine": "claude-deepseek",
  "claude": {
    "provider": "deepseek"
  },
  "qoder": {
    "models": ["Qwen3.7-Max"],
    "implicit_auto_fallback": true
  }
}
```

When `enabled` is `false`, `engine` is inert for provider invocation. The value exists only to satisfy the schema and runner resolver.

## Internal Plan Model

Build a plan before writes.

Plan item schema:

```json
{
  "id": "plan-0001",
  "module": "ai-pr-review",
  "kind": "file",
  "action": "create",
  "source": ".github/workflows/ai-pr-review.yml",
  "target": ".github/workflows/ai-pr-review.yml",
  "exists_before": false,
  "requires_force": false,
  "will_write": true,
  "reason": "AI PR review workflow asset"
}
```

Allowed `kind` values:

```text
file
directory
command
validation
commit
warning
```

Allowed `action` values:

```text
create
copy
write
skip
overwrite
backup
preserve
run
warn
fail
remove
restore
```

The displayed install plan should be human-readable. The internal `.tmp/install/plan.json` may be JSON for tests and debugging.

Plan rendering must include:

- target path
- project type
- selected modules
- bootstrap invocation summary
- AI configure invocation summary
- files that will be created, skipped, preserved, or overwritten
- whether GitHub variables will be touched
- validation commands
- commit/push action

## Operation Ledger

Do not parse human stdout as the source of truth for manifest generation.

Add optional JSONL ledger support to `scripts/bootstrap-project.sh`.

Environment variable:

```text
DOGSQUARD_LEDGER_FILE=/absolute/path/to/ledger.jsonl
```

When absent, bootstrap behavior and output stay unchanged.

When present, helper primitives append one JSON object per operation.

Ledger entry schema:

```json
{
  "tool": "bootstrap-project.sh",
  "module": "bootstrap",
  "operation": "copy_file",
  "action": "created",
  "path": "scripts/doc-check-local.sh",
  "source": "scripts/doc-check-local.sh",
  "existed_before": false,
  "force": false,
  "dry_run": false,
  "sha256_before": null,
  "sha256_after": "...",
  "backup_path": null
}
```

Allowed ledger actions:

```text
planned
created
skipped
overwritten
preserved
backup_created
directory_created
directory_preexisting
appended
```

Bootstrap helpers to instrument:

- `ensure_dir`
- `touch_file`
- `copy_file`
- `copy_dir`
- `write_file`
- `.gitignore` append helper
- production-profile chmod step

The install shell should also write ledger entries for module-only AI file operations and configure-helper invocations.

## Manifest Schema

Target file:

```text
.dogsquard/install-manifest.json
```

Schema version: `1`.

Example shape:

```json
{
  "schema_version": "1",
  "installed_at": "2026-07-01T20:00:00+08:00",
  "dogsquard_source": {
    "path": "/home/daishun/dev/dogsquard",
    "git_commit": "<commit-or-unknown>"
  },
  "target": {
    "path": "/home/daishun/dev/dogci-uat-demo-20260630-102459",
    "git_remote_origin": "https://github.com/proletariat64/dogci-uat-demo-20260630-102459.git",
    "git_branch": "feature/dogsquard-install"
  },
  "project_type": "docs-only",
  "modules": ["ai-pr-review"],
  "options": {
    "force": false,
    "run_checks": true,
    "commit_push": false
  },
  "ai_review": {
    "configured": true,
    "enabled": true,
    "engine": "qoder",
    "qoder_models": ["Qwen3.7-Max", "GLM-5.2"],
    "apply_github_vars": false
  },
  "files": [
    {
      "path": ".github/workflows/ai-pr-review.yml",
      "module": "ai-pr-review",
      "action": "created",
      "source": ".github/workflows/ai-pr-review.yml",
      "sha256_before": null,
      "sha256_after": "<sha256>",
      "backup_path": null
    }
  ],
  "directories": [
    {
      "path": ".dogsquard",
      "action": "created"
    }
  ],
  "validation": {
    "run_checks": true,
    "commands": []
  }
}
```

Rules:

- manifest contains no secret values
- skipped pre-existing files are recorded but not uninstall-removable
- overwritten files must have a backup path and checksums
- created files must have `sha256_after` when practical
- generated `.github/ai-review/settings.json` checksum must be recorded
- manifest write is the last file operation before validation/commit

## Backup Policy

When `--force` overwrites a file:

1. create `.dogsquard/backups/<timestamp>/<relative-path>` inside target repo
2. record `sha256_before`
3. record `backup_path`
4. after writing, record `sha256_after`

If backup creation fails, the overwrite must fail before modifying the target file.

Do not back up or overwrite Git data, secrets, `.env.local`, `.claude/`, `AGENTS.md`, `CLAUDE.md`, or `roster.md` unless a future explicit feature allows it.

## Install Flow

### Parse And Validate

1. read config file if provided
2. parse CLI flags
3. merge config and CLI, with CLI precedence
4. validate allowed keys and flags
5. resolve absolute target path for filesystem operations
6. reject target path equal to Dogsquard repo root
7. require target exists for MVP
8. require `PROJECT_TYPE` for install mode
9. validate modules
10. validate module dependency rules

### Build Plan

1. inspect target existing files
2. build bootstrap invocation if needed
3. build AI asset operations if `ai-pr-review` selected
4. build AI configure command or disabled safe config operation
5. build validation commands
6. build optional commit/push plan
7. render plan
8. write `.tmp/install/plan.env` only for interactive reviewed plans

### Dry-run

Dry-run must:

- write no target files
- not create manifest
- not call `gh variable set`
- not call `gh secret set`
- not commit or push
- not require GitHub network access
- print exact commands that apply would run

Qoder dry-run model behavior:

- if `qodercli --list-models` is available, validate provided Qoder models
- if `qodercli` is unavailable, warn and defer live model validation to apply
- never silently append user-selected `Auto`; the runner appends implicit `Auto`

### Apply

Apply must:

1. print final plan
2. require explicit `--apply` or menu confirmation
3. create `.tmp/install` workspace in Dogsquard repo, not target repo
4. run bootstrap-backed installation with ledger enabled when needed
5. copy AI assets with install-owned ledger when needed
6. run copied target `scripts/configure-ai-ci.sh` only when AI config inputs require it
7. create disabled safe AI config when `ai-pr-review` is installed without AI config inputs and no target settings exist
8. write manifest
9. run validation when requested
10. offer commit/push only after validation succeeds

## AI Configure Pass-through Algorithm

Inputs:

```text
AI_REVIEW_ENABLED
AI_REVIEW_ENGINE
QODER_MODELS
AI_REVIEW_APPLY_GITHUB_VARS
```

Derived helper args:

```text
--enabled <true|false>
--engine <claude-deepseek|qoder>
--qoder-model <model> repeated
--apply
--apply-github-vars optional
```

Rules:

- `--ai-apply-github-vars` requires install `--apply`
- `AI_REVIEW_ENGINE=qoder` requires one or two Qoder models
- `QODER_MODELS` must not include `Auto`
- duplicate Qoder models fail
- `AI_REVIEW_ENGINE=claude-deepseek` must not pass Qoder models
- disable-only may omit engine only when an existing target config exists; otherwise use disabled safe config
- if target `.github/ai-review/settings.json` exists and `--force` is not set, do not run configure helper in apply mode; fail if the user requested config mutation
- if target settings exists and `--force` is set, back it up before configure helper writes

Required secret names to print:

| Engine | Secret |
|---|---|
| `claude-deepseek` | `DEEPSEEK_AUTH_TOKEN` |
| `qoder` | `QODER_PERSONAL_ACCESS_TOKEN` |

Optional non-secret variables delegated to configure helper:

```text
AI_REVIEW_ENGINE
AI_REVIEW_CONFIGURED=true
```

## Validation Flow

Validation is controlled by `RUN_CHECKS=true|false` or `--run-checks` / `--no-run-checks`.

Always safe target checks when applicable:

```bash
git diff --check
bash -n scripts/*.sh
```

AI module checks when `ai-pr-review` is installed:

```bash
bash -n scripts/configure-ai-ci.sh
python3 -m py_compile .github/workflows/scripts/ai_review_pr.py
python3 -m json.tool .github/ai-review/settings.json >/dev/null
python3 -m json.tool .github/qoder/settings.json >/dev/null
python3 -m json.tool .github/claude/deepseek-settings.json >/dev/null
python3 .github/workflows/scripts/ai_review_pr.py --resolve-config
```

Generated profile checks when bootstrap generated Dogsquard Makefile targets:

```bash
make help
make doc-check
make doc-guard
make release-check
```

Dogsquard source validation before handoff:

```bash
bash -n install scripts/install.sh scripts/test-install.sh
bash -n scripts/bootstrap-project.sh scripts/configure-ai-ci.sh
bash scripts/test-bootstrap-project.sh
bash scripts/test-configure-ai-ci.sh
bash scripts/test-install.sh
git diff --check
```

If validation fails:

- print failure
- leave files for manual inspection
- do not offer push as recommended action
- do not delete manifest automatically

## Commit And Push Flow

Commit/push is opt-in.

Preconditions:

- target is a git worktree
- validation succeeded when `RUN_CHECKS=true`
- plan has target file changes
- Dogsquard source repo changes are not staged

Interactive mode:

- show `git -C <target> status --short`
- if current branch is `main` or empty, ask for a feature branch name and create/switch before commit
- ask before `git push`

Non-interactive mode:

- if branch is `main`, fail and ask user to create a feature branch or use interactive menu
- stage only files recorded in the install plan plus `.dogsquard/install-manifest.json`
- commit message:

```text
Install Dogsquard modules
```

Push behavior:

- if upstream exists, run `git push`
- if upstream is missing, run `git push -u origin HEAD`
- never use force push

## Uninstall Algorithm

Input:

```text
<target>/.dogsquard/install-manifest.json
```

Dry-run default.

Algorithm:

1. read manifest
2. validate `schema_version`
3. build uninstall plan
4. for every file entry:
   - `created`: remove only if current checksum matches `sha256_after`; otherwise fail for manual review
   - `overwritten`: restore backup only if current checksum matches installed `sha256_after`; otherwise fail for manual review
   - `skipped` or `preserved`: never remove
5. remove empty directories that were created by Dogsquard and are now empty
6. remove manifest only after all planned removals/restores succeed
7. remove `.dogsquard` only if empty

Uninstall must not:

- ask for module selection
- remove files not listed in manifest
- remove skipped pre-existing files
- remove target source/tests/docs unrelated to Dogsquard
- remove `.git`
- remove or unset GitHub secrets or variables
- infer cleanup from filenames when manifest is missing

Missing manifest behavior:

```text
FAIL: no Dogsquard install manifest found at <target>/.dogsquard/install-manifest.json.
Refusing broad cleanup. Use manual review or a future audited fallback.
```

## Test Plan

Add `scripts/test-install.sh` using temporary target directories.

Test cases:

1. `./install --help` exits 0 and mentions dry-run, modules, AI flags, and uninstall.
2. Unknown CLI flag fails.
3. Unknown config key fails.
4. Dry-run writes no target files.
5. `docs-only` bootstrap apply creates expected docs/Makefile/workflow and manifest.
6. `node` bootstrap dry-run shows bootstrap invocation and optional flags.
7. `go-js` bootstrap dry-run shows bootstrap invocation and optional flags.
8. Existing file is skipped without `--force` and recorded as skipped.
9. Existing file with `--force` is backed up and recorded as overwritten.
10. Uninstall dry-run prints all created files and no module picker.
11. Uninstall apply removes created files and preserves skipped pre-existing files.
12. Uninstall refuses when manifest is missing.
13. `ai-pr-review` install copies one unified AI workflow and no separate provider workflow.
14. `ai-pr-review` no-input install creates disabled safe config when no target config exists.
15. Existing target `.github/ai-review/settings.json` is preserved without `--force`.
16. AI configure pass-through invokes copied target `scripts/configure-ai-ci.sh` with expected args using a test stub or mock.
17. Qoder config rejects zero models, more than two models, duplicates, and `Auto`.
18. `--ai-apply-github-vars` without `--apply` fails.
19. Secret-looking values in config or CLI are rejected or never printed.
20. `--commit-push` on `main` fails in non-interactive mode.

Mocking guidance:

- use temporary mock `qodercli --list-models`
- use temporary mock `gh` for variable assertions
- avoid real network calls in unit tests
- verify file checksums with `sha256sum`

## UAT Plan

Dedicated UAT target:

```text
/home/daishun/dev/dogci-uat-demo-20260630-102459
```

Remote:

```text
https://github.com/proletariat64/dogci-uat-demo-20260630-102459
```

Known target secrets by name:

```text
DEEPSEEK_AUTH_TOKEN
QODER_PERSONAL_ACCESS_TOKEN
```

UAT sequence:

1. create or switch to a feature branch in the UAT repo
2. run dry-run AI module install
3. run apply AI module install with Qoder models
4. run validation
5. commit/push only the target repo install changes
6. open a PR or workflow-dispatch run
7. verify one Dogsquard AI review comment is created or updated
8. verify Qoder uses `QODER_PERSONAL_ACCESS_TOKEN`
9. uninstall in dry-run and confirm full all-or-nothing plan
10. uninstall apply in a separate cleanup branch if needed

DeepSeek UAT is optional. If used, a visible credit/balance/provider failure is acceptable only when the workflow is non-green and posts/logs the failure clearly.

## Local Validation Checklist

Before handoff:

```bash
bash -n install scripts/install.sh scripts/test-install.sh
bash -n scripts/bootstrap-project.sh scripts/configure-ai-ci.sh
bash scripts/test-bootstrap-project.sh
bash scripts/test-configure-ai-ci.sh
bash scripts/test-install.sh
python3 -m json.tool .github/ai-review/settings.json >/dev/null
python3 -m json.tool .github/qoder/settings.json >/dev/null
python3 -m json.tool .github/claude/deepseek-settings.json >/dev/null
git diff --check
```

If temporary config values are used during validation, restore intended defaults before handoff.

## Acceptance Criteria

- `./install --help` documents interactive and non-interactive use.
- `./install --menu` can produce a reviewed install plan.
- Dry-run is default and writes no target files.
- Apply requires `--apply` or final menu confirmation.
- `scripts/bootstrap-project.sh` remains the canonical profile bootstrap engine.
- Bootstrap-backed installs emit a structured ledger when invoked by install.
- Existing files are preserved unless `--force` is explicit.
- Overwritten files are backed up before modification.
- Apply writes `.dogsquard/install-manifest.json` without secrets.
- Manifest records created, skipped, overwritten, backup, checksum, module, and AI configure metadata.
- Uninstall is all-or-nothing and does not ask for modules.
- Uninstall without manifest fails safely.
- Uninstall removes only manifest-recorded created files and restores only backed-up overwritten files.
- Uninstall does not unset GitHub secrets or variables.
- `ai-pr-review` installs one unified Dogsquard AI review workflow.
- `ai-pr-review` delegates provider/model config to `scripts/configure-ai-ci.sh`.
- Non-interactive AI install with no AI config input does not silently invoke a provider.
- Qoder config rejects zero models, more than two models, duplicate models, and user-selected `Auto`.
- `--ai-apply-github-vars` is explicit and only touches non-secret variables through the configure helper.
- Commit/push is opt-in and stages only planned target repo changes.
- UAT proves install can target an existing non-Node/non-Go repo without destructive overwrite.
- UAT proves visible Dogsquard AI review output or visible selected-provider failure.

## Non-goals

- Do not create GitHub repositories.
- Do not configure production deployment.
- Do not edit servers, reverse proxies, domains, or firewall rules.
- Do not read, print, store, commit, or unset secret values.
- Do not replace `scripts/bootstrap-project.sh`.
- Do not install separate Qoder and Claude review workflows.
- Do not implement partial uninstall.
- Do not implement `ai-fix-bug` module in MVP.
- Do not provide manifest-missing heuristic cleanup in MVP.
