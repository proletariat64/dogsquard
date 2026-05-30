---
title: "Use GitHub Actions for cn.ant Dev Deploy"
doc_type: "adr"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-30"
updated: "2026-05-30"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# ADR 0005: Use GitHub Actions for cn.ant Dev Deploy

## Status

Draft.

## Context

Dogsquard has completed local manual deployment validation:

- artifact packaging
- isolated deploy to `cn.ant`
- runtime start, status, health, stop
- runtime hardening
- explicit rollback helper

`us.hermes` hosts existing multica services on `proletariat.icu`. Dogsquard must not claim `/` or `/api`, and `us.hermes` must not be the first automated deploy target.

## Decision

Use GitHub Actions on a GitHub-hosted runner to trigger dev deployment to `cn.ant` using existing packaging, deploy, and runtime scripts in a future Phase 6C-2 implementation.

The workflow should target the GitHub Environment:

```text
development
```

The workflow should not target `us.hermes` or production.

## Consequences

Positive consequences:

- CI/CD authority stays in GitHub Actions.
- Dev deployment reuses scripts already validated locally.
- `cn.ant` remains isolated from the `proletariat.icu` multica routes.
- Deployment logs are visible from GitHub.
- Manual rollback remains available.

Tradeoffs:

- GitHub-hosted runner needs SSH access to `cn.ant`.
- The local SSH alias may not work in GitHub and may need a real host value.
- Public route exposure remains unsolved.
- Production release remains a separate future decision.

## Alternatives Considered

### Deploy To us.hermes First

Rejected for now.

`us.hermes` already serves multica at `/` and `/api`. Automating Dogsquard deployment there before route design would increase risk to the existing application.

### Self-Hosted Runner

Deferred.

Current needs are satisfied by a GitHub-hosted runner using SSH. A self-hosted runner may be useful later for UAT, private network access, or reduced SSH exposure.

### Manual Deploy Only

Rejected as the next direction.

Manual deploy was valuable for Phase 6B validation, but Dogsquard needs a repeatable GitHub-controlled dev deployment path.

### Docker Compose Deploy

Deferred.

Dogsquard has no approved Docker Compose runtime design yet. Current artifact deploy is simpler and already validated.

## Why cn.ant Is Preferred First

`cn.ant` accepted isolated deployment under:

```text
~/apps/dogsquard-dev
```

Runtime validation succeeded on localhost-only ports, and no known `proletariat.icu` routing constraints apply to `cn.ant`.

## Why us.hermes Is Not Used First

`us.hermes` hosts the existing multica frontend and backend. It requires a separate route strategy before any Dogsquard activation.

## Why GitHub-Hosted Runner Is Enough For Now

The planned workflow needs checkout, build, test, package, SSH upload, runtime restart, and health checks. A GitHub-hosted runner can perform those without adding server-side CI authority.

## Why Self-Hosted Runner Is Not Needed Yet

No current requirement demands local server execution, private network-only access, or persistent runner state.

## Why Existing Scripts Should Be Used

The scripts already encode Dogsquard deployment safety:

- package artifact without secrets
- deploy to isolated root
- manage runtime with pid files
- keep `us.hermes` blocked by default
- provide diagnostics and rollback helpers

Reusing them reduces duplicated workflow logic.

## Why Production Remains Future Phase

Production deployment requires explicit approval, stricter release rules, and a separate environment. It is outside Phase 6C.

## Rollback Implications

Rollback should remain explicit and release-id based. The first deploy workflow should not silently rollback without a later approved design.

## Future Migration Paths

Possible future paths:

- public route strategy for a dev URL
- production deployment workflow with approval
- Docker Compose if an ADR approves it
- self-hosted runner for UAT or private network deployment
- automated rollback if future test evidence justifies it
