---
title: "Dev Public Access PRD"
doc_type: "prd"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Dev Public Access PRD

## Purpose

Define how the Dogsquard development runtime should become accessible for external validation without changing deployment, production, or protected host behavior in this phase.

## Target User

The target user is the repository owner validating Dogsquard as a reusable bootstrap kit from an Ubuntu workstation, GitHub, and controlled cloud hosts.

## Problem Statement

Dogsquard currently deploys and runs successfully on `cn.ant`, but the runtime binds to localhost-only ports:

- backend: `127.0.0.1:18080`
- frontend: `127.0.0.1:14173`

These ports are not in the user-provided public firewall range. A public access strategy is needed before external browser or mobile validation can happen.

## Goals

- keep the current localhost runtime as the safe default
- design public access for `cn.ant` only
- account for firewall allowed ports
- evaluate SSH tunnel, direct high-port exposure, and reverse proxy options
- keep `us.hermes` and `proletariat.icu` protected
- avoid implementation in Phase 6D

## Non-Goals

- no public URL exposure
- no runtime port binding change
- no firewall configuration change
- no reverse proxy configuration
- no production deployment
- no Docker or Docker Compose
- no database or auth
- no self-hosted runner

## Known Firewall Constraints

For `cn.ant` and `us.hermes`, public firewall access is limited to:

- `80`
- `22`
- `443`
- `8000-8999`
- ICMP / ping

Current Dogsquard runtime ports `18080` and `14173` are outside the public range and must not be assumed publicly reachable.

## Current Internal Runtime State

`cn.ant` is the validated development deploy target.

Runtime state:

- deploy root: `~/apps/dogsquard-dev`
- backend: `127.0.0.1:18080`
- frontend: `127.0.0.1:14173`
- no public route
- no reverse proxy integration

## Public Access Options

### Option A: Direct Public High Ports

Candidate future ports:

- frontend: `8173`
- backend: `8180`

Candidate future URLs:

- `http://47.103.65.82:8173`
- `http://47.103.65.82:8180/healthz`

Pros:

- simple
- no reverse proxy
- no port 80/443 change
- no certificate requirement

Cons:

- no HTTPS
- public dev ports
- less production-like
- possible CORS or mixed-origin issues

### Option B: Reverse Proxy on cn.ant

Candidate future URL shape:

- `https://<future-dev-domain>/`
- `https://<future-dev-domain>/api`

Pros:

- production-like
- HTTPS
- cleaner frontend and API routing

Cons:

- requires reverse proxy configuration
- may require domain and DNS decisions
- may require certificate management
- more operational risk

### Option C: Private Access Through SSH Tunnel

Candidate commands:

```bash
ssh -L 8173:127.0.0.1:14173 admin@47.103.65.82
ssh -L 8180:127.0.0.1:18080 admin@47.103.65.82
```

Pros:

- safest
- no public exposure
- no firewall or reverse proxy change
- preserves localhost runtime

Cons:

- not a true public dev URL
- less convenient for mobile or external validation

## Recommended Staged Approach

Phase 6D recommends staged public access on `cn.ant`:

1. Phase 6D-1: document and validate SSH tunnel access.
2. Phase 6D-2: optionally design direct high-port dev exposure using only `8000-8999`.
3. Phase 6D-3: design reverse proxy and HTTPS only after domain strategy is chosen.

Do not use `us.hermes` for Dogsquard dev public access yet.

## cn.ant Role

`cn.ant` remains the only candidate for Dogsquard dev public access in this stage.

The current runtime should stay localhost-only until an explicit implementation phase changes it.

## us.hermes Protection

Dogsquard must not use:

- `us.hermes`
- `43.130.49.185`
- `proletariat.icu`
- `www.proletariat.icu`
- `/`
- `/api`

Existing multica routing remains protected.

## Security Constraints

- do not expose secrets
- do not commit raw server config
- do not bind to public interfaces without explicit approval
- do not use ports outside the approved firewall range for public exposure
- do not weaken GitHub deploy target guards
- do not require `sudo` in this design phase

## Acceptance Criteria

- public access options are documented
- firewall constraints are documented
- SSH tunnel is identified as the first validation path
- direct high-port and reverse proxy paths remain future options
- `cn.ant` remains the only public access candidate
- `us.hermes` remains protected
- no runtime, firewall, reverse proxy, or deployment behavior is changed
