---
title: "Design Production Deployment as Approval-gated Profile"
doc_type: "adr"
status: "draft"
owner: "user"
source: "agent"
created: "2026-06-01"
updated: "2026-06-01"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# ADR 0008: Design Production Deployment as Approval-gated Profile

## Status

Draft.

## Context

Dogsquard has proven that it can bootstrap and operate real repos:

- profile-aware bootstrap exists
- `PROJECT_TYPE=node` was validated on a real app
- `dogpdteamreport` adopted Dogsquard governance
- a real product fix and a small product feature merged through Dogsquard workflow

Production deployment remains intentionally unimplemented.

`us.hermes` is protected because it hosts `proletariat.icu` and multica. Dogsquard must not claim `/` or `/api`, restart reverse proxies, or touch multica without an approved route plan.

## Decision

Production deployment will be designed as an opt-in, approval-gated profile for adopted apps.

This phase defines design artifacts only. It does not add production workflow files, server config, reverse proxy config, public routes, or deployment behavior.

## Consequences

- Dogsquard can discuss production safely without changing servers.
- Production implementation remains blocked until explicit approval.
- Adopted apps can later opt into production support through a separate implementation milestone.
- Dev deploy defaults remain separate from production deployment.

## Alternatives Considered

### Reuse dev deploy as production deploy

Rejected for now.

Dev deploy uses `cn.ant` and dev high-port defaults. Production needs explicit host, route, domain, certificate, rollback, and approval decisions.

### Use `us.hermes` immediately

Rejected for implementation.

`us.hermes` may be considered by design only, but it already serves multica through `proletariat.icu` `/` and `/api`.

### Delay all production discussion

Rejected.

The first real project operating loop is stable enough to begin design. Design is useful now, implementation is not yet approved.

## Why a Profile

Dogsquard is a reusable kit. Production behavior should be opt-in per adopted app rather than automatically added to every repo.

The profile can later generate:

- production runbook
- production environment variable names
- production workflow template
- route protection checklist
- rollback checklist

## Future Migration Path

1. Merge production design.
2. Review route and target options.
3. Approve or reject production implementation.
4. If approved, add a production workflow/template PR.
5. Validate production in a safe route without affecting multica.
