# AGENTS.md

Guidance for agent sessions working in this repository.

## Hard rules

- Do not execute run, serve, migrate, or build commands. The user runs commands.
- Retain the existing versioned layered structure.
- Verify dependency APIs through Context7 before writing dependency-specific code.
- Do not edit generated Swagger files under `docs/`.

## Scope

The backend contains three related resources: users, roles, and user roles. It has no
web UI and no tenant/schema-routing behavior. Shared infrastructure includes JWT auth,
PostgreSQL, OpenTelemetry, slog, Swagger, cobra, and uber/dig. S3, Infisical and NATS are
present in the codebase but commented out until needed.

New backend code follows the existing entity, model, repository, service, handler, and
route layers. Register constructable dependencies in `internal/container/di.go` and
entities in `internal/configs/postgres.go`. To add a resource, use the `apta-go-backend`
skill (CRUD scaffolding) instead of hand-copying files.

All database access belongs in repositories. Pass `c.Request.Context()` from Gin
handlers to methods accepting `context.Context`; pass `*gin.Context` only where the
method explicitly requires it.
