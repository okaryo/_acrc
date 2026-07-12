# Known Limitations

`_acrc` is intentionally small. The limitations below are not accidental
production bugs to hide; they are boundaries that keep the current learning
surface inspectable.

## Database And Adapter

- Only SQLite is supported.
- There is no connection pool.
- There is no prepared statement cache.
- SQL execution is synchronous and uses one adapter instance directly.
- Database-specific behavior is not normalized across adapters.
- Constraint errors are grouped under `Acrc::ConstraintError` rather than split
  into specific subclasses such as unique constraint or foreign key errors.

## Schema And Attributes

- Models require explicit `table_name`; table names are not inferred.
- Attribute types are declared manually with `attribute`; schema introspection
  does not automatically configure type casting.
- Default values from the database are not applied to new Ruby objects before
  insert.
- Unknown attributes are accepted when assigned, because the model does not
  continuously validate assignments against the database schema.
- Partial `select` results create model objects with only the selected
  attributes loaded.

## Querying

- Query composition supports only a small subset: `where`, `order`, `limit`,
  `select`, and `preload`.
- `where` supports equality and array-backed `IN`, but not arbitrary
  expressions, ranges, joins, OR conditions, NULL helpers, or subqueries.
- SQL identifiers are validated, but there is no quoting strategy for unusual
  table or column names.
- There is no identity map, so loading the same row twice creates separate Ruby
  objects.
- There are no aggregate helpers such as `count`, `sum`, or `exists?`.

## Persistence

- `save` inserts new records and updates changed columns, but there are no
  automatic timestamps.
- There is no optimistic locking column such as Rails' `lock_version`.
- Stale row detection only checks whether an update or delete affected zero
  rows.
- There are no bulk insert, upsert, or batch update APIs.
- Destroyed records remember their destroyed state in memory, but there is no
  dependent association cleanup.

## Associations And Loading

- Only minimal `belongs_to` and `has_many` associations exist.
- `preload` supports `belongs_to` only.
- There is no JOIN-based eager loading.
- There are no scoped associations, inverse associations, polymorphic
  associations, or `has_many :through` associations.
- Association caches are local to each object and are not invalidated by
  unrelated writes.

## Validations And Callbacks

- Only presence validation exists.
- Validation errors are plain hashes, not rich error objects.
- There are no validation contexts such as create versus update.
- There are no custom validator objects.
- Validations read current in-memory attributes only.
- Only `before_save` and `after_save` callbacks exist.
- There is no callback halting protocol except raising an exception.
- There are no transaction callbacks such as `after_commit` or
  `after_rollback`.

## Transactions

- Transactions are delegated directly to the adapter.
- Nested transactions use SQLite savepoints.
- There is no automatic retry behavior.
- There is no integration with lifecycle callbacks after commit or rollback.
- Transaction state is kept on the adapter instance, not in a connection pool.

## Diagnostics

- The adapter query log is useful for tests and examples, but it is not a
  production logging system.
- Error messages are intentionally small and do not include every possible
  debugging detail.
- There is no structured instrumentation API.

## Learning Boundary

These limitations are useful because they leave the core ORM questions visible:

- How does SQL execution cross into Ruby objects?
- When does a lazy relation run SQL?
- Which values can be bound, and which SQL identifiers must be validated?
- How do validations, callbacks, transactions, and persistence interact?
- Which conveniences make application code shorter, and which ones hide
  important control flow?

Future steps can choose from this list deliberately instead of expanding the
ORM surface by accident.

