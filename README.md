# Apta-Ai-Skills

Internal Agent-Skills toolbox for the Apta team. Skills live here as the source of
truth and are installed **project-scoped**: `install.sh` copies them into a target
project's repo (never symlinked), that team commits them, and every clone of the
project gets the same skills. Linux-only team — bash + coreutils, nothing else.

## Skills

| Skill | Description |
| --- | --- |
| [`apta-superskill`](skills/apta-superskill/) | React + TypeScript + Vite + Tailwind/shadcn frontend standard: architecture, component patterns, API layer, styling. |
| [`apta-go-backend`](skills/apta-go-backend/) | Go + Gin backend generator modeled on fleet-backend: scaffold a new project (GORM/Postgres, JWT, users/roles/user-roles, slog, Swagger, cobra, dig, OpenTelemetry), add CRUD endpoints, enable optional S3/Infisical/NATS. |
| [`apta-go-local-cloud`](skills/apta-go-local-cloud/) | Go + Gin workspace with `shared`, `local` (on-site, open API) and `cloud` (JWT, schema-scoped reads) modules, modeled on simple-weighbridge-service: scaffold it, add CRUD resources with a data-authority side, enable optional S3/Infisical/NATS. |
| [`apta-flutter-desktop`](skills/apta-flutter-desktop/) | Flutter Desktop (Linux & Windows) app standard: Screen → Provider → Repository → ApiService layering (Dio, get_it, Provider, forui), hardware behind fake/real interfaces (serial, NFC, OCR), mDNS server discovery, Windows/Linux release builds, PR review checklist. |
| [`apta-frontend-deployment-setup`](skills/apta-frontend-deployment-setup/) | Vite/React frontend deploy setup: multi-stage Dockerfile + nginx SPA image, docker compose, GitHub Actions to `registry.apta.works` and self-hosted runners (dev on push to `dev`, prod on `v*.*.*` tags), build-time `VITE_*` from Infisical, repo secrets filled from Infisical via `gh`. |

Run `./install.sh --list` for the live list and which agents each skill supports.

## Quick start

This repo is compatible with the [`skills`](https://github.com/vercel-labs/skills) CLI.
From inside the target project (needs git access to the private repo):

```bash
npx skills add devapta/Apta-Ai-Skills
```

It prompts for the skills and agents to install. Useful flags:

```bash
npx skills add devapta/Apta-Ai-Skills --list                              # list available skills
npx skills add devapta/Apta-Ai-Skills --skill apta-superskill -a claude-code
npx skills add devapta/Apta-Ai-Skills --all                               # every skill, every agent
npx skills add devapta/Apta-Ai-Skills -g -a claude-code -y                # global, non-interactive
npx skills add devapta/Apta-Ai-Skills --copy                              # copy files instead of symlinking
```

By default the CLI installs into the current project (`-g`/`--global` installs for
your user). Then **commit the created directories**. Remove skills with
`npx skills remove`. See `npx skills add --help` for all options.

## Alternative: `install.sh`

The repo's own installer is still available. It always copies (never symlinks), and
it is the only route that installs the Antigravity rules (`.agents/rules/`). From
inside the target project (no clone needed — needs Node 18+ and git access to the
private repo):

```bash
npx --allow-git=root github:devapta/Apta-Ai-Skills
```

Every `install.sh` flag below works the same way after the repo name, e.g.
`npx --allow-git=root github:devapta/Apta-Ai-Skills --agent claude-code --skill apta-superskill`.
`--allow-git=root` is required on npm 12+, which refuses git-hosted packages by
default (older npm only warns about the unknown flag). Pin a branch, tag or commit with `#ref` (`npx --allow-git=root github:devapta/Apta-Ai-Skills#main`).

Without Node (needs `gh` authenticated, repo is private):

```bash
gh api repos/devapta/Apta-Ai-Skills/contents/install.sh --jq .content \
  | base64 -d > /tmp/apta-install.sh && bash /tmp/apta-install.sh
```

Or the explicit equivalent:

```bash
git clone git@github.com:devapta/Apta-Ai-Skills.git /tmp/apta-skills   # or use your local clone
/tmp/apta-skills/install.sh
```

You get two checkbox pickers — first agents, then skills:

```
Install skills for which agents?
[x] claude-code
[ ] codex
[ ] opencode
[ ] antigravity
↑/↓ move · space toggle · enter confirm
```

Arrow keys move, space toggles, enter confirms; an empty selection just
re-asks. Non-interactive runs (scripts, CI, or any `--agent`/`--skill` flag)
never prompt. Without `--skill` a run installs every skill in the repo:

```bash
/tmp/apta-skills/install.sh --agent claude-code --agent codex
```

With one or more `--skill NAME` flags, only those skills:

```bash
/tmp/apta-skills/install.sh --agent claude-code --skill apta-superskill
```

Then **commit the created directories** to the target project.

### `install.sh` flags

| Flag | Effect |
| --- | --- |
| `--agent NAME` | Install for `claude-code`, `codex`, `opencode`, or `antigravity` (repeatable). |
| `--skill NAME` | Install — or with `--uninstall`, remove — only skill `NAME` (repeatable). Default: all skills. |
| `--target DIR` | Target project directory (default: current directory). |
| `--global` | Install into your home directory (`$HOME`) for every project instead of one project; nothing to commit. Not available for `antigravity`. Mutually exclusive with `--target`. |
| `--force` | Overwrite — or with `--uninstall`, delete — files that differ from this repo. |
| `--uninstall` | Remove exactly the files this script would create; refuses locally-modified files unless `--force`. |
| `--list` | Show available skills and which agents each supports. |

Re-running the installer refreshes in place: identical files are left alone, files
that differ block the run (their paths are listed) unless `--force`.

### Global install

A plain `./install.sh` in a terminal first asks where to install — `Project` (default) or `Global` — then the agent and skill pickers. Or pass `--global` directly: it copies the skills under `$HOME` so every project on your machine gets them
(restart the agent afterwards):

```bash
./install.sh --global --agent claude-code --agent codex      # or omit --agent for the picker
```

| Agent | Global path |
| --- | --- |
| claude-code | `~/.claude/skills/<name>/` |
| codex | `~/.agents/skills/<name>/` |
| opencode | `~/.agents/skills/<name>/` when codex is also selected, otherwise `~/.config/opencode/skills/<name>/` |

Antigravity only reads project rules (`.agents/rules/`), so it stays project-only.
`--uninstall --global` removes exactly what it installed.

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
