#!/usr/bin/env bash
#
# scripts/validate-skills.sh — assert the skill-format rules for every skills/*/.
# Run by CI (.github/workflows/validate.yml) and by scripts/selftest.sh.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
shopt -s nullglob

# Antigravity enforces a per-rule size limit; keep every rule file well under it.
ANTIGRAVITY_MAX_BYTES=8192

dirs=(skills/*/)
[[ ${#dirs[@]} -gt 0 ]] || { echo "FAIL: no skills/*/ folders found"; exit 1; }

fail=0
for dir in "${dirs[@]}"; do
  name="$(basename "$dir")"
  skill="$dir/SKILL.md"

  # (a) SKILL.md exists with non-empty name and description frontmatter
  if [[ ! -f "$skill" ]]; then
    echo "FAIL $name: missing SKILL.md"; fail=1; continue
  fi
  fm="$(awk 'NR==1 { if ($0 != "---") exit } NR>1 { if ($0 == "---") exit; print }' "$skill")"
  fname="$(sed -n 's/^name:[[:space:]]*//p' <<<"$fm" | head -1)"
  fdesc="$(sed -n 's/^description:[[:space:]]*//p' <<<"$fm" | head -1)"
  [[ -n "${fname// /}" ]] || { echo "FAIL $name: empty or missing 'name' frontmatter"; fail=1; }
  [[ -n "${fdesc// /}" ]] || { echo "FAIL $name: empty or missing 'description' frontmatter"; fail=1; }

  # (b) every relative .md reference in SKILL.md resolves to a file inside the skill.
  # Catches markdown links `](references/foo.md)` and backtick spans `` `references/foo.md` ``.
  refs="$(
    { grep -oE '\]\([^) ]+\)' "$skill" | sed 's/^](//; s/)$//'
      grep -oE '`[^`]+`'      "$skill" | sed 's/^`//;   s/`$//'
    } | sort -u
  )"
  while IFS= read -r ref; do
    p="${ref%%#*}" # drop anchor
    case "$p" in
      ""|/*|http:*|https:*|mailto:*) continue ;;
      *.md) ;;
      *) continue ;;
    esac
    case "$p" in
      *..*) echo "FAIL $name: reference escapes the skill dir: $p"; fail=1; continue ;;
    esac
    [[ -f "$dir/$p" ]] || { echo "FAIL $name: broken reference $p"; fail=1; }
  done <<<"$refs"

  # (c) each antigravity/*.md is below the size cap
  for rule in "$dir"/antigravity/*.md; do
    size="$(wc -c <"$rule")"
    if (( size > ANTIGRAVITY_MAX_BYTES )); then
      echo "FAIL $name: antigravity/$(basename "$rule") is $size bytes (cap ${ANTIGRAVITY_MAX_BYTES})"
      fail=1
    fi
  done
done

if (( fail == 0 )); then echo "validate-skills: all OK"; fi
exit "$fail"
