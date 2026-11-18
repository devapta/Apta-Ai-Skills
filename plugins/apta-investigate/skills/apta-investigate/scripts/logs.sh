#!/usr/bin/env bash
# logs.sh — read an Environment's logs from Grafana Loki through logcli.
#
#   logs.sh <env> query '<logql>' [window] [--limit N] [--output default|raw|jsonl] [--step D]
#   logs.sh <env> labels [window]
#   logs.sh <env> label-values <label> [window]
#   logs.sh <env> series ['<selector>'] [window]
#
# Window: --since 30m|1h|6h|2d (default 1h) or --from/--to RFC3339 times.
#   Windows longer than 24h are refused unless --allow-long-window is given,
#   which the agent adds only after the user agreed.
# The Environment's LOKI_SELECTOR is the base of every query:
#   starts with '|'        -> appended to it:   '|= "error"'  =>  {selector} |= "error"
#   contains {{selector}}  -> substituted:      'sum(count_over_time({{selector}} |= "panic" [5m]))'
#   starts with '{'        -> used as it is (a different stream selector)
# --limit: log lines to return, default 500, max 5000. Times print in UTC.
#
# Exit: 0 ok · 1 query/connection failed · 2 rejected/usage · 3 not configured

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$HERE/_lib.sh"

usage() { sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit "${AI_EXIT_USAGE}"; }

[[ $# -ge 2 ]] || usage
env_name="$1" cmd="$2"; shift 2
case "$cmd" in query|labels|label-values|series) ;; -h|--help) usage ;; *) ai_usage "unknown command '$cmd' (query, labels, label-values, series)";; esac

since="" from="" to="" limit=500 output=default step="" allow_long=0
positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) [[ $# -ge 2 ]] || usage; since="$2"; shift 2 ;;
    --since=*) since="${1#*=}"; shift ;;
    --from) [[ $# -ge 2 ]] || usage; from="$2"; shift 2 ;;
    --from=*) from="${1#*=}"; shift ;;
    --to) [[ $# -ge 2 ]] || usage; to="$2"; shift 2 ;;
    --to=*) to="${1#*=}"; shift ;;
    --limit) [[ $# -ge 2 ]] || usage; limit="$2"; shift 2 ;;
    --limit=*) limit="${1#*=}"; shift ;;
    --output) [[ $# -ge 2 ]] || usage; output="$2"; shift 2 ;;
    --output=*) output="${1#*=}"; shift ;;
    --step) [[ $# -ge 2 ]] || usage; step="$2"; shift 2 ;;
    --step=*) step="${1#*=}"; shift ;;
    --allow-long-window) allow_long=1; shift ;;
    -h|--help) usage ;;
    *) positional+=("$1"); shift ;;
  esac
done

[[ "$limit" =~ ^[0-9]+$ ]] && (( limit >= 1 && limit <= 5000 )) || ai_usage "--limit must be between 1 and 5000"
case "$output" in default|raw|jsonl) ;; *) ai_usage "--output must be default, raw or jsonl" ;; esac

ai_load_env "$env_name"
if ! ai_loki_configured; then
  ai_note "Environment '$AI_ENV' has no Loki settings (LOKI_MODE with LOKI_URL, or GRAFANA_URL + GRAFANA_LOKI_UID)."
  ai_note "Carry on without the logs for this Environment."
  exit "${AI_EXIT_UNCONFIGURED}"
fi

# --- time window --------------------------------------------------------------

window_args=() window_secs=0
if [[ -n "$from" || -n "$to" ]]; then
  [[ -z "$since" ]] || ai_usage "use either --since or --from/--to"
  [[ -n "$from" ]] || ai_usage "--to needs --from"
  from_s="$(date -u -d "$from" +%s 2>/dev/null)" || ai_usage "--from is not a valid time: $from"
  if [[ -n "$to" ]]; then to_s="$(date -u -d "$to" +%s 2>/dev/null)" || ai_usage "--to is not a valid time: $to"
  else to_s="$(date -u +%s)"; fi
  (( to_s > from_s )) || ai_usage "--to must be after --from"
  window_secs=$((to_s - from_s))
  window_args=(--from="$(date -u -d "@$from_s" +%Y-%m-%dT%H:%M:%SZ)" --to="$(date -u -d "@$to_s" +%Y-%m-%dT%H:%M:%SZ)")
else
  window_secs="$(ai_duration_seconds "${since:-1h}")"
  [[ -n "$window_secs" && "$window_secs" -gt 0 ]] || ai_usage "--since must look like 30m, 1h, 6h or 2d"
  window_args=(--since="${window_secs}s")
