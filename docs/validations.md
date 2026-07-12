# Validations

The first validation step adds presence validation.

```ruby
class User < Acrc::Model
  table_name "users"
  validates_presence_of :name
end
```

## Current Flow

```ruby
user = User.new("name" => nil)
user.save
# => false

user.errors
# => { "name" => ["can't be blank"] }
```

1. `save` checks whether the record is destroyed.
2. `save` calls `valid?`.
3. `valid?` clears previous errors.
4. Each configured validation runs against the in-memory attributes.
5. If errors were added, `save` returns `false` and does not execute SQL.
6. If there are no errors, `save` proceeds to insert or update.

## Validation Errors

Validation errors are stored on the model instance:

```ruby
user.errors
```

The current shape is a hash from attribute name to messages:

```ruby
{ "name" => ["can't be blank"] }
```

`errors` returns a copy so callers cannot mutate the model's internal error
state accidentally.

## Validations Versus Constraints

Validations run in Ruby before SQL is sent:

```ruby
User.new("name" => nil).save
# => false
```

Database constraints run in the database after SQL is sent:

```ruby
adapter.execute("INSERT INTO users (name) VALUES (?)", [nil])
# raises Acrc::ConstraintError
```

Both are useful, but they answer different questions:

- validations provide application-level feedback before touching the database
- constraints protect the database even if application code is wrong or bypassed

## Intentional Limitations

- Only presence validation exists.
- `save` returns `false` on validation failure; there is no `save!` yet.
- There is no rich error object, only a hash of messages.
- There is no validation context such as create versus update.
- There are no custom validators yet.
- Validations read current in-memory attributes; they do not load missing
  columns from the database.
- Lifecycle callbacks are not implemented yet.

This step keeps validation focused on the first boundary: stop invalid
in-memory data before generating SQL.
