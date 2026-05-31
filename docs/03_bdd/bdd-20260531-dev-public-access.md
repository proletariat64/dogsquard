---
title: "Dev Public Access BDD"
doc_type: "bdd"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-31"
updated: "2026-05-31"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Dev Public Access BDD

## Feature: Dev Public Access Design

Dogsquard needs a safe staged path from localhost-only runtime to external validation.

### Scenario: User accesses dev app through SSH tunnel

Given Dogsquard runtime is running on `cn.ant`
And the frontend listens on `127.0.0.1:14173`
When the user opens an SSH tunnel from local port `8173` to remote port `14173`
Then the user can open `http://127.0.0.1:8173`
And no public firewall or reverse proxy change is required

### Scenario: User validates backend health through tunnel

Given Dogsquard backend listens on `127.0.0.1:18080`
When the user opens an SSH tunnel from local port `8180` to remote port `18080`
Then `http://127.0.0.1:8180/healthz` returns the backend health response

### Scenario: Public high-port access is only enabled after explicit decision

Given Phase 6D is design-only
When the user reviews public high-port access
Then no script binds Dogsquard to a public interface
And no firewall rule is changed

### Scenario: Public high-port access uses only allowed public range

Given public high-port access is approved in a future phase
When public ports are selected
Then selected ports must be inside `8000-8999`
And the current internal ports `18080` and `14173` are not assumed public

### Scenario: us.hermes is not used for Dogsquard dev access

Given `us.hermes` hosts existing multica routes
When Dogsquard dev public access is designed
Then `us.hermes` is excluded
And `43.130.49.185` is excluded

### Scenario: proletariat.icu API route is not changed

Given `proletariat.icu/api` routes to multica backend
When Dogsquard dev public access is designed
Then Dogsquard does not claim `/api`
And Dogsquard does not claim `/`

### Scenario: Reverse proxy is not modified without approved design

Given reverse proxy access is a future option
When Phase 6D is implemented
Then no nginx, Caddy, or Traefik configuration is changed
And no reverse proxy service is restarted

### Scenario: Public access design does not expose secrets

Given docs describe public access options
When commands and examples are documented
Then no private key, token, server config dump, or secret value is included

### Scenario: Rollback remains available after public access design

Given Dogsquard has runtime rollback support
When public access is only designed
Then rollback behavior is unchanged
And public access design does not remove release history
