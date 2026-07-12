# Callbacks

The first callback step adds `before_save` and `after_save`.

```ruby
class User < Acrc::Model
  table_name "users"

  before_save :normalize_name
  after_save :remember_saved_name

  private

  def normalize_name
    self.name = name.strip
  end

  def remember_saved_name
    # observe that the save completed
  end
end
```

## Current Save Flow

The current `save` order is:

1. Raise if the record is destroyed.
2. Run validations.
3. Return `false` if validations failed.
4. Run `before_save` callbacks.
5. Insert or update the row.
6. Run `after_save` callbacks.
7. Return `true`.

This means callbacks do not run when validation fails.

## Method Callbacks And Block Callbacks

Callbacks can be registered by method name:

```ruby
before_save :normalize_name
```

or by block:

```ruby
before_save do
  self[:role] = "member"
end
```

Method callbacks are called with `send`, so private callback methods can be used.
Block callbacks run with `instance_exec`, so `self` is the model instance.

## Inheritance

Callbacks are inherited. Parent callbacks run before child callbacks for the
same callback kind:

```ruby
class User < Acrc::Model
  before_save :normalize_name
end

class Admin < User
  before_save :set_admin_role
end
```

`Admin#save` runs `normalize_name` and then `set_admin_role`.

## Why Callbacks Are Useful And Risky

Callbacks are useful for colocating lifecycle behavior with the model. For
example, a model can normalize attributes before every save.

They are risky because they hide work behind ordinary method calls. `save` may
change attributes, run extra Ruby code, or raise from callback code even when
the caller only sees `user.save`.

## Intentional Limitations

- Only `before_save` and `after_save` exist.
- Callback chains cannot be halted except by raising an exception.
- There is no `before_validation` or `after_commit`.
- There are no transaction-aware callbacks.
- Callback order is simple parent-first inheritance plus local declaration
  order.
- There is no callback removal or conditional callback support.

This step keeps lifecycle behavior visible while showing why callbacks can make
save behavior harder to reason about.
