# _acrc

`_acrc` is a learning-oriented ActiveRecord-style ORM implementation in Ruby.

The goal of this project is not to build a production-ready replacement for
Rails Active Record, Sequel, ROM, or other mature Ruby persistence libraries.
The goal is to understand what sits underneath the ORM APIs we usually use:
database connections, SQL execution, model mapping, table conventions,
attribute handling, query construction, lazy relations, persistence,
associations, transactions, schema changes, validations, callbacks, and the
tradeoffs between convenience and explicit behavior.

## Purpose

This project is for studying ActiveRecord and ORM internals step by step.

This repository follows the learning-project approach described in
`LEARNING_PROJECT.md`: small milestones, inspectable changes, and optional
advanced topics after the core goal is met.

The project assumes that the learner is already comfortable with Ruby and basic
backend or Web development. Therefore, the focus is not on basic Ruby syntax or
ordinary application structure, but on deeper implementation details behind an
ActiveRecord-style data mapper and persistence layer.

## Learning Topics

This project may cover topics such as:

- Database connections: adapter boundaries, connection lifecycle, error
  handling, and why an ORM usually hides raw driver objects.
- SQL execution: prepared statements, bind parameters, result rows, type
  conversion, and SQL injection boundaries.
- Model mapping: table names, primary keys, column metadata, row-to-object
  hydration, and object identity tradeoffs.
- Attributes: generated accessors, dirty tracking, default values, type
  casting, nil handling, and serialization decisions.
- Query API: `find`, `where`, `order`, `limit`, `select`, query composition,
  lazy relations, and when SQL is executed.
- Persistence: `insert`, `update`, `delete`, timestamps, partial updates,
  optimistic locking, and validation boundaries.
- Associations: `belongs_to`, `has_many`, foreign keys, eager loading, N+1
  queries, and inverse relationship behavior.
- Transactions: commit, rollback, nested transaction behavior, savepoints, and
  exception handling.
- Schema changes: migrations, schema dumps, column introspection, and how model
  code depends on database shape.
- Validations and callbacks: lifecycle hooks, error collection, callback order,
  and why these features can become hard to reason about.
- Robustness: diagnostics, SQL logging, test databases, deterministic examples,
  and behavior comparisons with Rails Active Record.

## Non-goals

The following are not the main focus of this project:

- Building a full production-ready ORM.
- Replacing Rails Active Record, Sequel, ROM, or direct SQL usage.
- Supporting every SQL database or every Rails Active Record feature.
- Building a complete Web framework around the ORM.
- Prioritizing API breadth over implementation understanding.

Some production-oriented topics may still be explored when they help explain how
real ActiveRecord-style ORMs behave.

## Core Milestone

The core learning milestone is not complete yet.

The first core target is to build a tiny SQLite-backed model layer that can:

- Open a database connection through a small adapter boundary.
- Map a Ruby model class to a database table.
- Load rows into model instances.
- Provide a minimal read API such as `find` and `where`.
- Use bind parameters rather than string interpolation for user values.
- Include tests or examples that make the raw SQL and object mapping visible.

Further persistence, relations, associations, validations, callbacks,
transactions, migrations, and Rails Active Record comparisons should be treated
as later learning steps.

## Approach

The preferred starting point is a deliberately tiny ORM surface:

1. Connect to a local SQLite database.
2. Execute a simple SQL query through a small adapter object.
3. Define a model class with an explicit table name and primary key.
4. Hydrate result rows into model instances with attribute readers.
5. Implement `find(id)` using a bind parameter.
6. Implement a minimal `where(column: value)` query path.
7. Add persistence, lazy relations, associations, migrations, transactions, and
   diagnostics only after the basic database-to-object lifecycle is visible.

The detailed learning-project operating pattern is documented in
`LEARNING_PROJECT.md`.

## Running the Current ORM

The current implementation has a minimal SQLite adapter, model hydration, lazy
relations, explicit attribute type casting, insert/update persistence, dirty
tracking, and destroy behavior.

Run the tests:

```sh
bundle install
bundle exec ruby -Itest -Ilib -e 'Dir["test/**/*_test.rb"].sort.each { |path| load path }'
```

Run a small query example:

```sh
bundle exec ruby -Ilib -e 'require "acrc"; db = Acrc::SQLiteAdapter.new(":memory:"); db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"); db.execute("INSERT INTO users (name) VALUES (?)", ["Ruby"]); p db.execute("SELECT id, name FROM users WHERE name = ?", ["Ruby"]); db.close'
```

