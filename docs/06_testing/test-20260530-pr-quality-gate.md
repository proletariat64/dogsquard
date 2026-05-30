---
title: "PR Quality Gate Test Plan"
doc_type: "test"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-30"
updated: "2026-05-30"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# PR Quality Gate Test Plan

## Objective

Define the Phase 4 validation scope for the Dogsquard PR Quality Gate.

The gate should provide deterministic checks for early template repository work without adding deployment, production release, self-hosted runners, backend/frontend app code, or Playwright.

## Checks Included

The Phase 4 workflow includes:

- shell syntax validation for `scripts/*.sh`
- repository hygiene through `git diff --check`
- local foundation commands through `make help`, `make doc-check`, `make doc-guard`, and `make release-check`
- temporary scope guard for forbidden out-of-phase paths
- final `PR Quality Summary` job that fails when a required job fails or is cancelled

## Checks Excluded From Phase 4

Phase 4 does not include:

- backend app tests
- frontend app tests
- Playwright
- deployment
- production release
- self-hosted runner
- external SaaS integrations
- external LLM commands

The existing `make release-check` can run backend or frontend checks later when those folders exist, but Phase 4 does not add those app areas.

## Local Validation

Run these commands before opening or updating a PR:

```bash
make doc-check
make doc-guard
make release-check
git diff --check
bash -n scripts/*.sh
```

Expected local result:

- documentation checks pass
- shell scripts parse
- whitespace check passes
- lint and test steps skip cleanly while `backend/` and `frontend/` do not exist

## PR Validation

Open a pull request targeting `main`.

GitHub Actions should run `PR Quality Gate` and report:

- `Shell Check`
- `Repository Hygiene`
- `Local Foundation`
- `Temporary Phase 4 Scope Guard`
- `PR Quality Summary`

The `PR Quality Summary` job is intended to become the future required status check after branch protection is configured.

## Known Limitations

- The scope guard is temporary and now allows backend/frontend changes for Phase 5B.
- The workflow does not install Go or Node dependencies.
- The workflow does not run Playwright.
- The workflow does not deploy.
- The workflow does not validate label sync automation.
- The workflow does not replace human review of product meaning.

## Future Expansion Plan

Later phases may add:

- backend test setup when backend code exists
- frontend test setup when frontend code exists
- Playwright smoke checks
- documentation gate refinements
- branch protection requiring `PR Quality Summary`
- deployment workflows for dev and production
- production approval gates
