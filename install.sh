#!/usr/bin/env bash
#
# install.sh — copy this repo's Agent Skills into a target project (project-scoped).
#
# Run from inside the target project (or pass --target DIR). Skills are COPIED,
# never symlinked, so the target team commits them and every clone gets them.
# Linux-only, bash + coreutils.

set -euo pipefail
shopt -s nullglob

BOOTSTRAP_REPO="devapta/Apta-Ai-Skills"   # used only when run standalone

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"

if [[ ! -d "$SKILLS_SRC" ]]; then
  # Standalone: no skills/ beside this script → clone the repo to a temp dir
  # (shallow) and re-exec its install.sh. Requires gh (repo is private).
  command -v gh >/dev/null || { echo "install.sh: standalone mode needs 'gh' (gh auth login) — or clone $BOOTSTRAP_REPO and run its install.sh" >&2; exit 1; }
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  gh repo clone "$BOOTSTRAP_REPO" "$tmp" -- --depth 1 --quiet 2>/dev/null || gh repo clone "$BOOTSTRAP_REPO" "$tmp" -- --depth 1
  exec bash "$tmp/install.sh" "$@"
fi

AGENTS=(claude-code codex opencode antigravity)

ACTION="install"      # install | uninstall | list
FORCE=0
TARGET=""
SELECTED=()   # agents
SKILL_SEL=()  # skills picked via --skill (empty = all)

usage() {
  cat <<'EOF'
Usage: install.sh [--agent NAME]... [--skill NAME]... [--target DIR] [--force] [--uninstall] [--list]

Copies the selected skills (default: all) into the target project's per-agent
skill directories. Default target: the current directory (run inside the project).
Copy is the only mode — commit the results to the target project.

  (no --agent)   Interactive checkbox pickers: agents, then skills
                 (↑/↓ move · space toggle · enter confirm).
  --agent NAME   Install for NAME, repeatable: claude-code codex opencode antigravity.
  --skill NAME   Install (or uninstall) only skill NAME, repeatable — see --list.
                 Default without --skill: every skill in this repo.
  --target DIR   Target project directory (default: current directory).
  --force        Overwrite (or, with --uninstall, delete) files that differ from this repo.
  --uninstall    Remove exactly the files this script would create; refuses
                 locally-modified files unless --force.
  --list         List available skills and which agents each supports.
  -h, --help     This help.

Destinations inside the target project:
  claude-code   .claude/skills/<name>/   full skill folder (no antigravity/ subdir)
  codex         .agents/skills/<name>/   full skill folder
  opencode      .agents/skills/<name>/ when codex is also selected (both read that
                dir), otherwise .opencode/skills/<name>/
  antigravity   .agents/rules/           each skill's antigravity/*.md, copied flat
EOF
  exit "${1:-0}"
}

die() { echo "install.sh: $*" >&2; exit 1; }

add_agent() {
  local a valid=0
  for a in "${AGENTS[@]}"; do if [[ "$a" == "$1" ]]; then valid=1; break; fi; done
  if [[ $valid -eq 0 ]]; then die "unknown agent '$1' — valid agents: ${AGENTS[*]}"; fi
  SELECTED+=("$1")
}

selected() { # selected NAME -> true if NAME was chosen
  local s
  for s in "${SELECTED[@]}"; do if [[ "$s" == "$1" ]]; then return 0; fi; done
  return 1
}

