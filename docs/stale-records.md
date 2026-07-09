# Stale Records And Affected Rows

A model can believe it represents a persisted row while the database row has
already been removed by another object or process. This is a stale record.

This step uses affected-row counts to detect that situation for `UPDATE` and
`DELETE`.

## Current Flow

```ruby
user = User.find(1)

# Another object or process deletes row 1.

user.name = "Bob"
user.save
```

1. `_acrc` builds an `UPDATE ... WHERE id = ?` statement.
2. The adapter executes it.
3. The adapter exposes how many rows were changed.
4. If zero rows were changed, `_acrc` raises `Acrc::StaleRecordError`.
5. The model keeps its in-memory state unchanged so the failed change remains
   visible.

`destroy` uses the same check after `DELETE`.

## Why This Matters

Without affected-row checks, an update can silently do nothing:

```sql
UPDATE users SET name = 'Bob' WHERE id = 1
```

If row `1` no longer exists, the SQL statement still succeeds at the database
protocol level. The application must inspect the affected-row count to notice
that no row was updated.

## Intentional Limitations

- This detects missing rows, not conflicting updates.
- There is no optimistic locking column yet.
- Insert behavior does not use affected-row checks yet.
- Adapter support is minimal and currently depends on SQLite's `changes` API.

These limitations keep this step focused on the difference between SQL success
and application-level persistence success.
