# Attributes And Type Casting

The fourth implementation step adds explicit attribute type declarations.

SQLite and the `sqlite3` driver return values in driver-specific Ruby shapes.
`Acrc::Model` now has a small type-casting boundary so a model can say how a
loaded column should behave in Ruby:

```ruby
class User < Acrc::Model
  table_name "users"
  attribute :id, :integer
  attribute :admin, :boolean
  attribute :created_at, :time
end
```

## Current Flow

1. The adapter returns a row hash.
2. `hydrate(row)` normalizes row keys to strings.
3. Declared attributes are cast during hydration.
4. Undeclared attributes keep the values returned by the driver.
5. The model stores the casted attributes as the loaded baseline.

Casting during hydration keeps the model's readers simple: `user.age` returns
the already-casted value instead of casting every time it is read.

## Supported Types

The first type set is deliberately small:

- `:integer`
- `:float`
- `:string`
- `:boolean`
- `:time`

`nil` values are preserved for every type. Invalid values raise
`Acrc::TypeCastError`.

## Original Attributes

The model stores `original_attributes` after type casting. This does not
implement dirty tracking yet, but it preserves the loaded baseline that a later
dirty-tracking step can compare against.

## Intentional Limitations

- There is no schema introspection yet.
- Type declarations are manual.
- Query values are not type-cast separately yet.
- Boolean casting accepts only a small set of common values.
- Time casting uses Ruby's standard `Time.parse`.
- There are no writers, defaults, serialized attributes, or custom types yet.

These limitations keep the type boundary focused on one question: when raw
database values become Ruby model values.
