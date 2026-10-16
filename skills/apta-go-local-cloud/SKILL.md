---
name: apta-go-local-cloud
description: Scaffold an Apta Go + Gin backend split into shared, local (on-site, open API) and cloud (JWT auth, schema-scoped reads) modules joined by go.work, modeled on simple-weighbridge-service, and add CRUD endpoints that respect which side owns the data. Use whenever the user wants a new Go backend with a local and a cloud service, edge/site plus head-office split, a go.work workspace with shared/local/cloud, per-site data replicated to a cloud database, or wants to add a resource/table/entity/CRUD endpoint to such a project, or enable its optional S3, Infisical or NATS modules, even if they never say "scaffold".
---

# Apta Go local + cloud backend

Generates a three-module Go workspace — `shared/`, `local/`, `cloud/` — modeled on
`simple-weighbridge-service`: each site runs a **local** service on its own PostgreSQL; one **cloud**
service gives head office a combined view; every table has one **authority** side that may write, the
other side only reads a replicated copy. Both services keep the standard stack (Gin, GORM/Postgres, slog,
Swagger, cobra, uber/dig, OpenTelemetry). Cloud adds JWT auth with users / roles / user-roles; local has
no auth and advertises itself over mDNS.

Everything is produced by `scripts/scaffold.py` from templates in `assets/`, so output is deterministic
and the module path is rewritten in one pass. Run the script instead of hand-copying files — copies drift
from the standard and leave stale module paths. Needs `python3` (stdlib only); run it as
`python3 <skill-dir>/scripts/scaffold.py <command> ...` (`--help` on any command lists all flags).

For a single-service backend (no local/cloud split) use the `apta-go-backend` skill instead.

## 1. New project

1. Get the base Go **module path** (e.g. `github.com/devapta/orders`); ask if not given. The modules become
   `<module>/shared`, `<module>/local`, `<module>/cloud`. Optional: `--name` (kebab-case, drives image and
   container names), `--title`, `--db-name` (cloud DB gets `_cloud`), `--local-port` (7008), `--cloud-port`
   (7009), `--short` (mDNS label), `--no-mdns` (omit the advertisement), `--dir` (default `./<name>`; `--dir .`
   for the current empty repo).
2. Run:
   ```bash
   python3 <skill-dir>/scripts/scaffold.py init --module <module> [--name ...] [--dir ...]
   ```
   It renders ~100 files, fails loudly if a placeholder or reference-project name survives, writes stub
   `docs/` packages, creates `local/.env` and `cloud/.env` (cloud with a random `JWT_SECRET`), then runs
   `go mod tidy` in each module and `swag init` in each service when those tools exist.
3. The skeleton has **no business resources yet** — only cloud's users / roles / user-roles. Ask what
   tables the system needs and add them with `crud` (next section).
4. Tell the user what to run next (they run it): review both `.env` files, then `make swag`,
   `make migrate`, `make go` inside `local/` and `cloud/`. Do not run `serve` or `migrate` yourself, and
   respect the project's own AGENTS.md (the generated one forbids build/run commands; if in force, skip
   `go build` and leave verification to the user).

## 2. Add a CRUD resource

First settle the **authority**: where is this data created and edited? That decides everything else, so
ask the user when it is not obvious (master data entered at head office → `cloud`; records produced
on-site → `local`). From inside the project:

```bash
python3 <skill-dir>/scripts/scaffold.py crud --name Driver --authority cloud \
  --field nickname:string:notnull --field licenseNo:string:unique
```

- `--field name:type[:unique][:notnull]`, repeatable; types `string int int64 uint float64 bool time date`.
  `notnull` also makes the field `binding:"required"` on the request model. Foreign keys are plain `uint`
  fields (`driverId:uint`). No `--field` gives a `Name` string. `--plural` fixes a wrong plural.
- It creates the entity once in `shared/entities` and the model, repository, service, handler and route in
  **both** services. The authority side gets full CRUD; the other side gets `GET` only. On cloud, reads
  accept `?scope=<site>` and run through the schema middleware.
- It wires everything into each service's `di.go`, `routes/router.go` and `configs/postgres.go`, adds
  permissions to `shared/enums/permissions.go`, adds the table to the README authority table, and for
  cloud-authority tables registers the replication bookkeeping columns on local. It runs `go mod tidy`
  afterwards because the first resource pulls in dependencies the empty skeleton did not use.
- It refuses to overwrite existing files.

Then read `references/crud-endpoint.md` for what a generator cannot know: joins in `pageQuery`, relations
across the replication boundary, custom logic, extra routes, permissions. Remind the user that the
replication itself (PeerDB) is set up outside this repository and must run authority → other side for the
new table, and to run `make swag` / `make migrate` in both services.

If the project has no `// scaffold:` markers (older or hand-edited), make the same edits by hand following
`references/crud-endpoint.md`.

## 3. Enable S3 / Infisical / NATS

```bash
python3 <skill-dir>/scripts/scaffold.py enable s3 infisical nats [--side local|cloud|both]
```

Ships fully commented on both services. This uncomments the module's files (and the shared S3 helpers),
DI providers, env fields and example env vars, adds imports and runs `go mod tidy`. Afterwards the user
fills in the new env vars. Details in `references/optional-modules.md`.

## Rules to keep when editing the generated code

Read `references/architecture.md` before changing structure. In short:

- `shared/` never imports `local/` or `cloud/`, and takes configuration as parameters (see its jwt/cookie
  helpers) instead of reading service `configs`.
- Entities live in `shared`; the other layers are per-service. Register constructors in the service's
  `di.go`, entities in its `postgres.go`. All DB access stays in repositories; handlers pass
  `c.Request.Context()`.
- Write endpoints only on the authority side. Never edit replicated tables on the other side — the next sync
  overwrites the change.
- Cloud writes always go to the main schema; `scope` is read-only (`GET`) and validated against the site list.
- Every handler carries swaggo annotations; never edit generated `docs/` files. Look up dependency APIs
  with Context7 before writing library-specific code.

## Differences from simple-weighbridge-service (say so if the user compares)

- The domain tables (drivers, identifiers, item types, weighing inputs, transactions) are not included.
- `local` carries no user / role / auth code at all (the reference kept it but unused).
- The non-authority side is read-only for **every** table. The reference left full CRUD open on local for
  cloud-authority tables, which its own README says not to use.
- Cloud's `scope` is checked against the site list and unknown values return `400`, as the reference README
  describes; the reference middleware did not enforce it and interpolated the value into SQL.
- PeerDB bookkeeping `ALTER TABLE` uses `ADD COLUMN IF NOT EXISTS`, so re-running `migrate` is clean.
- Ports are consistent: local 7008, cloud 7009 (compose, Dockerfiles and env agree).
- Cookie `MaxAge` and the no-roles `GetPermissions` bugs of the single-service template are fixed here too.

Retained as-is, so tell the user instead of silently changing: on cloud `POST /api/v1/users` is public (no
`users#create` permission) and `/api/v1/user-roles` needs a login but no permission; the seeded Admin role
holds `*`.
