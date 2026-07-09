# Persistence Update And Dirty Tracking

The next persistence step adds updates for existing records.

`Acrc::Model` now tracks a loaded baseline in `original_attributes` and compares
that baseline with current `attributes`.

## Current Flow

```ruby
user = User.find(1)
user.name = "Bob"
user.save
```

1. `find` hydrates a persisted model and stores the loaded attributes as the
   baseline.
2. Attribute writers update the current in-memory attributes.
3. `changes` compares original values with current values.
4. `save` on a persisted record builds an `UPDATE` with changed columns only.
5. Changed values are passed as bind parameters.
6. The primary key is used in the `WHERE` clause.
7. After a successful update, the current attributes become the new baseline.

## Dirty Tracking Shape

`changes` returns a hash keyed by attribute name:

```ruby
user.changes
# => { "name" => ["Alice", "Bob"] }
```

The array stores `[old_value, new_value]`.

## Insert Versus Update

`save` now branches on record state:

- `new_record?`: run `INSERT`.
- `persisted?`: run `UPDATE` for changed attributes.

Calling `save` on a persisted record without changes is a no-op that still
returns `true`.

## Intentional Limitations

- There is no stale row detection yet.
- There is no affected-row count check yet.
- The primary key itself is not updated.
- There are still no validations or callbacks.
- Attribute writers are generated from currently known attributes.

These limitations keep this step focused on the basic dirty-tracking and update
SQL lifecycle.
