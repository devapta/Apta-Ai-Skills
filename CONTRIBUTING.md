# Contributing skills

A skill is a folder under `skills/<name>/` carrying the team standard in two
renditions. The folder name is the selection name — it is what the interactive
skill picker shows and what users pass to `install.sh --skill <name>`:

```
skills/
└── my-skill/
    ├── SKILL.md            # required: the agent skill (frontmatter + instructions)
    ├── references/         # optional: detail files SKILL.md points to
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

## Before you commit

```bash
scripts/validate-skills.sh   # the exact checks CI runs on every PR
scripts/selftest.sh          # end-to-end installer test in a throwaway project
```

CI (`.github/workflows/validate.yml`) asserts per skill: `SKILL.md` exists with
non-empty `name` and `description` frontmatter, every relative `.md` reference in
`SKILL.md` resolves to a file inside the skill, and every `antigravity/*.md` is
under the size cap.
