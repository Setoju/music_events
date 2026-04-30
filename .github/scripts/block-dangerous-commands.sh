#!/usr/bin/env bash
set -euo pipefail

raw="$(cat)"

if [ -z "${raw// }" ]; then
  echo '{"continue":true}'
  exit 0
fi

command_text=""

if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$raw" | jq -r '.command // empty' 2>/dev/null || true)"
  args="$(printf '%s' "$raw" | jq -r 'if (.args|type)=="array" then .args|join(" ") else (.args // "") end' 2>/dev/null || true)"
  command_text="${cmd} ${args}"
fi

if [ -z "${command_text// }" ]; then
  command_text="$raw"
fi

command_text="$(printf '%s' "$command_text" | tr '[:upper:]' '[:lower:]')"

if printf '%s' "$command_text" | grep -Eq '(^|[[:space:]])git[[:space:]]+reset[[:space:]]+--hard([[:space:]]|$)|(^|[[:space:]])git[[:space:]]+checkout[[:space:]]+--([[:space:]]|$)|(^|[[:space:]])git[[:space:]]+clean[[:space:]]+-f([[:space:]]|d|x|fd|xdf|xfd|ffdx)*([[:space:]]|$)|(^|[[:space:]])rails[[:space:]]+db:drop([[:space:]]|$)|(^|[[:space:]])rails[[:space:]]+db:reset([[:space:]]|$)|(^|[[:space:]])rails[[:space:]]+db:schema:load([[:space:]]|$)|(^|[[:space:]])rm[[:space:]]+-rf[[:space:]]+/([[:space:]]|$)|(^|[[:space:]])del[[:space:]]+/f[[:space:]]+/s[[:space:]]+/q([[:space:]]|$)'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked by safety policy: dangerous command detected."}}'
  exit 2
fi

echo '{"continue":true}'
exit 0
