# Dogsquard

Dogsquard is a reusable vibe-coding bootstrap kit for future small and medium internal application repositories.

It is not the business product itself.

Dogsquard provides project governance, local commands, GitHub workflow, PR quality checks, optional dev deploy patterns, and agent operating rules so new repositories can start with a disciplined delivery foundation.

## Who It Is For

Dogsquard is for the user as a solo developer, product owner, and process owner.

The intended working model is:

- human controls product meaning, review, process, and release decisions
- agents do most implementation work
- GitHub issues and PRs control project progress
- docs drive development through BRD, PRD, BDD, ADR, tests, and runbooks

## Current Capabilities

- documentation governance structure and checks
- Makefile command center
- guided install and uninstall shell for target repositories
- GitHub issue and PR templates
- PR Quality Gate workflow
- optional unified AI PR Review workflow
- approval-gated AI bug-fix draft PR workflow
- example Go backend and TypeScript frontend
- API smoke and Playwright smoke tests
- dev deployment pattern for `cn.ant`
- user-level runtime management
- GitHub Actions Dev Deploy workflow
- SSH tunnel dev validation
- Control Board dashboard process

## Quick Start For This Repo

Run local checks:

```bash
make doc-check
make doc-guard
make release-check
git diff --check
bash -n scripts/*.sh
```

Run the example app checks:

```bash
cd backend && go test ./...
cd ../frontend && npm install && npm run build
cd ..
make e2e-smoke
```

Package a release artifact:

```bash
make package-release
```

## New Repo Bootstrap Flow

Dogsquard assumes the user manually creates a new GitHub repository first.

Recommended install flow:

```bash
git clone <new-repo-url>
cd dogsquard
./install --repo ../new-repo --project-type node --modules governance,pr-quality
./install --repo ../new-repo --project-type node --modules governance,pr-quality --apply
```

Dry-run is the default. Use `--apply` only after reviewing the printed plan.

Interactive flow:

```bash
./install --menu
```

Common module choices:

```bash
# Docs/governance-only repository
./install --repo ../new-repo --project-type docs-only --modules governance,pr-quality --apply

# Go backend + TypeScript frontend example app
./install --repo ../new-repo --project-type go-js --modules governance,pr-quality,example-app --apply

# Add production planning scaffold
./install --repo ../new-repo --project-type node --modules governance,pr-quality,production-profile --apply
```

Available modules:

- `governance`
- `pr-quality`
- `dev-deploy`
- `example-app`
- `production-profile`
- `ai-pr-review`

Use `--force` only when you intentionally want Dogsquard to overwrite target files. Overwritten files are backed up under `.dogsquard/backups/`, and apply mode writes `.dogsquard/install-manifest.json` for uninstall.

Install can validate and activate target repo changes:

```bash
./install --repo ../new-repo --project-type node --modules governance,pr-quality \
  --apply --run-checks --commit-push
```

`scripts/init-new-repo.sh` remains a conservative legacy compatibility flow. `scripts/bootstrap-project.sh` remains the lower-level profile bootstrap helper. Use `./install` by default because it supports module selection, AI PR Review installation, manifest writing, and uninstall.

Review generated files before committing in the target repo unless `--commit-push` is explicitly selected.

## AI CI Setup

Install unified AI PR Review into a target repository:

```bash
./install --repo ../target-repo --project-type docs-only --modules ai-pr-review --apply
```

Without AI config flags, this installs the workflow and a disabled safe config. Configure later inside the target repo:

```bash
cd ../target-repo
scripts/configure-ai-ci.sh
```

Configure Qoder non-interactively during install:

```bash
./install --repo ../target-repo --project-type docs-only --modules ai-pr-review \
  --ai-enabled true \
  --ai-engine qoder \
  --qoder-model Qwen3.7-Max \
  --apply
```

Configure Qoder with two preferred models:

```bash
./install --repo ../target-repo --project-type docs-only --modules ai-pr-review \
  --ai-enabled true \
  --ai-engine qoder \
  --qoder-model GLM-5.2 \
  --qoder-model Qwen3.7-Max \
  --apply
```

