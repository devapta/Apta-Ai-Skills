#!/usr/bin/env bash
# init.sh — create the project's .apta-investigate folder and Environment files.
#
#   init.sh <env> [<env>...]      e.g. init.sh dev prod-medan prod-riau
#
# Safe to re-run: existing files are never overwritten, so it also adds new
# Environments later. Creates, at the project root (git top level):
#   .apta-investigate/.gitignore              "*": the whole folder stays out of git
#   .apta-investigate/environments/<env>.env  Environment Settings (agent may edit)
#   .apta-investigate/secrets/<env>.env       Environment Secrets (user fills in; mode 600)
#   .apta-investigate/reports/                Investigation Reports
# If the project has a .claude/ folder, also adds deny rules for secrets/ to
# .claude/settings.json so Claude Code's Read/Edit tools refuse those files.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$HERE/_lib.sh"

[[ $# -ge 1 && "$1" != -h && "$1" != --help ]] || { sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit "${AI_EXIT_USAGE}"; }
for e in "$@"; do
  ai_valid_env_name "$e" || ai_usage "invalid Environment name '$e' (lowercase letters, digits, '.', '_' or '-')"
done

root="$(ai_project_root)"
dir="$root/$AI_DIR_NAME"
umask 077
mkdir -p "$dir/environments" "$dir/secrets" "$dir/reports"
chmod 700 "$dir" "$dir/secrets"
[[ -f "$dir/.gitignore" ]] || printf '# Created by apta-investigate: nothing in this folder is ever committed.\n*\n' >"$dir/.gitignore"

created=() kept=()
for env in "$@"; do
  settings="$dir/environments/$env.env"
  secrets="$dir/secrets/$env.env"
  if [[ -e "$settings" ]]; then kept+=("environments/$env.env"); else
    cat >"$settings" <<EOF
# Environment Settings for "$env" (apta-investigate).
# Non-secret values only: the agent may read and edit this file.
# Passwords and tokens belong in ../secrets/$env.env, never here.
# Leave the database or the Loki part empty if this Environment does not have it.
# Format: KEY=value, one per line. No inline comments, no shell expansion.

# --- Database (PostgreSQL) ---
DB_HOST=
DB_PORT=5432
DB_NAME=
DB_USER=
DB_SCHEMA=public
# disable | allow | prefer | require | verify-ca | verify-full
DB_SSLMODE=prefer
# Seconds allowed to open a connection; raise it for sites on slow links.
DB_CONNECT_TIMEOUT=30
# Time allowed per statement on the server: 120, 120s, 5min, 1h.
DB_STATEMENT_TIMEOUT=120s

# --- Logs (Grafana Loki) ---
# direct: talk to Loki itself.  grafana: go through Grafana's data source proxy.
LOKI_MODE=
# direct mode: Loki base URL, optional basic-auth user, optional tenant (X-Scope-OrgID).
LOKI_URL=
LOKI_USERNAME=
LOKI_ORG_ID=
# grafana mode: Grafana base URL and the UID of its Loki data source.
GRAFANA_URL=
GRAFANA_LOKI_UID=
# Stream selector for this Environment's logs, e.g. {service_name="weighbridge.medan.prod"}
LOKI_SELECTOR=
EOF
    created+=("environments/$env.env")
  fi
  if [[ -e "$secrets" ]]; then kept+=("secrets/$env.env"); else
    cat >"$secrets" <<EOF
# Environment Secrets for "$env" (apta-investigate).
# Fill these in your own editor. Never paste them into an agent chat.
# The agent never opens this file; only the skill's scripts read it.

# Password for DB_USER.
DB_PASSWORD=
# direct mode: basic-auth password for LOKI_USERNAME.
LOKI_PASSWORD=
# direct mode: bearer token.  grafana mode: Grafana service-account token.
LOKI_TOKEN=
EOF
    chmod 600 "$secrets"
    created+=("secrets/$env.env")
  fi
done

# Claude Code guard: deny the Read/Edit tools on secrets/.
claude_note=""
if [[ -d "$root/.claude" ]]; then
  sfile="$root/.claude/settings.json"
  rules='["Read(./.apta-investigate/secrets/**)","Edit(./.apta-investigate/secrets/**)"]'
  [[ -s "$sfile" ]] || printf '{}\n' >"$sfile"
  if command -v jq >/dev/null 2>&1; then
    if tmp="$(jq --argjson r "$rules" '.permissions.deny = ((.permissions.deny // []) as $d | $d + ($r - $d))' "$sfile" 2>/dev/null)"; then
      printf '%s\n' "$tmp" >"$sfile"; chmod 644 "$sfile"; claude_note="deny rules for secrets/ are in .claude/settings.json"
    else claude_note="could not parse .claude/settings.json; add the deny rules by hand (see references/setup.md)"; fi
  elif command -v python3 >/dev/null 2>&1; then
    if python3 -I - "$sfile" "$rules" <<'PY'
import json, sys
path, rules = sys.argv[1], json.loads(sys.argv[2])
with open(path) as f:
    data = json.load(f)
deny = data.setdefault("permissions", {}).setdefault("deny", [])
for r in rules:
    if r not in deny:
        deny.append(r)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
    then chmod 644 "$sfile"; claude_note="deny rules for secrets/ are in .claude/settings.json"
    else claude_note="could not update .claude/settings.json; add the deny rules by hand (see references/setup.md)"; fi
  else
    claude_note="jq/python3 not found; add the deny rules to .claude/settings.json by hand (see references/setup.md)"
  fi
fi

echo "Folder: $dir"
(( ${#created[@]} )) && printf '  created  %s\n' "${created[@]}"
(( ${#kept[@]} ))    && printf '  kept     %s (already existed)\n' "${kept[@]}"
if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git -C "$root" check-ignore -q "$dir/secrets/x.env"; then echo "  git: the folder is ignored"; else echo "  WARNING: git does not ignore $dir; check $dir/.gitignore"; fi
fi
[[ -n "$claude_note" ]] && echo "  claude: $claude_note"
echo
echo "Next:"
echo "  1. The agent fills in the non-secret settings: environments/<env>.env"
echo "  2. You fill in passwords and tokens in your editor: $dir/secrets/<env>.env"
echo "  3. Run check.sh <env> to test the connections."
