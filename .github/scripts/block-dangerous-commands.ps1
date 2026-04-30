$raw = [Console]::In.ReadToEnd()

if ([string]::IsNullOrWhiteSpace($raw)) {
  Write-Output '{"continue":true}'
  exit 0
}

try {
  $payload = $raw | ConvertFrom-Json -Depth 50
}
catch {
  Write-Output '{"continue":true}'
  exit 0
}

$commandParts = @()

if ($null -ne $payload.command -and -not [string]::IsNullOrWhiteSpace([string]$payload.command)) {
  $commandParts += [string]$payload.command
}

if ($null -ne $payload.args) {
  if ($payload.args -is [System.Array]) {
    $commandParts += ($payload.args | ForEach-Object { [string]$_ })
  }
  else {
    $commandParts += [string]$payload.args
  }
}

$commandText = ($commandParts -join ' ').ToLowerInvariant()
if ([string]::IsNullOrWhiteSpace($commandText)) {
  $commandText = $raw.ToLowerInvariant()
}

$blockedPatterns = @(
  '(^|\s)git\s+reset\s+--hard(\s|$)',
  '(^|\s)git\s+checkout\s+--(\s|$)',
  '(^|\s)git\s+clean\s+-f(d|x|fd|xdf|xfd|ffdx)*(\s|$)',
  '(^|\s)rails\s+db:drop(\s|$)',
  '(^|\s)rails\s+db:reset(\s|$)',
  '(^|\s)rails\s+db:schema:load(\s|$)',
  '(^|\s)rm\s+-rf\s+/(\s|$)',
  '(^|\s)del\s+/f\s+/s\s+/q(\s|$)'
)

$match = $false
foreach ($pattern in $blockedPatterns) {
  if ($commandText -match $pattern) {
    $match = $true
    break
  }
}

if ($match) {
  Write-Output '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked by safety policy: dangerous command detected."}}'
  exit 2
}

Write-Output '{"continue":true}'
exit 0
