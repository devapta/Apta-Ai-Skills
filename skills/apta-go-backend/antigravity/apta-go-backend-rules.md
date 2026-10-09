# Apta Go backend (Gin + GORM) rules

Applies to Go backends modeled on fleet-backend. The `apta-go-backend` skill has a generator; without it, follow these rules by hand.

## Layers (`internal/`)
`entities` (GORM, embeds `gorm.Model`) → `v1/models` (`<Name>Input` embeds `common.InputModel`, `<Name>Page`) → `v1/repositories` (`I<Name>Repo`, all DB access, `gorm.G[T]`, paginated raw `pageQuery` filtering `deleted_at IS NULL`) → `v1/services` → `v1/handlers` (swaggo annotations on every handler) → `v1/routes` (`setup<Name>Routes`, group `authM.Authn`, per-verb `authM.Authz(enums.Perm…)`).

## Wiring
- Register every repo/service/handler in `internal/container/di.go` (uber/dig, `dig.As` for interfaces).
- Register entities in `internal/configs/postgres.go` (`AutoMigrate` + `DropTable`, children dropped first).
- Add handler to `routes.APIHandlers` and call `setup<Name>Routes` in `routes/router.go`.
- Permissions: `<kebab-plural>#create|read|update|delete` in `internal/enums/permissions.go` (+ `ListPerms`).

## Naming
Files `<snake_name>.<layer>.go`; routes `/api/v1/<kebab-plural>`; json tags camelCase; env vars UPPER_SNAKE in `internal/configs/env.go` and `example.env`.

## Behaviour
- Handlers pass `c.Request.Context()`; respond with `common.ResultOk` / `common.ResultErr` (400 on bad JSON).
- Log with `slog` `*Context` methods; OpenTelemetry is on by default.
- S3, Infisical and NATS are committed commented out; enable deliberately, with their env vars.
- Never edit generated `docs/`; run `make swag` after changing annotations. Do not run serve/migrate.
- Verify dependency APIs with Context7.
