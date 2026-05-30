---
title: "Dev Deployment BDD"
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

# Dev Deployment BDD

Feature: Dev Deployment
  Dogsquard should deploy merged main-branch changes to a development cloud host through GitHub-controlled delivery without deploying production.

  Background:
    Given GitHub Actions is the CI/CD controller
    And the cloud server is the dev deployment target
    And production deployment requires a separate future approval path

  Scenario: Merge to main triggers future dev deployment
    Given a pull request has passed PR Quality Gate
    When the pull request is merged to `main`
    Then the future dev deployment workflow starts
    And the workflow targets the dev environment only

  Scenario: Build or test failure blocks deployment
    Given the future dev deployment workflow starts
    When build or test checks fail
    Then no artifact is deployed
    And the active dev release is unchanged

  Scenario: Deployment artifact is uploaded to dev server
    Given build and test checks pass
    When the future deployment workflow packages the release
    Then the artifact is uploaded to the dev server
    And the artifact is unpacked into a timestamped release directory

  Scenario: Current symlink points to latest successful release
    Given a new release has been unpacked successfully
    When activation succeeds
    Then `current` points to the latest successful release
    And the previous release remains available for rollback

  Scenario: Health check passes after deployment
    Given the dev release is activated
    When the workflow requests `GET /healthz`
    Then the response is successful
    And the JSON health status is `ok`

  Scenario: API smoke passes after deployment
    Given the dev release is activated
    When API smoke verification runs against the dev API URL
    Then task list, create, validation, update, and delete smoke checks pass

  Scenario: Frontend smoke passes after deployment
    Given the dev release is activated
    When frontend smoke verification runs against the dev app URL
    Then the app loads
    And the empty state is visible
    And a valid task can be created through the UI
    And missing-title validation is visible

  Scenario: Failed deployment does not replace current release
    Given a working dev release is active
    When upload, activation, health, or smoke verification fails
    Then `current` still points to the previous working release
    And the failure is visible in GitHub Actions

  Scenario: Rollback switches current to previous release
    Given at least two successful releases exist
    When rollback is triggered in a future implementation
    Then `current` points to the previous successful release
    And health verification runs after rollback

  Scenario: Production is not deployed by dev workflow
    Given the future dev deployment workflow runs
    When deployment completes
    Then production is not deployed
    And no production approval gate is consumed
