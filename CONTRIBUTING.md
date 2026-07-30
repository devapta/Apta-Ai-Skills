# Contributing skills

A skill is a folder under `skills/<name>/` whose entrypoint is `SKILL.md`. It follows
the open [Agent Skills](https://agentskills.io) standard, so author it to be **portable**
first, Claude-enhanced second.

## Directory layout

```
skills/
└── my-skill/
    ├── SKILL.md          # required: frontmatter + instructions
    ├── reference.md      # optional: detail Claude loads on demand
    └── scripts/          # optional: bundled scripts
```

## SKILL.md format

```markdown
---
name: my-skill
description: One line — what this does and when to use it. (Only required-ish field.)
---

# My Skill

Instructions for the agent. Keep this file under ~500 lines; push detail into sibling
files and link to them so they load only when needed.
```

## Portability rules

Author to the **portable base** (just `name` + `description` + markdown) so the skill
loads in Cursor, Copilot, Codex, Gemini CLI, etc. Claude-specific frontmatter is allowed
(`allowed-tools`, `when_to_use`, `argument-hint`, …) — other tools ignore unknown fields.
To stay cross-tool, avoid *relying* on Claude-only features in the body:

| Portable ✅ | Claude-only (other tools ignore / can't run) |
| --- | --- |
| Plain markdown instructions | `!`cmd`` dynamic-context blocks |
| Links to sibling `reference.md` | `${CLAUDE_SKILL_DIR}` substitution |
| `name`, `description` | `context: fork`, `model`, `effort` |

## Before you commit

```bash
# If your Claude Code version has the plugin CLI (validates manifests + frontmatter):
claude plugin validate .

# Otherwise, sanity-check the JSON and each SKILL.md's frontmatter:
python3 -m json.tool .claude-plugin/plugin.json >/dev/null
python3 -m json.tool .claude-plugin/marketplace.json >/dev/null
```

Fix anything reported, then commit. Installed skills update automatically for anyone
using the symlinked `install.sh` path; plugin users get the new version on the next
`/plugin` update.
