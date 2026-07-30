#!/usr/bin/env bash
#
# install.sh — install the portable Agent Skills in ./skills into the AI agent(s)
# installed on this machine.
#
# Skills follow the open Agent Skills standard (https://agentskills.io), so the
# SKILL.md content is identical for every tool — only the *destination directory*
# differs. This script simply places each skills/<name>/ folder into each detected
# agent's skill directory (symlink by default so `git pull` updates them live).

set -uo pipefail
shopt -s nullglob

# --- resolve repo root (this script lives at the repo root) ------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
SKILLS_SRC="$REPO_ROOT/skills"

# --- options -----------------------------------------------------------------
SCOPE="user"          # user | project
MODE="link"           # link | copy
ACTION="install"      # install | uninstall
FORCE=0
TARGET=""
ONLY_AGENT=""
PROJECT_DIR="$(pwd)"

usage() {
  cat <<'EOF'
Usage: install.sh [options]

  (no args)         Link skills into each detected agent's user skill dir.
  --scope project   Install into the current project's per-agent skill dirs instead.
  --copy            Copy instead of link (frozen snapshot; survives repo deletion).
  --agent NAME      Restrict to one agent from the registry (e.g. cursor).
  --target DIR      Install into an arbitrary directory (skips agent detection).
  --uninstall       Remove the skills this script installed (use --force for copies).
  --force           Overwrite/removed existing entries without prompting.
  -h, --help        Show this help.

Verified paths: claude-code. Other agents (cursor, gemini-cli, codex, copilot,
windsurf) are best-effort and only activate when the agent appears installed;
fix their directories in the agent_* functions or use --target.
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)      SCOPE="$2"; shift 2 ;;
    --copy)       MODE="copy"; shift ;;
    --uninstall)  ACTION="uninstall"; shift ;;
    --force)      FORCE=1; shift ;;
    --target)     TARGET="$2"; shift 2 ;;
    --agent)      ONLY_AGENT="$2"; shift 2 ;;
    -h|--help)    usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

[[ "$SCOPE" == "user" || "$SCOPE" == "project" ]] || { echo "Invalid --scope: $SCOPE (use user|project)" >&2; exit 1; }
[[ -d "$SKILLS_SRC" ]] || { echo "No skills/ directory found at $SKILLS_SRC" >&2; exit 1; }

