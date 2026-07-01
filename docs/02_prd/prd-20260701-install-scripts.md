---
title: "Dogsquard Install Scripts PRD"
doc_type: "prd"
status: "draft"
owner: "user"
source: "agent"
created: "2026-07-01"
updated: "2026-07-01"
related_issue: ""
related_pr: ""
supersedes: ""
---

# Dogsquard Install Scripts PRD

## Purpose

Dogsquard needs a simple install entrypoint that turns the current profile-aware bootstrap into a guided adoption flow for real target repositories.

The user should be able to start from Dogsquard, choose a target repo, choose modules, optionally configure AI PR review through the existing AI CI configure helper, review the plan, apply it, validate it, and optionally let the script prepare commit/push activation.

## Current Findings

- `scripts/bootstrap-project.sh` is the current canonical bootstrap engine. It already supports `PROJECT_TYPE=node`, `PROJECT_TYPE=go-js`, and `PROJECT_TYPE=docs-only`; defaults to dry-run; skips existing files unless `FORCE=true`; and is covered by `make bootstrap-test`.
- `scripts/init-new-repo.sh` is legacy compatibility and should not be the new user-facing path.
- Existing bootstrap modules already map to governance core, PR Quality Gate, dev deploy, example app, and production-profile scaffold.
- AI PR review is now a reusable unified surface rather than an install-script-owned feature. The installer must reuse the completed configure-shell design in [[docs/05_design/design-20260701-ai-ci-configure-shell-spec.md]] and the unified AI PR review PRD in [[docs/02_prd/prd-20260701-unified-ai-pr-review-ci.md]] instead of reimplementing provider/model selection.
- Existing AI review assets to install as one module are:
  - `.github/workflows/ai-pr-review.yml`
  - `.github/workflows/scripts/ai_review_pr.py`
  - `.github/workflows/prompts/pr-review-policy.md`
  - `.github/workflows/prompts/pr-review-output-contract.md`
  - `.github/ai-review/settings.json` as the target canonical config file; generate/update it through `scripts/configure-ai-ci.sh` rather than blindly copying Dogsquard's active local config over an existing target config
  - `.github/claude/deepseek-settings.json`
  - `.github/qoder/settings.json`
  - `scripts/configure-ai-ci.sh`
  - `scripts/upsert-pr-comment.sh`
- Local/private agent files such as `AGENTS.md`, `CLAUDE.md`, `roster.md`, and `.claude/` must stay out of installed target repos unless explicitly approved.

## UAT Playground

The user provided a dedicated UAT playground repository for proving install behavior without risking Dogsquard itself:

