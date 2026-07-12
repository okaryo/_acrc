# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"

require "acrc"

class SchemaTest < Minitest::Test
  class User < Acrc::Model
    table_name "users"
    attribute :id, :integer
  end

  def setup
    @dir = Dir.mktmpdir("acrc-test-")
    @adapter = Acrc::SQLiteAdapter.new(File.join(@dir, "test.sqlite3"))
    @adapter.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, age INTEGER DEFAULT 0)")
    User.connection @adapter
  end

  def teardown
    @adapter.close
    FileUtils.remove_entry(@dir)
  end

  def test_model_columns_reads_the_database_schema
    columns = User.columns

    assert_equal ["id", "name", "age"], columns.map(&:name)
    assert_equal ["INTEGER", "TEXT", "INTEGER"], columns.map(&:type)
    assert_equal [false, false, true], columns.map(&:nullable)
    assert_equal [true, false, false], columns.map(&:primary_key)
    assert_equal [nil, nil, "0"], columns.map(&:default)
  end

  def test_model_column_names_returns_names_only
    assert_equal ["id", "name", "age"], User.column_names
  end

  def test_model_columns_requires_a_connection
    disconnected_model = Class.new(Acrc::Model) do
      table_name "users"
    end

    error = assert_raises(Acrc::ConfigurationError) do
      disconnected_model.columns
    end

    assert_equal "model connection is not configured", error.message
  end

  def test_schema_introspection_does_not_define_attribute_types
    assert_equal({ "id" => :integer }, User.attribute_types)
  end
end
