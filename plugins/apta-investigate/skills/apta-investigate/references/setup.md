# Setting up Environments

Setup is done once per project, and again whenever an Environment is added. Run every
script from the project root. Done when `check.sh` reports each configured Evidence
Source as `ok`, or the user has decided to leave it unconfigured.

## 1. Create the folder

```bash
<skill-dir>/scripts/init.sh dev prod-medan prod-riau
```

Ask the user for the Environment names: lowercase, one per deployment, e.g.
`prod-medan`, `prod-cloud`. Each Environment has at most one database, so a cloud
service and an on-site service are separate Environments. Re-running `init.sh` with
new names adds those Environments and leaves existing files alone. It creates the
following at the project root (the git top level):

- `.apta-investigate/.gitignore`: contains `*`, so git ignores the whole folder.
  The project's own `.gitignore` needs no change.
- `environments/<env>.env`: Environment Settings, which you fill in.
- `secrets/<env>.env`: Environment Secrets, which the user fills in. Mode 600.
- `reports/`: saved Investigation Reports.
- When the project has a `.claude/` folder, deny rules in `.claude/settings.json`, so
  Claude Code's Read and Edit tools refuse `secrets/`. Mention this change to the user,
  since that file is usually committed.

## 2. Fill in Environment Settings

Edit `environments/<env>.env`. The format is `KEY=value`, one per line. No inline
comments, no quotes needed, no shell expansion. Fill in from the codebase what you can
and ask the user for the rest. Leave the database part or the Loki part empty when the
Environment has none.

| Key | Where to find it |
| --- | --- |
| `DB_HOST` | Ask the user. Usually a Tailscale name like `medan-db` or `<host>.<tailnet>.ts.net`. |
| `DB_PORT`, `DB_NAME`, `DB_SCHEMA` | The project's `example.env` / `.env` (`DB_PORT`, `DB_NAME`, `DB_SCHEMA`) or its docker compose files. Confirm the deployed values with the user. |
| `DB_USER` | Ideally a read-only role (section 4). Ask the user. |
| `DB_SSLMODE` | `prefer` by default. `disable` for plain Tailscale hosts that refuse TLS. |
| `DB_CONNECT_TIMEOUT`, `DB_STATEMENT_TIMEOUT` | Defaults 30 (seconds) and `120s`. Raise them for sites on slow links. |
| `LOKI_MODE` | `direct` if the user can reach Loki's own URL, `grafana` if only Grafana is reachable. |
| `LOKI_URL`, `LOKI_USERNAME`, `LOKI_ORG_ID` | Direct mode: Loki base URL (no `/loki/api/...` path), optional basic-auth user, optional tenant. |
| `GRAFANA_URL`, `GRAFANA_LOKI_UID` | Grafana mode: Grafana base URL, and the Loki data source UID (Grafana → Connections → Data sources → Loki: the last part of the page URL). |
| `LOKI_SELECTOR` | The stream selector for this Environment's logs (section 3). |

## 3. Find the log selector

Apta Go services send logs over OpenTelemetry with
`service.name = <app>.<SERVER_ID>.<SERVER_ENV>`. Search the code for `OTLPServiceName`
in `internal/configs/env.go` to get `<app>`. Loki exposes it as the `service_name`
label. With the Loki part filled in, list the real values:

```bash
<skill-dir>/scripts/logs.sh <env> label-values service_name --since 24h
```

Propose the matching value to the user, e.g. `{service_name="weighbridge.medan.prod"}`,
or a regex for several, e.g. `{service_name=~"weighbridge\\..*\\.prod"}`. Put it in
`LOKI_SELECTOR` once the user confirms.

## 4. The user fills in Environment Secrets

Tell the user which keys to fill in `.apta-investigate/secrets/<env>.env`, in their
own editor:

- `DB_PASSWORD`, for `DB_USER`.
- `LOKI_PASSWORD`, for direct mode with basic auth.
- `LOKI_TOKEN`: a bearer token in direct mode, or a Grafana service-account token in
  grafana mode (Grafana → Administration → Service accounts → add a `Viewer` account →
  add token).

Recommend a dedicated read-only database role. A DBA runs this once per database:

```sql
CREATE ROLE investigator LOGIN PASSWORD '...';
GRANT pg_read_all_data TO investigator;   -- PostgreSQL 14+
-- before 14: GRANT CONNECT, USAGE, and SELECT ON ALL TABLES IN SCHEMA ... TO investigator;
```

Sessions are forced read-only whatever the role. The role is the second layer.

## 5. Check

```bash
<skill-dir>/scripts/check.sh <env>        # or --all
```

| Result | Meaning and next move |
| --- | --- |
| `ok` | Ready. |
| `not configured` | That part of the settings is empty. Fine if intended. |
| `FAILED` + `password authentication failed` | Wrong `DB_USER` or `DB_PASSWORD`. Ask the user to fix the secrets file. |
| `FAILED` + timeout / could not connect | Tailscale down, wrong host or port, or a slow link (raise `DB_CONNECT_TIMEOUT`). |
| `FAILED` + `401` / `403` from Loki or Grafana | Wrong or expired `LOKI_TOKEN` / `LOKI_PASSWORD`, or a missing tenant (`LOKI_ORG_ID`). |
| `WARNING ... can write` / `superuser` | Works, but recommend the read-only role (section 4). |
| `WARNING LOKI_SELECTOR matched no log streams` | Re-check the selector with `label-values service_name`. |

## Where the tools run

`psql` and `logcli` are used when installed. Otherwise each call runs in a throwaway
Docker container (`postgres:17-alpine`, `grafana/logcli`) with `--rm --network host`.
If neither the tool nor Docker exists, the script says how to install it.

**Codex**: its sandbox blocks network access by default, so `db.sh` and `logs.sh` fail
inside it, and the scripts print a hint when that happens. Leave the user's config to
them. Tell them they can either approve the command to run outside the sandbox, or set
this in `~/.codex/config.toml`:

```toml
[sandbox_workspace_write]
network_access = true
```

## Claude Code deny rules by hand

When `init.sh` could not edit `.claude/settings.json`, give the user this to merge in:

```json
{ "permissions": { "deny": [
  "Read(./.apta-investigate/secrets/**)",
  "Edit(./.apta-investigate/secrets/**)"
] } }
```

The Claude Code plugin install also ships a hook that blocks these paths.
