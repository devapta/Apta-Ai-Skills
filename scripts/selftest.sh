#!/usr/bin/env bash
#
# scripts/selftest.sh — end-to-end test of install.sh in a throwaway project.
# Runs against a temp copy of the repo plus a fake extra skill (so --skill is
# testable): install for all four agents non-interactively, assert every
# expected file, exercise --skill subsets, run the same skill checks CI runs,
# then uninstall and assert a clean tree. The repo tree itself stays untouched.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALL=(--agent claude-code --agent codex --agent opencode --agent antigravity)

fail()    { echo "SELFTEST FAIL: $*" >&2; exit 1; }
exists()  { [[ -e "$1" ]] || fail "expected to exist: $1"; }
missing() { [[ ! -e "$1" ]] || fail "expected absent: $1"; }

tmp="$(mktemp -d)"
proj="$tmp/project"
mkdir -p "$proj"
trap 'rm -rf "$tmp"' EXIT

# Temp copy of the repo + a second, fake skill so per-skill selection is testable.
copy="$tmp/repo"
mkdir -p "$copy/skills/fake-skill"
cp "$REPO/install.sh" "$copy/"
cp -r "$REPO/skills/." "$copy/skills/"
cat >"$copy/skills/fake-skill/SKILL.md" <<'EOF'
---
name: fake-skill
description: Selftest fixture — never a real skill.
---

# Fake Skill
EOF
INSTALL="$copy/install.sh"
SKILLS_DIR="$copy/skills"

echo "== skill-format checks (same as CI) =="
bash "$REPO/scripts/validate-skills.sh"

echo "== unknown agent is rejected =="
if "$INSTALL" --target "$proj" --agent bogus >/dev/null 2>&1; then fail "bogus agent accepted"; fi

echo "== unknown skill is rejected =="
if "$INSTALL" --target "$proj" --skill bogus --agent claude-code >/dev/null 2>&1; then fail "bogus skill accepted"; fi

echo "== non-TTY run without --agent is rejected =="
if "$INSTALL" --target "$proj" </dev/null >/dev/null 2>&1; then fail "non-TTY run without --agent accepted"; fi

echo "== --list works =="
"$INSTALL" --list | grep -q "apta-superskill" || fail "--list did not show skills"

echo "== --skill installs only the named skill =="
"$INSTALL" --target "$proj" --skill fake-skill "${ALL[@]}" >/dev/null 2>&1
missing "$proj/.claude/skills/apta-superskill"
missing "$proj/.agents/skills/apta-superskill"
missing "$proj/.agents/rules"                  # apta-superskill's rules never land
exists  "$proj/.claude/skills/fake-skill/SKILL.md"
exists  "$proj/.agents/skills/fake-skill/SKILL.md"

echo "== install all four agents =="
"$INSTALL" --target "$proj" "${ALL[@]}" >/dev/null

for d in "$SKILLS_DIR"/*/; do
  s="$(basename "$d")"
  [[ -f "$d/SKILL.md" ]] || continue
  exists "$proj/.claude/skills/$s/SKILL.md"
  exists "$proj/.agents/skills/$s/SKILL.md"     # codex + opencode share .agents/skills/
  missing "$proj/.opencode"                     # ... so .opencode/ is not created
  missing "$proj/.claude/skills/$s/antigravity" # antigravity/ never lands in skill dirs
  while IFS= read -r rel; do
    exists "$proj/.claude/skills/$s/$rel"
    exists "$proj/.agents/skills/$s/$rel"
  done < <(cd "$d" && find . -name antigravity -prune -o -type f -print | sed 's|^\./||')
  for f in "$d/antigravity/"*.md; do
    [[ -e "$f" ]] || continue
    exists "$proj/.agents/rules/$(basename "$f")"
  done
done

echo "== idempotent re-run =="
"$INSTALL" --target "$proj" "${ALL[@]}" >/dev/null

echo "== uninstall --skill removes only the named skill =="
"$INSTALL" --target "$proj" --skill fake-skill --uninstall "${ALL[@]}" >/dev/null
missing "$proj/.claude/skills/fake-skill"
missing "$proj/.agents/skills/fake-skill"
exists  "$proj/.claude/skills/apta-superskill/SKILL.md"
exists  "$proj/.agents/skills/apta-superskill/SKILL.md"

first_skill="$(basename "$(ls -d "$SKILLS_DIR"/*/ | head -1)")"
victim="$proj/.claude/skills/$first_skill/SKILL.md"

