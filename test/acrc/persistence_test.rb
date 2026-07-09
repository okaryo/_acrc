# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "acrc"

class PersistenceTest < Minitest::Test
  class User < Acrc::Model
    table_name "users"
    attribute :id, :integer
    attribute :age, :integer
  end

  def setup
    @dir = Dir.mktmpdir("acrc-test-")
    @adapter = Acrc::SQLiteAdapter.new(File.join(@dir, "test.sqlite3"))
    @adapter.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, age INTEGER)")
    User.connection @adapter
  end

  def teardown
    @adapter.close
    FileUtils.remove_entry(@dir)
  end

  def test_new_instances_start_as_new_records
    user = User.new("name" => "Alice", "age" => "42")

    assert user.new_record?
    refute user.persisted?
    assert_equal 42, user.age
    assert_equal({}, user.original_attributes)
  end

  def test_hydrated_instances_start_as_persisted_records
    user = User.hydrate("id" => "1", "name" => "Alice")

    refute user.new_record?
    assert user.persisted?
    assert_equal({ "id" => 1, "name" => "Alice" }, user.original_attributes)
  end

  def test_save_inserts_a_new_record_and_stores_generated_primary_key
    user = User.new("name" => "Alice", "age" => "42")

    assert_equal true, user.save

    refute user.new_record?
    assert user.persisted?
    assert_equal 1, user.id
    assert_equal({ "id" => 1, "name" => "Alice", "age" => 42 }, user.original_attributes)

    rows = @adapter.execute("SELECT id, name, age FROM users")
    assert_equal [{ "id" => 1, "name" => "Alice", "age" => 42 }], rows
  end

  def test_save_uses_bind_parameters_for_insert_values
    suspicious_name = "Alice'); DROP TABLE users; --"
    user = User.new("name" => suspicious_name, "age" => 42)

    user.save

    rows = @adapter.execute("SELECT name FROM users WHERE id = ?", [user.id])
    assert_equal [{ "name" => suspicious_name }], rows
  end

  def test_save_can_insert_an_explicit_primary_key
    user = User.new("id" => "10", "name" => "Alice")

    user.save

    assert_equal 10, user.id
    assert_equal [{ "id" => 10, "name" => "Alice" }], @adapter.execute("SELECT id, name FROM users")
  end

  def test_save_requires_a_connection
    disconnected_model = Class.new(Acrc::Model) do
      table_name "users"
    end

    error = assert_raises(Acrc::ConfigurationError) do
      disconnected_model.new("name" => "Alice").save
    end

    assert_equal "model connection is not configured", error.message
  end

  def test_save_on_persisted_records_is_deferred
    user = User.new("name" => "Alice")
    user.save

    error = assert_raises(Acrc::NotImplementedError) do
      user.save
    end

    assert_equal "updating existing records is not implemented yet", error.message
  end
end
