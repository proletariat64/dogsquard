---
title: "Server Preflight Runbook"
doc_type: "runbook"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-30"
updated: "2026-05-30"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Server Preflight Runbook

## Purpose

This runbook describes safe server discovery before Dogsquard dev deployment implementation.

Phase 6B-0 is preflight only. It must not deploy, restart services, modify config files, or expose secrets in committed documentation.

## When To Run

Run server preflight before choosing the Dogsquard dev host, route, deploy path, or artifact activation strategy.

Run it again when server topology changes or before implementing Phase 6B-1 deployment scripts.

## Commands

```bash
make server-preflight HOST=us.hermes
make server-preflight HOST=cn.ant
```

Direct script usage:

```bash
scripts/server-preflight.sh us.hermes
scripts/server-preflight.sh cn.ant
```

Deep read-only mode:

```bash
scripts/server-preflight.sh --deep us.hermes
```

Do not commit raw `--deep` output.

## What Output Means

The script reports:

- hostname
- kernel and OS profile from `uname`
- uptime
- current SSH user
- disk space
- Docker availability
- running Docker containers when visible
- Docker Compose availability
- reverse proxy command presence
- `systemctl` availability
- listening TCP ports when `ss` exists
- common web port status for 80, 443, 8080, 18080, and 4173

## Docker Results

If Docker is present, `docker ps` shows visible running containers.

Use this to identify whether multica or other services are already using names, images, ports, or networks that Dogsquard must avoid.

Do not stop, restart, inspect secrets from, or modify containers during preflight.

## Docker Compose Results

If Docker Compose is present, `docker compose ls` shows visible Compose projects.

Use this to understand whether an existing Compose-managed app is present.

Do not run `docker compose down`, `up`, `restart`, or config-changing commands during preflight.

## Reverse Proxy Results

The script checks whether these commands exist:

- `nginx`
- `caddy`
- `traefik`

Presence only means the command is installed or available in `PATH`. It does not prove the service is active or responsible for public routing.

Do not run `nginx -T`, read Caddyfiles, read Traefik config, or dump proxy config into docs unless the user explicitly requests deep inspection and reviews the output for secrets.

## What Not To Do

During preflight:

- do not restart services
- do not stop containers
- do not edit reverse proxy config
- do not edit SSL config
- do not write deployment files to the server
- do not require `sudo`
- do not print secrets into committed files
- do not assume `/` or `/api` are available on `proletariat.icu`

## No-Restart Rule

Preflight is read-only.

No command should restart, reload, stop, or start a service.

## No-Config-Modification Rule

Preflight must not modify:

- nginx configuration
- Caddy configuration
- Traefik configuration
- Docker Compose files
- systemd units
- SSL configuration
- application files

## No-Secrets-In-Docs Rule

Do not commit:

- private keys
- tokens
- full proxy config dumps
- raw environment files
- internal credentials
- sensitive host details that are not needed for design

Summarize only the safe operational facts needed for Dogsquard routing and deployment decisions.

## What To Summarize Into Topology Docs

After preflight, manually summarize:

- host role
- reverse proxy type if known
- Docker presence
- existing public route ownership
- obvious port conflicts
- safe candidate Dogsquard routes
- unresolved questions

Do not paste full command output unless it has been reviewed and sanitized.

## Next Step After Preflight

After safe topology facts are known, choose one Phase 6B-1 implementation path:

- path-based dev route under `/dogsquard-dev`
- path-based dev route under `/dev/dogsquard`
- separate dev subdomain if user configures it
- separate host/port for early testing

Only then should deployment scripts and workflow implementation begin.
