---
title: "New Repo Bootstrap Runbook"
doc_type: "runbook"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# New Repo Bootstrap Runbook

## Purpose

Describe the workflow for applying Dogsquard to a newly created repository.

Dogsquard now provides a profile-aware bootstrap script. Use `scripts/bootstrap-project.sh` as the default entrypoint because it supports `PROJECT_TYPE=node`, `PROJECT_TYPE=go-js`, and `PROJECT_TYPE=docs-only`, and it is covered by `make bootstrap-test`.

`scripts/init-new-repo.sh` remains available as a conservative legacy compatibility flow, but it is not the canonical path for new adoption work.

## Expected Future Workflow

1. Manually create the new GitHub repository.
2. Clone the target repository locally.
3. Apply Dogsquard bootstrap files and rules.
4. Review generated files.
5. Configure GitHub project settings as needed.
6. Run local validation.
7. Open the first Control Board.
8. Open the first design issue.
9. Use the first PR to prove local and CI gates.

## Manual New Repo Creation

Create the new repository in GitHub using the normal GitHub UI or GitHub CLI.

Do not assume Dogsquard creates the GitHub repository itself.

## Clone Target Repo

Clone the new repository locally:

```bash
git clone <new-repo-url>
cd <new-repo>
```

## Apply Dogsquard Bootstrap

From the Dogsquard repository, run a dry-run first:

```bash
PROJECT_TYPE=node TARGET_DIR=<target-path> scripts/bootstrap-project.sh
```

Apply the bootstrap after reviewing the planned actions:

```bash
PROJECT_TYPE=node TARGET_DIR=<target-path> DRY_RUN=false scripts/bootstrap-project.sh
```

If the target already contains files, the script skips existing paths by default. Only overwrite existing files when intentional:

```bash
PROJECT_TYPE=node TARGET_DIR=<target-path> DRY_RUN=false FORCE=true scripts/bootstrap-project.sh
```

Choose the profile that matches the target repo:

- `PROJECT_TYPE=node` for Node/JS/TS-only repos
- `PROJECT_TYPE=go-js` for Go backend plus JS/TS frontend repos
- `PROJECT_TYPE=docs-only` for documentation/process repos

The profile-aware bootstrap copies or initializes:

- docs governance structure
- Makefile and scripts
- `.github` issue and PR templates
- PR Quality Gate workflow
- Control Board and roadmap docs
- README template
- CHANGELOG template
- `.env.example`

Directory copies intentionally exclude generated and local-only paths such as `.git/`, `.claude/`, `node_modules/`, `dist/`, Playwright reports, test results, `.env.local`, and `*.local`.

## Optional Example App Include

The Internal Task Intake app is example and validation material, not mandatory business starter logic.

Copy it only when useful:

```bash
PROJECT_TYPE=go-js TARGET_DIR=<target-path> DRY_RUN=false INCLUDE_EXAMPLE_APP=true scripts/bootstrap-project.sh
```

This copies `backend/`, `frontend/`, API/e2e smoke scripts, and example app design/test/runbook docs.

## Optional Dev Deploy Include

Dev deploy assets are default for `PROJECT_TYPE=node` and `PROJECT_TYPE=go-js`, because current Dogsquard policy treats cn.ant dev deployment and high-port access as baseline capabilities.

Disable them only when the target repository should remain local/docs-only for now:

```bash
PROJECT_TYPE=node TARGET_DIR=<target-path> DRY_RUN=false INCLUDE_DEV_DEPLOY=false scripts/bootstrap-project.sh
```

For `PROJECT_TYPE=docs-only`, dev deploy remains off by default and can be explicitly included:

```bash
PROJECT_TYPE=docs-only TARGET_DIR=<target-path> DRY_RUN=false INCLUDE_DEV_DEPLOY=true scripts/bootstrap-project.sh
```

Dev deploy material still requires GitHub secrets, variables, target hosts, deploy roots, and protected-host rules before any real deploy.

## Optional Production Profile Scaffold

Production profile scaffold is opt-in and planning-only:

```bash
PROJECT_TYPE=node TARGET_DIR=<target-path> DRY_RUN=false INCLUDE_PRODUCTION_PROFILE=true scripts/bootstrap-project.sh
```

This generates placeholders, a guard script, and production runbook/test docs. It does not generate a production deploy workflow, deploy anything, change servers, edit reverse proxy config, or expose a public route.

## Legacy Conservative Bootstrap

Use `scripts/init-new-repo.sh` only when a conservative compatibility copy is explicitly desired:

```bash
scripts/init-new-repo.sh <target-path>
DRY_RUN=false scripts/init-new-repo.sh <target-path>
```

Prefer `scripts/bootstrap-project.sh` for current Dogsquard adoption work.

## Review Generated Files

After bootstrap, the user should review:

- project name and app name placeholders
- Go module name
- frontend package name
- protected host settings
- development deploy settings
- generated Control Board content
- README and CHANGELOG starting content
- whether example app files should remain
- whether dev deploy files should remain

## Configure GitHub Labels And Templates

Issue and PR templates should be available after bootstrap.

Labels remain manual unless future automation is added. Use:

```text
docs/07_runbooks/runbook-github-labels.md
```

## Configure Development Environment If Needed

If the new project uses dev deploy, configure GitHub Environment `development` with the required secrets and variables.

Use:

```text
docs/07_runbooks/runbook-github-dev-deploy-workflow.md
```

Do not configure production by default.

## Run Local Validation

Expected local commands:

```bash
make doc-check
make doc-guard
make release-check
git diff --check
bash -n scripts/*.sh
```

Additional backend/frontend/e2e checks depend on whether the example app or real product app is present.

## Create Control Board In Target Repo

Create Issue #1 in the target repository using the one-screen Control Board style.

Start with:

- Current Milestone
- Current Objective
- Capability Map
- Now / Next / Later
- Current Decisions
- Open Questions
- Guardrails
- Latest Completed
- Next Deliverable

Keep detailed history in roadmap docs, not in the issue body.

## Open First Control Board

Create or update the project Control Board issue.

It should use the one-screen dashboard style:

- current milestone
- current objective
- capability map
- now / next / later
- current decisions
- open questions
- guardrails
- latest completed

## Open First Design Issue

The first product-specific issue should define the business direction.

Agents must not invent that direction.

## Open First PR

The first PR should prove that the initialized repository works:

- docs pass
- local commands run
- PR template is usable
- PR Quality Gate can run
- no secrets were copied
- business direction remains user-owned

## What Not To Copy Blindly

Do not blindly copy:

- secrets
- raw server output
- private SSH config
- local agent session files
- production host settings
- `cn.ant` or `us.hermes` assumptions
- example app business meaning
- Dogsquard-specific host assumptions unless dev deploy was intentionally included and reviewed

## Known Future Improvements

- placeholder replacement
- generated first Control Board body
- optional template profiles
- label automation
- stricter target repository validation
