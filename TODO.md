# TODO

This file is the living roadmap for the Ruby ActiveRecord-style ORM
implementation. See `LEARNING_PROJECT.md` for the reusable learning-project
pattern behind this roadmap.

The roadmap is intentionally flexible. Update it whenever the learning goal,
implementation direction, or level of detail changes.

## Current Learning Goal

Build a small ActiveRecord-style ORM in Ruby and use it to understand the
mechanics usually hidden by Rails Active Record and similar persistence
libraries.

Initial focus:

- Database connection and adapter boundaries.
- SQL execution with bind parameters.
- Table-to-model mapping.
- Row hydration into Ruby objects.
- Minimal query APIs such as `find` and `where`.
- Attribute access and type conversion.
- Later exploration of persistence, lazy relations, associations, migrations,
  transactions, validations, callbacks, and diagnostics.

## Core Milestone Status

Core milestone not complete.

The initial core milestone is to make the database-to-object lifecycle visible:
connect to SQLite, execute parameterized SQL, map a row to a Ruby model object,
and expose a tiny query API. Broader ORM behavior should be introduced only
after this first lifecycle is easy to inspect and explain.

## Roadmap

Roadmap sections are learning themes, not single work units.

### 0. Project Setup

- [x] Define the project purpose.
- [x] Create initial project documentation.
- [x] Copy the reusable learning-project pattern.
- [x] Decide the first implementation milestone.
- [ ] Decide the initial Ruby package layout after the first milestone is
  ready to start.
- [ ] Decide how to organize learning notes.

First implementation milestone:

- Build a minimal SQLite-backed model reader.
- Open a database connection through a small adapter boundary.
- Define a model class with an explicit table name and primary key.
- Implement `find(id)` with a bind parameter.
- Hydrate a database row into a model instance with readable attributes.
- Keep writes, relations, associations, migrations, validations, callbacks, and
  transactions out of scope until the basic database-to-object lifecycle is
  visible.

### 1. Minimal Database Connection And Query

- [ ] Initialize the Ruby project structure.
- [ ] Decide whether the first adapter uses the `sqlite3` gem or another
  deliberately small local test database approach.
- [ ] Create a small connection or adapter object.
- [ ] Execute a simple `SELECT` statement.
- [ ] Pass user values through bind parameters.
- [ ] Return result rows in a predictable shape.
- [ ] Add a small example or test database fixture.
- [ ] Document the first SQL execution lifecycle.

Questions to answer:

- What does the database driver expose directly?
- Which behavior should the ORM adapter hide?
- Where do bind parameters enter the SQL execution path?
- What errors should remain driver errors, and what errors should become ORM
  errors?

### 2. Model Class And Row Hydration

- [ ] Define a minimal model base class.
- [ ] Configure or infer a table name.
- [ ] Configure or assume a primary key.
- [ ] Convert a result row into a model instance.
- [ ] Add attribute readers for loaded columns.
- [ ] Decide behavior for unknown attributes.
- [ ] Add tests for row mapping and missing values.
- [ ] Document the table-to-object mapping boundary.

Questions to answer:

- What is the difference between a row hash and a model object?
- Should attributes be generated methods, stored in a hash, or both?
- How much naming convention should exist in the first version?
- When should a model know about its database connection?

### 3. Minimal Finder API

- [ ] Implement `find(id)`.
- [ ] Decide behavior when a row is not found.
- [ ] Implement a minimal `where(column: value)` path.
- [ ] Restrict or validate column names used in generated SQL.
- [ ] Return one model, an array of models, or a relation-like object
  intentionally.
- [ ] Add tests for successful lookup, missing rows, and unsafe values.

Questions to answer:

- Which parts of a query can be safely bound as parameters?
- Why can values be bound, but identifiers need validation or quoting?
- Should `find` raise for missing rows or return nil?
- When does a query API become a query builder?

### 4. Attributes And Type Casting

- [ ] Inspect or declare column metadata.
- [ ] Cast integer, float, string, boolean, time, and nil values where useful.
- [ ] Decide whether type casting happens during hydration or attribute read.
- [ ] Preserve original values for later dirty tracking.
- [ ] Document intentional type-casting limitations.

Questions to answer:

- What type information does SQLite provide?
- Which types belong to the database and which belong to the Ruby model?
- How does Active Record make attributes feel native to Ruby?
- What happens when database values cannot be cast cleanly?

### 5. Persistence

