---
title: "Dev Public Access Runbook"
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

# Dev Public Access Runbook

## Purpose

Describe the safe first access path for validating Dogsquard dev runtime from outside the `cn.ant` host.

Phase 6D is design-only. It does not expose a public URL.

## Current State

Dogsquard dev runtime runs on `cn.ant`:

- backend: `127.0.0.1:18080`
- frontend: `127.0.0.1:14173`

Known public firewall allowed ports:

- `80`
- `22`
- `443`
- `8000-8999`
- ICMP / ping

The current runtime ports are not public firewall ports.

## Start Runtime Before Tunnel

If runtime is not already running:

```bash
make runtime-start HOST=cn.ant DEPLOY_ROOT='~/apps/dogsquard-dev'
make runtime-health HOST=cn.ant DEPLOY_ROOT='~/apps/dogsquard-dev'
```

## SSH Tunnel Method

Open frontend tunnel:

```bash
ssh -L 8173:127.0.0.1:14173 admin@47.103.65.82
```

Open backend tunnel:

```bash
ssh -L 8180:127.0.0.1:18080 admin@47.103.65.82
```

These commands keep Dogsquard bound to localhost on `cn.ant` and expose access only through the local workstation tunnel.

## Browser URL

Open:

```text
http://127.0.0.1:8173
```

## Backend Health URL

Open or curl:

```text
http://127.0.0.1:8180/healthz
```

## Stop Runtime After Validation

If desired:

```bash
make runtime-stop HOST=cn.ant DEPLOY_ROOT='~/apps/dogsquard-dev'
```

## What Not To Do

- do not bind Dogsquard to `0.0.0.0` in Phase 6D
- do not open ports outside `8000-8999`
- do not edit firewall rules
- do not edit nginx, Caddy, or Traefik config
- do not restart reverse proxy services
- do not target `us.hermes`
- do not use `proletariat.icu` root or `/api`
- do not commit secrets or raw server config

## Future Direct High-Port Approach

If approved later, Dogsquard may expose dev ports directly on `cn.ant` using only the allowed `8000-8999` range.

Candidate ports:

- frontend: `8173`
- backend: `8180`

This would require an explicit implementation phase and safety review.

## Future Reverse Proxy Approach

If approved later, Dogsquard may use a dev domain with HTTPS.

Future design must define:

- domain or subdomain
- certificate strategy
- frontend route
- API route
- rollback behavior
- how multica remains unaffected

## us.hermes Protection Warning

Do not use `us.hermes`, `43.130.49.185`, `proletariat.icu`, or `www.proletariat.icu` for Dogsquard dev public access in Phase 6D.

Existing multica routes on `/` and `/api` must remain untouched.
