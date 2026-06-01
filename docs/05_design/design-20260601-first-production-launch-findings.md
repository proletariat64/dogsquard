---
title: "First Production Launch Findings"
doc_type: "design"
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

Capture reusable lessons from the first Dogsquard-guided production launch.

The proof app was `dogpdteamreport`. The approved production routes were:

- frontend: `https://proletariat.icu/dogpdteamreport/`
- backend: `https://proletariat.icu/dogpdteamreport/api`

# Result

The first production launch activation succeeded.

Validated outcomes:

- `dogpdteamreport` deployed to `us.hermes`.
- The frontend route served the app under `/dogpdteamreport/`.
- The backend health route returned JSON health success under `/dogpdteamreport/api/health`.
- Static assets loaded under the repo prefix.
- Rollback was validated to a previous release and rolled forward to the fixed release.
- Existing multica behavior on `www.proletariat.icu` `/` and `/api` remained intact.

# Launch Sequence

The successful launch required one coherent app-side implementation path:

1. Add production package, deploy, runtime, health, and rollback scripts in the adopted app.
2. Add route-prefix support to the app.
3. Deploy a release to an isolated app root on `us.hermes`.
4. Activate only the approved repo-scoped route in nginx.
5. Validate frontend, backend health, assets, multica preservation, and rollback.

# Lessons

## Deploy Root Expansion

Remote scripts must expand `~/...` on the remote host, not locally and not as a literal directory named `~`.

The first app launch found this failure mode during production deployment. Future generated scripts or runbooks should explicitly test:

- `DEPLOY_ROOT=~/apps/<repo>-prod`
- no literal `$HOME/~` directory is created
- rollback and status report the expanded absolute path

## Active Reverse Proxy File

`sites-available` and `sites-enabled` may not be symlinked.

Route activation instructions must identify the active nginx file before editing. A safe operator flow is:

1. Locate active server block.
2. Back up the active file.
3. Apply only the approved repo-prefix location.
4. Run `nginx -t`.
5. Reload nginx, not restart it.

Raw server config should not be committed.

## Nginx Module Preflight

`nginx -t` can fail for unrelated existing server issues before route changes are evaluated.

The first launch found a duplicate stream module load. The safe lesson is not to generalize server repair into Dogsquard automation. Instead, production runbooks should require:

- preflight `nginx -t` before route activation
- narrow backup and remediation notes if an existing nginx issue blocks reload
- no raw config or logs committed

## Base Path Frontend Root

Apps deployed under `/{reponame}/` need an explicit regression test for the frontend root.

The first launch found that `/dogpdteamreport/` redirected to itself while assets and API health worked. Future adopted apps should validate:

- `/{reponame}` redirects to `/{reponame}/`
- `/{reponame}/` returns the frontend HTML with HTTP 200
- `/{reponame}/api/health` returns health JSON
- static assets load under the prefix

# Reusable Pattern

Dogsquard's reusable production pattern should remain:

- production route shape: `https://proletariat.icu/{reponame}/`
- backend route shape: `https://proletariat.icu/{reponame}/api`
- app runtime isolated under a repo-specific deploy root
- runtime bound to localhost behind reverse proxy
- route activation scoped to the repo prefix only
- rollback validated before the launch is considered complete
- multica `/` and `/api` preservation explicitly verified

# What Not To Automate Yet

Do not automatically generate or apply raw nginx config.

Future Dogsquard work may generate route snippets or operator checklists, but route activation should remain approval-gated until more apps prove the pattern.

# Follow-up Candidates

- Add route-prefix frontend-root checks to production profile guidance.
- Add deploy-root expansion checks to production script templates if Dogsquard later generates full production scripts.
- Add active reverse proxy file discovery to the production route activation runbook.
- Keep raw server config, raw logs, and secrets out of repository history.

# Post-launch Health Evidence

The first post-launch health check found a production health regression after the initial successful launch:

- `https://proletariat.icu/dogpdteamreport/` returned HTTP 502
- `https://proletariat.icu/dogpdteamreport/api/health` returned HTTP 502
- `https://www.proletariat.icu/auth.html` still returned the multica access page
- the existing multica API route remained separate from the `dogpdteamreport` route

Safe read-only investigation found:

- the expected Dogsquard production runtime bind was `127.0.0.1:18987`
- no process was listening on `127.0.0.1:18987`
- the production release symlink pointed at `20260601131820-67b0897f3892`
- the release manifest recorded `base_path=/dogpdteamreport`
- a separate Node process was running from a dev checkout on port `9999`
- localhost `:9999` answered `/api/health`, but not `/dogpdteamreport/api/health`
- the production PID file did not match the live app process

The likely failure class is runtime/upstream mismatch: the approved route had no healthy app process on the expected local production port.

The recommended recovery path is to restart the approved production runtime from the current release on the expected local bind, then recheck the public frontend and backend health routes. That recovery still requires explicit approval. The investigation did not deploy, rollback, restart services, edit reverse proxy config, touch multica, or capture raw logs/config.

Reusable lesson:

- post-launch health evidence must include both public route checks and expected-local-upstream checks
- PID-file consistency belongs in the standard production health investigation flow
- app Control Boards should track the incident issue, suspected failure class, and approved next recovery action
- raw logs and server config should stay out of GitHub issues and docs