# --- collect skills (each subfolder with a SKILL.md) -------------------------
SKILLS=()
for d in "$SKILLS_SRC"/*/; do
  [[ -f "${d}SKILL.md" ]] && SKILLS+=("$(basename "$d")")
done
[[ ${#SKILLS[@]} -gt 0 ]] || { echo "No skills found in $SKILLS_SRC (each needs a SKILL.md)" >&2; exit 1; }

# --- agent registry ----------------------------------------------------------
# Edit these three functions to add/fix an agent. {HOME}/{PROJECT} are substituted.
AGENTS=(claude-code cursor gemini-cli codex copilot windsurf)

agent_user_dir() { case "$1" in
  claude-code) echo "{HOME}/.claude/skills" ;;
  cursor)      echo "{HOME}/.cursor/skills" ;;
  gemini-cli)  echo "{HOME}/.gemini/skills" ;;
  codex)       echo "{HOME}/.codex/skills" ;;
  copilot)     echo "{HOME}/.copilot/skills" ;;
  windsurf)    echo "{HOME}/.codeium/windsurf/skills" ;;
  *) return 1 ;; esac; }

agent_project_dir() { case "$1" in
  claude-code) echo "{PROJECT}/.claude/skills" ;;
  cursor)      echo "{PROJECT}/.cursor/skills" ;;
  gemini-cli)  echo "{PROJECT}/.gemini/skills" ;;
  codex)       echo "{PROJECT}/.codex/skills" ;;
  copilot)     echo "{PROJECT}/.github/copilot/skills" ;;
  windsurf)    echo "{PROJECT}/.codeium/windsurf/skills" ;;
  *) return 1 ;; esac; }

# Config dir whose presence implies the agent is installed ("" = always assume).
agent_detect() { case "$1" in
  claude-code) echo "{HOME}/.claude" ;;
  cursor)      echo "{HOME}/.cursor" ;;
  gemini-cli)  echo "{HOME}/.gemini" ;;
  codex)       echo "{HOME}/.codex" ;;
  copilot)     echo "" ;;
  windsurf)    echo "{HOME}/.codeium" ;;
  *) return 1 ;; esac; }

sub() { local s="$1"; s="${s//\{HOME\}/$HOME}"; s="${s//\{PROJECT\}/$PROJECT_DIR}"; printf '%s' "$s"; }

dest_dir_for() {
  if [[ "$SCOPE" == "user" ]]; then sub "$(agent_user_dir "$1")"
  else sub "$(agent_project_dir "$1")"; fi
}

# --- per-skill actions -------------------------------------------------------
install_skill() {
  local agent="$1" skill="$2" dest_dir="$3"
  local src="$SKILLS_SRC/$skill" dest="$dest_dir/$skill"
  mkdir -p "$dest_dir"
  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ "$MODE" == "link" && -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
      echo "  = $agent:$skill (already linked)"; return
    fi
    if [[ $FORCE -eq 1 ]]; then rm -rf "$dest"
    else echo "  ! $agent:$skill exists at $dest (--force to overwrite)"; return; fi
  fi
  if [[ "$MODE" == "link" ]]; then
    if ln -s "$src" "$dest" 2>/dev/null; then echo "  + $agent:$skill (linked)"
    else cp -r "$src" "$dest" && echo "  + $agent:$skill (copied — symlink unsupported)"; fi
  else
    cp -r "$src" "$dest" && echo "  + $agent:$skill (copied)"
  fi
}

uninstall_skill() {
  local agent="$1" skill="$2" dest_dir="$3"
  local src="$SKILLS_SRC/$skill" dest="$dest_dir/$skill"
  if [[ -L "$dest" ]]; then
    # Only remove symlinks that point into THIS repo — never an unrelated link.
    if [[ "$(readlink "$dest")" == "$src" ]]; then
      rm -f "$dest" && echo "  - $agent:$skill (removed link)"
    else
      echo "  . $agent:$skill (symlink not ours, left untouched)"
    fi
  elif [[ -d "$dest" ]]; then
    if [[ $FORCE -eq 1 ]]; then rm -rf "$dest" && echo "  - $agent:$skill (removed copy)"
    else echo "  ! $agent:$skill is a copy at $dest (--force to remove)"; fi
  else
    echo "  . $agent:$skill (not present)"
  fi
}

# --- main --------------------------------------------------------------------
main() {
  local -a labels=() dirs=()
  if [[ -n "$TARGET" ]]; then
    labels+=("target"); dirs+=("$TARGET")
  else
    local -a active=()
    for a in "${AGENTS[@]}"; do
      [[ -n "$ONLY_AGENT" && "$a" != "$ONLY_AGENT" ]] && continue
      if [[ "$ACTION" == "uninstall" ]]; then
        active+=("$a")                       # clean up everywhere we might have written
      else
        local marker; marker="$(sub "$(agent_detect "$a")")"
        [[ -z "$marker" || -e "$marker" ]] && active+=("$a")   # best-effort: only if installed
      fi
    done
    if [[ ${#active[@]} -eq 0 ]]; then
      echo "No agents from the registry appear to be installed." >&2
      echo "Use --target DIR to install into a specific directory." >&2
      exit 1
    fi
    for a in "${active[@]}"; do labels+=("$a"); dirs+=("$(dest_dir_for "$a")"); done
  fi

  echo "== apta-skills: $ACTION ${#SKILLS[@]} skill(s) → ${#labels[@]} destination(s) [$MODE, scope=$SCOPE] =="
  local i
  for i in "${!labels[@]}"; do
    echo "[${labels[$i]}] → ${dirs[$i]}"
    for skill in "${SKILLS[@]}"; do
      if [[ "$ACTION" == "uninstall" ]]; then uninstall_skill "${labels[$i]}" "$skill" "${dirs[$i]}"
      else install_skill "${labels[$i]}" "$skill" "${dirs[$i]}"; fi
    done
  done

  if [[ "$ACTION" == "install" ]]; then
    echo
    echo "Done. Tip: for a native Claude Code experience instead, run in a session:"
    echo "  /plugin marketplace add <owner>/Apta-Ai-Skills  then  /plugin install apta-skills@apta-skills"
  fi
}
main
