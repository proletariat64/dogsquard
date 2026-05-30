---
title: "Use SSH Artifact Deploy for Dev"
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

# ADR 0003: Use SSH Artifact Deploy for Dev

## Status

Draft

## Context

Dogsquard needs a development deployment path for a small internal full-stack app template.

The user's fixed environment includes an Ubuntu workstation, two Unix cloud servers, GitHub repositories, domains, SSL, and future HTTPS path-based services.

GitHub Actions is already the deterministic CI authority. The cloud server should be the deployment target, not the primary CI authority.

Phase 6A is documentation-only and must decide direction without implementing deployment.

## Decision

Use GitHub Actions to build, test, package, and later deploy a development artifact over SSH to a cloud host.

The future implementation should:

- run quality gates in GitHub Actions
- package backend and frontend output
- upload the artifact over SSH
- unpack into a timestamped release directory
- update a `current` symlink only after successful deploy steps
- run health and smoke verification
- preserve previous releases for rollback

## Consequences

Positive consequences:

- keeps GitHub Actions as CI/CD controller
- avoids introducing self-hosted runner operations too early
- avoids Docker decisions before the dev deployment path is proven
- matches the small current app scope
- supports clear rollback with release directories
- keeps production deployment separate

Tradeoffs:

- server setup still needs later careful implementation
- SSH deploy requires secret handling discipline
- artifact format must be kept predictable
- runtime process management remains a Phase 6B design detail

## Alternatives Considered

### Self-hosted runner on the cloud server

Rejected for Phase 6A.

A self-hosted runner may be useful later for private-network checks, server-local UAT, or heavier deployment verification. It adds runner lifecycle, permissions, and trust-boundary decisions that are not needed to define the first dev deployment strategy.

### Production deployment first

Rejected.

Production deployment must require explicit approval and a separate release policy. Dev deployment should prove the delivery mechanism first.

### Docker or Docker Compose in Phase 6A

Rejected for this phase.

Docker may become useful later for runtime parity, but Phase 6A is design-only and should not add Docker files, Compose configuration, or server runtime assumptions.

### Manual SCP from workstation

Rejected as the standard path.

Manual upload can help emergency debugging, but it would make the workstation or human operator the deployment authority instead of GitHub Actions.

## Why Artifact Deploy Is Simple Enough

The current example app is small:

- Go backend
- built frontend assets
- in-memory storage
- no auth
- no database
- minimal smoke tests

An SSH artifact deploy is enough to prove build, upload, release activation, health verification, and rollback without expanding infrastructure scope.

## Future Migration Path

If the app or target repositories need more runtime parity later, Dogsquard can migrate to:

- Docker Compose on the dev host
- a self-hosted runner for trusted branches or UAT
- richer environment-specific deployment workflows
- separate production release workflows with required approval

Any migration should be documented in a new ADR or an update to this one.
