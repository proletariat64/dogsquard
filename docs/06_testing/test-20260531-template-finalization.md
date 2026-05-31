---
title: "Template Finalization Test Plan"
doc_type: "test"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Template Finalization Test Plan

## Objective

Define how to validate future Dogsquard template finalization and new-repo bootstrap implementation.

This test plan supports 6E-B implementation. It does not implement bootstrap behavior.

## Test Strategy For Future Init Implementation

Future implementation should be tested against a fresh local repository so Dogsquard can prove it initializes a usable project without relying on current repo state.

Validation should cover:

- generated file layout
- placeholder replacement
- documentation governance
- local commands
- GitHub templates
- PR Quality Gate behavior
- example app inclusion or exclusion
- no secrets copied

## Fresh Repo Bootstrap Test

Test flow:

1. Create a temporary empty git repository.
2. Run the Dogsquard bootstrap/init process.
3. Inspect generated files.
4. Commit generated output in the temporary repo.
5. Run local validation commands.
6. Confirm the generated repo can open a first Control Board and first design issue.

Expected:

- core template files exist
- project-specific placeholders are replaced or clearly marked for review
- no private Dogsquard local state is copied

## Docs Check Validation

Run:

```bash
make doc-check
make doc-guard
```

Expected:

- required docs folders exist
- required metadata exists
- naming rules pass
- inbox/archive rules remain intact

## PR Quality Gate Validation

Expected future validation:

- `.github/workflows/pr-quality.yml` exists
- PR Quality Gate can run in the generated repo
- summary check remains the primary branch protection candidate
- checks do not require unavailable backend/frontend/example app files unless included

## No Secrets Validation

Confirm generated repo does not include:

- `.env`
- private SSH keys
- GitHub secret values
- raw server output
- private host config
- local tool credentials

## Example App Inclusion/Exclusion Validation

If the example app is excluded:

- generated repo still passes docs/local checks
- README explains how to start product-specific implementation
- no Internal Task Intake business meaning appears as required product direction

If the example app is included:

- backend tests pass
- frontend build passes
- e2e smoke passes if Playwright is configured
- docs clearly mark it as example material

## GitHub Environment Setup Validation

If dev deploy is enabled for a generated repo:

- GitHub Environment `development` is documented
- required secrets and variables are listed
- target host and deploy root are configurable
- protected host guard is configurable
- production is not configured by default

## Acceptance Criteria For 6E-B Implementation

- bootstrap/init path exists or checklist path is explicitly accepted
- fresh repo can be initialized from Dogsquard
- docs checks pass in initialized repo
- PR Quality Gate path is ready
- example app handling matches approved policy
- agent-local file policy is enforced
- no secrets are copied
- README explains how to use Dogsquard
- `v0.1.0` readiness checklist can be evaluated
