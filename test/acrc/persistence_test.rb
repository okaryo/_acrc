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
    refute user.destroyed?
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

  def test_save_updates_persisted_records
    user = User.new("name" => "Alice")
    user.save

    user.name = "Bob"
    user.save

    assert_equal [{ "name" => "Bob" }], @adapter.execute("SELECT name FROM users WHERE id = ?", [user.id])
  end

  def test_writer_tracks_changes_on_persisted_records
    user = User.new("name" => "Alice", "age" => 42)
    user.save

    user.name = "Bob"
    user.age = "43"

    assert user.changed?
    assert_equal(
      { "name" => ["Alice", "Bob"], "age" => [42, 43] },
      user.changes
    )
  end

  def test_save_updates_only_changed_attributes_and_resets_dirty_state
    user = User.new("name" => "Alice", "age" => 42)
    user.save

    user.name = "Bob"
    user.save

    assert_equal [{ "name" => "Bob", "age" => 42 }], @adapter.execute("SELECT name, age FROM users")
    refute user.changed?
    assert_equal({ "id" => 1, "name" => "Bob", "age" => 42 }, user.original_attributes)
  end

  def test_save_without_changes_keeps_persisted_record_unchanged
    user = User.new("name" => "Alice", "age" => 42)
    user.save

    assert_equal true, user.save

    assert_equal [{ "name" => "Alice", "age" => 42 }], @adapter.execute("SELECT name, age FROM users")
    refute user.changed?
  end

  def test_update_uses_bind_parameters_for_changed_values
    user = User.new("name" => "Alice", "age" => 42)
    user.save
    suspicious_name = "Bob', age = 100 --"

    user.name = suspicious_name
    user.save

    assert_equal(
      [{ "name" => suspicious_name, "age" => 42 }],
      @adapter.execute("SELECT name, age FROM users WHERE id = ?", [user.id])
    )
  end

  def test_update_requires_a_primary_key_value
    user = User.hydrate("name" => "Alice", "age" => 42)
    user.name = "Bob"

    error = assert_raises(Acrc::UnknownAttributeError) do
      user.save
    end

    assert_equal "unknown attribute: id", error.message
  end

  def test_destroy_deletes_a_persisted_record
    user = User.new("name" => "Alice", "age" => 42)
    user.save

    returned = user.destroy

    assert_same user, returned
    refute user.new_record?
    refute user.persisted?
    assert user.destroyed?
    assert_equal [], @adapter.execute("SELECT * FROM users WHERE id = ?", [user.id])
  end

  def test_destroy_on_a_new_record_marks_it_destroyed_without_sql_delete
    user = User.new("name" => "Alice")

    user.destroy

    refute user.new_record?
    refute user.persisted?
    assert user.destroyed?
  end

  def test_destroy_requires_a_primary_key_value_for_persisted_records
    user = User.hydrate("name" => "Alice", "age" => 42)

    error = assert_raises(Acrc::UnknownAttributeError) do
      user.destroy
    end

    assert_equal "unknown attribute: id", error.message
  end

  def test_destroyed_records_cannot_be_saved
    user = User.new("name" => "Alice")
    user.save
    user.destroy

    error = assert_raises(Acrc::DestroyedRecordError) do
      user.save
    end

    assert_equal "cannot save a destroyed record", error.message
  end

  def test_save_detects_a_stale_record_when_update_affects_no_rows
    user = User.new("name" => "Alice")
    user.save
    @adapter.execute("DELETE FROM users WHERE id = ?", [user.id])

    user.name = "Bob"
    error = assert_raises(Acrc::StaleRecordError) do
      user.save
    end

    assert_equal "attempted to update or delete a stale PersistenceTest::User", error.message
    assert user.changed?
  end

  def test_destroy_detects_a_stale_record_when_delete_affects_no_rows
    user = User.new("name" => "Alice")
    user.save
    @adapter.execute("DELETE FROM users WHERE id = ?", [user.id])

    error = assert_raises(Acrc::StaleRecordError) do
      user.destroy
    end

    assert_equal "attempted to update or delete a stale PersistenceTest::User", error.message
    assert user.persisted?
    refute user.destroyed?
  end
end
