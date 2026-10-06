# Apta-Ai-Skills

Internal Agent-Skills toolbox for the Apta team. Skills live here as the source of
truth and are installed **project-scoped**: `install.sh` copies them into a target
project's repo (never symlinked), that team commits them, and every clone of the
project gets the same skills. Linux-only team — bash + coreutils, nothing else.

## Skills

| Skill | Description |
| --- | --- |
| [`apta-superskill`](skills/apta-superskill/) | React + TypeScript + Vite + Tailwind/shadcn frontend standard: architecture, component patterns, API layer, styling. |

Run `./install.sh --list` for the live list and which agents each skill supports.

## Quick start

From inside the target project (no clone needed — needs `gh` authenticated, repo is private):

```bash
gh api repos/devapta/Apta-Ai-Skills/contents/install.sh --jq .content \
  | base64 -d > /tmp/apta-install.sh && bash /tmp/apta-install.sh
```

Or the explicit equivalent:

```bash
git clone git@github.com:devapta/Apta-Ai-Skills.git /tmp/apta-skills   # or use your local clone
/tmp/apta-skills/install.sh
```

You get a numbered prompt:

```
Install skills for which agents? (one or more numbers, e.g. 1 3 or 1,3)
  1) claude-code
  2) codex
  3) opencode
  4) antigravity
>
```

Non-interactive (scripts, CI):

```bash
/tmp/apta-skills/install.sh --agent claude-code --agent codex
```

Then **commit the created directories** to the target project.

### Flags

| Flag | Effect |
| --- | --- |
| `--agent NAME` | Install for `claude-code`, `codex`, `opencode`, or `antigravity` (repeatable). |
| `--target DIR` | Target project directory (default: current directory). |
| `--force` | Overwrite — or with `--uninstall`, delete — files that differ from this repo. |
| `--uninstall` | Remove exactly the files this script would create; refuses locally-modified files unless `--force`. |
| `--list` | Show available skills and which agents each supports. |

Re-running the installer refreshes in place: identical files are left alone, files
that differ block the run (their paths are listed) unless `--force`.

## Agents & project paths

| Agent | Path inside target project | What lands there |
| --- | --- | --- |
| Claude Code | `.claude/skills/<name>/` | full skill folder |
| Codex | `.agents/skills/<name>/` | full skill folder |
| OpenCode | `.agents/skills/<name>/` when Codex is also selected, else `.opencode/skills/<name>/` | full skill folder |
| Antigravity | `.agents/rules/` | each skill's `antigravity/*.md`, copied flat |

Codex and OpenCode both officially read `.agents/skills/`, so selecting both writes
that directory once. "Full skill folder" means `SKILL.md` plus `references/` /
`scripts/` if present — never the `antigravity/` subdir, which only Antigravity
consumes (it has flat rules, not skill folders).

## Adding a skill

See [CONTRIBUTING.md](CONTRIBUTING.md) for the format: `SKILL.md` + `references/`
plus an optional `antigravity/` terse variant, both maintained in tandem. Every PR
is validated by CI (`.github/workflows/validate.yml`); run `scripts/selftest.sh`
locally to test the installer end-to-end.

## License

MIT — see [LICENSE](LICENSE).
