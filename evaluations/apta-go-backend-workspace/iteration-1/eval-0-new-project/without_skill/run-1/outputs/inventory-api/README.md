# inventory-api

Go + Gin backend for the inventory service (`github.com/devapta/inventory-api`).

Stack: Gin, GORM/PostgreSQL, uber/dig DI, cobra CLI, JWT (HS256 access/refresh), argon2id,
permission-based authz, swaggo Swagger, OpenTelemetry (traces, metrics, logs via slog).

Layout: `internal/{entities,v1/models,v1/repositories,v1/services,v1/handlers,v1/routes}`;
register new constructors in `internal/container/di.go`, entities in `internal/configs/postgres.go`.

## Setup
    cp example.env .env   # set JWT_SECRET, DEFAULT_PASSWORD, DB_*
    make swag             # generate docs/ (Swagger)
    make migrate          # migrate + seed admin user / Admin role (perm "*")
    make go               # serve; Swagger at /swagger/index.html
    make test

Endpoints under `/api/v1`: `users` (incl. login, refresh, current, permissions, roles), `roles`, `user-roles`.
