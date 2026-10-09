# Architecture reference

Contents: layout · layer responsibilities · naming · request flow · auth · env vars · logging and tracing · scaffold markers

## Layout

```
main.go                      swagger general info (@title, @BasePath /api, ApiKeyAuth), calls cmd.Execute
cmd/                         cobra: root.go, serve.go (otel + dig + app.Run), migrate.go (--drop)
internal/
  app/app.go                 gin engine: recovery, otelgin, slog middleware, CORS, /swagger, /api group
  container/di.go            uber/dig container; every Provide lives here
  common/                    Result envelope, base CRUD generics, jwt, cookies, Cast, InputModel
  configs/                   env.go, postgres.go (connect/migrate/drop/seed), otel.go, slog.go, gorm_logger.go
                             (+ commented s3.go, infisical.go, nats.go)
  entities/                  GORM entities (<name>.entity.go)
  enums/                     permissions.go, errors.go, time.go, io_color.go, app.go (AppVersion)
  v1/
    models/                  <Name>Input (request) and <Name>Page (list row)
    repositories/            I<Name>Repo + implementation, all DB access
    services/                I<Name>Service, business logic over repos
    handlers/                gin handlers with swaggo annotations
    routes/                  router.go (APIHandlers bundle) + one setup<Name>Routes per resource
    middlewares/             auth (Authn / Refresh / Authz), slog request logger
    consumers/               NATS consumers (commented example)
  tests/                     `make test` runs ./internal/tests/...
pkg/                         generic helpers: arrays, jsonb (+ commented aws/s3)
```

## Layer responsibilities

- **Entity**: embeds `gorm.Model` (soft delete via `deleted_at`). json tags are camelCase.
- **Model**: `Input` embeds `common.InputModel` (ID/timestamps hidden from JSON). `Page` is the list
  projection; it can differ from the entity (joins, aggregates).
- **Repository**: implements `common.IBaseCrudRepo[Entity, Input, Page]` — `Create`, `Read`, `Update`,
  `Delete`, `GetByID`. Uses `gorm.G[T](db)` generics and `mapper.AutoMapper` to map Input → Entity.
  `Read` paginates a raw `pageQuery` with `morkid/paginate`; the query must filter `deleted_at IS NULL`.
- **Service**: implements `common.IBaseCrudService[...]`; thin pass-through unless there is logic
  (e.g. `UserService` hashes passwords with argon2id and builds token pairs).
- **Handler**: bind JSON → call service with `c.Request.Context()` → `common.ResultOk` / `ResultErr`.
  Bind errors return 400; `ResultErr` maps `gorm.ErrRecordNotFound` to 404, else 500.
- **Route**: `v1.Group("/<kebab-plural>", authM.Authn)` then one `authM.Authz(enums.Perm…)` per verb.

Adding an interface method beyond the base CRUD: add it to `I<Name>Repo` / `I<Name>Service`, implement it,
and keep the `var _ I<Name>Repo = &<Name>Repo{}` assertion.

## Naming

- Files: `<snake_name>.<layer>.go` (`vehicle_type.repo.go`, like `user_role.repo.go`). Only URLs, swagger
  tags and permission keys are kebab-case.
- Types: `<Name>Repo`, `I<Name>Repo`, `New<Name>Repo`, same for Service / Handler; `setup<Name>Routes`.
- Routes: `/api/v1/<kebab-plural>`; swagger tag is the same string.
- Permissions: `<kebab-plural>#create|read|update|delete` → const `Perm<PascalPlural><Action>`;
  `*` (`PermFullAccess`) grants everything.
- Tables: GORM default (snake plural). The `pageQuery` table name must match.

## Auth

`POST /users/login` returns access + refresh tokens (HS256, `JWT_SECRET`; access lifetime
`JWT_EXPIRY_MINUTES`, refresh 1 day or 30 days with `isRemember`) and sets `at`/`rt` cookies.
`Authn` reads `Authorization: Bearer <token>` and stores `userId` and `permissions` claims;
`Authz(perm)` passes when the permissions claim has `*` or `perm`; `Refresh` reads `X-Refresh-Token`.
Permissions are the union of the user's roles' `permissions` (jsonb string array), computed at login.

## Environment variables (`example.env`)

`PORT`, `DB_PORT|USER|PASSWORD|NAME|HOST|SCHEMA`, `JWT_SECRET`, `JWT_EXPIRY_MINUTES`, `SERVER_ENV`
(`prod` switches gin to release mode and quiets GORM logs), `SERVER_ID`, `DEFAULT_USER|EMAIL|PASSWORD`
(seeded admin), `OTEL_EXPORTER_OTLP_ENDPOINT`, `CORS_ALLOW_ORIGINS` (comma separated).
Commented: `INFISICAL_*`, `AWS_*`, `NATS_URI`. Add a new variable in three places: `env.go` struct,
its `os.Getenv` assignment, and `example.env`.

## Logging and tracing

`configs.NewSlog` fans out to stdout and the OTel log bridge; the slog middleware logs every request;
`SlogGormLogger` sends each SQL statement through slog; `otelgin` and `otelgorm` produce traces.
`OTLPServiceName` is `<app-name>.<SERVER_ID>.<SERVER_ENV>`. Use `logger.InfoContext(ctx, …)` so logs
carry the trace id.

## Scaffold markers

The generator inserts into `// scaffold:<name>` comments (`repos`, `services`, `handlers`,
`api-handlers`, `routes`, `migrate`, `drop`, `perm-consts`, `perm-list`). Leave them in place; they cost
nothing and keep `crud` working. For `drop`, new entities are inserted below the marker so children
drop before parents — reorder by hand if a new entity is a parent of an older one.
