---
name: api-contract-change
description: "Manage API response/request contract changes for Grape entities. Use when modifying app/api/entities, endpoint payloads, error schema, versioned routes, or request spec contracts."
---

# API Contract Change

## Purpose

Keep API behavior stable and explicit when changing entities, payloads, or errors.

## When To Use

- Entity fields change in app/api/entities
- Route request/response payload changes in app/api/v1
- Error codes or messages are altered
- New required parameters are introduced

## Inputs

- Affected resources and endpoints
- Intended contract delta (added/removed/renamed fields)
- Backward compatibility requirement (strict or best-effort)

## Change Workflow

1. Identify affected entities and endpoints.
2. Define exact contract delta:
   - Added fields
   - Removed fields
   - Renamed fields
   - Type/format changes
   - Error schema changes
3. Apply endpoint and entity updates together to avoid drift.
4. Ensure authorization and validation behavior still match policy intent.
5. Update request specs to assert new contract and protect against regressions.
6. If breaking change is unavoidable, require versioning plan under /api/v1 policy.

## Required Output

Provide:

1. Contract delta summary by endpoint
2. Breaking-change risk assessment
3. Test updates required (happy path + validation + auth failure)
4. Migration/rollout notes if clients are impacted

## Contract Guardrails

- Never change entity output silently without matching spec updates
- Keep error response structure consistent across endpoints
- Prefer additive changes; document removals/renames explicitly
- Preserve pagination/filter semantics when editing list endpoints

## Definition Of Done

- Entity and endpoint code are aligned
- Request specs cover changed contract and error behavior
- Authorization behavior remains correct after contract update
- Breaking-change impact is documented with mitigation
