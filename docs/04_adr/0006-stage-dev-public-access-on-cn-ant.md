---
title: "Stage Dev Public Access on cn.ant"
doc_type: "adr"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# ADR 0006: Stage Dev Public Access on cn.ant

## Status

Draft.

## Context

Dogsquard dev deployment and runtime are validated on `cn.ant`.

Current runtime ports are localhost-only:

- backend: `127.0.0.1:18080`
- frontend: `127.0.0.1:14173`

The user-provided firewall rule allows public access only on:

- `80`
- `22`
- `443`
- `8000-8999`
- ICMP / ping

`us.hermes` is protected because it already serves multica through `proletariat.icu` and `/api`.

## Decision

Stage dev public access on `cn.ant`, starting with SSH tunnel documentation and design validation before enabling direct public ports or reverse proxy.

Do not expose Dogsquard publicly in Phase 6D.

## Consequences

- current localhost runtime remains the default
- first validation path is private SSH tunnel access
- direct public ports and reverse proxy remain future explicit phases
- `us.hermes` remains excluded
- no firewall, reverse proxy, or runtime binding changes are made in this phase

## Alternatives Considered

### Direct High Ports First

Dogsquard could bind frontend/backend to `0.0.0.0` using ports such as `8173` and `8180`.

This is simple, but it exposes dev services without HTTPS and is less controlled.

### Reverse Proxy First

Dogsquard could use 80/443 with a future dev domain and path routing.

This is cleaner and more production-like, but it requires DNS, certificates, and reverse proxy changes.

### Keep Private Forever

Dogsquard could stay localhost-only and use SSH tunnels indefinitely.

This is safest, but it does not provide a true public dev URL for external validation.

## Why cn.ant Is Preferred

`cn.ant` is already validated for isolated deploy and runtime.

It does not have the known multica routing responsibilities of `us.hermes`.

## Why us.hermes Is Excluded

`us.hermes` hosts:

- `https://proletariat.icu/`
- `https://www.proletariat.icu/`
- `https://proletariat.icu/api`
- `https://www.proletariat.icu/api`

Dogsquard must not claim `/` or `/api` there.

## Why Localhost Runtime Remains Default

Localhost binding prevents accidental public exposure while deployment and runtime workflows are still maturing.

It also keeps rollback and health validation independent from public routing decisions.

## Why SSH Tunnel Is Safest First

SSH tunnel access uses the already allowed port `22`.

It does not require:

- public bind
- firewall change
- reverse proxy change
- DNS
- TLS certificate

## Why Direct High Ports May Come Later

The firewall allows `8000-8999`, so future direct public dev ports can be designed using that range.

Candidate ports:

- frontend: `8173`
- backend: `8180`

This must be an explicit later phase.

## Why Reverse Proxy And HTTPS Are Later

Reverse proxy and HTTPS require route, domain, and certificate decisions.

Those decisions are useful but carry more operational risk than SSH tunnel validation.

## Firewall Rule Implications

Ports `18080` and `14173` are not publicly accessible under the known firewall policy.

Future public exposure must use either:

- SSH tunnel over port `22`
- direct public ports inside `8000-8999`
- reverse proxy through `80` or `443`

## Future Migration Path

1. Validate SSH tunnel access.
2. Decide whether a short-lived direct high-port dev URL is useful.
3. Decide whether a future dev domain should route through HTTPS.
4. Only then implement public binding or reverse proxy configuration.
