#!/usr/bin/env bash
# check.sh — test each Evidence Source of one or more Environments.
#
#   check.sh <env> [<env>...]
#   check.sh --all
#
# Per Environment it reports the database and the logs as
#   ok · FAILED (with the masked error) · not configured
# and warns, without failing, when the database user can write.
# No secret value is ever printed.
#
# Exit: 0 nothing FAILED · 1 something FAILED · 2 usage

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$HERE/_lib.sh"

[[ $# -ge 1 && "$1" != -h && "$1" != --help ]] || { sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit "${AI_EXIT_USAGE}"; }

if ! dir="$(ai_find_dir)"; then
  echo "No $AI_DIR_NAME folder: nothing to check. Evidence Sources available: code only."
  exit 0
fi
if [[ "$1" == --all ]]; then mapfile -t targets < <(ai_list_envs "$dir"); else targets=("$@"); fi
(( ${#targets[@]} )) || { echo "No Environments configured yet (init.sh <env>)."; exit 0; }

indent() { sed 's/^/      /'; }
failed=0

write_check_sql="SELECT CASE
  WHEN r.rolsuper THEN 'superuser'
  WHEN EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind IN ('r','p') AND n.nspname NOT IN ('pg_catalog','information_schema')
      AND n.nspname NOT LIKE 'pg_toast%'
      AND has_table_privilege(c.oid, 'INSERT, UPDATE, DELETE, TRUNCATE')
  ) THEN 'can-write'
  ELSE 'read-only' END AS access
FROM pg_roles r WHERE r.rolname = current_user"

for env in "${targets[@]}"; do
  echo "$env"
  if ! ai_valid_env_name "$env" || [[ ! -f "$dir/environments/$env.env" ]]; then
    echo "  not configured (known: $(ai_list_envs "$dir" | tr '\n' ' '))"
    continue
  fi
  [[ -f "$dir/secrets/$env.env" ]] || echo "  note: secrets/$env.env is missing; connecting without passwords or tokens"

  # Database
  out="$("$HERE/db.sh" "$env" --csv "SELECT current_user AS db_user, current_database() AS db_name, current_setting('server_version') AS server_version" 2>&1)"
  rc=$?
  case $rc in
    0)
      info="$(sed -n 2p <<<"$out")"
      echo "  database: ok ($info)"
      access="$("$HERE/db.sh" "$env" --csv "$write_check_sql" 2>&1 | sed -n 2p)"
      case "$access" in
        read-only) ;;
        superuser) echo "  database: WARNING the user is a superuser. Sessions are still forced read-only, but a dedicated read-only role is safer (references/setup.md)." ;;
        can-write) echo "  database: WARNING the user can write to some tables. Sessions are still forced read-only, but a dedicated read-only role is safer (references/setup.md)." ;;
        *) echo "  database: could not tell whether the user can write" ;;
      esac ;;
    3) echo "  database: not configured" ;;
    *) echo "  database: FAILED"; indent <<<"$out"; failed=1 ;;
  esac

  # Logs
  out="$("$HERE/logs.sh" "$env" labels --since 1h 2>&1)"
  rc=$?
  case $rc in
    0)
      n="$(grep -c . <<<"$out")"
      echo "  logs:     ok ($n labels in the last hour)"
      sel_out="$("$HERE/logs.sh" "$env" series --since 24h 2>&1)"
      src=$?
      if (( src == 0 )); then
        ns="$(grep -c '^{' <<<"$sel_out")"
        if (( ns == 0 )); then echo "  logs:     WARNING LOKI_SELECTOR matched no log streams in the last 24h"
        else echo "  logs:     selector matches $ns stream(s) in the last 24h"; fi
      elif (( src == 2 )); then echo "  logs:     note: no LOKI_SELECTOR set; every query must give a full stream selector"
      else echo "  logs:     WARNING could not list streams for LOKI_SELECTOR"; indent <<<"$sel_out"; fi ;;
    3) echo "  logs:     not configured" ;;
    *) echo "  logs:     FAILED"; indent <<<"$out"; failed=1 ;;
  esac
done
exit "$failed"
