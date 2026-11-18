#!/usr/bin/env bash
# db.sh — run ONE read-only query against an Environment's PostgreSQL database.
#
#   db.sh <env> "<sql>"            the query as an argument
#   db.sh <env> -                  the query from stdin
#
# Options (before or after the query):
#   --limit N   rows to return, default 200, max 1000 (more rows => a truncation note)
#   --csv       CSV output instead of an aligned table
#
# Allowed: one SELECT, WITH, TABLE, VALUES, EXPLAIN or SHOW statement, or a psql
# describe command (\d, \d+, \dt, \di, \dv, \dm, \ds, \df, \dn, \dT, \dx, \l)
# with at most one name pattern.
# Every query runs inside BEGIN TRANSACTION READ ONLY with a statement timeout,
# then rolls back. Credentials never appear in arguments or output.
#
# Exit: 0 ok · 1 query/connection failed · 2 rejected/usage · 3 not configured

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$HERE/_lib.sh"

usage() { sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit "${AI_EXIT_USAGE}"; }

env_name="" sql="" sql_set=0 limit=200 csv=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit) [[ $# -ge 2 ]] || usage; limit="$2"; shift 2 ;;
    --limit=*) limit="${1#*=}"; shift ;;
    --csv) csv=1; shift ;;
    -h|--help) usage ;;
    *)
      if [[ -z "$env_name" ]]; then env_name="$1"
      elif (( ! sql_set )); then sql="$1"; sql_set=1
      else ai_usage "unexpected argument: pass the SQL as one quoted argument"; fi
      shift ;;
  esac
done
[[ -n "$env_name" && $sql_set -eq 1 ]] || usage
[[ "$limit" =~ ^[0-9]+$ ]] && (( limit >= 1 && limit <= 1000 )) || ai_usage "--limit must be between 1 and 1000"
if [[ "$sql" == "-" ]]; then sql="$(cat)"; fi

ai_load_env "$env_name"
if ! ai_db_configured; then
  ai_note "Environment '$AI_ENV' has no database settings (DB_HOST, DB_NAME, DB_USER)."
  ai_note "Carry on without the database for this Environment."
  exit "${AI_EXIT_UNCONFIGURED}"
fi

# --- classify the query --------------------------------------------------------

trimmed="${sql#"${sql%%[![:space:]]*}"}"
trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
[[ -n "$trimmed" ]] || ai_usage "empty query"

