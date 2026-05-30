---
title: "Protect Existing Multica Routing During Dogsquard Dev Deploy"
doc_type: "adr"
status: "draft"
owner: "user"
source: "user"
created: "2026-05-30"
updated: "2026-05-30"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# ADR 0004: Protect Existing Multica Routing During Dogsquard Dev Deploy

## Status

Draft

## Context

The user has confirmed that `us.hermes` hosts:

```text
https://proletariat.icu
https://www.proletariat.icu
```

Current routing:

```text
/      -> multica frontend Docker service
/api   -> multica backend Docker service
```

Dogsquard is a bootstrap kit and example app, not the existing multica product.

Phase 6B-0 is deployment discovery and server preflight only.

## Decision

Dogsquard dev deploy must not use root path `/` or `/api` on `proletariat.icu` because those paths are already used by multica.

Dogsquard must not overwrite, break, or hijack:

- existing multica containers
- existing root frontend routing
- existing `/api` backend routing
- existing reverse proxy configuration
- existing SSL configuration

## Safe Future Routing Options

Potential future Dogsquard dev routes:

```text
/dogsquard-dev
/dogsquard-dev/api
/dev/dogsquard
/dev/dogsquard/api
```

Other safe options if the user configures them later:

- separate dev subdomain
- separate host/port during early testing

Final routing remains undecided until server preflight is reviewed.

## Consequences

Positive consequences:

- protects the existing multica deployment
- keeps Dogsquard dev deployment isolated
- avoids accidental production-domain hijacking
- forces discovery before automation

Tradeoffs:

- path-based routing may require frontend base-path handling later
- separate ports may be less representative of final HTTPS routing
- separate subdomain may require DNS and SSL setup outside Phase 6B-0

## Alternatives Considered

### Reuse `/`

Rejected because `/` already serves the multica frontend.

### Reuse `/api`

Rejected because `/api` already serves the multica backend.

### Replace existing reverse proxy config immediately

Rejected because Phase 6B-0 is preflight only and must not modify server configuration.

### Deploy to `cn.ant` without discovery

Rejected because `cn.ant` responsibilities and routing are not yet confirmed.

## Why Server Discovery Is Required

Server discovery is required to understand:

- reverse proxy type
- container names and port usage
- existing deployment directories
- whether path-based routing is safe
- whether separate port-based testing is safer
- which host should receive Dogsquard dev deployment

## Why Phase 6B-0 Is Preflight Only

Preflight separates fact gathering from deployment implementation.

This avoids changing a live server before Dogsquard has a safe route, deployment path, rollback concept, and implementation plan.
