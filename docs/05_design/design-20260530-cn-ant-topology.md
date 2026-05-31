---
title: "cn.ant Topology Notes"
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

# cn.ant Topology Notes

## Known Facts

The user has a local SSH alias:

```bash
ssh cn.ant
```

`cn.ant` is a reachable cloud host alias.

Current domain responsibilities are not yet confirmed.

## Candidate Role

`cn.ant` may be a candidate Dogsquard dev host.

Do not assume it serves:

```text
proletariat.icu
www.proletariat.icu
```

Do not make a deployment decision until preflight has been run and summarized safely.

## Unknowns To Discover

- whether existing apps or services already occupy likely deployment paths
- whether it is safer than `us.hermes` for Dogsquard dev deployment

## Preflight Command

Run read-only discovery from the local workstation:

```bash
make server-preflight HOST=cn.ant
```

## Standard Preflight Summary

A standard read-only preflight was run from the local workstation on 2026-05-30.

Sanitized findings:

- Host is reachable through the `cn.ant` SSH alias.
- Docker was not detected.
- Docker Compose was not detected.
- Nginx, Caddy, and Traefik were not detected.
- Ports 80, 443, 8080, 18080, and 4173 were not visible as listening during this preflight.
- `systemctl` is present.
- Existing local services are present, so this host is not empty.

No `--deep` preflight was run, no configuration was dumped, and no server state was changed.

## Safety Notes

Do not modify server configuration during topology discovery.

Do not restart services during topology discovery.

Do not commit raw output if it includes sensitive paths, private hostnames, or service details.

## Phase 6B-1 Candidate Note

`cn.ant` may be safer for early isolated dry-run or manual deploy validation because the standard preflight did not detect Docker, Docker Compose, nginx, Caddy, Traefik, or public web ports.

This does not prove `cn.ant` is the final dev host.

Domain routing remains unconfirmed, so Phase 6B-1 should use only an isolated deploy root and must not assume public HTTPS access.

## Phase 6B-2 Manual Deploy Summary

Phase 6B-2 validated `cn.ant` as the preferred host for early isolated dev deploy validation.

Sanitized result:

- `cn.ant` accepted a dry-run deploy plan under `~/apps/dogsquard-dev`.
- `cn.ant` accepted a real isolated deploy under `~/apps/dogsquard-dev`.
- The deploy root contains `releases/`, `shared/`, and `logs/`.
- `current` points to a timestamped release under `releases/`.

Still not confirmed:

- public domain routing
- reverse proxy integration
- service manager integration
- runtime process start strategy

`cn.ant` is preferred for the next early dev deployment validation because it avoids the known `us.hermes` multica routing constraints.

## Phase 6B-3 Runtime Summary

Phase 6B-3 validated `cn.ant` as the preferred host for early Dogsquard dev runtime validation.

Sanitized result:

- Dogsquard backend ran on localhost port `18080`.
- Dogsquard frontend static server ran on localhost port `14173`.
- Runtime state used pid files under `~/apps/dogsquard-dev/shared/run/`.
- Runtime logs used `~/apps/dogsquard-dev/logs/`.
- Runtime health passed before shutdown.
- Runtime stop left backend and frontend stopped.

No public URL was exposed.

No reverse proxy integration was added.

No system-wide service was added.

## Phase 6B-4 Runtime Hardening Summary

`cn.ant` is validated for isolated Dogsquard dev runtime hardening.

Runtime layout:

- deploy root: `~/apps/dogsquard-dev`
- pid files: `shared/run/`
- logs: `logs/`
- backend: localhost port `18080`
- frontend: localhost port `14173`

Validated hardening:

- stale pid reporting and cleanup
- idempotent start
- occupied port diagnostics
- runtime logs
- runtime diagnose
- restart and health after restart
- explicit rollback helper

No public route is configured yet.

No reverse proxy integration is configured yet.

## Phase 6C-4 Workflow Hardening Summary

`cn.ant` remains the only automated Dogsquard dev deploy target.

Phase 6C-4 hardens workflow validation and diagnostics but does not change the runtime topology:

- deploy root remains `~/apps/dogsquard-dev`
- backend remains localhost-only on port `18080`
- frontend remains localhost-only on port `14173`
- public routing remains unconfigured
- reverse proxy integration remains unconfigured

Manual workflow rollback, when used, must target an explicit release id under the cn.ant deploy root.

## Phase 6C-1 Dev Workflow Design Note

`cn.ant` is the preferred first GitHub Actions dev deploy target.

The future workflow should deploy only under the configured development deploy root, currently expected to be:

```text
~/apps/dogsquard-dev
```

or the configured `DEV_DEPLOY_ROOT`.

This does not imply public routing or reverse proxy integration.

## Phase 6C-2 Dev Workflow Implementation Note

`cn.ant` is the first automated dev deploy target.

GitHub-hosted runners may not know the local SSH alias `cn.ant`, so `DEV_HOST` may need to be the real reachable hostname or IP for the same host.

Deployment remains isolated under:

```text
DEV_DEPLOY_ROOT
```

No public route is exposed by the workflow.

## Phase 6C-3 Workflow Validation Summary

`cn.ant` has been validated as the automated dev deploy target for the `Dev Deploy` workflow.

Sanitized result:

- GitHub Environment `development` was configured with the expected deploy values.
- Manual dry-run dispatch succeeded.
- Manual real deploy dispatch succeeded.
- Runtime restart and health passed after workflow deployment.
- Local runtime status confirmed backend and frontend processes running from the remote deploy root.

The active dev runtime remains isolated:

- deploy root: `~/apps/dogsquard-dev`
- backend: localhost port `18080`
- frontend: localhost port `14173`

No public route is configured yet.

No reverse proxy integration is configured yet.
