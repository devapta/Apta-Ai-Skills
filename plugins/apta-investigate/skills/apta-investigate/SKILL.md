---
name: apta-investigate
description: Investigate a reported issue in an Apta project by checking its code against an Environment's PostgreSQL database and Grafana Loki logs, read-only. Use when asked to investigate, diagnose or find the root cause of a bug, error, slowness or wrong data in a deployed Environment (dev, prod-medan...), or to set up the project's .apta-investigate folder.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/*)
---

# Apta Investigate

An **Investigation** finds the cause of a reported issue by checking the code against
what an **Environment** (a named deployment such as `dev` or `prod-medan`) shows in its
database and logs. These are the three **Evidence Sources**: the code, the database
and the logs. Everything is read-only. You report the cause and propose a fix, and you
leave code and data as they are. Applying the fix is a separate request.

This runs on the user's machine only (Claude Code, Codex CLI, Codex in the ChatGPT
desktop app): databases and Loki sit on the team's Tailscale network.

## Tools

The scripts live in `scripts/` in this skill's directory (Claude Code:
`${CLAUDE_SKILL_DIR}/scripts/`). Run them by full path from the project root. Each
has `--help`.

| Script | Does |
| --- | --- |
| `envs.sh [env]` | Lists Environments and which Evidence Sources each has. |
| `db.sh <env> "<sql>"` | One read-only statement. Returns up to 200 rows (`--limit` up to 1000, `--csv`). |
| `logs.sh <env> query '<logql>'` | Log lines, default window 1h and 500 lines (`--since`, `--from/--to`, `--limit`, `--output jsonl`). |
| `logs.sh <env> labels \| label-values <name> \| series` | Explore what the logs contain. |
| `check.sh <env>\|--all` | Tests each Evidence Source, without printing secrets. |
| `init.sh <env>...` | Creates the `.apta-investigate` folder. Setup only. |
| `cleanup.sh` | Removes leftover Docker containers. Run it once the Investigation ends. |

Exit codes: `0` ok · `1` failed (read the masked error) · `2` rejected or bad
arguments · `3` **not configured**: carry on without that Evidence Source.

`db.sh` accepts one `SELECT`, `WITH`, `TABLE`, `VALUES`, `EXPLAIN` or `SHOW`, or a psql
`\d`-family command, and runs it in a read-only transaction with a statement timeout.
In `logs.sh`, a query starting with `|` is appended to the Environment's
`LOKI_SELECTOR`, and `{{selector}}` is replaced by it. Log times print in UTC.

## Environment Secrets

Reach the database and logs only through these scripts: they read the passwords and
tokens themselves and mask them in everything they print. Read Environment Settings
(`.apta-investigate/environments/<env>.env`) freely. **Never open, read, search,
source or edit anything under `.apta-investigate/secrets/`**, and never ask for a
password or token in chat. The user types secrets into that file in their own editor.
If they paste one into chat anyway, leave it unused and ask them to put it in the file.

## Steps

1. **Find the Environment.** Run `envs.sh`. If the user named no Environment, list the
   configured ones and ask, and never default to a prod one. "All prod" means running
   the same query on each Environment whose name matches. If the user asks for setup,
   or wants a missing Environment added, follow [references/setup.md](references/setup.md),
   then come back.
2. **Pin the symptom.** Done when you know, or have recorded as unknown, each of these:
   *what* happened, *which* record, user or endpoint, *when* (a time window with a
   timezone; Indonesian sites run on WIB = UTC+7, and log times print in UTC), and
   *which* Environment.
3. **State the Evidence Sources.** Say in one line which ones this Environment lacks
   (exit `3`, or `check.sh` FAILED), for example "prod-medan has no database settings:
   checking code and logs only". Never stop because one is missing.
4. **Gather evidence.** Follow [references/investigation.md](references/investigation.md)
   for each available source: the code first (routes, handlers, services, models, and
   the log messages they emit), then the logs around the window, then the database rows
   involved.
5. **Test hypotheses.** Write each hypothesis down, look for evidence that would refute
   it, and keep only the survivors. A cause is **corroborated** when the code *and* at
   least one of the logs or the database support it. With only the code available,
   label the conclusion **Unconfirmed: code only**, and name the exact log query or SQL
   that would confirm it.
6. **Report.** Give the Investigation Report in chat and save it as a Markdown file named
   `YYYY-MM-DD-<slug>` in `.apta-investigate/reports/` (if that folder exists), using the
   template in [references/investigation.md](references/investigation.md). Then run
   `cleanup.sh`.

## Load and data limits

- Select only the columns you need. Use `count(*)`, `min()` and `max()` before
  pulling rows, and avoid `SELECT *` on tables holding personal data (users, drivers,
  customers).
- Keep log windows tight around the symptom. A window over 24h needs the user's OK
  first, then `--allow-long-window`.
- Raise `--limit` only when a narrower query cannot answer the question.
- Quote in the report only the rows and log lines that serve as evidence.
- If a database is slow to reach, the user can raise `DB_CONNECT_TIMEOUT` or
  `DB_STATEMENT_TIMEOUT` in that Environment's settings.
