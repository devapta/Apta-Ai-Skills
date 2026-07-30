# Apta-Ai-Skills

A collection of portable **Agent Skills** plus a one-command installer that drops them
into the AI agent(s) on your machine. Each skill is a cross-tool folder (`SKILL.md` +
optional references/scripts) following the open [Agent Skills](https://agentskills.io)
standard, so the **same skill file works in Claude Code, Cursor, GitHub Copilot, Codex,
Gemini CLI, and others** — only the install location differs.

## Skills

| Skill | Description |
| --- | --- |
| [`tdd`](skills/tdd/) | Test-driven development — build features / fix bugs test-first. |

## Install

Two paths, pick one. The **installer script** is agent-agnostic and works on any clone;
the **Claude Code plugin** gives you the native marketplace experience.

### Option A — Installer script (works for any agent)

```bash
git clone https://github.com/devapta/Apta-Ai-Skills.git
cd Apta-Ai-Skills
./install.sh
```

By default this **symlinks** every skill into each agent's skill directory that it detects
(links = `git pull` updates them live). Flags:

| Flag | Effect |
| --- | --- |
| `--scope project` | Install into the *current project's* per-agent skill dirs instead of your home dir. |
| `--copy` | Copy a frozen snapshot instead of linking (survives repo deletion). |
| `--agent NAME` | Restrict to one agent from the registry (e.g. `cursor`). |
| `--target DIR` | Install into an arbitrary directory (for agents not in the registry). |
| `--uninstall` | Remove what this script installed (`--force` for copies). |
| `--force` | Overwrite/remove existing entries. |

Windows: `powershell -ExecutionPolicy Bypass -File .\install.ps1` (same flags, e.g. `-Copy`, `-Scope project`).

### Option B — Native Claude Code plugin

From inside a Claude Code session:

```
/plugin marketplace add devapta/Apta-Ai-Skills
/plugin install apta-skills@apta-skills
```

(If your Claude Code version exposes the `claude plugin` shell CLI, the same two
commands run from your terminal.) Skills then appear as `apta-skills:<name>`
(e.g. `/apta-skills:tdd`). For team distribution, add this to `.claude/settings.json`:

```jsonc
{
  "extraKnownMarketplaces": {
    "apta-skills": { "source": { "source": "github", "repo": "devapta/Apta-Ai-Skills" } }
  },
  "enabledPlugins": { "apta-skills@apta-skills": true }
}
```

## Supported agents

The installer writes the portable skill folder into each agent's skill directory. Only
the **Claude Code** paths are verified; the rest are best-effort community conventions —
they activate only when the agent appears installed, and you can fix them in the registry
tables inside `install.sh` / `install.ps1`, or just use `--target`.

| Agent | User dir | Verified? |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/` | ✅ |
| Cursor | `~/.cursor/skills/` | best-effort |
| Gemini CLI | `~/.gemini/skills/` | best-effort |
| Codex | `~/.codex/skills/` | best-effort |
| GitHub Copilot | `~/.copilot/skills/` | best-effort |
| Windsurf | `~/.codeium/windsurf/skills/` | best-effort |

## Adding a skill

Drop a new folder under `skills/<name>/SKILL.md`. See [CONTRIBUTING.md](CONTRIBUTING.md)
for the portable frontmatter format and the `claude plugin validate .` check before
committing.

## License

MIT — see [LICENSE](LICENSE).
