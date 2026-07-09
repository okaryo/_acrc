# Minimal Finder API

The third implementation step connects model metadata to SQL execution.

`Acrc::Model` now knows how to use a configured adapter:

```ruby
class User < Acrc::Model
  table_name "users"
end

User.connection adapter
User.find(1)
User.where(role: "member")
```

This is the first point where the ORM starts hiding SQL construction behind a
model API.

## Current Flow

`find(id)`:

1. Reads the model's table name and primary key.
2. Validates both as SQL identifiers.
3. Builds a small `SELECT ... WHERE primary_key = ? LIMIT 1` query.
4. Sends the id as a bind parameter.
5. Hydrates the first returned row into a model instance.
6. Raises `Acrc::RecordNotFound` when no row exists.

`where(conditions)`:

1. Accepts a non-empty hash of column names to values.
2. Validates each column name as a SQL identifier.
3. Builds `column = ?` clauses joined with `AND`.
4. Sends all condition values as bind parameters.
5. Hydrates every returned row and returns an array.

## Values Versus Identifiers

SQL values can be bound:

```ruby
User.where(name: "Alice")
```

The value `"Alice"` is passed separately from the SQL string.

SQL identifiers cannot be bound in the same way:

```ruby
User.where(name: "Alice")
#       ^ column name
```

The column name becomes part of the SQL syntax, so `_acrc` validates it before
including it in the SQL string. This first version allows only simple
identifier names such as `users`, `id`, and `created_at`.

## Return Shapes

`find(id)` returns one model instance or raises `Acrc::RecordNotFound`.

`where(...)` returns an array of model instances immediately. It does not return
a lazy relation object yet. That keeps query execution visible before adding
query composition.

## Intentional Limitations

- Only equality conditions are supported.
- `where` combines multiple conditions with `AND`.
- Identifier validation is deliberately simple and does not quote names.
- There is no `order`, `limit`, `select`, or lazy relation object yet.
- Models use one class-level connection adapter.

These limitations keep the first query API focused on the difference between
bound values and SQL identifiers.
