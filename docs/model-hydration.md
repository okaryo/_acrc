# Model Hydration

The second implementation step introduces `Acrc::Model`, but only for row
hydration. It does not query the database yet.

This keeps the current boundary clear:

- `Acrc::SQLiteAdapter` turns SQL results into row hashes.
- `Acrc::Model.hydrate(row)` turns one row hash into one Ruby object.

## Current Flow

1. A database adapter returns a row such as `{ "id" => 1, "name" => "Alice" }`.
2. A model class calls `hydrate(row)`.
3. The row keys are normalized to strings.
4. Attribute reader methods are defined on that instance for safe loaded column
   names.
5. The instance stores its own copy of the attributes.

After hydration, both method readers and index-style access are available:

```ruby
user = User.hydrate("id" => 1, "name" => "Alice")

user.id
user[:name]
```

## Explicit Table Metadata

The first model API requires explicit table names:

```ruby
class User < Acrc::Model
  table_name "users"
end
```

The primary key defaults to `"id"` and can be configured:

```ruby
class Post < Acrc::Model
  table_name "posts"
  primary_key "uuid"
end
```

This avoids introducing naming conventions before the table-to-object mapping
itself is visible.

## Unknown Attributes

Index-style access raises `Acrc::UnknownAttributeError` when a value was not
loaded:

```ruby
user[:missing]
```

Reader methods are only generated on the hydrated instance for loaded columns
whose names are safe Ruby method names and do not already exist on the model
instance. This keeps the first version inspectable while avoiding accidental
overrides of existing Ruby methods.

## Intentional Limitations

- Models do not know about database connections yet.
- There is no `find`, `where`, or relation object yet.
- Schema introspection exists, but hydration still uses the loaded row rather
  than defining readers from the full table schema.
- Attribute methods are generated from loaded rows rather than declared columns.
- Type casting is limited to whatever the adapter already returned.

These limitations are intentional. The next useful boundary is a minimal finder
API that connects model metadata to SQL execution.
