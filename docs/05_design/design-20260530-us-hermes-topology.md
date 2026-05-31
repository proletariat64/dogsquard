---
title: "us.hermes Topology Notes"
doc_type: "design"
status: "draft"
owner: "user"
source: "user"
created: "2026-05-30"
updated: "2026-05-30"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# us.hermes Topology Notes

## Known Facts

The user has a local SSH alias:

```bash
ssh us.hermes
```

`us.hermes` is the server for:

```text
https://proletariat.icu
https://www.proletariat.icu
```

Current routing on `us.hermes`:

```text
https://proletariat.icu
https://www.proletariat.icu
  -> local Docker multica frontend

https://proletariat.icu/api
https://www.proletariat.icu/api
  -> multica Docker backend
```

## Constraint

Dogsquard dev deployment must not claim, overwrite, hijack, or break:

- `/`
- `/api`
- existing multica containers
- existing reverse proxy configuration
- existing SSL configuration

## Safe Candidate Routes

Future Dogsquard dev routing may use one of these paths if server discovery confirms it is safe:

```text
/dogsquard-dev
/dogsquard-dev/api
/dev/dogsquard
/dev/dogsquard/api
```

Other future options:

- separate dev subdomain if the user configures it later
- separate host/port during early testing

## Unknowns To Discover

- current deployment directories
- whether path-based routing is easy
- whether separate port-based dev preview is safer
- whether existing Docker networks or ports constrain Dogsquard
- where deployment logs should live

## Preflight Command

Run read-only discovery from the local workstation:

```bash
make server-preflight HOST=us.hermes
```

Do not include secrets, raw config dumps, or sensitive paths in committed docs.

## Standard Preflight Summary

A standard read-only preflight was run from the local workstation on 2026-05-30.

Sanitized findings:

- Host is reachable through the `us.hermes` SSH alias.
- Docker is installed.
- Docker Compose is installed.
- Multica frontend, backend, and database containers are running.
- Nginx is installed and appears to be the likely reverse proxy.
- Caddy and Traefik were not detected.
- Ports 80 and 443 are listening.
- Multica frontend and backend are bound to local-only ports behind the host.
- Port 8080 is also in use.
- Ports 18080 and 4173 were not visible as listening during this preflight.

No `--deep` preflight was run, no proxy configuration was dumped, and no server state was changed.

## Notes

`us.hermes` is an important shared host because it already serves multica through the `proletariat.icu` domain.

Dogsquard deployment design must preserve existing multica routing first, then add Dogsquard only under a confirmed safe path or endpoint.

## Phase 6B-1 Deploy Script Warning

If `us.hermes` is used for Phase 6B-1 script validation, Dogsquard must use an isolated deploy root such as:

```bash
DEPLOY_ROOT=~/apps/dogsquard-dev
```

Phase 6B-1 must not:

- edit nginx config
- restart nginx
- touch multica containers
- use Docker for Dogsquard
- claim `/`
- claim `/api`
- expose Dogsquard publicly

## Phase 6B-2 Dry-Run Summary

Phase 6B-2 ran `us.hermes` in dry-run mode only.

Sanitized result:

- dry-run deploy plan completed against an isolated home-directory deploy root
- no real deploy activation was performed
- no `current` symlink was changed by Dogsquard deploy
- no reverse proxy config was changed
- no nginx restart was performed
- no multica container was touched

Future real deployment on `us.hermes` requires an explicit route plan that preserves existing `/` and `/api` multica routing.

## Phase 6B-3 Runtime Warning

Runtime start and restart remain blocked by default for `us.hermes`.

Phase 6B-3 did not perform real runtime activation on `us.hermes`.

Future `us.hermes` runtime activation requires an explicit route strategy that protects:

- `/`
- `/api`
- existing multica containers
- existing reverse proxy configuration
- existing SSL configuration

## Phase 6B-4 Runtime Hardening Warning

`us.hermes` remains protected during Phase 6B-4.

Allowed actions:

- runtime status
- runtime diagnose

Blocked by default:

- runtime start
- runtime restart
- runtime rollback

No route strategy exists yet for Dogsquard on `us.hermes`.

## Phase 6C-1 Dev Workflow Exclusion

`us.hermes` is explicitly excluded from the Phase 6C dev deploy workflow design.

Any future `us.hermes` activation requires a separate route strategy that protects:

- `/`
- `/api`
- existing multica containers
- existing reverse proxy configuration
- existing SSL configuration

## Phase 6C-2 Dev Workflow Guard

The dev deploy workflow explicitly rejects protected targets:

- `us.hermes`
- `proletariat.icu`
- `www.proletariat.icu`
- `43.130.49.185`

The workflow must not deploy to `us.hermes`.

## Phase 6C-3 Validation Summary

`us.hermes` remains excluded from the Dev Deploy workflow.

Phase 6C-3 validated deployment against `cn.ant`, not `us.hermes`.

The protected host guard now rejects:

- `us.hermes`
- `proletariat.icu`
- `www.proletariat.icu`
- `43.130.49.185`

No real deployment, runtime activation, reverse proxy change, nginx restart, or multica operation was performed on `us.hermes`.

## Phase 6C-4 Workflow Hardening Warning

`us.hermes` and `43.130.49.185` remain blocked by the Dev Deploy workflow guard.

No Phase 6C workflow may target:

- `us.hermes`
- `43.130.49.185`
- `proletariat.icu`
- `www.proletariat.icu`

Workflow rollback support does not change this boundary. Rollback is for the cn.ant development deploy root only.

## Phase 6D Dev Public Access Warning

User-provided firewall policy for `us.hermes` allows public access on:

- `80`
- `22`
- `443`
- `8000-8999`
- ICMP / ping

This does not make `us.hermes` a Dogsquard dev public access target.

Dogsquard dev public access must not use:

- `proletariat.icu/`
- `proletariat.icu/api`
- `www.proletariat.icu/`
- `www.proletariat.icu/api`

No public access through `us.hermes` is designed or implemented in Phase 6D.