- remote repo: [proletariat64/dogci-uat-demo-20260630-102459](https://github.com/proletariat64/dogci-uat-demo-20260630-102459)
- local path: `/home/daishun/dev/dogci-uat-demo-20260630-102459`
- GitHub Actions secrets page: [dogci-uat-demo Actions secrets](https://github.com/proletariat64/dogci-uat-demo-20260630-102459/settings/secrets/actions)
- UAT repo secrets verified by name on 2026-07-01:
  - `DEEPSEEK_AUTH_TOKEN`
  - `QODER_PERSONAL_ACCESS_TOKEN`
- Dogsquard self repo also has `QODER_PERSONAL_ACCESS_TOKEN` ready.

The UAT repo is a lightweight Python repo with `requirements.txt`, `hello.py`, `bst_sort.py`, `test_bst.py`, and `.qoder-ci.yml`. It is intentionally useful as an existing non-Node/non-Go repo, so the installer must support module-specific adoption without forcing a full Node or Go/JS project profile.

For Claude Code + DeepSeek UAT, provider calls may fail because of credit or balance exhaustion. That is normal when the failure is explicit and visible. The installer should not treat a visible provider-balance failure as a fake success, and should not hide it by falling back to Qoder.

## Problem

The current bootstrap is powerful but too env-var driven for repeated human use.

A practical install flow needs:

- one obvious command
- interactive menu mode
- non-interactive config mode
- safe dry-run by default
- explicit apply/force behavior
- module selection
- AI PR review adoption through the existing configure shell
- target repo validation
- optional post-install commit/push support

## User Experience

Primary command:

```bash
cd dogsquard
./install --repo ../target-repo --project-type node --modules governance,pr-quality,ai-pr-review --config install.env
```

Interactive command:

```bash
cd dogsquard
./install --menu
```

Apply requires explicit confirmation or flag:

```bash
./install --repo ../target-repo --project-type node --modules governance,pr-quality --apply
```

AI PR review module with non-interactive configure pass-through:

```bash
./install --repo ../target-repo --project-type docs-only --modules ai-pr-review --ai-engine qoder --qoder-model Qwen3.7-Max --qoder-model GLM-5.2 --apply
```

Uninstall is all-or-nothing and still dry-runs by default:

```bash
./install --uninstall --repo ../target-repo
./install --uninstall --repo ../target-repo --apply
```

Uninstall must not ask the user to choose modules. It removes all Dogsquard-managed installed assets for that target, based on the install manifest.

The command name should be `./install` or `scripts/install.sh`, not plain `install`, because `install` conflicts with the system coreutils command.

## Goals

- Provide `./install` as a thin root shim over `scripts/install.sh`.
- Reuse `scripts/bootstrap-project.sh` for existing copy behavior instead of duplicating file lists.
- Allow module-specific installation into an existing repo, especially `ai-pr-review` without full governance bootstrap when the target repo is only a UAT playground.
- Keep AI PR review configuration delegated to `scripts/configure-ai-ci.sh`; install may pass through engine/model choices, but must not duplicate the configure shell's provider registry, Qoder model rules, GitHub variable handling, or secret setup logic.
- Add a menu flow that asks:
  - target repo path
  - project type: `node`, `go-js`, `docs-only`
  - selected modules
  - for `ai-pr-review`: whether to run the AI CI configure helper after copying assets
  - whether to run validation
  - whether to create commit/push after successful validation
- Support non-interactive config files for repeatable installs.
- Keep dry-run as default; require `--apply` or final menu confirmation before writing files.
- Print a clear plan before applying.
- Provide one simple uninstall mode that removes all Dogsquard-managed installed assets, not part-by-part modules.
- Never copy secrets or local machine/session files.
- Never overwrite existing target files unless `--force` is explicitly set.
- Keep AI PR review advisory; deterministic `PR Quality Gate` remains the merge authority.

## Non-Goals

- Do not create the GitHub repository.
- Do not configure production deployment.
- Do not edit servers, reverse proxies, domains, or firewall rules.
- Do not collect or print secret values.
- Do not commit/push by default.
- Do not replace `scripts/bootstrap-project.sh`; wrap it.
- Do not install two separate AI review workflows.
- Do not reimplement `scripts/configure-ai-ci.sh` provider registry, Qoder model picker, fallback policy, GitHub variable sync, or secret setup.
- Do not provide partial uninstall by module, provider, or feature.
- Do not remove files that pre-existed before Dogsquard install.
- Do not unset GitHub repository secrets or variables during uninstall. Print follow-up cleanup commands only when needed.

## Modules

| Module | Initial behavior | Existing support |
|---|---|---|
| `governance` | docs structure, governance docs, scripts, Makefile, templates | `bootstrap-project.sh` core |
| `pr-quality` | profile-aware PR Quality Gate | `bootstrap-project.sh` profile workflow writers |
| `dev-deploy` | dev deployment scripts/workflow/docs | `INCLUDE_DEV_DEPLOY=true` |
| `example-app` | sample Go/JS app and smoke scripts | `INCLUDE_EXAMPLE_APP=true` |
| `production-profile` | scaffold-only production planning docs/guard | `INCLUDE_PRODUCTION_PROFILE=true` |
| `ai-pr-review` | unified workflow, runner, prompts, provider settings, configure shell, comment upsert helper | copy existing AI review assets, then delegate configuration to `scripts/configure-ai-ci.sh` in the target repo |
| `ai-fix-bug` | optional approved AI bug-fix workflow | later module, not MVP |

MVP modules: `governance`, `pr-quality`, `dev-deploy`, `example-app`, `production-profile`, `ai-pr-review`.

## Config File Contract

Use a simple key-value config file that can be parsed without extra dependencies:

```bash
TARGET_DIR=../target-repo
PROJECT_TYPE=node
MODULES=governance,pr-quality,ai-pr-review
AI_REVIEW_ENABLED=true
AI_REVIEW_ENGINE=claude-deepseek
AI_REVIEW_APPLY_GITHUB_VARS=false
RUN_CHECKS=true
COMMIT_PUSH=false
FORCE=false
```

UAT example:

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

Uninstall example:

```bash
TARGET_DIR=/home/daishun/dev/dogci-uat-demo-20260630-102459
UNINSTALL=true
RUN_CHECKS=true
COMMIT_PUSH=false
FORCE=false
```

Rules:

- config values are non-secret only
- unknown keys fail fast
- CLI flags override config values
- interactive mode may write a reviewed plan to `.tmp/install/plan.env`
- AI review config keys are pass-through inputs to `scripts/configure-ai-ci.sh`; the canonical AI review source of truth after installation is `.github/ai-review/settings.json`, not the install config file.
- For non-interactive `AI_REVIEW_ENGINE=qoder`, require one or two real Qoder models through `QODER_MODELS` or repeated CLI flags. Do not store or select `Auto`; the runner appends implicit `Auto`.
- If `ai-pr-review` is selected without AI config inputs in non-interactive mode, install the AI review assets and print the follow-up configure command; do not silently choose a provider or overwrite target AI settings.

AI configure pass-through mapping:

| Install config / flag | Configure helper argument | Notes |
|---|---|---|
| `AI_REVIEW_ENABLED=true|false` / `--ai-enabled` | `--enabled true|false` | optional when configure helper is invoked; default comes from existing target config or configure helper default |
| `AI_REVIEW_ENGINE=claude-deepseek|qoder` / `--ai-engine` | `--engine ...` | required when selecting/changing engine non-interactively; not required for disable-only |
| `QODER_MODELS=a,b` / repeated `--qoder-model` | repeated `--qoder-model ...` | one or two real models; no `Auto` |
| `AI_REVIEW_APPLY_GITHUB_VARS=true` / `--ai-apply-github-vars` | `--apply-github-vars` | valid only with install `--apply`; sets non-secret variables only |
| install dry-run | configure helper `--dry-run` or printed derived command | target repo must not be changed |
| install apply | configure helper `--apply` after AI assets are present | subject to install overwrite/force policy |

## AI PR Review Installation

When `ai-pr-review` is selected:

- install only the unified workflow shape and configure-shell assets listed in Current Findings
- create, update, or preserve `.github/ai-review/settings.json` as the canonical on/off and engine config file
- enforce install overwrite policy before invoking the configure helper: if `.github/ai-review/settings.json` already exists and was not created by the current install, do not let `scripts/configure-ai-ci.sh --apply` overwrite it unless `--force` is explicit
- preserve the Dogsquard comment marker `<!-- dogsquard-ai-code-review -->`
- require engine value `claude-deepseek` or `qoder`
- do not fall back across providers
- copy provider settings files without secrets:
  - `.github/claude/deepseek-settings.json`
  - `.github/qoder/settings.json`
- copy `scripts/configure-ai-ci.sh` and run it from the target repo when AI configuration is requested:
  - dry-run install prints the configure command and generated plan only
  - apply install may run `scripts/configure-ai-ci.sh --apply ...` after files are copied
  - `--apply-github-vars` remains explicit and may only set non-secret variables
  - when the install script owns target commit/push, invoke the configure helper non-interactively and let the install script perform the single final commit/push; do not create a nested commit/push prompt
- print required GitHub secret/variable setup:
  - `claude-deepseek`: `DEEPSEEK_AUTH_TOKEN`
  - `qoder`: `QODER_PERSONAL_ACCESS_TOKEN`
  - optional repo variable: `AI_REVIEW_ENGINE`
- do not implement a second provider registry, Qoder model picker, Qoder fallback sequence builder, or GitHub secret writer inside `scripts/install.sh`
- do not activate Qoder and Claude as separate workflows in the same target repo
- selected-provider failure must be visible and must not silently switch to another engine
- DeepSeek credit or balance failure is an expected UAT environment outcome only when the workflow posts or logs a clear failure; it is not a successful AI review

Boundary with `scripts/configure-ai-ci.sh`:

| Concern | Owner |
|---|---|
| target repo path, module selection, copying files, manifest, uninstall | `scripts/install.sh` |
| AI CI enabled/disabled source of truth | target `.github/ai-review/settings.json` |
| engine/provider/model validation | target `scripts/configure-ai-ci.sh` and runner |
| Qoder one-or-two model rule and implicit `Auto` fallback | target `scripts/configure-ai-ci.sh` and runner |
| optional non-secret GitHub variable sync | `scripts/configure-ai-ci.sh --apply-github-vars` |
| secret value input | `gh secret set`, only after explicit user confirmation |
| final install commit/push covering all installed assets | `scripts/install.sh` |
| AI-config-only commit/push when user runs configure helper standalone | `scripts/configure-ai-ci.sh` |
| install/uninstall audit of copied assets | `.dogsquard/install-manifest.json` |

## Install Execution Model

The installer should run in explicit phases:

1. Load CLI flags and optional config file.
2. Resolve target repo, project type, selected modules, and AI configure pass-through inputs.
3. Build and print one install plan:
   - target repo
   - modules
   - files to create, skip, or overwrite
   - bootstrap command or module-only copy list
   - AI configure command when `ai-pr-review` is selected
   - validation commands
   - optional commit/push action
4. Apply only when `--apply` or final menu confirmation is explicit.

Dry-run behavior:

- write no target files
- do not create `.dogsquard/install-manifest.json`
- print the derived `scripts/bootstrap-project.sh` environment and AI configure command
- for `ai-pr-review`, validate static inputs where possible, but do not require live GitHub access
- if Qoder models are provided, they may be checked with `qodercli --list-models` when available; if unavailable, dry-run should warn and defer live model validation to apply

Apply behavior:

- copy or generate files only after the final plan is printed
- skip existing files unless `--force` is explicit
- for `ai-pr-review`, copy the unified workflow, runner, prompts, provider config files, `scripts/configure-ai-ci.sh`, and `scripts/upsert-pr-comment.sh`
- then run the copied target `scripts/configure-ai-ci.sh` non-interactively when AI config inputs were supplied
- if AI config inputs were not supplied, print `cd <target> && scripts/configure-ai-ci.sh` as the next step instead of picking a provider implicitly
- never pass secret values to the configure helper
- write `.dogsquard/install-manifest.json` after successful file operations
- run validation when requested
- offer commit/push only after validation succeeds

Commit/push behavior:

- install owns the final target commit/push when `COMMIT_PUSH=true` or menu confirmation is used
- stage only target repo generated/modified files from the install plan
- never stage Dogsquard source repo changes
- do not call the configure helper's interactive commit/push path from install

## Uninstall Feature

Uninstall should be intentionally simple:

- one command
- one target repo
- one plan
- one all-or-nothing uninstall

No module picker should appear during uninstall. The user should not have to choose `governance`, `pr-quality`, `ai-pr-review`, or provider-specific pieces. If they choose uninstall, Dogsquard removes all Dogsquard-managed installed assets for that target.

The installer should write a non-secret install manifest during apply mode, for example:

```text
.dogsquard/install-manifest.json
```

The manifest should record:

- install timestamp
- Dogsquard source version or commit when available
- target repo path at install time
- selected modules and project type
- created files
- overwritten files, only when `--force` was used
- skipped pre-existing files
- checksums for created or overwritten files when practical
- AI configure command inputs when `ai-pr-review` was configured
- checksum of generated `.github/ai-review/settings.json` when created or overwritten
- backup path for each overwritten file when `--force` was used

Uninstall behavior:

- dry-run by default
- read the manifest
- print every file or empty directory it plans to remove
- remove only files recorded as created by Dogsquard
- restore overwritten files only if backup content exists; otherwise fail and ask for manual review
- never remove files that were skipped because they pre-existed
- never remove unrelated target repo source, tests, docs, secrets, or Git data
- never remove or unset GitHub repository secrets or variables
- remove `.dogsquard/install-manifest.json` only after successful uninstall

If no manifest exists, uninstall must not guess broadly. It should print a safe failure and explain that manual cleanup or a future audited fallback is required.

## Implementation Plan

1. Add `scripts/install.sh` and root `./install` shim.
2. Implement argument parsing, `--help`, `--menu`, `--config`, `--repo`, `--project-type`, `--modules`, `--ai-enabled`, `--ai-engine`, repeated `--qoder-model`, `--ai-apply-github-vars`, `--apply`, `--force`, `--run-checks`, `--commit-push`, and `--uninstall`.
3. Validate target path:
   - exists unless a later `--create-target` is added
   - is not the Dogsquard repo itself
   - is a git worktree when commit/push is requested
   - has expected profile signals where possible, e.g. `package.json`, `backend/go.mod`, `frontend/package.json`
4. Translate selected modules to existing bootstrap flags:
   - `PROJECT_TYPE`
   - `TARGET_DIR`
   - `DRY_RUN=true|false`
   - `FORCE=true|false`
   - `INCLUDE_DEV_DEPLOY`
   - `INCLUDE_EXAMPLE_APP`
   - `INCLUDE_PRODUCTION_PROFILE`
5. Add module-only install mode for assets that should be independently selectable, starting with `ai-pr-review`.
6. Implement the plan renderer before file writes:
   - show existing-file skip/overwrite decisions
   - show AI configure pass-through command
   - show whether GitHub variables will be touched
   - show validation and commit/push steps
7. Implement `ai-pr-review` by copying the existing unified assets and delegating configuration to `scripts/configure-ai-ci.sh`; do not duplicate configure-shell logic in the installer.
8. Add manifest writing for apply mode and all-or-nothing uninstall from that manifest.
9. Add UAT commands for the provided playground repo:
   - install `ai-pr-review` with `AI_REVIEW_ENGINE=qoder` and one or two `QODER_MODELS`
   - uninstall all Dogsquard-managed assets from the playground repo with no module picker
   - run a real PR or workflow-dispatch check against `dogci-uat-demo-20260630-102459`
   - verify one Dogsquard-branded PR review comment is created or updated
   - verify Qoder uses `QODER_PERSONAL_ACCESS_TOKEN`
   - optionally run `claude-deepseek` and accept only explicit credit/balance failure as an environment failure
10. Add validation commands:
   - always: `git diff --check`, `bash -n scripts/*.sh` in target when scripts exist
   - AI review module: `bash -n scripts/configure-ai-ci.sh`, `python3 -m py_compile .github/workflows/scripts/ai_review_pr.py`, `python3 -m json.tool .github/ai-review/settings.json`, `python3 .github/workflows/scripts/ai_review_pr.py --resolve-config`
   - generated target: `make help`, `make doc-check`, `make doc-guard`, `make release-check`
   - Dogsquard repo: `make bootstrap-test`, `bash scripts/test-configure-ai-ci.sh`
11. Add optional commit/push flow:
   - show `git status --short`
   - ask for branch name if not already on a feature branch
   - commit only generated target repo changes
   - push only after explicit confirmation
   - never commit Dogsquard working-tree changes as part of target install
12. Document install and uninstall flows in a runbook and README section.

## Safety Rules

- Dry-run must write no target files.
- Apply must print the exact target repo and selected modules before writing.
- Existing files are skipped unless `--force` is set.
- `scripts/configure-ai-ci.sh --apply` must not be used to bypass install's existing-file and `--force` rules for `.github/ai-review/settings.json`.
- Secret names may be printed; secret values must never be printed, copied, or stored.
- AI CI on/off must not be represented by deleting workflow files or by a repo variable as source of truth; use `.github/ai-review/settings.json`.
- `Auto` must not be stored as a user-selected Qoder model; it is an implicit runner fallback.
- `.claude/`, `AGENTS.md`, `CLAUDE.md`, `roster.md`, `.env.local`, build output, `node_modules`, and `dist` remain excluded unless separately approved.
- Commit/push is opt-in and must run only inside the target repository.
- If validation fails, do not offer push as the recommended action.
- Uninstall removes all Dogsquard-managed installed assets, not selected modules.
- Uninstall must refuse broad cleanup when the manifest is missing.
- Uninstall must not remove pre-existing files, target repo business code, or secrets.
- Uninstall must not unset GitHub repository variables or secrets.

## Acceptance Criteria

- `./install --help` explains interactive and non-interactive use.
- `./install --menu` can produce a reviewed install plan.
- `./install --repo <target> --project-type node --modules governance,pr-quality` dry-runs by default and writes nothing.
- Dry-run prints a complete plan, including the derived bootstrap command and AI configure command when applicable.
- `--apply` runs through `scripts/bootstrap-project.sh` and installs selected existing modules.
- Existing files are preserved unless `--force` is explicit.
- Existing target `.github/ai-review/settings.json` is preserved unless `--force` is explicit.
- Apply mode writes a non-secret install manifest that can drive uninstall.
- The manifest records created/skipped/overwritten files, AI configure inputs, generated config checksum, and backup paths for overwritten files.
- `./install --uninstall --repo <target>` dry-runs a full Dogsquard-managed uninstall and offers no module picker.
- `./install --uninstall --repo <target> --apply` removes every manifest-recorded Dogsquard-created asset and does not remove skipped pre-existing files.
- Uninstall does not unset GitHub variables or secrets; it may print manual cleanup guidance.
- Uninstall without a manifest fails safely instead of guessing.
- `ai-pr-review` installs one unified Dogsquard AI review workflow, not separate Qoder and Claude workflows.
- `ai-pr-review` installs `scripts/configure-ai-ci.sh` and uses it for enabled/engine/provider/model configuration rather than duplicating that logic.
- Non-interactive `ai-pr-review` without AI config inputs does not silently choose a provider; it prints the target configure command.
- When AI review is configured, selected AI engine is visible in target `.github/ai-review/settings.json`, runner resolution output, or workflow inputs.
- Qoder install/config rejects zero models, more than two models, duplicate models, and user-selected `Auto`.
- Missing AI secrets are reported as setup requirements, not hidden as success.
- `--ai-apply-github-vars` is explicit, requires install `--apply`, and only syncs non-secret repo variables through the configure helper.
- Install-owned `--commit-push` stages only planned target changes and does not invoke a nested configure-helper commit/push path.
- UAT against `/home/daishun/dev/dogci-uat-demo-20260630-102459` proves the installer can target an existing non-Node/non-Go repo without destructive overwrite.
- Qoder UAT uses the already prepared `QODER_PERSONAL_ACCESS_TOKEN` and produces a visible review result.
- Claude+DeepSeek UAT either produces a visible review result or a visible provider credit/balance failure; silent success or cross-provider fallback fails acceptance.
- Optional commit/push only runs after explicit confirmation and successful validation.
- Test coverage includes temporary target repos for `docs-only`, `node`, `go-js`, dry-run, apply, module selection, and no-secret copying.

## Open Questions

- Should `ai-pr-review` be part of default install for app repos, or explicitly selected only?
- Should generated install plans be committed into target repos as audit artifacts, or remain local `.tmp/` files?

Resolved by configure-shell spec:

- GitHub repo variable sync is optional and explicit through `scripts/configure-ai-ci.sh --apply-github-vars`; variables are non-secret and not the enabled/disabled source of truth.
- Secret setup, when offered interactively, delegates value entry to `gh secret set SECRET_NAME`; the installer/configure shell must never read or store secret values.