- [ ] Add new-record state.
- [ ] Implement `save` for inserts.
- [ ] Implement `save` or `update` for existing rows.
- [ ] Track changed attributes.
- [ ] Generate `INSERT` and `UPDATE` statements with bind parameters.
- [ ] Implement `destroy` or delete behavior if useful.
- [ ] Add tests for insert, update, delete, and stale object assumptions.

Questions to answer:

- How does an object know whether it represents an existing row?
- Which attributes should be written back to the database?
- What should happen after a successful insert returns a generated primary key?
- Where do database constraints surface in the model API?

### 6. Relation And Query Composition

- [ ] Introduce a relation-like query object when arrays become insufficient.
- [ ] Compose `where`, `order`, `limit`, and `select`.
- [ ] Delay SQL execution until records are needed.
- [ ] Decide when query objects are immutable.
- [ ] Add tests that show when SQL is generated and executed.

Questions to answer:

- Why does Active Record use lazy relation objects?
- What makes query composition easier or harder than direct SQL strings?
- How should multiple conditions combine?
- Which behavior should remain explicit for learning clarity?

### 7. Associations

- [ ] Implement a minimal `belongs_to`.
- [ ] Implement a minimal `has_many`.
- [ ] Decide foreign key naming conventions.
- [ ] Decide lazy loading behavior for associated records.
- [ ] Observe and document N+1 query behavior.
- [ ] Explore eager loading only after lazy associations are clear.

Questions to answer:

- What SQL does an association method hide?
- How are foreign keys derived or configured?
- When should association results be cached?
- Why does eager loading exist?

### 8. Transactions And Constraints

- [ ] Add a transaction API.
- [ ] Commit successful transaction blocks.
- [ ] Roll back on exceptions.
- [ ] Explore nested transactions or savepoints if useful.
- [ ] Surface constraint errors clearly.
- [ ] Add tests for commit, rollback, and nested behavior.

Questions to answer:

- What does the database guarantee inside a transaction?
- How should exceptions control rollback?
- What is the difference between validation failure and constraint failure?
- Why are nested transactions adapter-specific?

### 9. Schema And Migrations

- [ ] Decide whether schema is declared in Ruby or introspected from the
  database.
- [ ] Add a minimal migration runner if useful.
- [ ] Create and alter tables through migration objects or scripts.
- [ ] Track applied migrations.
- [ ] Document schema limitations.

Questions to answer:

- How does model code learn about database columns?
- What problem do migrations solve beyond running SQL manually?
- How should schema changes be tested?
- What does a schema dump make visible?

### 10. Validations, Callbacks, And Lifecycle

- [ ] Add a minimal validation error collection if useful.
- [ ] Validate presence or simple predicates.
- [ ] Decide where validations run in `save`.
- [ ] Add simple lifecycle callbacks only when the persistence lifecycle is
  already clear.
- [ ] Compare the benefits and costs of callbacks.

Questions to answer:

- Which rules belong in Ruby validations versus database constraints?
- How should validation errors be represented?
- Why can callback order become difficult to reason about?
- Which lifecycle hooks are useful for learning, and which add noise?

### 11. Robustness And Diagnostics

- [ ] Add clear ORM-specific error classes.
- [ ] Add optional SQL logging.
- [ ] Include generated SQL and binds in test-friendly diagnostics.
- [ ] Add comparison notes against Rails Active Record for selected behavior.
- [ ] Document known limitations.

Questions to answer:

- What information makes an ORM error actionable?
- How much SQL should be visible when debugging?
- Which Rails Active Record behaviors are intentionally not copied?
- What limitations are acceptable for a learning ORM?

### 12. Optional Advanced Topics

- [ ] Explore connection pooling.
- [ ] Explore prepared statement caching.
- [ ] Explore eager loading and preloading strategies.
- [ ] Explore optimistic locking.
- [ ] Explore single-table inheritance.
- [ ] Explore polymorphic associations.
- [ ] Compare behavior with Sequel or ROM.
- [ ] Explore database adapter differences beyond SQLite.

These are optional directions, not required steps. They should be started only
when there is a specific learning question worth answering.

## Learning Log

Use this section to record notable decisions, discoveries, and direction
changes.

- Initial direction: focus on ActiveRecord-style ORM internals rather than
  building a production-ready replacement for Rails Active Record or other Ruby
  persistence libraries.
- First implementation milestone: start with a SQLite-backed model reader that
  can connect to a database, execute parameterized SQL, load a row, and hydrate
  a Ruby model object before introducing persistence, relations, associations,
  migrations, transactions, validations, or callbacks.
- Initial documentation follows the reusable learning-project pattern copied
  from `_tpeg`.
