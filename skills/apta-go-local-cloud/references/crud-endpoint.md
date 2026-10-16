# Finishing a CRUD resource

`scaffold.py crud` produces a working endpoint pair over a single table. Review these before calling it done.

## 1. Authority and replication

- The authority side has create / read / update / delete; the other side only `GET`. If the user later needs to
  write from the other side, change the authority deliberately (it changes the replication direction) rather
  than adding write routes.
- Replication is configured outside the repo. Tell the user the new table must replicate authority → other side
  (and, for cloud-authority tables, that local `migrate` adds the PeerDB bookkeeping columns).
- Migrate order: both services `AutoMigrate` the table; the non-authority side still needs the table to exist
  to receive replicated rows.

## 2. Relations and joins

- Foreign key: a `uint` field `<thing>Id` (`driverId:uint`). To expose the related row, add a pointer field on the
  entity in `shared/entities` (`Driver *Driver \`json:"driver,omitzero"\``).
- A foreign key to a table whose authority is the *other* side points at a replicated copy. Replication can
  deliver rows out of order, so avoid hard database constraints that would reject a row whose parent has not
  arrived yet unless the user confirms the replication guarantees it.
- List rows with related data: edit `pageQuery` in each service's repository (the two copies are independent)
  and add fields to `<Name>Page`. Keep `WHERE t.deleted_at IS NULL`. Replicated tables on local also carry
  `_PEERDB_IS_DELETED`; filter it when it matters.
- `AutoMigrate` creates tables in listed order: list a referenced entity before the entity that references it
  (the `migrate` marker appends — move it if needed; `drop` is the reverse).

## 3. Business logic

Rules belong in the service, database access in the repository. Keep the two services' copies in step for
anything both sides use. Extra lookups use `common.IGetByKV[Entity]` (see `get_by_kv.repo.go`).

## 4. Extra routes

Add the method to the repo/service interfaces and implementation, a handler method with full swaggo
annotations, and a route line. On cloud, a `GET` that should support site scoping needs `schemaM.SchemaRouter`
in its chain and `UseScoped(c)` in the handler; a write must not. Non-CRUD verbs need their own permission
const + `perm-list` entry in `shared/enums/permissions.go`.

## 5. Permissions

Only cloud checks permissions. The generator adds `<plural>#create|read|update|delete` (just `read` when cloud is
read-only). They matter once a role holds them: create the role via `POST /api/v1/roles` / `PUT /api/v1/roles/{id}`
or extend the seed in cloud's `seedDefaultUser`. The seeded Admin role has `*`.

## 6. Manual checklist (when there are no markers)

In `shared`: entity, permission consts + `ListPerms`. In each service: model, repo, service, handler, route files;
`Provide` repo / service / handler in `di.go`; handler field in `routes.APIHandlers` and the `setup<Name>Routes`
call in `router.go` (cloud passes `authM` and `h.SchemaM`, local passes just the handler); entity in
`AutoMigrate` and `DropTable` in `postgres.go`; for cloud-authority tables also the table name in local's
`cloudAuthorityTables`.

## 7. Gotchas

- `Update` uses GORM `Updates` with a struct, so zero values (`0`, `false`, `""`) are ignored on PUT.
- `time` / `date` fields are `time.Time`: JSON must be RFC3339, even for `date` columns.
- Uniqueness comes from the DB constraint and soft-deleted rows still hold their unique values.
- After editing annotations run `make swag`; after adding entities run `make migrate` — in both services (the user runs these).