kind="" body=""
if [[ "$trimmed" == \\* ]]; then
  # psql meta-command: only the describe family, one optional name pattern.
  if [[ "$trimmed" =~ ^\\(d|d\+|dt|dt\+|di|di\+|dv|dv\+|dm|dm\+|ds|ds\+|df|df\+|dn|dn\+|dT|dT\+|dx|dx\+|l|l\+)([[:space:]]+[A-Za-z0-9_.*\"]+)?$ ]]; then
    kind=meta body="$trimmed"
  else
    ai_usage "only psql describe commands (\\d, \\dt, \\d+ table, \\dn, \\df, \\l ...) are allowed"
  fi
else
  # Split into statements outside of strings, quoted identifiers, comments and
  # dollar quotes. Prints: statement count, first keyword, forbidden functions
  # found, then the first statement's text.
  analysis="$(printf '%s' "$sql" | LC_ALL=C awk -v q="'" '
    { buf = buf $0 "\n" }
    END {
      n = length(buf); i = 1; cur = ""; raw = ""; nstmt = 0; first = ""; firstraw = ""; all = ""
      while (i <= n) {
        c = substr(buf, i, 1); c2 = substr(buf, i, 2)
        if (c2 == "--") { j = index(substr(buf, i), "\n"); if (j == 0) j = n - i + 2; raw = raw substr(buf, i, j - 1); cur = cur " "; i += j - 1; continue }
        if (c2 == "/*") {
          depth = 1; raw = raw c2; i += 2
          while (i <= n && depth > 0) {
            t = substr(buf, i, 2)
            if (t == "/*") { depth++; raw = raw t; i += 2 }
            else if (t == "*/") { depth--; raw = raw t; i += 2 }
            else { raw = raw substr(buf, i, 1); i++ }
          }
          cur = cur " "; continue
        }
        if (c == q) {
          prev = (i > 1) ? substr(buf, i - 1, 1) : ""
          prev2 = (i > 2) ? substr(buf, i - 2, 1) : ""
          estr = ((prev == "E" || prev == "e") && prev2 !~ /[A-Za-z0-9_]/)
          raw = raw c; i++
          while (i <= n) {
            t = substr(buf, i, 1)
            if (estr && t == "\\") { raw = raw substr(buf, i, 2); i += 2; continue }
            if (t == q) { if (substr(buf, i + 1, 1) == q) { raw = raw q q; i += 2; continue } raw = raw t; i++; break }
            raw = raw t; i++
          }
          cur = cur " " q q " "; continue
        }
        if (c == "\"") {
          raw = raw c; i++
          while (i <= n) {
            t = substr(buf, i, 1)
            if (t == "\"") { if (substr(buf, i + 1, 1) == "\"") { raw = raw "\"\""; i += 2; continue } raw = raw t; i++; break }
            raw = raw t; i++
          }
          cur = cur " x "; continue
        }
        if (c == "$" && match(substr(buf, i), /^\$([A-Za-z_][A-Za-z0-9_]*)?\$/)) {
          tag = substr(buf, i, RLENGTH); rest = substr(buf, i + RLENGTH)
          j = index(rest, tag)
          if (j == 0) { body_len = length(rest) } else { body_len = j - 1 + length(tag) }
          raw = raw tag substr(rest, 1, body_len); i += RLENGTH + body_len
          cur = cur " " q q " "; continue
        }
        if (c == ";") {
          if (cur ~ /[^ \t\n\r]/) { nstmt++; if (nstmt == 1) { first = cur; firstraw = raw } }
          all = all " " cur; cur = ""; raw = ""; i++; continue
        }
        cur = cur c; raw = raw c; i++
      }
      if (cur ~ /[^ \t\n\r]/) { nstmt++; if (nstmt == 1) { first = cur; firstraw = raw } }
      all = all " " cur
      kw = ""
      if (match(first, /[A-Za-z_]+/)) kw = tolower(substr(first, RSTART, RLENGTH))
      low = tolower(all); bad = ""
      fnre = "(^|[^a-z0-9_$])(set_config|pg_terminate_backend|pg_cancel_backend|pg_reload_conf|pg_rotate_logfile|pg_promote|pg_switch_wal|pg_create_restore_point|pg_log_backend_memory_contexts|lo_import|lo_export|lo_unlink|lo_create|lo_from_bytea|lo_put|dblink|dblink_exec|dblink_connect|pg_file_write|pg_file_unlink|pg_file_rename|pg_read_file|pg_read_binary_file|pg_ls_dir|pg_stat_reset|pg_advisory_lock|pg_advisory_xact_lock)[ \t\n\r]*\\("
      while (match(low, fnre)) {
        m = substr(low, RSTART, RLENGTH); sub(/^[^a-z_]*/, "", m); sub(/[ \t\n\r]*\($/, "", m)
        bad = bad " " m; low = substr(low, RSTART + RLENGTH)
      }
      print nstmt; print kw; print bad; printf "%s", firstraw
    }')"
  nstmt="$(sed -n 1p <<<"$analysis")"
  kw="$(sed -n 2p <<<"$analysis")"
  bad="$(sed -n 3p <<<"$analysis")"
  body="$(sed -n '4,$p' <<<"$analysis")"
  (( nstmt == 1 )) || ai_usage "pass exactly one statement per call (found $nstmt)"
  if [[ -n "${bad// /}" ]]; then
    ai_usage "query calls a function that is not allowed during an Investigation:${bad}"
  fi
  case "$kw" in
    select|with|table|values) kind=cursor ;;
    explain|show) kind=direct ;;
    *) ai_usage "only read queries are allowed (SELECT, WITH, TABLE, VALUES, EXPLAIN, SHOW or \\d...); got '${kw:-?}'" ;;
  esac
fi

# --- settings -> psql environment ---------------------------------------------

stmt_timeout="${S_DB_STATEMENT_TIMEOUT:-120s}"
[[ "$stmt_timeout" =~ ^[0-9]+$ ]] && stmt_timeout="${stmt_timeout}s"
[[ "$stmt_timeout" =~ ^[0-9]+(ms|s|min|h)$ ]] || ai_usage "DB_STATEMENT_TIMEOUT must look like 120, 120s, 5min or 1h"
stmt_secs="$(ai_duration_seconds "$stmt_timeout")"
connect_secs="${S_DB_CONNECT_TIMEOUT:-30}"
[[ "$connect_secs" =~ ^[0-9]+$ ]] || ai_usage "DB_CONNECT_TIMEOUT must be a whole number of seconds"
schema="${S_DB_SCHEMA:-}"
if [[ -n "$schema" && ! "$schema" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then ai_usage "DB_SCHEMA must be a plain schema name"; fi

export PGHOST="$S_DB_HOST" PGPORT="${S_DB_PORT:-5432}" PGDATABASE="$S_DB_NAME" PGUSER="$S_DB_USER"
export PGSSLMODE="${S_DB_SSLMODE:-prefer}" PGCONNECT_TIMEOUT="$connect_secs" PGAPPNAME="apta-investigate"
export PGPASSWORD="${X_DB_PASSWORD:-}"
unset PGOPTIONS PGSERVICE PGSERVICEFILE PGPASSFILE

# --- build the psql script -----------------------------------------------------

script="\\set ON_ERROR_STOP on
\\set QUIET on
\\pset pager off
\\pset null '(null)'
"
(( csv )) && script+="\\pset format csv
"
script+="BEGIN TRANSACTION READ ONLY;
SET LOCAL statement_timeout = '${stmt_timeout}';
"
[[ -n "$schema" ]] && script+="SET LOCAL search_path TO \"${schema}\", public;
"
case "$kind" in
  cursor)
    script+="DECLARE apta_investigate_cursor NO SCROLL CURSOR FOR
${body}
;
FETCH FORWARD ${limit} FROM apta_investigate_cursor;
\\set QUIET off
MOVE FORWARD 1 FROM apta_investigate_cursor;
\\set QUIET on
" ;;
  direct)
    script+="${body}
;
" ;;
  meta)
    script+="${body}
" ;;
esac
script+="ROLLBACK;
"

# --- run ---------------------------------------------------------------------

outer=$((connect_secs + stmt_secs + 30))
ai_container_guard
run_query() {
  printf '%s' "$script" \
    | ai_exec psql "$outer" PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD PGSSLMODE PGCONNECT_TIMEOUT PGAPPNAME \
        -- -X -q -f - 2>&1 \
    | ai_mask \
    | awk -v limit="$limit" '
        /^MOVE 1$/ { print "-- truncated: more than " limit " rows. Narrow the query or raise --limit (max 1000)."; next }
        /^MOVE 0$/ { next }
        { print }'
}
ai_run_bg run_query
rc=$?
if (( rc == 124 || rc == 137 )); then
  ai_note "error: gave up after ${outer}s (connect ${connect_secs}s + statement ${stmt_secs}s + 30s)."
  ai_codex_network_hint
  exit "${AI_EXIT_FAIL}"
fi
if (( rc != 0 )); then
  ai_codex_network_hint
  exit "${AI_EXIT_FAIL}"
fi
exit 0
