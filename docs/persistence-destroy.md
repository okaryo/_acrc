# Persistence Destroy

The destroy step adds the first delete path.

`destroy` removes the database row represented by a persisted model and marks
the Ruby object as destroyed.

## Current Flow

```ruby
user = User.find(1)
user.destroy
```

1. The model checks that the object is not a new record.
2. The model reads its primary key value.
3. The model executes `DELETE FROM table WHERE primary_key = ?`.
4. The primary key value is passed as a bind parameter.
5. The object is marked destroyed.

The object keeps its loaded attributes, so values such as `user.id` remain
readable after deletion. However, `persisted?` becomes false.

## Object State

The current lifecycle states are:

- new record: `new_record? == true`, `persisted? == false`,
  `destroyed? == false`
- persisted record: `new_record? == false`, `persisted? == true`,
  `destroyed? == false`
- destroyed record: `new_record? == false`, `persisted? == false`,
  `destroyed? == true`

Saving a destroyed record raises `Acrc::DestroyedRecordError`.

## Intentional Limitations

- Stale row detection is documented separately in `docs/stale-records.md`.
- There are no callbacks such as `before_destroy` or `after_destroy`.
- There is no association-dependent deletion behavior.

These limitations keep this step focused on the basic object-state transition
from persisted row to deleted row.
