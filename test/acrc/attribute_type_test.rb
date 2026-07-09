# frozen_string_literal: true

require "minitest/autorun"

require "acrc"

class AttributeTypeTest < Minitest::Test
  class User < Acrc::Model
    table_name "users"
    attribute :id, :integer
    attribute :age, :integer
    attribute :score, :float
    attribute :name, :string
    attribute :admin, :boolean
    attribute :created_at, :time
  end

  def test_declared_attributes_are_cast_during_hydration
    user = User.hydrate(
      "id" => "1",
      "age" => "42",
      "score" => "9.5",
      "name" => :Alice,
      "admin" => "true",
      "created_at" => "2026-07-09 10:30:00 UTC"
    )

    assert_equal 1, user.id
    assert_equal 42, user.age
    assert_in_delta 9.5, user.score
    assert_equal "Alice", user.name
    assert_equal true, user.admin
    assert_equal Time.utc(2026, 7, 9, 10, 30, 0), user.created_at
  end

  def test_nil_values_are_preserved
    user = User.hydrate("age" => nil, "admin" => nil, "created_at" => nil)

    assert_nil user.age
    assert_nil user.admin
    assert_nil user.created_at
  end

  def test_undeclared_attributes_keep_driver_values
    user = User.hydrate("nickname" => :ally)

    assert_equal :ally, user.nickname
  end

  def test_invalid_cast_raises_an_orm_error
    error = assert_raises(Acrc::TypeCastError) do
      User.hydrate("age" => "not-a-number")
    end

    assert_equal 'could not cast age to integer: "not-a-number"', error.message
  end

  def test_invalid_boolean_cast_raises_an_orm_error
    error = assert_raises(Acrc::TypeCastError) do
      User.hydrate("admin" => "maybe")
    end

    assert_equal 'could not cast admin to boolean: "maybe"', error.message
  end

  def test_unknown_attribute_type_is_rejected
    error = assert_raises(Acrc::UnknownTypeError) do
      Class.new(Acrc::Model) do
        attribute :metadata, :json
      end
    end

    assert_equal "unknown attribute type: :json", error.message
  end

  def test_original_attributes_preserves_the_loaded_baseline
    user = User.hydrate("age" => "42")

    original = user.original_attributes
    original["age"] = 99

    assert_equal({ "age" => 42 }, user.original_attributes)
    assert_equal 42, user.age
  end
end
