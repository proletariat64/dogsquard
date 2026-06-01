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

Dogsquard has now also proven one production launch through an adopted app:

- proof app: `dogpdteamreport`
- production host: `us.hermes`
- frontend route: `https://proletariat.icu/dogpdteamreport/`
- backend route: `https://proletariat.icu/dogpdteamreport/api`
- rollback validated and rolled forward to the fixed release
- existing multica behavior preserved on `www.proletariat.icu` `/` and `/api`

Dogsquard does not yet have:

- production deployment workflow
- production environment approval gate
- automatic production route activation

Production deployment design and the first proof launch have been completed. Further production changes still require explicit approval.

This proof launch does not authorize broad production automation, unapproved public routes, raw server config commits, or changes to existing multica routes.

# Design-only Procedure

1. Confirm Issue #1 says production implementation is approval-gated.
2. Identify the adopted app or template profile being designed for.
3. List candidate hosts and routes.
4. Mark protected hosts and routes.
5. Define required configuration names only.
6. Define health, rollback, and diagnostics expectations.
7. Stop before any implementation or server change.

# Implementation Planning Procedure

Use this procedure after production implementation planning is approved:

1. Confirm planning approval is recorded in Issue #1.
2. Identify the first adopted app candidate.
3. Select candidate host options without touching servers.
4. List approved and blocked route options.
5. Define GitHub environment, secret, and variable names without values.
6. Define protected target guard behavior.
7. Define production health, rollback, and diagnostics behavior.
8. Decide whether the next PR is a scaffold-only PR or an implementation PR.
9. Stop before adding production workflow files, server config, or public routes unless separately approved.

Planning may produce docs, checklists, and future implementation scope. It must not deploy.

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

# Current Route-strategy Decision

The current planning decision is:

- host: `us.hermes`
- frontend route: `https://proletariat.icu/{reponame}/`
- backend route: `https://proletariat.icu/{reponame}/api`

This avoids claiming the existing multica routes:

- `https://proletariat.icu/`
- `https://proletariat.icu/api`

This decision does not authorize implementation, server changes, reverse proxy edits, deploys, or route activation.

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

Production implementation planning also must not:

- treat planning approval as route approval
- treat planning approval as `us.hermes` approval
- reuse dev deploy settings as production settings without an explicit production profile
- add production behavior to every Dogsquard bootstrap profile by default

# Future Implementation Entry Criteria

Implementation may start only after:

- production design is reviewed
- target host is approved
- route/domain strategy is approved
- approval gate is defined
- rollback strategy is defined
- secret/variable names are defined without values
- the user explicitly approves a production implementation PR

# First Launch Operator Lessons

The `dogpdteamreport` launch produced reusable operator lessons:

- verify the active nginx file before editing; `sites-available` and `sites-enabled` may not be symlinked
- run `nginx -t` before and after route changes
- reload nginx only after syntax validation
- keep the route scoped to `/{reponame}` and `/{reponame}/api`
- validate `/{reponame}/` returns frontend HTML, not a self-redirect
- validate `/{reponame}/api/health` returns JSON health success
- validate static assets under the prefix
- validate existing `www.proletariat.icu` `/` and `/api` behavior after activation
- validate rollback to a previous release and roll forward to the desired release

Do not commit raw nginx config, raw logs, secrets, or server-specific dumps as evidence.
