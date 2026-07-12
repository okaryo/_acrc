# Rails Active Record Comparison

`_acrc` intentionally borrows some Rails Active Record surface ideas, but it
does not try to copy Rails behavior completely. The goal is to make the
underlying ORM mechanics visible.

## Similar Shapes

Some APIs are deliberately familiar:

```ruby
User.find(1)
User.where(name: "Alice")
user.save
user.save!
user.destroy
Post.preload(:user)
User.transaction { user.save! }
```

These names are useful because they let the project focus on implementation
questions:

- When does SQL execute?
- Which values are bound parameters?
- How does a row become a model object?
- Where do validations and callbacks run?
- What happens when a transaction block raises?

## Important Differences

| Topic | `_acrc` | Rails Active Record |
| --- | --- | --- |
| Table naming | Explicit `table_name` is required. | Convention-based table names are inferred from class names. |
| Schema knowledge | Column introspection exists, but model attribute types are manual. | Schema metadata is deeply integrated into model attributes and type casting. |
| Query API | `where`, `order`, `limit`, `select`, and `preload` cover a small subset. | Relations support a much broader query algebra. |
| Loading | Relations execute when enumerated with methods such as `to_a`, `map`, or `each`. | Rails relations are also lazy, with many more loading and caching rules. |
| Validations | Only simple presence validation exists. | Many validators, custom validators, contexts, and error object behavior exist. |
| Callbacks | Only `before_save` and `after_save` exist. | Many lifecycle callback points exist across validation, persistence, destroy, commit, and rollback. |
| Associations | Minimal `belongs_to`, `has_many`, and `belongs_to` preloading. | Rich association reflections, scopes, dependent behavior, inverse handling, through associations, polymorphism, and more. |
| Transactions | Adapter-level block transactions with SQLite savepoints. | Connection-managed transactions across adapters with more integration around callbacks and exception behavior. |
| Errors | Small project-specific error classes. | A broad hierarchy of Active Record errors with adapter-specific mapping. |

## `save` And `save!`

`_acrc` mirrors the common non-bang versus bang split:

```ruby
user.save
# => false when validations fail

user.save!
# raises Acrc::ValidationError when validations fail
```

This is close to the Rails convention, but the error object is intentionally
small. It keeps the invalid record available through `error.record`, while the
model stores validation messages in a plain hash.

The learning point is the control-flow choice:

- `save` treats validation failure as an expected branch.
- `save!` treats validation failure as an exception, which is useful inside
  transactions and internal workflows.

## Relation Laziness

`_acrc` uses lazy relations so chained query methods can compose SQL before
execution:

```ruby
relation = User.where(role: "member").order(name: :asc).limit(10)
relation.loaded?
# => false

relation.to_a
# SQL executes here
```

Rails Active Record relations follow the same broad idea, but with many more
rules around query merging, association scopes, loaded relation state, counting,
calculations, eager loading, and SQL generation.

`_acrc` keeps the lazy boundary easy to inspect by exposing `loaded?` and an
adapter query log.

## Preloading

`_acrc` currently supports only `belongs_to` preloading:

```ruby
Post.preload(:user).to_a
```

The relation first loads posts, then runs a second query for the needed users
with an `IN` condition, and finally stores each user in the post association
cache.

Rails Active Record supports more association shapes and also has multiple
loading strategies such as preload-style separate queries and JOIN-based eager
loading. `_acrc` keeps only the separate-query version because it makes the
N+1 query problem and the batching solution easier to observe.

## Callbacks

`_acrc` callbacks are intentionally narrow:

```ruby
before_save :normalize_name
after_save { audit_change }
```

They run after validation and around insert/update. There is no callback
halting protocol, no `before_validation`, no `after_commit`, and no destroy
callbacks.

This makes the hidden-control-flow cost visible without reproducing the full
Rails lifecycle.

## Intentional Non-Copies

`_acrc` intentionally does not copy these Rails Active Record features yet:

- automatic naming conventions
- pluralization and inflection
- default scopes
- scopes as composable class methods
- rich `ActiveModel::Errors` behavior
- validation contexts
- association scopes and dependent behavior
- `has_many :through`
- polymorphic associations
- eager loading through JOINs
- callbacks around commit and rollback
- timestamps such as `created_at` and `updated_at`
- connection pooling
- prepared statement caching
- adapter support beyond SQLite

Each of those features can be useful, but adding them too early would hide the
basic boundaries this project is trying to study.

