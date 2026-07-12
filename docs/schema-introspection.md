# Schema Introspection

The first schema step adds SQLite column introspection.

```ruby
User.columns
```

returns `Acrc::Column` objects built from SQLite's `PRAGMA table_info(...)`.

## Current Flow

```ruby
class User < Acrc::Model
  table_name "users"
end

User.connection adapter
User.columns
```

1. `Model.columns` checks that the model has a configured connection.
2. The model asks the adapter for columns for its table name.
3. `SQLiteAdapter#columns` executes `PRAGMA table_info(users)`.
4. Each returned row is normalized into an `Acrc::Column`.

The current column object exposes:

- `name`
- `type`
- `nullable`
- `primary_key`
- `default`

## Declared Attributes Versus Database Schema

Schema introspection and declared attributes are intentionally separate for now.

```ruby
class User < Acrc::Model
  table_name "users"
  attribute :id, :integer
end
```

`attribute :id, :integer` tells `_acrc` how to type cast values it sees.

`User.columns` tells `_acrc` what the database table actually contains.

Those two sources can disagree. This is useful for learning because it keeps a
common ORM tension visible: models may declare behavior in Ruby, while the
database remains the source of truth for actual table shape and constraints.

## Why Identifiers Are Still Validated

The table name in `PRAGMA table_info(users)` is a SQL identifier, not a bind
value. The adapter validates it before interpolating it into the PRAGMA
statement.

```ruby
adapter.columns("users; DROP TABLE users")
# raises Acrc::InvalidIdentifierError
```

## Intentional Limitations

- Introspection does not automatically define attributes yet.
- Introspection does not infer `_acrc` type declarations yet.
- There is no schema cache yet.
- There is no migration runner yet.
- SQLite default expressions are returned as SQLite reports them, for example
  string defaults may include quotes.

This step makes the database schema visible before adding a migration system
that changes that schema.
