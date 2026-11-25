# Contributing skills

A skill is a folder carrying the team standard in two renditions. The folder name
is the selection name — it is what the interactive skill picker shows and what users
pass to `install.sh --skill <name>`. Every skill also ships as a plugin, so its real
folder lives inside the plugin and `skills/<name>` is a symlink to it (see
[Shipping a skill as a plugin](#shipping-a-skill-as-a-plugin)):

```
plugins/my-skill/skills/my-skill/
├── SKILL.md            # required: the agent skill (frontmatter + instructions)
├── references/         # optional: detail files SKILL.md points to
├── scripts/, assets/   # optional: found relative to the skill folder, never by absolute path
└── antigravity/        # optional: terse rule files for Antigravity
```

## SKILL.md format

```markdown
---
name: my-skill
description: One line — what this does and when to use it.
---

# My Skill

Instructions. Keep SKILL.md lean; push detail into `references/foo.md` files and
reference them by relative path so agents load them only when needed.
```

## The antigravity/ variant

Antigravity has no skill folders — it reads flat rule files from `.agents/rules/`.
So a skill that should reach Antigravity carries an `antigravity/` subdir with
terse `.md` rule files distilled from the main skill. Three rules:

- **Update both renditions in tandem.** A change to `SKILL.md` / `references/`
  must be mirrored (in terse form) in `antigravity/`, and vice versa — they are
  one standard, not two.
- **Rule filenames must be globally unique across all skills.** They are copied
  flat into a single `.agents/rules/` directory, so two `antigravity/style.md`
  files would silently collide. Prefix with the skill name (`my-skill-style.md`).
- **Keep each rule file small.** CI enforces a cap (8192 bytes per file) because
  Antigravity limits rule file size.

## Shipping a skill as a plugin

The repo is a plugin marketplace for Claude Code and Codex: `.claude-plugin/marketplace.json`
lists one plugin per skill, and Codex reads the same file. Each skill keeps its real files
inside its plugin, and `skills/<name>` is a symlink to them:

```
plugins/my-skill/
├── .claude-plugin/plugin.json      # name, description (Codex reads this one too)
├── hooks/hooks.json                # optional Claude Code hooks
└── skills/my-skill/                # the real skill: SKILL.md, references/, scripts/, antigravity/
skills/my-skill -> ../plugins/my-skill/skills/my-skill
```

```bash
ln -s ../plugins/my-skill/skills/my-skill skills/my-skill
```

The symlink points that way because Codex's plugin install skips symlinks, while
`install.sh`, `npx skills` and `validate-skills.sh` all follow the `skills/` symlink.
An installed plugin is copied to a cache directory, so a skill reaches its own `scripts/`
and `assets/` relative to its folder and nothing outside it. Add the plugin's entry to
`.claude-plugin/marketplace.json`, then test an install from a local copy:

```bash
claude plugin marketplace add ./ && claude plugin install my-skill@apta-ai-skills
codex plugin marketplace add "$PWD" && codex plugin add my-skill@apta-ai-skills
```

Use a throwaway `CLAUDE_CONFIG_DIR` / `CODEX_HOME` to keep your own setup untouched.

## Before you commit

```bash
scripts/validate-skills.sh   # the exact checks CI runs on every PR
scripts/selftest.sh          # end-to-end installer test in a throwaway project
```

CI (`.github/workflows/validate.yml`) asserts per skill: `SKILL.md` exists with
non-empty `name` and `description` frontmatter, every relative `.md` reference in
`SKILL.md` resolves to a file inside the skill, and every `antigravity/*.md` is
under the size cap.

## The npx package

`npx --allow-git=root github:devapta/Apta-Ai-Skills` installs this repo as an npm package and runs
`bin/apta-skills.js`, a thin wrapper around `install.sh`. Only paths listed in
`package.json` `"files"` ship (`bin/`, `install.sh`, `skills/`); anything under
`skills/` is included automatically. `scripts/selftest.sh` asserts the package
contents, so a new top-level file the installer needs must be added there too.
