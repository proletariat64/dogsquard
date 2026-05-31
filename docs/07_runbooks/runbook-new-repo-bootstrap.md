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

Describe the expected future workflow for applying Dogsquard to a newly created repository.

This runbook is preparatory. The bootstrap implementation is pending.

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

Future implementation may provide:

```bash
scripts/init-new-repo.sh <target-path>
```

The bootstrap should copy or initialize:

- docs governance structure
- Makefile and scripts
- `.github` issue and PR templates
- PR Quality Gate workflow
- configurable Dev Deploy workflow template
- Control Board and roadmap docs
- README template
- CHANGELOG template
- `.env.example`

## Review Generated Files

After bootstrap, the user should review:

- project name and app name placeholders
- Go module name
- frontend package name
- protected host settings
- development deploy settings
- generated Control Board content
- README and CHANGELOG starting content

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

## What Not To Copy Blindly

Do not blindly copy:

- secrets
- raw server output
- private SSH config
- local agent session files
- production host settings
- `cn.ant` or `us.hermes` assumptions
- example app business meaning

## Known Future Implementation Pending

- bootstrap script or checklist implementation
- example app inclusion/exclusion mechanism
- placeholder replacement
- README template finalization
- agent-local file template/ignore policy
- `v0.1.0` readiness validation
