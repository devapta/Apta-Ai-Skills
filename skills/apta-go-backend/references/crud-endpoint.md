# Finishing a CRUD endpoint

`scaffold.py crud` produces a working endpoint over a single table. Review these before calling it done.

## 1. Relations and joins

- Foreign key: a `uint` field named `<thing>Id` (`ownerId:uint`) → column `owner_id`. To expose the related
  row, add a pointer field to the entity as `UserRole` does: `Owner *Owner \`json:"owner,omitzero"\``.
- List rows with related data: edit `pageQuery` in the repository and add fields to `<Name>Page`, e.g.
  ```go
  pageQuery: `
      SELECT t.*, o.name AS owner_name
      FROM vehicles t
      LEFT JOIN owners o ON o.id = t.owner_id AND o.deleted_at IS NULL
      WHERE t.deleted_at IS NULL
  `,
  ```
  Keep `WHERE t.deleted_at IS NULL`; paginate's `filters`/`sort` query params operate on the result columns.
- Migration order: `AutoMigrate` creates tables in listed order, so list a referenced entity before the entity
  that references it (the `migrate` marker appends at the end — move it if needed).

## 2. Business logic

Put rules (uniqueness checks, derived fields, state transitions) in the service, not the handler, and
database access in the repository. Extra lookups use the optional `common.IGetByKV[Entity]` interface — see
`repositories/get_by_kv.repo.go` for the generic implementation.

## 3. Extra routes

Add the method to the repo/service interfaces and implementation, a handler method with full swaggo
annotations (`@Router /v1/<plural>/{id}/action [verb]`), and a route line. Non-CRUD verbs need their own
permission const + `perm-list` entry (for example `PermHaulageRatesApproval = "haulage-rates#approval"`).

## 4. Permissions

The generator adds the four permissions to `enums`. They only matter once a role holds them: either create the role
via `POST /api/v1/roles` / `PUT /api/v1/roles/{id}` or extend the seed in `seedDefaultUser` in `postgres.go`.
The seeded Admin role has `*` and already passes every check.

## 5. Manual checklist (when there are no markers)

Entity → `AutoMigrate` + `DropTable` in `postgres.go`; `Provide` repo, service and handler in `di.go`;
handler field in `routes.APIHandlers` and `setup<Name>Routes` call in `router.go`; perm consts + `ListPerms`.

## 6. After editing

`make swag` (annotations changed) and `make migrate`. Both are the user's to run.

## Gotchas worth telling the user

- `Update` uses GORM `Updates` with a struct, so zero values (`0`, `false`, `""`) are ignored on PUT; use a map or `Select` in the repository when a field must be clearable.
- `time` / `date` fields are `time.Time`: JSON must be RFC3339 (`2026-01-31T00:00:00Z`), even for `date` columns.
- Uniqueness comes from the DB constraint, and soft-deleted rows still hold their unique values.
- A foreign key `uint` is only enforced by the database after migration; add a service-level existence check for friendlier errors.
