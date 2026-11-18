#!/usr/bin/env bash
# guard-secrets.sh — Claude Code PreToolUse hook (shipped with the plugin).
# Denies any tool call whose path, pattern or command points into
# .apta-investigate/secrets/. A guardrail against accidents, not a security
# boundary: see docs/adr/0001 in the Apta-Ai-Skills repo.
#
# Reads the hook JSON on stdin. Prints a deny decision, or nothing to allow.

set -uo pipefail
input="$(cat)"

# String values of the fields that can point at a file, without needing jq.
fields="$(grep -oE '"(file_path|path|notebook_path|pattern|command|cwd)"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' <<<"$input" || true)"
targets="$(grep -vE '^"cwd"' <<<"$fields" || true)"
cwd="$(grep -E '^"cwd"' <<<"$fields" | head -1 || true)"

deny=0
if grep -qE 'apta-investigate/+secrets' <<<"$targets"; then deny=1; fi
if [[ "$cwd" == *".apta-investigate"* ]] && grep -q 'secrets' <<<"$targets"; then deny=1; fi
if [[ "$cwd" == *".apta-investigate/secrets"* ]]; then deny=1; fi

if (( deny )); then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"apta-investigate: .apta-investigate/secrets/ holds Environment Secrets, which the agent never reads or edits. Use the skill scripts (db.sh, logs.sh, envs.sh, check.sh); they read the secrets themselves. Ask the user to edit that file in their own editor."}}'
fi
exit 0