# --- checkbox picker --------------------------------------------------------------
# pick TITLE ITEM... → echoes each checked ITEM to stdout, one per line.
# Pure bash + ANSI: ↑/↓ move, space toggles, enter submits (empty selection
# re-asks). Renders to stderr so stdout stays machine-readable. Needs a TTY.
pick() {
  local title="$1"; shift
  local items=("$@") state=() cur=0 printed=0 key ext any=0 i mark saved
  local hint="↑/↓ move · space toggle · enter confirm"
  for i in "${!items[@]}"; do state+=(0); done
  # bash dies on SIGINT received while blocked in `read` without running any
  # trap — so switch the tty out of signal mode for the picker and treat the
  # raw Ctrl-C byte as a key. stty is coreutils; needs pick's stdin = the TTY.
  saved="$(stty -g 2>/dev/null || true)"
  if [[ -n "$saved" ]]; then stty -isig 2>/dev/null || true; fi
  pick_restore() { # unhide cursor + undo stty -isig
    printf '\e[?25h' >&2
    if [[ -n "$saved" ]]; then stty "$saved" 2>/dev/null || true; fi
  }
  printf '\e[?25l' >&2                          # hide cursor
  trap 'exit 130' INT                           # kill -INT outside read; EXIT trap restores
  trap 'pick_restore' EXIT
  while :; do
    (( printed )) && printf '\e[%dA\r' "$printed" >&2 # rewind to the title line
    printf '%s\n' "$title" >&2; printed=1
    for i in "${!items[@]}"; do
      mark='[ ]'; (( state[i] )) && mark='[x]'
      (( i == cur )) && printf '\e[7m' >&2      # inverse video on current row
      printf '%s %s\e[27m\e[K\n' "$mark" "${items[i]}" >&2
      printed=$((printed + 1))
    done
    printf '%s\e[K\n' "$hint" >&2; printed=$((printed + 1))
    IFS= read -rsn1 key || die "selection aborted"
    case "$key" in
      $'\x03') exit 130 ;;                      # Ctrl-C byte (isig is off); EXIT trap restores
      $'\e') # escape sequence: arrows are ESC [ A / ESC [ B
        ext=""
        IFS= read -rsn2 -t 0.05 ext || true
        case "$ext" in
          '[A') (( cur > 0 )) && cur=$((cur - 1)) ;;
          '[B') (( cur < ${#items[@]} - 1 )) && cur=$((cur + 1)) ;;
        esac ;;
      ' ') state[cur]=$(( 1 - state[cur] )) ;;
      '') # enter — never proceed on an empty selection
        any=0
        for i in "${!items[@]}"; do (( state[i] )) && any=1; done
        (( any )) && break
        hint="select at least one · ↑/↓ move · space toggle · enter confirm" ;;
    esac
  done
  for i in "${!items[@]}"; do (( state[i] )) && printf '%s\n' "${items[i]}"; done
  pick_restore
  trap - INT EXIT
  return 0
}

# --- options -------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)     [[ -n "${2:-}" ]] || die "--agent needs a value"; add_agent "$2"; shift 2 ;;
    --skill)     [[ -n "${2:-}" ]] || die "--skill needs a value"; SKILL_SEL+=("$2"); shift 2 ;;
    --target)    [[ -n "${2:-}" ]] || die "--target needs a value"; TARGET="$2"; shift 2 ;;
    --force)     FORCE=1; shift ;;
    --uninstall) ACTION="uninstall"; shift ;;
    --list)      ACTION="list"; shift ;;
    -h|--help)   usage 0 ;;
    *)           die "unknown option: $1 (see --help)" ;;
  esac
done

[[ -d "$SKILLS_SRC" ]] || die "no skills/ directory at $SKILLS_SRC"

