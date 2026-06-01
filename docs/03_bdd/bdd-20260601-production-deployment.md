---
title: "Production Deployment BDD"
doc_type: "bdd"
status: "draft"
owner: "user"
source: "agent"
created: "2026-06-01"
updated: "2026-06-01"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Feature: Approval-gated production deployment design

Production deployment must be designed before it is implemented.

## Scenario: Production implementation remains blocked by default

Given Dogsquard has dev deploy and real-project adoption working
When a production deployment design PR is opened
Then it documents production behavior
And it does not add production workflow files
And it does not deploy to any host
And it does not expose a public URL

## Scenario: `us.hermes` remains protected

Given `us.hermes` hosts `proletariat.icu` and existing multica
When production deployment options are evaluated
Then Dogsquard must not claim `/`
And Dogsquard must not claim `/api`
And Dogsquard must not restart reverse proxy services
And Dogsquard must not touch multica containers

## Scenario: Route strategy is approved before implementation

Given an adopted app needs production deployment
When a production target is proposed
Then the proposal identifies the host, route, domain, runtime ports, and rollback path
And implementation waits for explicit user approval

## Scenario: Production and dev deploy stay separate

Given `cn.ant` is the first dev deploy target
When production deployment is designed
Then production configuration is separate from development configuration
And development high-port defaults do not become production exposure automatically

## Scenario: Secrets are configured outside the repo

Given production deployment needs credentials
When the design defines required configuration
Then secret names may be documented
And real secret values are never committed

## Scenario: Rollback remains required

Given a production deployment may fail after activation
When production deployment is implemented in a later approved phase
Then rollback to an explicit known release must be available
And diagnostics must avoid dumping secrets or raw server config