echo "== differing file blocks install unless --force =="
echo "local edit" >>"$victim"
if "$INSTALL" --target "$proj" "${ALL[@]}" >/dev/null 2>&1; then fail "differing file did not block"; fi
"$INSTALL" --target "$proj" "${ALL[@]}" --force >/dev/null || fail "--force install failed"

echo "== uninstall refuses modified files unless --force =="
echo "local edit" >>"$victim"
if "$INSTALL" --target "$proj" "${ALL[@]}" --uninstall >/dev/null 2>&1; then fail "uninstall did not refuse modified file"; fi
exists "$victim"
"$INSTALL" --target "$proj" "${ALL[@]}" --uninstall --force >/dev/null || fail "--force uninstall failed"

echo "== tree is clean after uninstall =="
for d in .claude .agents .opencode; do missing "$proj/$d"; done

echo "== --global installs into \$HOME (fake HOME), never antigravity =="
fakehome="$tmp/home"; mkdir -p "$fakehome"
if HOME="$fakehome" "$INSTALL" --global --agent antigravity >/dev/null 2>&1; then fail "--global accepted antigravity"; fi
if HOME="$fakehome" "$INSTALL" --global --target "$proj" --agent claude-code >/dev/null 2>&1; then fail "--global + --target accepted"; fi
HOME="$fakehome" "$INSTALL" --global --agent claude-code --agent codex --skill fake-skill >/dev/null || fail "global install failed"
exists "$fakehome/.claude/skills/fake-skill/SKILL.md"
exists "$fakehome/.agents/skills/fake-skill/SKILL.md"
HOME="$fakehome" "$INSTALL" --global --agent opencode --skill fake-skill >/dev/null || fail "global opencode install failed"
exists "$fakehome/.config/opencode/skills/fake-skill/SKILL.md"
HOME="$fakehome" "$INSTALL" --global --agent claude-code --agent codex --skill fake-skill --uninstall >/dev/null || fail "global uninstall failed"
HOME="$fakehome" "$INSTALL" --global --agent opencode --skill fake-skill --uninstall >/dev/null || fail "global opencode uninstall failed"
missing "$fakehome/.claude"; missing "$fakehome/.agents"; missing "$fakehome/.config"

if command -v node >/dev/null && command -v npm >/dev/null; then
  # The npx entry point: bin/apta-skills.js must forward args, cwd and exit code.
  mkdir -p "$copy/bin"
  cp "$REPO/bin/apta-skills.js" "$copy/bin/"
  NPX_BIN="$copy/bin/apta-skills.js"

  echo "== npx wrapper: --list =="
  node "$NPX_BIN" --list | grep -q "fake-skill" || fail "wrapper --list did not show skills"

  echo "== npx wrapper: exit code is forwarded =="
  set +e; node "$NPX_BIN" --agent bogus >/dev/null 2>&1; rc=$?; set -e
  [[ $rc -eq 1 ]] || fail "wrapper exit code for bogus agent: $rc (want 1)"

  echo "== npx wrapper: installs into the caller's cwd, then uninstalls =="
  (cd "$proj" && node "$NPX_BIN" --agent claude-code --skill fake-skill >/dev/null) || fail "wrapper install failed"
  exists "$proj/.claude/skills/fake-skill/SKILL.md"
  (cd "$proj" && node "$NPX_BIN" --agent claude-code --skill fake-skill --uninstall >/dev/null) || fail "wrapper uninstall failed"
  missing "$proj/.claude"

  echo "== npm package contents =="
  packed="$(cd "$REPO" && npm pack --dry-run --json 2>/dev/null \
    | node -e 'for (const f of Object.values(JSON.parse(require("fs").readFileSync(0)))[0].files) console.log(f.path)')"
  has()    { grep -qxF "$1" <<<"$packed" || fail "npm package is missing: $1"; }
  hasnt()  { ! grep -q "$1" <<<"$packed" || fail "npm package should not contain: $1"; }
  has bin/apta-skills.js
  has install.sh
  while IFS= read -r rel; do has "$rel"; done < <(cd "$REPO" && git ls-files skills)
  hasnt '^evaluations/'
  hasnt '^scripts/'
  hasnt '^\.github/'
else
  echo "== npx wrapper + npm package: SKIPPED (node/npm not installed) =="
fi

echo "SELFTEST PASSED"