# --- collect skills ------------------------------------------------------------
SKILLS=()
for d in "$SKILLS_SRC"/*/; do
  if [[ -f "${d}SKILL.md" ]]; then SKILLS+=("$(basename "$d")"); fi
done
[[ ${#SKILLS[@]} -gt 0 ]] || die "no skills found in $SKILLS_SRC (each needs a SKILL.md)"

# --- --skill filter (default: all skills) -----------------------------------------
if [[ ${#SKILL_SEL[@]} -gt 0 ]]; then
  for t in "${SKILL_SEL[@]}"; do
    found=0
    for s in "${SKILLS[@]}"; do [[ "$s" == "$t" ]] && found=1; done
    [[ $found -eq 1 ]] || die "unknown skill '$t' — available skills: ${SKILLS[*]}"
  done
  chosen=()
  for s in "${SKILLS[@]}"; do
    for t in "${SKILL_SEL[@]}"; do [[ "$s" == "$t" ]] && { chosen+=("$s"); break; }; done
  done
  SKILLS=("${chosen[@]}")
fi

if [[ "$ACTION" == "list" ]]; then
  echo "Skills in $SKILLS_SRC:"
  for skill in "${SKILLS[@]}"; do
    agents="claude-code, codex, opencode"
    rules=("$SKILLS_SRC/$skill/antigravity/"*.md)
    if [[ ${#rules[@]} -gt 0 ]]; then agents="$agents, antigravity"; fi
    printf '  %-24s %s\n' "$skill" "$agents"
  done
  exit 0
fi

TARGET="${TARGET:-$PWD}"
[[ -d "$TARGET" ]] || die "target directory not found: $TARGET"
TARGET="$(cd "$TARGET" && pwd)"

# --- agent + skill selection -----------------------------------------------------
# Prompts only when fully interactive: no --agent flag, no --skill flag, TTY stdin.
# (Any --agent/--skill flag, or non-TTY stdin, makes the run non-interactive.)
if [[ ${#SELECTED[@]} -eq 0 ]]; then
  if [[ -t 0 && ${#SKILL_SEL[@]} -eq 0 ]]; then
    mapfile -t SELECTED < <(pick "Install skills for which agents?" "${AGENTS[@]}")
    mapfile -t SKILLS < <(pick "Install which skills?" "${SKILLS[@]}")
  else
    die "--agent is required when --skill is used or stdin is not a terminal (valid: ${AGENTS[*]})"
  fi
fi

# --- per-file install/uninstall ------------------------------------------------
CONFLICTS=()

handle_file() { # $1=src (in this repo)  $2=dest (in target project)
  local src="$1" dest="$2"
  if [[ "$ACTION" == "uninstall" ]]; then
    [[ -e "$dest" || -L "$dest" ]] || return 0
    if [[ ! -L "$dest" && -f "$dest" ]] && cmp -s "$src" "$dest"; then
      rm -- "$dest"
    elif [[ $FORCE -eq 1 ]]; then
      rm -rf -- "$dest"
    else
      CONFLICTS+=("$dest")
    fi
  else
    if [[ -e "$dest" || -L "$dest" ]]; then
      if [[ ! -L "$dest" && -f "$dest" ]] && cmp -s "$src" "$dest"; then return 0; fi # identical
      if [[ $FORCE -eq 0 ]]; then CONFLICTS+=("$dest"); return 0; fi
      rm -rf -- "$dest"
    fi
    mkdir -p "${dest%/*}"
    cp -- "$src" "$dest"
  fi
}

cleanup_dirs() { # remove now-empty dirs under $1 (deepest first), then its parents up to the target
  local d="$1"
  find "$d" -depth -type d -empty -delete 2>/dev/null || true
  d="${d%/*}"
  while [[ "$d" == "$TARGET"/* ]]; do
    rmdir -- "$d" 2>/dev/null || break
    d="${d%/*}"
  done
}

# --- destination runners -------------------------------------------------------
run_skill_dir() { # $1=label  $2=dest dir relative to target
  local label="$1" rel_dir="$2" dest_root="$TARGET/$2" skill rel
  echo "[$label] → $rel_dir/"
  for skill in "${SKILLS[@]}"; do
    while IFS= read -r rel; do
      handle_file "$SKILLS_SRC/$skill/$rel" "$dest_root/$skill/$rel"
    done < <(cd "$SKILLS_SRC/$skill" && find . -name antigravity -prune -o -type f -print | sed 's|^\./||')
    if [[ "$ACTION" == "uninstall" ]]; then cleanup_dirs "$dest_root/$skill"; fi
  done
}

run_antigravity() {
  local dest_root="$TARGET/.agents/rules" skill f
  echo "[antigravity] → .agents/rules/"
  for skill in "${SKILLS[@]}"; do
    local rules=("$SKILLS_SRC/$skill/antigravity/"*.md)
    if [[ ${#rules[@]} -eq 0 ]]; then
      echo "  ! $skill: no antigravity/ rule files, skipped for this agent" >&2
      continue
    fi
    for f in "${rules[@]}"; do
      handle_file "$f" "$dest_root/$(basename "$f")"
    done
  done
  if [[ "$ACTION" == "uninstall" ]]; then cleanup_dirs "$dest_root"; fi
}

# --- main ----------------------------------------------------------------------
echo "== apta-skills: $ACTION ${#SKILLS[@]} skill(s) into $TARGET =="
if selected claude-code; then run_skill_dir "claude-code" ".claude/skills"; fi
if selected codex && selected opencode; then
  run_skill_dir "codex + opencode (shared dir)" ".agents/skills"
elif selected codex; then
  run_skill_dir "codex" ".agents/skills"
elif selected opencode; then
  run_skill_dir "opencode" ".opencode/skills"
fi
if selected antigravity; then run_antigravity; fi

if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
  verb="overwrite"
  [[ "$ACTION" == "uninstall" ]] && verb="delete" || true
  echo "Refusing to $verb ${#CONFLICTS[@]} file(s) that differ from this repo (--force):" >&2
  printf '  %s\n' "${CONFLICTS[@]}" >&2
  exit 1
fi
echo "Done."
