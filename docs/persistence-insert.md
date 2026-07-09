# Persistence Insert

The fifth implementation step starts persistence with one path: inserting new
records.

The project now distinguishes between two object states:

- `new_record?`: the object has not been inserted yet.
- `persisted?`: the object represents a row that exists in the database.

Hydrated objects are persisted because they came from a database row. Objects
created with `Model.new(...)` are new records.

## Current Flow

```ruby
user = User.new("name" => "Alice")
user.save
```

1. `User.new(...)` casts declared attributes and marks the object as a new
   record.
2. `save` rejects persisted records for now because update behavior has not
   been implemented yet.
3. The model builds an `INSERT` statement from its current attributes.
4. Attribute values are passed as bind parameters.
5. If the primary key was not provided, the generated SQLite row id is stored
   back on the model.
6. The model is marked persisted, and `original_attributes` becomes the loaded
   baseline after insert.

## Primary Keys

When the primary key is omitted or nil, `_acrc` leaves it out of the insert:

```ruby
User.new("name" => "Alice").save
```

SQLite generates the `id`, and the adapter exposes `last_insert_row_id` so the
model can store it.

If a primary key value is explicitly provided, `_acrc` inserts that value and
keeps it:

```ruby
User.new("id" => 10, "name" => "Alice").save
```

## Intentional Limitations

- Updating existing records is not implemented yet.
- Dirty tracking is not implemented yet.
- There are no attribute writers yet.
- There are no validations or callbacks yet.
- Insert column names are validated, not quoted.
- Generated primary key handling currently depends on SQLite adapter behavior.

These limitations keep this step focused on how an object crosses from "new
Ruby object" to "database row represented by a Ruby object".
