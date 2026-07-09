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

## Intentional Limitations

- Only equality `where` conditions are supported.
- There is no `order`, `limit`, or `select` yet.
- Loaded records are cached inside the relation, but there is no reload API.
- There is no SQL inspection API yet.

These limitations keep this step focused on why ActiveRecord-style APIs use
lazy relation objects instead of returning arrays immediately.
