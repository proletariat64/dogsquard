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
