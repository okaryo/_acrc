# SQL Execution Lifecycle

The first implementation step introduces only one ORM boundary:
`Acrc::SQLiteAdapter`.

The adapter hides the raw `SQLite3::Database` object from callers and exposes a
small `execute(sql, binds = [])` method. This is intentionally much smaller than
an ActiveRecord-style model API. The goal is to observe the database execution
path before adding table-to-model mapping.

## Current Flow

1. `Acrc::SQLiteAdapter.new(path)` opens a SQLite database connection.
2. `execute(sql, binds)` sends SQL and bind values to the SQLite driver.
3. The SQLite driver performs statement execution.
4. Result rows are normalized into hashes keyed by column name strings.
5. SQLite driver errors are wrapped in `Acrc::DatabaseError`.

## Why Bind Parameters Matter

The adapter accepts SQL and bind values separately:

```ruby
adapter.execute("SELECT name FROM users WHERE id = ?", [1])
```

The value `1` is not interpolated into the SQL string by `_acrc`. It is passed
to the database driver as a bind parameter. This is the first important safety
boundary for a future query API: user values can be bound, while SQL identifiers
such as table names and column names need separate validation or quoting.

## Intentional Limitations

- There is no model class yet.
- There is no query builder yet.
- There is no type-casting layer beyond values returned by the SQLite driver.
- The adapter currently normalizes row keys but does not hide all SQLite-specific
  behavior.
- Connection lifecycle is manual: callers are expected to call `close`.

These limitations keep the first database-to-result lifecycle small enough to
inspect before adding ActiveRecord-style conveniences.
