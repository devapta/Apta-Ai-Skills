#!/usr/bin/env bash
# envs.sh — list the configured Environments and which Evidence Sources each has.
# Prints non-secret settings only; for secrets it says "set" or "empty".
#
#   envs.sh            all Environments
#   envs.sh <env>      one Environment, with its full settings
#
# Exit: 0 ok (also when nothing is configured) · 2 usage

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$HERE/_lib.sh"

[[ "${1:-}" == -h || "${1:-}" == --help ]] && { sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit "${AI_EXIT_USAGE}"; }

if ! dir="$(ai_find_dir)"; then
  echo "No $AI_DIR_NAME folder in this project: no Environments configured."
  echo "Evidence Sources available: code only. (Set up with init.sh <env>...)"
  exit 0
fi

secret_state() { local v="X_$1"; [[ -n "${!v:-}" ]] && echo set || echo empty; }

describe() {
  local env="$1" full="$2"
  ( ai_load_env "$env" 2>/dev/null
    local db logs sec
    if ai_db_configured; then db="postgres://${S_DB_USER}@${S_DB_HOST}:${S_DB_PORT:-5432}/${S_DB_NAME} (password $(secret_state DB_PASSWORD))"
    else db="not configured"; fi
    if ai_loki_configured; then
      case "$S_LOKI_MODE" in
        direct)  logs="direct $S_LOKI_URL" ;;
        grafana) logs="grafana $S_GRAFANA_URL (data source $S_GRAFANA_LOKI_UID, token $(secret_state LOKI_TOKEN))" ;;
      esac
    else logs="not configured"; fi
    [[ -f "$AI_DIR/secrets/$env.env" ]] && sec="present" || sec="missing"
    printf '%s\n  database: %s\n  logs:     %s\n' "$env" "$db" "$logs"
    if ai_loki_configured; then printf '  selector: %s\n' "${S_LOKI_SELECTOR:-(none: queries must give a full stream selector)}"; fi
    if [[ "$full" == 1 ]]; then
      printf '  secrets file: %s\n  settings:\n' "$sec"
      local k v
      for k in "${AI_SETTINGS_KEYS[@]}"; do v="S_$k"; printf '    %s=%s\n' "$k" "${!v}"; done
      for k in "${AI_SECRET_KEYS[@]}"; do printf '    %s: %s\n' "$k" "$(secret_state "$k")"; done
    fi )
}

if [[ $# -ge 1 ]]; then
  ai_valid_env_name "$1" || ai_usage "invalid Environment name '$1'"
  [[ -f "$dir/environments/$1.env" ]] || { echo "Environment '$1' is not configured. Known: $(ai_list_envs "$dir" | tr '\n' ' ')"; exit 0; }
  describe "$1" 1
  exit 0
fi

envs="$(ai_list_envs "$dir")"
if [[ -z "$envs" ]]; then echo "$dir exists but has no Environments yet (init.sh <env>)."; exit 0; fi
while IFS= read -r e; do describe "$e" 0; done <<<"$envs"
