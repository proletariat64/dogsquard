---
title: "v0.1.0 Candidate"
doc_type: "release"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# v0.1.0 Candidate

## Purpose

Define what Dogsquard needs before it can be treated as a first reusable bootstrap-kit candidate.

`v0.1.0` is a template readiness milestone, not a production product release.

## Included Capabilities

The candidate includes:

- documentation governance structure and checks
- Makefile command center
- GitHub issue and PR templates
- PR Quality Gate workflow
- Control Board and roadmap operating model
- example Internal Task Intake app as optional validation material
- API smoke and minimal Playwright smoke support
- cn.ant dev deploy pattern and runtime management
- Dev Deploy GitHub Actions workflow as optional template material
- new-repo bootstrap script and runbook
- agent operating guidance through reusable docs

## Excluded Capabilities

The candidate does not include:

- production deployment
- public URL exposure by default
- `us.hermes` route changes
- `proletariat.icu` root or `/api` ownership
- Docker or Docker Compose conversion
- database or auth
- self-hosted runner setup
- full product generator behavior
- automatic GitHub label synchronization

## Readiness Checklist

- [ ] Control Board dashboard is current.
- [ ] Roadmap reflects completed capability groups and next milestone.
- [ ] README explains how to use Dogsquard.
- [ ] Template inventory is complete enough for bootstrap review.
- [ ] `scripts/init-new-repo.sh` dry-run works.
- [ ] `scripts/init-new-repo.sh` actual copy works in a temporary target.
- [ ] Example app is optional, not mandatory.
- [ ] Dev deploy files are optional, not mandatory.
- [ ] Agent-local file policy is documented and enforced.
- [ ] `make doc-check` passes.
- [ ] `make doc-guard` passes.
- [ ] `make release-check` passes.
- [ ] `make e2e-smoke` passes.
- [ ] `make package-release` passes.
- [ ] No secrets or raw server output are committed.
- [ ] Production remains explicitly future.

## Known Limitations

- Bootstrap does not fully replace project-specific names yet.
- Generated target repositories still require manual GitHub settings review.
- Labels are documented but not synchronized automatically.
- Dev deploy requires manual GitHub Environment setup.
- Public dev access remains SSH-tunnel oriented and private by default.
- The example app remains in the Dogsquard repo rather than under `examples/`.

## Release Blockers

Blockers before tagging `v0.1.0`:

- failed local release-check
- failed bootstrap validation
- accidental inclusion of local-only files
- stale or misleading Control Board
- unclear README bootstrap instructions
- secrets or raw server output in tracked files

## Post-v0.1.0 Candidates

After `v0.1.0`, possible follow-up work includes:

- placeholder replacement improvements
- optional template profiles
- generated Control Board body
- label automation
- example app relocation
- production deployment design
- public access hardening if needed

## Production Remains Future

Production deployment requires a separate design, explicit approval gate, and route strategy. It is not required for `v0.1.0`.
