---
title: "Production Deployment Design Runbook"
doc_type: "runbook"
status: "draft"
owner: "user"
source: "agent"
created: "2026-06-01"
updated: "2026-06-01"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Purpose

Guide production deployment design work without accidentally implementing production deployment.

# Current State

Dogsquard has:

- dev deploy to `cn.ant`
- high-port dev defaults for app profiles
- project-profile bootstrap
- real `dogpdteamreport` adoption evidence
- one real post-adoption product feature

Dogsquard does not yet have:

- production deployment workflow
- production route strategy
- production environment approval gate
- production public URL

# Design-only Procedure

1. Confirm Issue #1 says production implementation is approval-gated.
2. Identify the adopted app or template profile being designed for.
3. List candidate hosts and routes.
4. Mark protected hosts and routes.
5. Define required configuration names only.
6. Define health, rollback, and diagnostics expectations.
7. Stop before any implementation or server change.

# Protected Targets

Do not target or modify without explicit approval:

- `us.hermes`
- `43.130.49.185`
- `proletariat.icu`
- `www.proletariat.icu`
- `proletariat.icu` `/`
- `proletariat.icu` `/api`
- existing multica containers
- reverse proxy configuration

# Candidate Design Questions

- Is production deployment for Dogsquard itself, an adopted app, or both?
- Which host owns production?
- Which route or domain is safe?
- What approval gate blocks implementation?
- What rollback command is required before route activation?
- What secrets and variables are required?
- What diagnostics are safe to collect?

# What Not To Do

Do not:

- add `.github/workflows/deploy-production.yml`
- edit reverse proxy config
- restart nginx, caddy, traefik, or multica
- run remote deploy
- expose a public URL
- commit secrets
- commit raw server config
- use old UAT assumptions as production design

# Future Implementation Entry Criteria

Implementation may start only after:

- production design is reviewed
- target host is approved
- route/domain strategy is approved
- approval gate is defined
- rollback strategy is defined
- secret/variable names are defined without values
