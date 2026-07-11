# Associations

The first association steps add `belongs_to` and `has_many`.

The APIs are intentionally explicit:

```ruby
class User < Acrc::Model
  table_name "users"
end

class Post < Acrc::Model
  table_name "posts"
  belongs_to :user, class_name: User, foreign_key: :user_id
end

User.has_many :posts, class_name: Post, foreign_key: :user_id
```

This avoids naming conventions for now and keeps the hidden SQL easy to see.

## `belongs_to` Flow

```ruby
post = Post.find(1)
post.user
```

1. The `user` method reads `post[:user_id]`.
2. If the foreign key is nil, the association returns nil.
3. Otherwise it calls `User.find(post.user_id)`.
4. `User.find` executes a normal primary-key query and hydrates a `User`.

The association method therefore hides a second query:

```sql
SELECT * FROM users WHERE id = ?
```

## `has_many` Flow

```ruby
user = User.find(1)
user.posts
```

1. The `posts` method reads `user[:id]`.
2. It returns `Post.where("user_id" => user.id)`.
3. No SQL is executed until the returned relation is enumerated or converted to
   an array.

The association method therefore hides a query shape, but still leaves the
query lazy and composable:

```ruby
user.posts.where(title: "Hello").order(id: :desc).limit(1).to_a
```

The final SQL is still executed by `Relation#to_a`, just like a normal query:

```sql
SELECT * FROM posts WHERE user_id = ? AND title = ? ORDER BY id DESC LIMIT ?
```

Returning a relation instead of an array matters because callers can keep
adding query constraints before the database is touched.

## N+1 Query Behavior

Lazy association methods make object access convenient, but they can also hide
repeated SQL.

```ruby
adapter.clear_query_log
posts = Post.all.order(id: :asc).to_a
posts.map { |post| post.user&.name }
adapter.query_log
```

With three posts that point at users and one orphan post, the observed SELECT
queries look like this:

```ruby
[
  { sql: "SELECT * FROM posts ORDER BY id ASC", binds: [] },
  { sql: "SELECT * FROM users WHERE id = ?", binds: [1] },
  { sql: "SELECT * FROM users WHERE id = ?", binds: [1] },
  { sql: "SELECT * FROM users WHERE id = ?", binds: [2] }
]
```

The first query loads the post collection. Each `post.user` call then performs
its own lookup unless the foreign key is nil. Even the repeated `user_id = 1`
lookup runs twice because `_acrc` does not cache association results and does
not have an identity map.

This is the classic N+1 shape:

- 1 query for the parent or source collection.
- N additional queries caused by lazy association access while iterating that
  collection.

The next concepts that normally address this are preloading or eager loading,
but this project intentionally observes the problem before adding the solution.

## Minimal `belongs_to` Preloading

`preload(:user)` reduces the N+1 shape by loading all needed users in one
additional query:

```ruby
adapter.clear_query_log
posts = Post.all.order(id: :asc).preload(:user).to_a
posts.map { |post| post.user&.name }
adapter.query_log
```

The observed SELECT queries now look like this:

```ruby
[
  { sql: "SELECT * FROM posts ORDER BY id ASC", binds: [] },
  { sql: "SELECT * FROM users WHERE id IN (?, ?)", binds: [1, 2] }
]
```

The relation still loads posts first. After the posts are hydrated, preload:

1. Reads each post's `user_id`.
2. Removes nil and duplicate foreign key values.
3. Loads matching users with `WHERE id IN (?, ?)`.
4. Stores each loaded user in the post's association cache.

After that, calling `post.user` reads the cached association instead of running
another `User.find(...)` query.

This is preloading, not a SQL join. The post rows and user rows are still loaded
by separate SELECT statements.

## Intentional Limitations

- `belongs_to` requires explicit `class_name` and `foreign_key`.
- `has_many` requires explicit `class_name` and `foreign_key`.
- Association results are cached only when `preload` sets them.
- `preload` currently supports only `belongs_to`.
- There is no JOIN-based eager loading yet.
- There is no inverse relationship handling.
- There is no `has_many` preloading yet.
- A `has_many` call on a record without a loaded primary key raises an unknown
  attribute error.
- A nil primary key currently builds a `WHERE foreign_key = NULL` query, which
  SQLite does not treat as `IS NULL`.

These limitations keep this step focused on the SQL hidden behind a
single-record association method, a collection association method, and the
first batched association load.
