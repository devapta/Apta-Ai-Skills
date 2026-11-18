#!/usr/bin/env bash
# Internal helpers for the apta-investigate scripts. Not a public interface:
# agents call db.sh, logs.sh, envs.sh, check.sh, init.sh and cleanup.sh only.
#
# Environment files are parsed, never sourced: values are data, not shell code.
# Environment Secrets are only ever exported into the environment of the one
# child process that needs them (psql, logcli, docker), and every line those
# processes print passes through ai_mask before the agent sees it.

set -uo pipefail

AI_DIR_NAME=".apta-investigate"
AI_LABEL="apta-investigate"
AI_PG_IMAGE="${APTA_INVESTIGATE_PG_IMAGE:-postgres:17-alpine}"
AI_LOGCLI_IMAGE="${APTA_INVESTIGATE_LOGCLI_IMAGE:-grafana/logcli:3.7.10}"

# Exit codes shared by every script.
AI_EXIT_FAIL=1         # the query or connection failed
AI_EXIT_USAGE=2        # bad arguments or a rejected query
AI_EXIT_UNCONFIGURED=3 # this Evidence Source is not configured: carry on without it

AI_SETTINGS_KEYS=(DB_HOST DB_PORT DB_NAME DB_USER DB_SCHEMA DB_SSLMODE DB_CONNECT_TIMEOUT
  DB_STATEMENT_TIMEOUT LOKI_MODE LOKI_URL LOKI_USERNAME LOKI_ORG_ID GRAFANA_URL
  GRAFANA_LOKI_UID LOKI_SELECTOR)
AI_SECRET_KEYS=(DB_PASSWORD LOKI_PASSWORD LOKI_TOKEN)

ai_die()   { printf 'apta-investigate: %s\n' "$*" >&2; exit "${AI_EXIT_FAIL}"; }
ai_usage() { printf 'apta-investigate: %s\n' "$*" >&2; exit "${AI_EXIT_USAGE}"; }
ai_note()  { printf '%s\n' "$*" >&2; }

# --- locating the project's .apta-investigate folder -------------------------

# Directory init.sh creates the folder in: $APTA_INVESTIGATE_ROOT, else the git
# top level, else the current directory.
ai_project_root() {
  if [[ -n "${APTA_INVESTIGATE_ROOT:-}" ]]; then
    (cd "$APTA_INVESTIGATE_ROOT" && pwd)
  elif git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
  else
    pwd
  fi
}

# Print the path of the existing .apta-investigate folder: under
# $APTA_INVESTIGATE_ROOT if set, else the nearest one at or above $PWD.
# Returns 1 when there is none.
ai_find_dir() {
  if [[ -n "${APTA_INVESTIGATE_ROOT:-}" ]]; then
    [[ -d "$APTA_INVESTIGATE_ROOT/$AI_DIR_NAME" ]] || return 1
    (cd "$APTA_INVESTIGATE_ROOT/$AI_DIR_NAME" && pwd)
    return 0
  fi
  local d="$PWD"
  while :; do
    if [[ -d "$d/$AI_DIR_NAME" ]]; then printf '%s\n' "$d/$AI_DIR_NAME"; return 0; fi
    [[ "$d" == "/" ]] && return 1
    d="$(dirname "$d")"
  done
}

ai_valid_env_name() { [[ "$1" =~ ^[a-z0-9][a-z0-9._-]{0,62}$ ]]; }

