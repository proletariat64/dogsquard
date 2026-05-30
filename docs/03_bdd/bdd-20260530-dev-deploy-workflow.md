---
title: "Dev Deploy Workflow BDD"
doc_type: "bdd"
status: "draft"
owner: "user"
source: "agent"
created: "2026-05-30"
updated: "2026-05-30"
related_issue: "#1"
related_pr: ""
supersedes: ""
---

# Dev Deploy Workflow BDD

## Feature: GitHub Actions Dev Deployment To cn.ant

The repository owner needs a deterministic workflow that deploys Dogsquard to `cn.ant` after merge to `main`, while keeping `us.hermes`, production, and public routing out of scope.

### Scenario: Push To Main Triggers Dev Deploy Workflow

Given a change has been merged to `main`
When the future dev deploy workflow is present
Then GitHub Actions should start the dev deploy workflow
And the workflow should target the development environment
And the workflow should target `cn.ant`

### Scenario: Workflow Dispatch Can Trigger Manual Dev Deploy

Given the repository owner needs to redeploy development manually
When the owner runs `workflow_dispatch`
Then the workflow should run the same dev deploy stages
And the workflow should still target only `cn.ant`
And the workflow should not target production

### Scenario: Failed PR Quality Gate Prevents Merge Before Deploy

Given a pull request has failing PR Quality Gate checks
When branch protection is configured to require the PR Quality Summary
Then the pull request should not merge to `main`
And the dev deploy workflow should not be triggered by that pull request

### Scenario: Package Release Failure Stops Deployment

Given the workflow is building a dev release
When `scripts/package-release.sh` fails
Then the workflow should stop before SSH upload
And no remote runtime restart should be attempted

### Scenario: SSH Connection Failure Stops Deployment

Given the workflow has a release artifact
When SSH connection to the development host fails
Then the workflow should fail
And the workflow should not attempt runtime restart
And the workflow should report the SSH failure without printing secrets

### Scenario: Artifact Deploy Failure Does Not Update Runtime

Given the workflow can connect to `cn.ant`
When artifact deployment fails
Then the workflow should fail
And the runtime should not be restarted
And the previous release should remain recoverable

### Scenario: Runtime Restart Failure Reports Diagnostics

Given a release artifact has deployed to `cn.ant`
When runtime restart fails
Then the workflow should fail
And diagnostics should be collected with `runtime-diagnose`
And logs should not include secret values

### Scenario: Runtime Health Failure Fails Workflow

Given the runtime restart step has completed
When the runtime health check fails
Then the workflow should fail
And diagnostics should identify backend and frontend health status

### Scenario: Successful Deploy Updates Current Release On cn.ant

Given the workflow has a valid artifact
When artifact deployment and runtime health succeed
Then `cn.ant` should have an updated `current` symlink under the dev deploy root
And runtime should pass health checks
And previous releases should remain available for rollback

### Scenario: us.hermes Is Not Targeted By Dev Deploy Workflow

Given `us.hermes` hosts existing multica routes
When the dev deploy workflow runs
Then the workflow should not connect to `us.hermes`
And the workflow should not claim `/`
And the workflow should not claim `/api`

### Scenario: Production Is Not Deployed

Given Phase 6C is development deployment only
When the workflow runs from `main` or `workflow_dispatch`
Then production deployment should not run
And production approval should not be requested by this workflow

### Scenario: Secrets Are Not Printed

Given the workflow uses SSH credentials
When logs are written
Then secret values should not be printed
And diagnostics should avoid dumping environment variables wholesale

### Scenario: Rollback Remains Manual Or Explicitly Triggered

Given a deployment has failed after artifact activation
When rollback is needed
Then rollback should require an explicit release id
And rollback should not silently select a target release
And rollback should not target `us.hermes`
