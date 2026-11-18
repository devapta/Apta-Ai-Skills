# Gathering evidence

One section per Evidence Source, in the order to use them, then the report template.
`<s>` below stands for this skill's `scripts/` directory.

## Code

Done when you can name the route, the handler → service → repository chain it runs,
the tables it touches, and the log messages each step emits.

- Apta Go services (the `apta-go-backend` / `apta-go-local-cloud` layout; local-cloud
  has the same tree under `local/` and `cloud/`):
  - routes live in `internal/v1/routes`,
  - handlers in `internal/v1/handlers`, which call services, which call repositories,
  - GORM entities in `internal/entities` name the tables.

  Search by endpoint path, error text or entity name.
- Note every `slog` call on the path, with its message and attribute names: those are
  what you filter logs on. The framework already logs:
  - `"request"` for every HTTP request, with `method`, `path`, `query`, `status`,
    `latency`, `client_ip`, `server_id`,
  - `"request error"`, with `error`,
  - `"gorm query failed"`, with `query` and `error`,
  - `"gorm slow query"`, with `query`, `elapsed` and `threshold`.
- Check `git log` on the files involved: a recent change near the symptom's start time
  is a strong lead.
- Local-cloud projects: decide which side owns the data (the local site or the cloud),
  then which Environment holds it. Sync problems usually need both Environments.

## Logs

Done when you have either found the log lines around the symptom or shown that the
selector and window return lines but none of them match.

1. **Inspect before filtering.** Take one sample with `--output jsonl --limit 5` to see
   which fields exist. Over OTLP, slog attributes usually arrive as structured metadata
   (`status`, `path`, `trace_id`, `severity_text`, `detected_level`...), and the line
   itself is the message (`request`, `gorm query failed`).
2. **Narrow down** with the base selector, appending filters:

```bash
<s>/logs.sh prod-medan query '|= "gorm query failed"' --since 2h
<s>/logs.sh prod-medan query '| detected_level="error"' --from 2026-11-18T02:00:00Z --to 2026-11-18T03:00:00Z
<s>/logs.sh prod-medan query '|= "request" | path="/api/v1/weighings" | status >= 500' --since 6h
<s>/logs.sh prod-medan query '| trace_id="4bf92f3577b34da6a3ce929d0e0e4736"' --since 6h
<s>/logs.sh prod-medan query '|~ "(?i)weighing.?42"' --since 24h
```

3. **Count before reading** when lines are many. Find when an error started:

```bash
<s>/logs.sh prod-medan query 'sum by (detected_level) (count_over_time({{selector}} [10m]))' --since 6h --step 10m
```

4. **Follow a trace.** A `trace_id` on an error line leads to every line of that
   request, including its SQL.

Times print in UTC. Convert the user's local time (WIB = UTC+7) into `--from`/`--to`.

## Database

Done when the rows involved have been looked at (counts, the specific records, their
timestamps) or you have shown they don't exist.

```bash
<s>/db.sh prod-medan '\dt'                       # tables
<s>/db.sh prod-medan '\d weighings'              # columns, indexes, constraints
<s>/db.sh prod-medan "SELECT count(*), min(created_at), max(created_at) FROM weighings WHERE synced = false"
<s>/db.sh prod-medan "SELECT id, status, created_at, updated_at FROM weighings WHERE id = 42"
<s>/db.sh prod-medan "EXPLAIN SELECT ... "      # a slow query's plan, without running it
```

- Start with counts and ranges, then fetch the few rows that matter, selecting only
  the columns you need.
- `created_at`/`updated_at`/`deleted_at` (GORM soft delete) often explain "missing"
  rows: check `deleted_at IS NOT NULL` before concluding a row was never written.
- `EXPLAIN ANALYZE` really runs the query. Use it only on queries that are cheap, and
  never on prod tables that are both big and hot.
- A query rejected with exit `2` was not a single read statement. Rewrite it as one
  `SELECT`.

## Investigation Report template

```markdown
# <one-line symptom>

- Environment: <env> · Window: <from>–<to> UTC · Date: <YYYY-MM-DD>
- Evidence Sources: code ✔ · database ✔/✘ (<why>) · logs ✔/✘ (<why>)

## Symptom
<what was reported, by whom, exact record/endpoint>

## Evidence
- Code: <file:line> — <what it does that matters>
- Logs: <query> → <the 1–3 lines that matter, timestamps in UTC>
- Database: <query> → <the few rows/values that matter>

## Hypotheses ruled out
- <hypothesis> — <the evidence that refutes it>

## Root cause
<cause> — **Corroborated** (code + logs/database) | **Unconfirmed: code only**
(confirm with: <exact query>)

## Proposed fix
<change, file by file; not applied>
```