ai_list_envs() { # $1 = .apta-investigate dir
  local f
  shopt -s nullglob
  for f in "$1"/environments/*.env; do basename "$f" .env; done
  shopt -u nullglob
}

# --- parsing KEY=value files -------------------------------------------------

ai_in_list() { local x="$1"; shift; local k; for k in "$@"; do [[ "$k" == "$x" ]] && return 0; done; return 1; }

# ai_parse_kv FILE PREFIX KIND
# Sets ${PREFIX}${KEY} for each allowed key. KIND is "settings" or "secrets".
# Keys belonging to the other file are ignored with a warning that names the key
# only, never its value.
ai_parse_kv() {
  local file="$1" prefix="$2" kind="$3" line key val n=0
  local -a allowed other
  if [[ "$kind" == settings ]]; then allowed=("${AI_SETTINGS_KEYS[@]}"); other=("${AI_SECRET_KEYS[@]}")
  else allowed=("${AI_SECRET_KEYS[@]}"); other=("${AI_SETTINGS_KEYS[@]}"); fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    n=$((n + 1))
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"     # trim leading space
    line="${line%"${line##*[![:space:]]}"}"     # trim trailing space
    [[ -z "$line" || "$line" == \#* ]] && continue
    line="${line#export }"
    if [[ ! "$line" =~ ^([A-Z_][A-Z0-9_]*)[[:space:]]*=(.*)$ ]]; then
      ai_note "warning: $(basename "$file"):$n is not KEY=value; ignored"
      continue
    fi
    key="${BASH_REMATCH[1]}"
    val="${BASH_REMATCH[2]}"
    val="${val#"${val%%[![:space:]]*}"}"
    if [[ ${#val} -ge 2 && ( ( "${val:0:1}" == '"' && "${val: -1}" == '"' ) || ( "${val:0:1}" == "'" && "${val: -1}" == "'" ) ) ]]; then
      val="${val:1:${#val}-2}"
    fi
    if ai_in_list "$key" "${allowed[@]}"; then
      printf -v "${prefix}${key}" '%s' "$val"
    elif ai_in_list "$key" "${other[@]}"; then
      if [[ "$kind" == settings ]]; then
        ai_note "warning: $key is a secret and belongs in secrets/, not environments/; ignored"
      else
        ai_note "warning: $key is a setting and belongs in environments/, not secrets/; ignored"
      fi
    else
      ai_note "warning: unknown key $key in $(basename "$file"); ignored"
    fi
  done <"$file"
}

# ai_load_env ENV
# Sets AI_DIR, AI_ENV, S_<KEY> (settings, may be empty) and X_<KEY> (secrets,
# may be empty). Dies when the folder or the Environment does not exist.
ai_load_env() {
  local env="$1" k
  ai_valid_env_name "$env" || ai_usage "invalid Environment name '$env' (use lowercase letters, digits, '.', '_' or '-')"
  if ! AI_DIR="$(ai_find_dir)"; then
    ai_note "No $AI_DIR_NAME folder in this project, so no Environment is configured."
    ai_note "Carry on with the code only, or set one up with init.sh."
    exit "${AI_EXIT_UNCONFIGURED}"
  fi
  if [[ ! -f "$AI_DIR/environments/$env.env" ]]; then
    local known; known="$(ai_list_envs "$AI_DIR" | tr '\n' ' ')"
    ai_note "Environment '$env' is not configured. Known: ${known:-none}."
    ai_note "Carry on without its database and logs, or add it with init.sh $env."
    exit "${AI_EXIT_UNCONFIGURED}"
  fi
  AI_ENV="$env"
  for k in "${AI_SETTINGS_KEYS[@]}"; do printf -v "S_$k" '%s' ""; done
  for k in "${AI_SECRET_KEYS[@]}"; do printf -v "X_$k" '%s' ""; done
  ai_parse_kv "$AI_DIR/environments/$env.env" S_ settings
  if [[ -f "$AI_DIR/secrets/$env.env" ]]; then
    ai_parse_kv "$AI_DIR/secrets/$env.env" X_ secrets
  fi
}

ai_db_configured()   { [[ -n "${S_DB_HOST:-}" && -n "${S_DB_NAME:-}" && -n "${S_DB_USER:-}" ]]; }
ai_loki_configured() {
  case "${S_LOKI_MODE:-}" in
    direct)  [[ -n "${S_LOKI_URL:-}" ]] ;;
    grafana) [[ -n "${S_GRAFANA_URL:-}" && -n "${S_GRAFANA_LOKI_UID:-}" ]] ;;
    *) return 1 ;;
  esac
}

# Address logcli talks to. In grafana mode it is Grafana's data source proxy.
ai_loki_addr() {
  case "${S_LOKI_MODE:-}" in
    direct)  printf '%s\n' "${S_LOKI_URL%/}" ;;
    grafana) printf '%s/api/datasources/proxy/uid/%s\n' "${S_GRAFANA_URL%/}" "$S_GRAFANA_LOKI_UID" ;;
  esac
}

# --- masking secrets in output ----------------------------------------------

# Filter stdin to stdout, replacing every Environment Secret value with ****.
ai_mask() {
  local -a envs=()
  local k v i=0
  for k in "${AI_SECRET_KEYS[@]}"; do
    v="X_$k"; v="${!v:-}"
    [[ -n "$v" ]] || continue
    i=$((i + 1)); envs+=("AI_MASK_$i=$v")
  done
  if (( i == 0 )); then cat; return; fi
  env "${envs[@]}" AI_MASK_N="$i" LC_ALL=C awk '
    BEGIN { n = ENVIRON["AI_MASK_N"] + 0; for (i = 1; i <= n; i++) s[i] = ENVIRON["AI_MASK_" i] }
    {
      line = $0
      for (i = 1; i <= n; i++) {
        out = ""
        while ((p = index(line, s[i])) > 0) { out = out substr(line, 1, p - 1) "****"; line = substr(line, p + length(s[i])) }
        line = out line
      }
      print line; fflush()
    }'
}

# --- running psql / logcli: local binary first, Docker second ----------------

# ai_runtime TOOL -> prints "local" or "docker", or dies with an install hint.
# APTA_INVESTIGATE_RUNTIME=local|docker forces one.
ai_runtime() {
  local tool="$1" forced="${APTA_INVESTIGATE_RUNTIME:-}"
  if [[ "$forced" != docker ]] && command -v "$tool" >/dev/null 2>&1; then echo local; return; fi
  if [[ "$forced" == local ]]; then ai_die "$tool is not installed (APTA_INVESTIGATE_RUNTIME=local)"; fi
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then echo docker; return; fi
  case "$tool" in
    psql)   ai_die "psql is not installed and Docker is not available. Install the PostgreSQL client (e.g. 'sudo apt install postgresql-client' or 'sudo pacman -S postgresql') or start Docker." ;;
    logcli) ai_die "logcli is not installed and Docker is not available. Install logcli from https://github.com/grafana/loki/releases or start Docker." ;;
  esac
}

ai_docker_image() { case "$1" in psql) echo "$AI_PG_IMAGE" ;; logcli) echo "$AI_LOGCLI_IMAGE" ;; esac; }

# Pull before the timed run, so a first-time download is not cut off by a timeout.
ai_docker_ensure_image() {
  docker image inspect "$1" >/dev/null 2>&1 && return 0
  ai_note "Pulling $1 (first use only)..."
  docker pull -q "$1" >/dev/null || ai_die "could not pull $1"
}

AI_CONTAINER=""
ai_docker_cleanup_current() {
  if [[ -n "$AI_CONTAINER" ]] && command -v docker >/dev/null 2>&1; then
    docker rm -f "$AI_CONTAINER" >/dev/null 2>&1 || true
  fi
  AI_CONTAINER=""
}

# Call in the main shell before running ai_exec inside a pipeline: it names the
# container up front, so if this script is interrupted the container is removed
# here, not only in the pipeline's subshell.
ai_container_guard() {
  AI_CONTAINER="apta-investigate-$$-$RANDOM"
  trap ai_docker_cleanup_current EXIT
  trap 'exit 143' INT TERM HUP
}

# ai_exec TOOL SECONDS ENVVAR... -- ARGS...
# Runs TOOL with ARGS under a timeout. Only the named ENVVARs (already exported
# by the caller) reach a Docker container, by name, so values never appear in
# any command line. Containers run with --rm, are labelled for cleanup.sh, and
# are force-removed if this script exits early.
ai_exec() {
  local tool="$1" secs="$2"; shift 2
  local -a names=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do names+=("$1"); shift; done
  shift
  local rt; rt="$(ai_runtime "$tool")" || exit $?
  if [[ "$rt" == local ]]; then
    timeout --kill-after=5 "$secs" "$tool" "$@"
    return $?
  fi
  local image; image="$(ai_docker_image "$tool")"
  ai_docker_ensure_image "$image"
  [[ -n "$AI_CONTAINER" ]] || AI_CONTAINER="apta-investigate-$$-$RANDOM"
  trap ai_docker_cleanup_current EXIT
  trap 'exit 143' INT TERM HUP
  local -a eflags=()
  local n
  for n in "${names[@]}"; do eflags+=(-e "$n"); done
  local rc
  timeout --kill-after=5 "$secs" docker run --rm -i --network host --name "$AI_CONTAINER" \
    --label "$AI_LABEL=1" "${eflags[@]}" --entrypoint "$tool" "$image" "$@"
  rc=$?
  ai_docker_cleanup_current
  return "$rc"
}

# Run "$@" (a function holding the whole pipeline) in the background and wait
# for it. Bash only runs a signal trap after the foreground command ends, but
# `wait` returns as soon as a trapped signal arrives: an interrupted script then
# exits at once and its EXIT trap removes the container. With pipefail, the
# status is the pipeline's last failing command, i.e. ai_exec's.
ai_run_bg() {
  "$@" &
  wait "$!"
}

# Explain Codex's default sandbox when a network call fails inside it.
ai_codex_network_hint() {
  if [[ "${CODEX_SANDBOX_NETWORK_DISABLED:-}" == 1 || -n "${CODEX_SANDBOX:-}" ]]; then
    ai_note "hint: this looks like the Codex sandbox, which blocks network access by default."
    ai_note "      Either approve this command to run outside the sandbox, or set"
    ai_note "      [sandbox_workspace_write] network_access = true in ~/.codex/config.toml."
  fi
}

# Durations: 90, 90s, 30m, 30min, 2h, 1d, 1w -> seconds. Empty output if invalid.
ai_duration_seconds() {
  local d="$1"
  if [[ "$d" =~ ^([0-9]+)(ms|s|m|min|h|d|w)?$ ]]; then
    local n="${BASH_REMATCH[1]}" u="${BASH_REMATCH[2]:-s}"
    case "$u" in
      ms) echo $(((n + 999) / 1000)) ;;
      s) echo "$n" ;;
      m|min) echo $((n * 60)) ;;
      h) echo $((n * 3600)) ;;
      d) echo $((n * 86400)) ;;
      w) echo $((n * 604800)) ;;
    esac
  fi
}
