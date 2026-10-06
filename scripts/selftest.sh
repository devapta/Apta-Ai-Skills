#!/usr/bin/env bash
#
# scripts/selftest.sh — end-to-end test of install.sh in a throwaway project:
# install for all four agents non-interactively, assert every expected file,
# run the same skill checks CI runs, then uninstall and assert a clean tree.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$REPO/install.sh"
ALL=(--agent claude-code --agent codex --agent opencode --agent antigravity)

fail()    { echo "SELFTEST FAIL: $*" >&2; exit 1; }
exists()  { [[ -e "$1" ]] || fail "expected to exist: $1"; }
missing() { [[ ! -e "$1" ]] || fail "expected absent: $1"; }

tmp="$(mktemp -d)"
proj="$tmp/project"
mkdir -p "$proj"
trap 'rm -rf "$tmp"' EXIT

echo "== skill-format checks (same as CI) =="
bash "$REPO/scripts/validate-skills.sh"

echo "== unknown agent is rejected =="
if "$INSTALL" --target "$proj" --agent bogus >/dev/null 2>&1; then fail "bogus agent accepted"; fi

echo "== --list works =="
"$INSTALL" --list | grep -q "apta-superskill" || fail "--list did not show skills"

echo "== install all four agents =="
"$INSTALL" --target "$proj" "${ALL[@]}" >/dev/null

for d in "$REPO"/skills/*/; do
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

first_skill="$(basename "$(ls -d "$REPO"/skills/*/ | head -1)")"
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

echo "SELFTEST PASSED"
