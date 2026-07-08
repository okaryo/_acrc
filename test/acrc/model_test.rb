# frozen_string_literal: true

require "minitest/autorun"

require "acrc"

class ModelTest < Minitest::Test
  class User < Acrc::Model
    table_name "users"
  end

  class Post < Acrc::Model
    table_name "posts"
    primary_key "uuid"
  end

  def test_table_name_is_explicit
    assert_equal "users", User.table_name
  end

  def test_primary_key_defaults_to_id
    assert_equal "id", User.primary_key
  end

  def test_primary_key_can_be_configured
    assert_equal "uuid", Post.primary_key
  end

  def test_hydrate_converts_a_row_hash_into_a_model_instance
    user = User.hydrate("id" => 1, "name" => "Alice")

    assert_instance_of User, user
    assert_equal 1, user.id
    assert_equal "Alice", user.name
  end

  def test_hydrate_accepts_symbol_keys_but_stores_string_attribute_names
    user = User.hydrate(id: 1, name: "Alice")

    assert_equal 1, user["id"]
    assert_equal 1, user[:id]
    assert_equal({ "id" => 1, "name" => "Alice" }, user.attributes)
  end

  def test_attributes_returns_a_copy
    user = User.hydrate("id" => 1, "name" => "Alice")

    copy = user.attributes
    copy["name"] = "Bob"

    assert_equal "Alice", user.name
  end

  def test_unknown_index_attribute_raises_an_orm_error
    user = User.hydrate("id" => 1)

    error = assert_raises(Acrc::UnknownAttributeError) do
      user[:name]
    end

    assert_equal "unknown attribute: name", error.message
  end

  def test_reader_is_only_defined_for_columns_loaded_on_that_instance
    user = User.hydrate("id" => 1)

    refute_respond_to user, :name
  end
end
