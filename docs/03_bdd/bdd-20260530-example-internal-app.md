---
title: "Example Internal App BDD"
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

# Example Internal App BDD

Feature: Internal Task Intake
  The example app lets the user create and manage small internal task intake records so Dogsquard can prove a realistic full-stack lifecycle.

  Background:
    Given the example app is running locally
    And task storage starts empty for the test context

  Scenario: Health check returns ok
    When the user or system requests `GET /health`
    Then the API returns a successful response
    And the response body is JSON
    And the health status is `ok`

  Scenario: User creates a valid task
    Given the user enters a title
    And the user enters an optional description
    And the user selects priority `medium`
    When the user submits the task
    Then the API creates the task
    And the task has an id
    And the task status is `open`
    And the task has created and updated timestamps

  Scenario: User cannot create task without title
    Given the user leaves the title blank
    When the user submits the task
    Then the task is not created
    And the user sees a validation error for the title

  Scenario: User sees task in dashboard table
    Given a valid task exists
    When the user opens the dashboard
    Then the dashboard table shows the task title
    And the dashboard table shows the priority
    And the dashboard table shows the status

  Scenario: User updates task status
    Given a task exists with status `open`
    When the user changes the task status to `in_progress`
    Then the API updates the task
    And the dashboard shows status `in_progress`
    And the task updated timestamp changes

  Scenario: User deletes task
    Given a task exists
    When the user deletes the task
    Then the API removes the task
    And the dashboard no longer shows the task

  Scenario: Dashboard handles empty state
    Given no tasks exist
    When the user opens the dashboard
    Then the dashboard shows an empty state
    And the dashboard still shows the task creation form

  Scenario: Validation error is visible in UI
    Given the user enters invalid task input
    When the user submits the form
    Then the UI displays a clear validation message
    And the invalid task is not added to the table

  Scenario: API returns JSON error for invalid input
    Given an API client sends a create task request without a title
    When the API validates the request
    Then the API returns a non-success status
    And the response body is JSON
    And the response includes an error message

  Scenario: Local release-check still passes
    Given the example app implementation is prepared
    When `make release-check` runs
    Then documentation checks pass
    And available lint checks pass
    And available tests pass
