# Transactions

The first transaction step adds a minimal block API:

```ruby
User.transaction do
  User.new("name" => "Alice").save
  User.new("name" => "Bob").save
end
```

The model delegates to its configured adapter. The adapter then sends explicit
transaction control statements to SQLite:

```sql
BEGIN
INSERT INTO users (name) VALUES (?)
INSERT INTO users (name) VALUES (?)
COMMIT
```

## Current Flow

1. `Model.transaction` checks that the model has a configured connection.
2. The adapter executes `BEGIN`.
3. The block runs normal ORM work such as `save`, `destroy`, and queries.
4. If the block completes, the adapter executes `COMMIT`.
5. If the block raises, the adapter executes `ROLLBACK` and re-raises the
   original exception.

This makes a group of writes atomic at the database level. Either all writes in
the block commit, or none of them remain after rollback.

## Return Value

The transaction method returns the block value after a successful commit:

```ruby
result = User.transaction do
  User.new("name" => "Alice").save
  "created"
end

result
# => "created"
```

## Rollback

Rollback is controlled by exceptions:

```ruby
User.transaction do
  User.new("name" => "Alice").save
  raise "boom"
end
```

The inserted row is rolled back because the exception exits the block before
commit. The exception is not swallowed; callers still see it.

## Constraint Errors

SQLite constraint failures are wrapped as `Acrc::ConstraintError`, which is a
subclass of `Acrc::DatabaseError`.

```ruby
User.transaction do
  User.new("name" => "Alice").save
  User.new("name" => nil).save
end
```

If the database table has `name TEXT NOT NULL`, the second insert raises:

```ruby
Acrc::ConstraintError
```

Because the error exits the transaction block, the adapter rolls back the whole
transaction. The first insert is not committed either.

This is different from a validation error. A validation would be Ruby code
checking data before SQL is sent. A constraint error means SQL reached the
database and the database rejected it.

## Intentional Limitations

- Nested transactions are rejected for now.
- Savepoints are not implemented yet.
- There is no special rollback-only exception like Active Record's
  `ActiveRecord::Rollback`.
- Object state is not rewound after rollback. If a model instance changes its
  in-memory state before rollback, the database may roll back while the Ruby
  object still reflects the attempted write.
- Constraint errors are classified, but not yet split into specific subclasses
  such as not-null, unique, or foreign-key errors.

These limitations keep the first step focused on the database boundary:
`BEGIN`, ordinary work, then either `COMMIT` or `ROLLBACK`.
