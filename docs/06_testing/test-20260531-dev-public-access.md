---
title: "Dev Public Access Test Plan"
doc_type: "test"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Dev Public Access Test Plan

## Objective

Define how to validate future Dogsquard development public access without changing runtime exposure in Phase 6D.

## Test Preconditions

- Dogsquard is deployed on `cn.ant`
- runtime is running on localhost-only ports
- SSH access to `admin@47.103.65.82` works
- no public route has been configured
- `us.hermes` remains excluded

## SSH Tunnel Validation

Open frontend tunnel:

```bash
ssh -L 8173:127.0.0.1:14173 admin@47.103.65.82
```

Expected:

- SSH session opens
- local port `8173` forwards to remote frontend
- no firewall change is needed

## Backend Health Through Tunnel

Open backend tunnel:

```bash
ssh -L 8180:127.0.0.1:18080 admin@47.103.65.82
```

Validate:

```bash
curl http://127.0.0.1:8180/healthz
```

Expected:

- backend health response is returned
- no direct public access to `18080` is required

## Frontend Through Tunnel

Open:

```text
http://127.0.0.1:8173
```

Expected:

- Internal Task Intake frontend loads
- no public DNS or reverse proxy is involved

## Public High-Port Validation Future Plan

If direct high-port public access is approved later:

- use only ports inside `8000-8999`
- candidate frontend port: `8173`
- candidate backend port: `8180`
- validate that runtime binds only as explicitly configured
- validate backend health and frontend load
- validate rollback remains available

## Reverse Proxy Validation Future Plan

If reverse proxy access is approved later:

- confirm domain and DNS first
- confirm certificate strategy
- confirm path strategy
- validate frontend route
- validate API route
- validate rollback
- validate no effect on multica

## Negative Tests

### us.hermes Not Targeted

Confirm no public access command, workflow, or doc instruction targets:

- `us.hermes`
- `43.130.49.185`

### Existing /api Not Changed

Confirm no instruction changes:

- `proletariat.icu/`
- `proletariat.icu/api`

### Public Ports Outside Allowed Range Not Used

Confirm public exposure designs do not use ports outside:

```text
8000-8999
```

The current internal ports `18080` and `14173` may remain localhost-only.

## Acceptance Criteria

- SSH tunnel validation path is documented
- backend health tunnel validation is documented
- frontend tunnel validation is documented
- direct high-port validation remains future
- reverse proxy validation remains future
- `us.hermes` and `proletariat.icu` remain protected
- Phase 6D does not expose a public URL
