---
title: "Production Health Investigation Runbook"
doc_type: "runbook"
status: "draft"
owner: "user"
source: "agent"
created: "2026-06-02"
updated: "2026-06-02"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Purpose

Guide post-launch production health investigations for Dogsquard-adopted apps without making unapproved production changes.

This runbook is for evidence collection and recovery recommendation. It does not authorize deploys, rollbacks, restarts, reverse-proxy edits, or public route changes.

# Scope

Use this runbook when a production app route or health endpoint fails after launch.

For the first proof app, the approved routes are:

- frontend: `https://proletariat.icu/dogpdteamreport/`
- backend health: `https://proletariat.icu/dogpdteamreport/api/health`

Existing multica routes must remain preserved:

- `https://www.proletariat.icu/`
- `https://www.proletariat.icu/api`
- `https://proletariat.icu/`
- `https://proletariat.icu/api`

# Safe Evidence

Collect only the evidence needed to identify the failure class:

- public route HTTP status
- public health endpoint HTTP status
- multica preservation checks
- active release identifier
- current symlink target
- expected local runtime bind
- whether the expected local runtime port is listening
- whether localhost health works on the expected runtime port
- PID-file consistency
- process command, working directory, and non-secret environment keys such as `PORT`, `HOST`, `APP_BASE_PATH`, and `NODE_ENV`

Do not collect or commit:

- secrets
- raw server config
- raw logs
- full environment dumps
- database files
- runtime data
- private host inventory beyond what is needed for the incident

# Investigation Flow

1. Recheck public routes.
2. Confirm existing multica routes are still preserved.
3. Identify the expected production runtime bind from the app scripts/docs.
4. Check whether the expected local port is listening.
5. Probe localhost health on the expected app path.
6. Confirm the production release symlink and release manifest.
7. Check whether the PID file matches a live process.
8. If another app process is running, record its working directory and non-secret port/base-path values.
9. Classify the likely failure.
10. Recommend one recovery action that still requires explicit approval.

# Failure Classes

Common classes:

- runtime stopped
- stale PID file
- wrong upstream port
- wrong app working directory
- app running without the expected base path
- release symlink points to the wrong release
- deploy artifact missing required files
- route/proxy mismatch
- app crash on startup

The first post-launch `dogpdteamreport` health investigation found this class:

- public app routes returned HTTP 502
- expected Dogsquard production runtime port `127.0.0.1:18987` was not listening
- production release symlink pointed at `20260601131820-67b0897f3892`
- a separate Node process was running from a dev checkout on port `9999`
- the production PID file did not match the live app process

The recommended recovery path was to start the approved production runtime from the current release on the expected local bind, then recheck public routes. That action still requires explicit approval.

# Control Board Evidence

During an incident, the app Control Board should include:

- affected public routes
- current HTTP status
- multica preservation status
- focused issue link
- suspected failure class
- next approved action
- explicit note that no deploy/restart/rollback/proxy edit occurred unless approved

The Dogsquard Control Board should include:

- reusable lesson status
- whether the incident exposes a template/runbook gap
- whether the recovery should become a reusable pattern
- next deliverable, not command-sized substeps

# Recovery Recommendations

Recommend exactly one next recovery path where possible:

- restart the app runtime
- rollback to a known release
- redeploy the same release
- deploy a fix
- adjust route configuration
- repair deploy artifact

Each recovery path requires explicit approval before execution.

# Hard Stops

Stop and ask for approval before:

- restarting production app runtime
- rolling back
- redeploying
- editing reverse proxy config
- reloading nginx/caddy/traefik
- touching multica
- changing public routes
- reading or copying raw server config
- copying raw logs into GitHub issues or docs
