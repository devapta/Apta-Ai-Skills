# Architecture reference

Contents: workspace layout · local vs cloud · data authority and replication · schema scoping · shared module rules · environment · build and deploy

## Workspace layout

```
go.work                     ties ./shared ./local ./cloud
shared/                     module <module>/shared — entities, common, enums, pkg (third-party deps only)
  entities/  common/  enums/  pkg/{arrays,jsonb,aws}
local/                      module <module>/local — on-site service
cloud/                      module <module>/cloud — head-office service
  cmd/                      cobra: root, serve (otel + dig + app.Run), migrate (--drop)
  internal/app              gin engine: recovery, otelgin, slog middleware, CORS, /swagger, /api group
  internal/container        uber/dig container; every Provide lives in di.go
  internal/configs          env, postgres (connect/migrate/drop), otel, slog, gorm_logger (+ commented s3, infisical, nats)
  internal/v1/{models,repositories,services,handlers,routes,middlewares,consumers}
docker-compose.dev.yml  .github/workflows/{test,deploy-dev}.yml  README.md  AGENTS.md
```

Each service's `go.mod` has `replace <module>/shared => ../shared`, so `go mod tidy` and Docker builds work without
go.work. Images build from the repo root: `docker build -f local/Dockerfile .`.

Layer responsibilities and naming are as in the single-service standard: entity (embeds `gorm.Model`), model
(`<Name>Input` embeds `common.InputModel`, `<Name>Page` is the list row), repository (`I<Name>Repo`, all DB access,
paginated raw `pageQuery` that filters `deleted_at IS NULL`), service, handler, `setup<Name>Routes`. Files are
`<snake_name>.<layer>.go`; URLs, swagger tags and permission keys are kebab-case plurals
(`/api/v1/weighing-records`, `weighing-records#read`); json tags are lowerCamel (`driverId`).

## Local vs cloud

| | local | cloud |
| --- | --- | --- |
| Where | on a site network, one per site | head office, one |
| Auth | none — routes are open; no users/roles tables | JWT (HS256 access + refresh), users / roles / user-roles, `Authn` + `Authz(perm)` |
| Database | its own PostgreSQL | main schema + one schema per site (replicated rows) |
| Extras | mDNS advertisement `_<short>._tcp` on start | `GET /api/v1/sites`, schema middleware, `UseScoped` on every service |
| Defaults | port 7008, DB `<name>` | port 7009, DB `<name>_cloud`, seeded admin from `DEFAULT_*` |
| Network | docker host network (reaches site devices) | `infra-app` docker network, published port |

## Data authority and replication

Every table has exactly one authority — the side where rows are created and edited. The other side only
holds a copy, filled by database-level replication (PeerDB), not by application code; neither service calls
the other over HTTP. So:

- authority = cloud (master data, e.g. drivers): cloud exposes full CRUD; local exposes `GET` only. On local
  `migrate` adds `_PEERDB_IS_DELETED` / `_PEERDB_SYNCED_AT` columns to these tables (they are listed in
  `cloudAuthorityTables` in local's `postgres.go`).
- authority = local (records, e.g. transactions): local exposes full CRUD; cloud exposes `GET` only, with `scope`.

Decide the authority before adding a table; it sets who may write and which way replication must run. The
generator records each decision in the README table.

## Schema scoping on cloud

Reads of replicated data pick a schema with `?scope=<site>`. `GET /api/v1/sites` lists the site schemas
(schemas owned by the DB user, minus system schemas, `public` and the main schema). Mechanics:

1. `SchemaMiddleware.SchemaRouter` takes `scope` (default `DB_SCHEMA`), validates it against the site list
   (`400` if unknown), opens a transaction, runs `SET LOCAL search_path TO "<schema>"` and stores the
   transaction under `services.ScopedTxKey`.
2. Handlers call `h.service.UseScoped(c).Read(c)` / `.GetByID(...)`; `UseScoped` rebuilds the service on a repository
   bound to that transaction (or returns itself when the request was not scoped).
3. Writes never use `scope`; they go to the main schema. The middleware sits only on `GET` routes.

## Shared module rules

`shared` must compile without `local` or `cloud`. It therefore cannot read service `configs`: helpers take
parameters (`GenerateJWTPair(secret, atExp, claims, permissions, isRemember)`, `GenerateCookies(..., atExp, secure)`).
Put things in `shared` only when both services use them (entities, enums, permissions, result envelope, jsonb/arrays).

## Environment

Per service `example.env` → `.env`: `PORT`, `DB_PORT|USER|PASSWORD|NAME|HOST|SCHEMA`, `SERVER_ENV` (`prod` = release
mode), `SERVER_ID` (name the site on local), `OTEL_EXPORTER_OTLP_ENDPOINT`, `CORS_ALLOW_ORIGINS`. Cloud adds
`JWT_SECRET`, `JWT_EXPIRY_MINUTES`, `DEFAULT_USER|EMAIL|PASSWORD`. Optional modules are commented. Add a variable
in three places per service: the `env` struct, its `os.Getenv` assignment, `example.env`.
OTel service names are `<name>-local.<SERVER_ID>.<SERVER_ENV>` and `<name>-cloud....`.

## Build and deploy

- Dockerfiles build from the repo root with `GOWORK=off`, copying `shared` to `/shared` and relying on the `replace`.
  They need `go.sum`, so run `go mod tidy` first.
- `docker-compose.dev.yml`: `<name>-local-migrate` / `<name>-local` on the host network with `.env`; `<name>-cloud-migrate` /
  `<name>-cloud` on `infra-app` with `.env.cloud`. Each service starts only after its `migrate` container succeeds.
- `deploy-dev.yml`: matrix builds both images (`registry.apta.works/<name>-local|cloud:latest`), then the self-hosted
  dev runner writes `.env` and `.env.cloud` from Infisical (set the `project-slug`, secret envs `dev` and `dev-cloud`).
  `test.yml` runs shared, local and cloud tests.
