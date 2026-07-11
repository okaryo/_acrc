# Relation And Query Composition

The relation step introduces lazy query objects.

Before this step, `where(...)` immediately executed SQL and returned an array.
Now `where(...)` returns an `Acrc::Relation`.

## Current Flow

```ruby
relation = User.where(role: "member")
relation.loaded?
# => false

relation.to_a
# SQL executes here
```

`Acrc::Relation` stores query intent:

- model class
- where conditions
- bind values
- selected columns
- order clauses
- limit value
- preloaded associations

It executes only when records are needed through `to_a`, `each`, `map`, or
another Enumerable method.

## Composition

Relations are immutable. Calling `where` on a relation returns a new relation:

```ruby
members = User.where(role: "member")
carol = members.where(name: "Carol")
```

`members` still represents all members. `carol` adds the second condition.

The generated SQL uses `AND` between conditions:

```sql
SELECT * FROM users WHERE role = ? AND name = ?
```

Values are still passed as bind parameters.

Array values become simple `IN` conditions:

```ruby
User.where(id: [1, 3])
```

```sql
SELECT * FROM users WHERE id IN (?, ?)
```

This is intentionally small, but it gives preloading a way to fetch multiple
associated records in one query.

`order`, `limit`, and `select` also return new relations:

```ruby
User
  .where(role: "member")
  .order(name: :desc)
  .limit(10)
  .select(:id, :name)
```

The query is still not executed until records are needed.

`select` changes which attributes are loaded. If a column is not selected, the
hydrated model will not have a reader for that column.

`preload` also returns a new relation:

```ruby
Post.all.order(id: :asc).preload(:user)
```

The base query still executes first. After those records are hydrated, the
relation can run additional queries to populate association caches.

## Intentional Limitations

- Only equality and array-backed `IN` `where` conditions are supported.
- `order` supports only `:asc` and `:desc`.
- `limit` supports only one non-negative integer.
- `select` supports only simple column names.
- `preload` currently supports only `belongs_to` associations.
- Loaded records are cached inside the relation, but there is no reload API.
- SQL inspection is available through the adapter query log, not through the
  relation itself.

These limitations keep this step focused on why ActiveRecord-style APIs use
lazy relation objects instead of returning arrays immediately.
