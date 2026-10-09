# Shop Api

Shop Api is a Gin and GORM service containing user, role, and user-role management.

It ships with JWT authentication, PostgreSQL persistence, Swagger annotations,
OpenTelemetry traces/logs/metrics, slog request and GORM logging, cobra commands and
uber/dig dependency injection. S3, Infisical and NATS are included in the codebase but
commented out; see the `apta-go-backend` skill (`references/optional-modules.md`) to enable them.

## Getting started

```bash
cp example.env .env      # configure database, JWT and OTLP settings
make swag                # generate swagger docs (docs/ is git-ignored)
make migrate             # migrate the database and seed the default admin user
make go                  # run the API (or `make dev` for live reload with air)
```

Swagger UI: `http://localhost:7008/swagger/index.html`

## Commands

| Command | What it does |
| --- | --- |
| `make swag` | Regenerate swagger docs |
| `make dev` | Live reload with `air` |
| `make go` | Run the API server |
| `make migrate` | Migrate the database and seed the default user |
| `make migrate-force` | Drop all tables, then migrate |
| `make test` | Run tests under `internal/tests/` |