The runner appends implicit `Auto`; do not pass `Auto` as a model.

Configure Claude+DeepSeek:

```bash
./install --repo ../target-repo --project-type docs-only --modules ai-pr-review \
  --ai-enabled true \
  --ai-engine claude-deepseek \
  --apply
```

Required GitHub secrets are set in the target repository, never stored in Dogsquard config files:

```bash
cd ../target-repo
gh secret set QODER_PERSONAL_ACCESS_TOKEN
gh secret set DEEPSEEK_AUTH_TOKEN
```

For optional non-secret GitHub repository variables:

```bash
./install --repo ../target-repo --project-type docs-only --modules ai-pr-review \
  --ai-enabled true \
  --ai-engine qoder \
  --qoder-model Qwen3.7-Max \
  --ai-apply-github-vars \
  --apply
```

The canonical source of truth after setup is `.github/ai-review/settings.json`. GitHub variables are compatibility hints; they are not the enabled/disabled switch.

## Uninstall

Uninstall removes Dogsquard-managed assets recorded in the target repo manifest:

```bash
./install --uninstall --repo ../target-repo
./install --uninstall --repo ../target-repo --apply
```

Uninstall is all-or-nothing and has no module picker. It requires `.dogsquard/install-manifest.json`, refuses to guess when the manifest is missing, and does not remove target business code or pre-existing files.

Uninstall does not delete GitHub secrets or variables. If AI PR Review is no longer used, clean them up manually in the target repo:

```bash
gh secret delete QODER_PERSONAL_ACCESS_TOKEN
gh secret delete DEEPSEEK_AUTH_TOKEN
gh variable delete AI_REVIEW_ENGINE
gh variable delete AI_REVIEW_CONFIGURED
```

## GitHub Setup Overview

Dogsquard provides:

- `.github/ISSUE_TEMPLATE/`
- `.github/pull_request_template.md`
- `.github/labels.yml`
- `.github/workflows/pr-quality.yml`
- `.github/workflows/ai-pr-review.yml`
- `.github/workflows/ai-fix-bug.yml`

Labels are documented as source configuration and may need manual setup until label automation is added.

Dev deploy requires manual GitHub Environment setup if used.

## Dev Deploy Overview

The current Dogsquard dev deployment target is `cn.ant`.

The current dev runtime is isolated under:

```text
~/apps/dogsquard-dev
```

Public access is not exposed by default. SSH tunnel access is the validated human dev validation mode.

## Safety Notes

- Do not deploy Dogsquard to `us.hermes`.
- Do not target `43.130.49.185`.
- Do not claim `/` or `/api` on `proletariat.icu`.
- Do not modify reverse proxy, SSL, or firewall configuration as part of template bootstrap.
- Do not commit secrets, raw server output, private SSH config, or local agent session files.
- Production deployment is future work and requires explicit approval.

## Key Docs

- Control Board: https://github.com/proletariat64/dogsquard/issues/1
- Project roadmap: `docs/05_design/design-20260531-project-roadmap.md`
- New repo bootstrap runbook: `docs/07_runbooks/runbook-new-repo-bootstrap.md`
- PR Quality Gate runbook: `docs/07_runbooks/runbook-pr-quality-gate.md`
- AI bug-fix workflow runbook: `docs/07_runbooks/runbook-ai-bug-fix-workflow.md`
- Redesigned testing workflow, going a more detail runbook: `docs/07_runbooks/runbook-practice-project-testing-governance.md`
- Dev deployment runbook: `docs/07_runbooks/runbook-dev-deployment.md`
- Template Finalization PRD: `docs/02_prd/prd-20260531-template-finalization.md`
- Template boundary ADR: `docs/04_adr/0007-define-dogsquard-template-kit-boundary.md`
- Template inventory: `docs/05_design/design-20260531-template-inventory.md`

## v0.1.0 Readiness Status

Dogsquard is in Milestone 6E Template Finalization.

Current target:

- bootstrap/init path implemented
- README usable as template entrypoint
- fresh repo initialization validated locally
- no secrets or local-only files copied
- PR Quality Gate green

Production deployment is not required for `v0.1.0`.
