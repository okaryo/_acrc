# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "acrc"

class ModelFinderTest < Minitest::Test
  class User < Acrc::Model
    table_name "users"
  end

  def setup
    @dir = Dir.mktmpdir("acrc-test-")
    @adapter = Acrc::SQLiteAdapter.new(File.join(@dir, "test.sqlite3"))
    @adapter.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, role TEXT NOT NULL)")
    @adapter.execute("INSERT INTO users (name, role) VALUES (?, ?)", ["Alice", "admin"])
    @adapter.execute("INSERT INTO users (name, role) VALUES (?, ?)", ["Bob", "member"])
    @adapter.execute("INSERT INTO users (name, role) VALUES (?, ?)", ["Carol", "member"])
    User.connection @adapter
  end

  def teardown
    @adapter.close
    FileUtils.remove_entry(@dir)
  end

  def test_find_loads_one_model_by_primary_key
    user = User.find(1)

    assert_instance_of User, user
    assert_equal 1, user.id
    assert_equal "Alice", user.name
  end

  def test_find_raises_when_the_row_is_missing
    error = assert_raises(Acrc::RecordNotFound) do
      User.find(99)
    end

    assert_equal "could not find ModelFinderTest::User with id=99", error.message
  end

  def test_where_returns_matching_models_as_an_array
    users = User.where(role: "member")

    assert_equal ["Bob", "Carol"], users.map(&:name)
    assert users.all? { |user| user.is_a?(User) }
  end

  def test_where_combines_multiple_conditions
    users = User.where(role: "member", name: "Carol")

    assert_equal ["Carol"], users.map(&:name)
  end

  def test_where_uses_bind_parameters_for_values
    suspicious_name = "Alice' OR 1 = 1 --"
    @adapter.execute("INSERT INTO users (name, role) VALUES (?, ?)", [suspicious_name, "member"])

    users = User.where(name: suspicious_name)

    assert_equal [suspicious_name], users.map(&:name)
  end

  def test_where_rejects_unsafe_column_names
    error = assert_raises(Acrc::InvalidIdentifierError) do
      User.where("name OR 1 = 1" => "Alice")
    end

    assert_equal 'invalid column name: "name OR 1 = 1"', error.message
  end

  def test_find_rejects_unsafe_table_names
    unsafe_model = Class.new(Acrc::Model) do
      table_name "users; DROP TABLE users"
      connection User.connection
    end

    error = assert_raises(Acrc::InvalidIdentifierError) do
      unsafe_model.find(1)
    end

    assert_equal 'invalid table name: "users; DROP TABLE users"', error.message
  end

  def test_find_requires_a_connection
    disconnected_model = Class.new(Acrc::Model) do
      table_name "users"
    end

    error = assert_raises(Acrc::ConfigurationError) do
      disconnected_model.find(1)
    end

    assert_equal "model connection is not configured", error.message
  end
end