fi
if (( window_secs > 86400 && ! allow_long )); then
  ai_usage "the window is $((window_secs / 3600))h, over the 24h default. Ask the user first, then add --allow-long-window."
fi

# --- build the logcli command ---------------------------------------------------

selector="${S_LOKI_SELECTOR:-}"
compose_query() {
  local q="$1"
  if [[ "$q" == *"{{selector}}"* ]]; then
    [[ -n "$selector" ]] || ai_usage "{{selector}} used but LOKI_SELECTOR is empty for '$AI_ENV'"
    printf '%s' "${q//\{\{selector\}\}/"$selector"}"
  elif [[ "$q" =~ ^[[:space:]]*\| ]]; then
    [[ -n "$selector" ]] || ai_usage "the query starts with '|' but LOKI_SELECTOR is empty for '$AI_ENV'; pass a full {stream selector}"
    printf '%s %s' "$selector" "${q#"${q%%[![:space:]]*}"}"
  else
    printf '%s' "$q"
  fi
}

args=()
case "$cmd" in
  query)
    [[ ${#positional[@]} -eq 1 ]] || ai_usage "query needs exactly one LogQL argument (quote it)"
    q="$(compose_query "${positional[0]}")" || exit $?
    args=(query -q -z UTC -o "$output" --limit="$limit" "${window_args[@]}")
    [[ -n "$step" ]] && args+=(--step="$step")
    args+=("$q")
    ai_note "query: $q"
    ;;
  labels)
    [[ ${#positional[@]} -eq 0 ]] || ai_usage "labels takes no arguments (did you mean label-values?)"
    args=(labels -q "${window_args[@]}") ;;
  label-values)
    [[ ${#positional[@]} -eq 1 ]] || ai_usage "label-values needs the label name"
    args=(labels -q "${window_args[@]}" "${positional[0]}") ;;
  series)
    [[ ${#positional[@]} -le 1 ]] || ai_usage "series takes at most one selector"
    s="${positional[0]:-$selector}"
    [[ -n "$s" ]] || ai_usage "series needs a selector (LOKI_SELECTOR is empty for '$AI_ENV')"
    args=(series -q "${window_args[@]}" "$s") ;;
esac

# --- settings -> logcli environment -------------------------------------------------

unset LOKI_ADDR LOKI_USERNAME LOKI_PASSWORD LOKI_BEARER_TOKEN LOKI_BEARER_TOKEN_FILE LOKI_ORG_ID \
  LOKI_AUTH_HEADER LOKI_HTTP_PROXY_URL LOKI_ENV_PROXY
LOKI_ADDR="$(ai_loki_addr)"; export LOKI_ADDR
names=(LOKI_ADDR)
if [[ "$S_LOKI_MODE" == direct ]]; then
  [[ -n "${S_LOKI_USERNAME:-}" ]] && { export LOKI_USERNAME="$S_LOKI_USERNAME"; names+=(LOKI_USERNAME); }
  [[ -n "${X_LOKI_PASSWORD:-}" ]] && { export LOKI_PASSWORD="$X_LOKI_PASSWORD"; names+=(LOKI_PASSWORD); }
  [[ -n "${S_LOKI_ORG_ID:-}" ]] && { export LOKI_ORG_ID="$S_LOKI_ORG_ID"; names+=(LOKI_ORG_ID); }
fi
[[ -n "${X_LOKI_TOKEN:-}" ]] && { export LOKI_BEARER_TOKEN="$X_LOKI_TOKEN"; names+=(LOKI_BEARER_TOKEN); }
if [[ "$S_LOKI_MODE" == grafana && -z "${X_LOKI_TOKEN:-}" ]]; then
  ai_note "warning: grafana mode without LOKI_TOKEN in secrets/$AI_ENV.env; Grafana will most likely refuse."
fi

# --- run ---------------------------------------------------------------------

ai_container_guard
run_logcli() { ai_exec logcli 300 "${names[@]}" -- "${args[@]}" 2>&1 | ai_mask; }
ai_run_bg run_logcli
rc=$?
if (( rc == 124 || rc == 137 )); then
  ai_note "error: logcli gave up after 300s. Narrow the window or the selector."
  ai_codex_network_hint
  exit "${AI_EXIT_FAIL}"
fi
if (( rc != 0 )); then
  ai_codex_network_hint
  exit "${AI_EXIT_FAIL}"
fi
exit 0