Run a small hydration example:

```sh
bundle exec ruby -Ilib -e 'require "acrc"; class User < Acrc::Model; table_name "users"; end; user = User.hydrate("id" => 1, "name" => "Ruby"); puts user.name'
```

Run a small finder example:

```sh
bundle exec ruby -Ilib -e 'require "acrc"; db = Acrc::SQLiteAdapter.new(":memory:"); db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"); db.execute("INSERT INTO users (name) VALUES (?)", ["Ruby"]); class User < Acrc::Model; table_name "users"; end; User.connection db; puts User.find(1).name; db.close'
```

Run a small relation example:

```sh
bundle exec ruby -Ilib -e 'require "acrc"; db = Acrc::SQLiteAdapter.new(":memory:"); db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, role TEXT)"); db.execute("INSERT INTO users (name, role) VALUES (?, ?)", ["Ruby", "member"]); class User < Acrc::Model; table_name "users"; end; User.connection db; relation = User.where(role: "member"); p relation.loaded?; p relation.map(&:name); db.close'
```

Run a small type-casting example:

```sh
bundle exec ruby -Ilib -e 'require "acrc"; class User < Acrc::Model; attribute :age, :integer; attribute :admin, :boolean; end; user = User.hydrate("age" => "42", "admin" => "true"); p [user.age, user.admin]'
```

Run a small insert example:

```sh
bundle exec ruby -Ilib -e 'require "acrc"; db = Acrc::SQLiteAdapter.new(":memory:"); db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"); class User < Acrc::Model; table_name "users"; attribute :id, :integer; end; User.connection db; user = User.new("name" => "Ruby"); user.save; p [user.id, User.find(user.id).name]; db.close'
```

Run a small update example:

```sh
bundle exec ruby -Ilib -e 'require "acrc"; db = Acrc::SQLiteAdapter.new(":memory:"); db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"); db.execute("INSERT INTO users (name) VALUES (?)", ["Ruby"]); class User < Acrc::Model; table_name "users"; attribute :id, :integer; end; User.connection db; user = User.find(1); user.name = "Acrc"; user.save; p User.find(1).name; db.close'
```

Run a small destroy example:

```sh
bundle exec ruby -Ilib -e 'require "acrc"; db = Acrc::SQLiteAdapter.new(":memory:"); db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)"); db.execute("INSERT INTO users (name) VALUES (?)", ["Ruby"]); class User < Acrc::Model; table_name "users"; attribute :id, :integer; end; User.connection db; user = User.find(1); user.destroy; p [user.destroyed?, User.where(id: 1).length]; db.close'
```

The adapter opens a SQLite database, executes SQL with bind parameters, and
returns result rows as hashes keyed by column name strings. `Acrc::Model` can
hydrate one of those rows into a Ruby object with readable attributes. `find`
connects model metadata to SQL execution. `where` returns a lazy relation that
can compose query conditions before loading records. Query generation validates
SQL identifiers and binds user values. Declared attributes are cast during
hydration so model readers return Ruby-friendly values. `save` can insert new
records and store a generated SQLite primary key back on the model. Persisted
records track changes and `save` updates changed columns. `destroy` deletes the
row and marks the object destroyed.

## Project Documents

- `README.md`: project purpose, scope, and high-level learning direction.
- `AGENTS.md`: working instructions for AI agents and future contributors.
- `LEARNING_PROJECT.md`: reusable AI-assisted learning project pattern.
- `TODO.md`: living learning roadmap and progress tracker.
- `docs/sql-execution.md`: notes on the first SQLite SQL execution boundary.
- `docs/model-hydration.md`: notes on the first row-to-model mapping boundary.
- `docs/finder-api.md`: notes on the first model query API boundary.
- `docs/attributes-and-type-casting.md`: notes on explicit attribute type
  declarations and hydration-time casting.
- `docs/persistence-insert.md`: notes on the first new-record insert path.
- `docs/persistence-update.md`: notes on dirty tracking and existing-record
  updates.
- `docs/persistence-destroy.md`: notes on delete behavior and destroyed object
  state.
- `docs/stale-records.md`: notes on affected-row checks and stale record
  detection.
- `docs/relation-query-composition.md`: notes on lazy relations and query
  composition.
