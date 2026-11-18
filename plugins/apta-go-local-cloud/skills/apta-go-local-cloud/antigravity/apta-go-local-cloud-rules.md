# Apta Go local + cloud backend rules

Applies to a Go workspace with `shared/`, `local/` and `cloud/` modules joined by `go.work` (modeled on simple-weighbridge-service). The `apta-go-local-cloud` skill has a generator; without it, follow these rules by hand.

## Modules
- `shared/`: entities, enums (permissions), common helpers, pkg. Never imports `local/` or `cloud/`; takes config as parameters.
- `local/`: on-site service, open API (no auth), mDNS advertisement, own PostgreSQL.
- `cloud/`: head-office service, JWT auth + users/roles/user-roles, schema-scoped reads, own PostgreSQL (main schema + one schema per site).
- Each service `go.mod` has `replace <module>/shared => ../shared`; build Docker images from the repo root.

## Data authority
Every table has one authority side (README table). Write endpoints (POST/PUT/DELETE) exist only there; the other side is GET-only. Replication (PeerDB) is database-level, outside the repo; local adds PeerDB columns to cloud-authority tables on migrate (`cloudAuthorityTables`). Decide authority before adding a table.

## Layers per service (`<svc>/internal/`)
entity in `shared/entities` → `v1/models` (`<Name>Input`, `<Name>Page`) → `v1/repositories` (all DB access, `gorm.G[T]`, paginated `pageQuery` filtering `deleted_at IS NULL`) → `v1/services` → `v1/handlers` (swaggo annotations on every handler) → `v1/routes`.
- Register in `<svc>/internal/container/di.go` (dig, `dig.As` for interfaces) and `<svc>/internal/configs/postgres.go` (AutoMigrate + DropTable, children dropped first).
- Add the handler to `routes.APIHandlers` and a `setup<Name>Routes` call in `routes/router.go`.
- Permissions `<kebab-plural>#create|read|update|delete` in `shared/enums/permissions.go` (+ `ListPerms`); only cloud checks them.

## Cloud scoping
Reads accept `?scope=<site>`: `schemaM.SchemaRouter` validates it against the site list (400 if unknown), sets `search_path` in a transaction; handlers call `h.service.UseScoped(c).Read(c)`. Writes always hit the main schema.

## Naming and behaviour
Files `<snake_name>.<layer>.go`; routes `/api/v1/<kebab-plural>`; json tags lowerCamel. Handlers pass `c.Request.Context()` and answer with `common.ResultOk` / `common.ResultErr`. Log with slog `*Context` methods. S3, Infisical and NATS ship commented out; enable deliberately. Never edit generated `docs/`; run `make swag` after changing annotations. Do not run serve/migrate. Verify dependency APIs with Context7.
