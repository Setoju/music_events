---
name: policy-boundary-audit
description: "Audit authorization boundaries for Rails API endpoints. Use when reviewing Pundit coverage, role-based access (user/artist/admin), endpoint-policy mapping, and missing policy tests."
---

# Policy Boundary Audit

## Purpose

Verify every API action is explicitly authorized and tested at role boundaries.

## When To Use

- New endpoint or action is added under app/api/v1
- Policy files are modified under app/policies
- Role behavior changes in user, artist, or admin flows
- Security review before merge or release

## Inputs

- Target scope: one resource or full API
- Changed files list (if available)
- Expected role behavior per action

## Audit Steps

1. Enumerate actions in app/api/v1 for the target scope.
2. Map each action to its Pundit policy method in app/policies.
3. Verify authorization is called before data mutation or sensitive reads.
4. Confirm policy logic distinguishes user, artist, and admin as required.
5. Confirm denied paths return consistent API errors.
6. Verify request specs and policy specs cover allow/deny for each role.
7. Flag any implicit access path (missing policy call, broad scope, unsafe fallback).

## Required Output

Return findings sorted by severity:

1. Critical: missing or bypassed authorization
2. High: incorrect role boundary behavior
3. Medium: missing deny-path tests or inconsistent error contract
4. Low: maintainability or clarity issues

For each finding include:

- File and line reference
- Why it is risky
- Minimal fix recommendation
- Missing tests to add

If no findings exist, explicitly state "No policy boundary gaps found" and list residual risks.

## Definition Of Done

- Every endpoint action is mapped to a policy check
- Role matrix for user, artist, admin is validated
- Allow and deny paths are both tested
- Findings include actionable fixes and test updates
