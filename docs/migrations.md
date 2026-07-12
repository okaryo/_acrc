# Migrations

The first migration step adds a minimal migration runner.

```ruby
migrations = [
  Acrc::Migration.new("202607120001", "create_users") do |db|
    db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
  end
]

Acrc::MigrationRunner.new(db).migrate(migrations)
```

## Current Flow

1. The runner ensures that `acrc_schema_migrations` exists.
2. It reads applied versions from that table.
3. It sorts the supplied migrations by version.
4. It skips versions that were already applied.
5. It runs each pending migration inside a transaction.
6. After a migration succeeds, it records the version.

The version table is deliberately small:

```sql
CREATE TABLE IF NOT EXISTS acrc_schema_migrations (
  version TEXT PRIMARY KEY
)
```

## Why Versions Matter

Without version tracking, running the same schema change twice would often fail:

```sql
CREATE TABLE users (...)
CREATE TABLE users (...)
```

The migration runner separates two concerns:

- The migration block changes the schema.
- `acrc_schema_migrations` records that the change has already run.

This lets the same list of migrations be passed to the runner repeatedly while
only pending migrations are executed.

## Transaction Boundary

Each migration runs in a transaction:

```ruby
adapter.transaction do
  migration.up(adapter)
  adapter.execute(
    "INSERT INTO acrc_schema_migrations (version) VALUES (?)",
    [migration.version]
  )
end
```

If the migration raises, both the schema change and the version record are
rolled back where SQLite can roll them back. This keeps the version table from
claiming that a failed migration succeeded.

## Intentional Limitations

- Migrations only support `up`; there is no `down` or rollback command yet.
- Migrations are plain Ruby blocks that execute SQL directly.
- There is no file loader for migration files yet.
- There is no timestamp parser or generator.
- There is no schema dump yet.
- Adapter differences beyond SQLite are not handled.

This step keeps migrations focused on the core mechanism: run schema-changing
SQL once, and record that it ran.
